#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Add or promote the G16 kernel in the inspected custom GRUB menu, preserving defaults."""
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import textwrap

TITLE = 'G16 Patched'
ID = 'g16-patched'
KERNEL = 'linux-cachyos-g16'
STABLE = 'linux-cachyos-vmdtest'
NODE = re.compile(r"(?m)^\s*(menuentry|submenu)\b[^\n]*?'([^'\n]+)'[^\n]*\{")
HEADER = re.compile(r"(?m)^([ \t]*)(menuentry|submenu)\b[^\n]*?'([^'\n]+)'[^\n]*\{[ \t]*$")
RENAMES = {'Windows': 'Windows', 'G16 Patched': 'Linux G16',
           'Linux Stable': 'Linux Stable (older kernel)',
           'Advanced Linux Options': 'Advanced Linux Options',
           'CachyOS Original': 'CachyOS', 'CachyOS LTS': 'CachyOS LTS',
           'UEFI': 'BIOS'}
PROMOTED = [('menuentry', 'Windows'), ('menuentry', 'Linux G16'),
            ('submenu', 'Advanced Linux Options'), ('menuentry', 'CachyOS'),
            ('menuentry', 'CachyOS LTS'), ('menuentry', 'Linux Stable (older kernel)'),
            ('menuentry', 'BIOS')]


def menu_blocks(text):
    """Read the inspected multiline layout; reject ambiguous/unsupported blocks."""
    result = {}
    for match in HEADER.finditer(text):
        indent, kind, title = match.groups()
        if title in result:
            raise RuntimeError('Repeated menu title: '+title)
        closing = re.search(r'(?m)^'+re.escape(indent)+r'\}[ \t]*(?:#[^\n]*)?$', text[match.end():])
        if not closing:
            raise RuntimeError('Unrecognized closing brace for '+title)
        end = match.end()+closing.end()
        result[title] = {'kind': kind, 'start': match.start(), 'end': end,
                         'block': text[match.start():end]}
    if len(result) != len(NODE.findall(text)):
        raise RuntimeError('Unsupported menu block formatting')
    for title, record in result.items():
        parents = [name for name, other in result.items()
                   if other['kind'] == 'submenu' and other['start'] < record['start'] < other['end']]
        if len(parents) > 1:
            raise RuntimeError('Unexpected nested submenus')
        record['parent'] = parents[0] if parents else None
    return result


def boot_body(record):
    return [line.strip() for line in record['block'].splitlines()[1:-1]
            if line.strip() and not line.lstrip().startswith('#')]


def validate_promotion(old, new):
    """Preserve every boot command while validating the requested hierarchy."""
    before, after = menu_blocks(old), menu_blocks(new)
    mapping = RENAMES if set(before) == set(RENAMES) else {title: title for _, title in PROMOTED}
    if set(before) != set(mapping) or list(NODE.findall(new)) != PROMOTED:
        raise RuntimeError('Unexpected generated menu entries or order')
    for name, record in before.items():
        target = after[mapping[name]]
        if record['kind'] != target['kind']:
            raise RuntimeError('Menu node type changed for '+name)
        if record['kind'] == 'menuentry' and boot_body(record) != boot_body(target):
            raise RuntimeError('Boot commands changed for '+name)
    for name, record in after.items():
        expected = 'Advanced Linux Options' if name in ('CachyOS', 'CachyOS LTS', 'Linux Stable (older kernel)') else None
        if record['parent'] != expected:
            raise RuntimeError('Unexpected submenu placement for '+name)


