"""Pure transformations for the observed fresh-VM appearance problems."""
import json
import re
import shlex

MARKER = 'SUMI_QUIET_BOOT_V1'
AWK_FUNCTION = r'''
# SUMI_QUIET_BOOT_V1: preserve kernel arguments; omit normal loading notices.
function sumi_quiet_boot(text, lines, count, i, output) {
    count = split(text, lines, "\n")
    output = ""
    for (i = 1; i <= count; i++) {
        if (lines[i] ~ /^[ \t]*echo[ \t]+'Loading (Linux|initial ramdisk)[^']*'[ \t]*$/)
            continue
        output = output (output == "" ? "" : "\n") lines[i]
    }
    return output
}
'''


def quiet_defaults(text):
    expression = r'(?m)^([ \t]*GRUB_CMDLINE_LINUX_DEFAULT[ \t]*=[ \t]*)([\'"])([^\n]*?)\2([ \t]*)$'
    matches = list(re.finditer(expression, text))
    if len(matches) != 1:
        raise RuntimeError('Expected exactly one quoted GRUB_CMDLINE_LINUX_DEFAULT assignment; preserved')
    match = matches[0]
    raw = match.group(3)
    if any(char in raw for char in '$`\\\'"'):
        raise RuntimeError('Dynamic GRUB boot arguments preserved')
    arguments = shlex.split(raw)
    arguments = [arg for arg in arguments if not arg.startswith(('systemd.show_status=', 'rd.systemd.show_status='))]
    for arg in ['quiet', 'systemd.show_status=false', 'rd.systemd.show_status=false']:
        if arg not in arguments:
            arguments.append(arg)
    replacement = match.group(1) + match.group(2) + ' '.join(arguments) + match.group(2) + match.group(4)
    return text[:match.start()] + replacement + text[match.end():]


def quiet_generator(text):
    if MARKER in text:
        if len(re.findall(r'(?m)^\s*result\s*=\s*sumi_quiet_boot\(source\)\s*$', text)) != 1:
            raise RuntimeError('Existing quiet generator differs; preserved')
        return text
    pattern = r'(?m)^(\s*)result\s*=\s*(?:transform\(source\)|source)\s*$'
    if len(list(re.finditer(pattern, text))) != 1:
        raise RuntimeError('Unknown Evangelion boot-console generator; preserved')
    return re.sub(pattern, r'\1result = sumi_quiet_boot(source)', text, count=1).rstrip() + '\n' + AWK_FUNCTION


def cipher_settings(data):
    value = json.loads(data) if data else {}
    if not isinstance(value, dict) or not isinstance(value.get('theme', {}), dict):
        raise RuntimeError('Unknown Cipher settings structure; preserved')
    theme = value.setdefault('theme', {})
    theme['iconTheme'] = 'MacTahoe-dark'
    return (json.dumps(value, indent=2) + '\n').encode()


def validate_menu(text):
    lines = [line.strip() for line in text.splitlines()]
    linux = [line for line in lines if re.match(r'linux(?:efi)?\s+', line)]
    normal = [line for line in linux if 'single' not in line.split() and not any(v.startswith('systemd.unit=') for v in line.split())]
    if not normal or any('quiet' not in line.split() for line in normal):
        raise RuntimeError('Generated regular Linux entries did not retain quiet; original boot configuration restored')
    if any(re.match(r"echo\s+'Loading (?:Linux|initial ramdisk)", line) for line in lines):
        raise RuntimeError('Evangelion did not use the patched loading-message filter; original boot configuration restored')
    if not any('themes/evangelion/theme.txt' in line for line in lines):
        raise RuntimeError('Generated GRUB configuration lost the Evangelion theme; original restored')