def promote_entries(text):
    if text.splitlines()[:2] != ['#!/bin/sh', 'exec tail -n +3 $0']:
        raise RuntimeError('Unrecognized custom-menu generator header')
    blocks = menu_blocks(text)
    # Moving menu blocks must not discard independent commands in the source.
    def comments_only(value):
        return all(not line.strip() or line.lstrip().startswith('#') for line in value.splitlines())
    tops = sorted((r for r in blocks.values() if r['parent'] is None), key=lambda r: r['start'])
    cursor = text.index('\n', text.index('\n')+1)+1
    for record in tops:
        if not comments_only(text[cursor:record['start']]):
            raise RuntimeError('Unexpected commands outside menu entries')
        cursor = record['end']
    if not comments_only(text[cursor:]):
        raise RuntimeError('Unexpected commands after menu entries')
    advanced_record = blocks.get('Advanced Linux Options')
    if advanced_record:
        cursor = text.index('\n', advanced_record['start'])+1
        for record in sorted((r for r in blocks.values() if r['parent'] == 'Advanced Linux Options'), key=lambda r: r['start']):
            if not comments_only(text[cursor:record['start']]):
                raise RuntimeError('Unexpected standalone submenu commands')
            cursor = record['end']
        closing_start = text.rfind('\n', advanced_record['start'], advanced_record['end'])+1
        if not comments_only(text[cursor:closing_start]):
            raise RuntimeError('Unexpected standalone submenu commands')
    old_order = [('menuentry', 'Windows'), ('menuentry', 'Linux Stable'),
                 ('submenu', 'Advanced Linux Options'), ('menuentry', 'CachyOS Original'),
                 ('menuentry', 'CachyOS LTS'), ('menuentry', TITLE), ('menuentry', 'UEFI')]
    already = NODE.findall(text) == PROMOTED
    if not already and NODE.findall(text) != old_order:
        raise RuntimeError('Expected the installed Windows/Stable/Advanced/G16/UEFI menu')
    if not already:
        for name, record in blocks.items():
            expected = 'Advanced Linux Options' if name in ('CachyOS Original', 'CachyOS LTS', TITLE) else None
            if record['parent'] != expected:
                raise RuntimeError('Unexpected existing placement for '+name)
    role = {new: old for old, new in RENAMES.items()} if not already else {name: name for name in blocks}
    for title, kernel in [('Linux G16', KERNEL), ('Linux Stable (older kernel)', STABLE)]:
        body = blocks[role[title]]['block']
        if body.count('vmlinuz-'+kernel) != 1 or body.count('initramfs-'+kernel+'.img') != 1:
            raise RuntimeError('Unexpected boot file paths for '+title)

    def header(line, title, index):
        match = HEADER.match(line)
        old_title = match.group(3)
        line = line.replace("'"+old_title+"'", "'"+title+"'", 1)
        line = re.sub(r'\s+--class\s+evangelion-index-\d+\b', '', line)
        return line.replace(match.group(2), match.group(2)+' --class evangelion-index-0'+str(index), 1)

    def entry(title, index, nested=False):
        lines = textwrap.dedent(blocks[role[title]]['block']).splitlines()
        lines[0] = header(lines[0], title, index)
        block = '\n'.join(lines)
        return textwrap.indent(block, '    ') if nested else block

    prefix = text[:min(record['start'] for record in blocks.values())]
    advanced = textwrap.dedent(blocks['Advanced Linux Options']['block']).splitlines()[0]
    candidate = prefix+entry('Windows', 1)+'\n\n'+entry('Linux G16', 2)+'\n\n'
    candidate += header(advanced, 'Advanced Linux Options', 3)+'\n\n'
    candidate += '\n\n'.join(entry(title, index, True) for title, index in
                            [('CachyOS', 1), ('CachyOS LTS', 2), ('Linux Stable (older kernel)', 3)])
    candidate += '\n}\n\n'+entry('BIOS', 4)+'\n'
    validate_promotion(text, candidate)
    return candidate


def add_entry(text):
    if text.splitlines()[:2] != ['#!/bin/sh', 'exec tail -n +3 $0']:
        raise RuntimeError('Unrecognized custom-menu generator header')
    if TITLE in text or ID in text or 'vmlinuz-'+KERNEL in text:
        raise RuntimeError('A G16 entry already exists; no files changed')
    stable = re.search(r"(?ms)^menuentry 'Linux Stable'[^\n]*\{\n.*?^\}", text)
    advanced = re.search(r"(?ms)^submenu 'Advanced Linux Options'[^\n]*\{\n.*?^\}", text)
    if not stable or not advanced or stable.end() >= advanced.start():
        raise RuntimeError('Expected Stable/Advanced menu structure was not found')
    for title in ['Windows', 'Linux Stable', 'Advanced Linux Options', 'CachyOS Original', 'CachyOS LTS', 'UEFI']:
        if [name for _, name in NODE.findall(text)].count(title) != 1:
            raise RuntimeError('Missing or repeated menu title: '+title)
    entry = stable.group()
    for prefix in ['vmlinuz-', 'initramfs-']:
        if entry.count(prefix+STABLE) != 1:
            raise RuntimeError('Stable kernel/initramfs paths differ from expected layout')
    entry = entry.replace("menuentry 'Linux Stable'", "menuentry '"+TITLE+"' --id '"+ID+"'", 1)
    entry = entry.replace('vmlinuz-'+STABLE, 'vmlinuz-'+KERNEL)
    entry = entry.replace('initramfs-'+STABLE, 'initramfs-'+KERNEL)
    insert = '\n'+'\n'.join('    '+line if line else '' for line in entry.splitlines())+'\n'
    candidate = text[:advanced.end()-1]+insert+text[advanced.end()-1:]
    old = NODE.findall(text)
    new = [node for node in NODE.findall(candidate) if node != ('menuentry', TITLE)]
    if old != new:
        raise RuntimeError('Existing menu order changed unexpectedly')
    return candidate


def preserve_classes(old, new):
    """Retain the theme classes already attached to existing generated menu nodes."""
    classes = {}
    for line in old.splitlines():
        found = NODE.search(line)
        if found:
            classes[found.groups()] = re.findall(r'--class\s+(evangelion-index-\d+)\b', line)
    result = []
    for line in new.splitlines(keepends=True):
        found = NODE.search(line)
        if found:
            for name in classes.get(found.groups(), []):
                if name not in line:
                    line = line.replace(found.group(1), found.group(1)+' --class '+name, 1)
            if found.groups() == ('menuentry', TITLE) and any(classes.values()):
                if not re.search(r'--class\s+evangelion-index-\d+\b', line):
                    line = line.replace('menuentry', 'menuentry --class evangelion-index-03', 1)
        result.append(line)
    return ''.join(result)


def atomic_copy(path, data, reference):
    stat = reference.stat()
    fd, name = tempfile.mkstemp(prefix='.'+path.name+'-g16-', dir=path.parent)
    try:
        with os.fdopen(fd, 'wb') as output:
            output.write(data)
            output.flush()
            os.fsync(output.fileno())
        os.chmod(name, stat.st_mode & 0o7777)
        os.chown(name, stat.st_uid, stat.st_gid)
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def check_syntax(checker, text):
    result = subprocess.run([checker], input=text, text=True, capture_output=True)
    if result.returncode:
        raise RuntimeError('GRUB syntax check failed:\n'+result.stdout+result.stderr)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true', help='Back up, update and regenerate the menu')
    parser.add_argument('--promote', action='store_true', help='Put Linux G16 on the main menu and move Stable into Advanced')
    args = parser.parse_args()
    if os.geteuid() != 0:
        parser.error('Run with sudo so the protected GRUB files can be checked')
    checker = shutil.which('grub-script-check')
    generator = shutil.which('grub-mkconfig')
    if not checker or not generator:
        raise RuntimeError('grub-script-check and grub-mkconfig must be installed')
    cfg = Path('/boot/grub/grub.cfg')
    if not cfg.is_file() or cfg.is_symlink():
        raise RuntimeError('Expected a regular /boot/grub/grub.cfg')
    for name in ['vmlinuz-'+KERNEL, 'initramfs-'+KERNEL+'.img']:
        path = Path('/boot')/name
        if not path.is_file() or path.stat().st_size == 0:
            raise RuntimeError('Missing installed boot file: '+str(path))
    matches = []
    for path in sorted(Path('/etc/grub.d').iterdir()):
        if path.is_file() and not path.is_symlink() and path.stat().st_mode & 0o111:
            text = path.read_text()
            if ('Linux Stable' in text and 'Advanced Linux Options' in text):
                matches.append((path, text))
    if len(matches) != 1:
        raise RuntimeError('Expected one executable custom menu generator; found '+str(len(matches)))
    path, original = matches[0]
    old_cfg = cfg.read_text()
    if NODE.findall(old_cfg)[0] != ('menuentry', 'Windows'):
        raise RuntimeError('Windows is not the first current menu node')
    if not re.search(r'(?m)^\s*set default=[\x22\x27]0[\x22\x27]\s*$', old_cfg):
        raise RuntimeError('Current generated default is not entry 0; no files changed')
    candidate = promote_entries(original) if args.promote else add_entry(original)
    if args.promote:
        # The source must describe the same boot commands as the current menu.
        source_blocks, current_blocks = menu_blocks(original), menu_blocks(old_cfg)
        if set(source_blocks) != set(current_blocks):
            raise RuntimeError('Custom source and current generated menu differ')
        for title, record in source_blocks.items():
            current = current_blocks[title]
            if record['kind'] != current['kind'] or record['parent'] != current['parent'] or (record['kind'] == 'menuentry' and boot_body(record) != boot_body(current)):
                raise RuntimeError('Current boot stanza differs from source: '+title)
    check_syntax(checker, '\n'.join(candidate.splitlines()[2:])+'\n')
    print('Menu generator:', path)
    print('Menu: Windows | Linux G16 | Advanced Linux Options | BIOS' if args.promote else 'Entry: Advanced Linux Options > '+TITLE)
    if args.promote and candidate == original and NODE.findall(old_cfg) == PROMOTED:
        print('ALREADY APPLIED: requested G16 menu is installed; no files changed.')
        return
    if not args.apply:
        print('CHECK ONLY: no files changed. Run with --promote --apply to install this layout.' if args.promote else 'CHECK ONLY: no files changed. Run with --apply to install the entry.')
        return
    directory = Path('/var/backups')
    directory.mkdir(exist_ok=True)
    backup = Path(tempfile.mkdtemp(prefix='g16-grub-', dir=directory))
    saved_script, saved_cfg = backup/'menu-script', backup/'grub.cfg'
    shutil.copy2(path, saved_script)
    shutil.copy2(cfg, saved_cfg)
    print('Backup:', backup, flush=True)
    changed = False
    try:
        if path.read_text() != original or cfg.read_text() != old_cfg:
            raise RuntimeError('GRUB files changed during preflight')
        atomic_copy(path, candidate.encode(), saved_script)
        changed = True
        with tempfile.TemporaryDirectory(prefix='.g16-grub-', dir=cfg.parent) as stage:
            staged = Path(stage)/'grub.cfg'
            subprocess.run([generator, '-o', str(staged)], check=True)
            generated = staged.read_text() if args.promote else preserve_classes(old_cfg, staged.read_text())
            check_syntax(checker, generated)
            if args.promote:
                validate_promotion(old_cfg, generated)
            else:
                expected = NODE.findall(old_cfg)
                actual = [node for node in NODE.findall(generated) if node != ('menuentry', TITLE)]
                if actual != expected or NODE.findall(generated).count(('menuentry', TITLE)) != 1:
                    raise RuntimeError('Generated menu changed existing entries/order')
            if not re.search(r'(?m)^\s*set default=[\x22\x27]0[\x22\x27]\s*$', generated):
                raise RuntimeError('Generated default changed from Windows/entry 0')
            for name in ['vmlinuz-'+KERNEL, 'initramfs-'+KERNEL+'.img']:
                if name not in generated:
                    raise RuntimeError('New boot file absent from generated menu: '+name)
            atomic_copy(cfg, generated.encode(), saved_cfg)
        print('INSTALLED: Linux G16 on the main menu' if args.promote else 'INSTALLED: Advanced Linux Options > '+TITLE)
        print('Windows remains default; the older Stable, CachyOS and LTS kernels are retained.')
        print('No reboot or bootloader reinstall was requested.')
    except BaseException:
        if changed:
            atomic_copy(path, saved_script.read_bytes(), saved_script)
            atomic_copy(cfg, saved_cfg.read_bytes(), saved_cfg)
            print('Original menu script and generated configuration restored.')
        raise


if __name__ == '__main__':
    try:
        main()
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        raise SystemExit('G16 GRUB update stopped: '+str(error))
