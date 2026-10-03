"""Pinned-source adaptations; never run upstream setup or change another rice."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
from fonts import prepare_font

REVISION = 'c08bb928fe71c6a00bfede3e99ef26fb1825ebe2'
VERSION = '2.32.0'
DISPLAY_NAME = 'Eclipse'

def polkit_fallback(candidates=None):
    candidates=candidates if candidates is not None else [
        '/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1',
        '/usr/lib/polkit-kde-authentication-agent-1',
        '/usr/bin/lxqt-policykit-agent',
        '/usr/lib/mate-polkit/polkit-mate-authentication-agent-1',
        '/usr/libexec/polkit-mate-authentication-agent-1']
    return next((str(path) for path in candidates if Path(path).is_file() and os.access(path,os.X_OK)),None)

def replace_once(path, before, after):
    text = path.read_text()
    if text.count(before) != 1:
        raise RuntimeError('Pinned integration anchor differs: '+str(path))
    path.write_text(text.replace(before, after, 1))

def prepare(source, stage, final, package, real_home):
    spec = importlib.util.spec_from_file_location('inir_payload',source/'sdata/lib/runtime-payload.py')
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    payload = module.Payload(source)
    runtime = stage/'runtime'
    runtime.mkdir()
    for name in sorted(set(payload.paths())):
        original = source/name; target = runtime/name
        target.parent.mkdir(parents=True,exist_ok=True)
        if original.is_symlink(): target.symlink_to(original.readlink())
        else: shutil.copy2(original,target)
    for name in ['LICENSE','README.md','qmldir']:
        if (source/name).is_file(): shutil.copy2(source/name,runtime/name)
    prepare_font(package,runtime)
    replace_once(runtime/'modules/common/Appearance.qml','Singleton {\n',
                 'Singleton {\n    property FontLoader profileRobotoFlex: FontLoader {\n'
                 '        source: Quickshell.shellPath("assets/fonts/roboto-flex/RobotoFlex.ttf")\n'
                 '    }\n')
    # Bind the taskbar input region to its layer surface dimensions. The
    # content-derived mask left the visible bar without hover/click input
    # on the G16; explicit dimensions restored both in the live session.
    replace_once(runtime/'modules/waffle/bar/WaffleBar.qml',
                 'mask: Region {\n                    item: content\n                }',
                 'mask: Region {\n                    width: barRoot.width\n'
                 '                    height: barRoot.height\n                }')
    # The upstream process killer is inappropriate in a multi-rice session.
    replace_once(runtime/'services/ConflictKiller.qml',
                 'function _maybeHandleConflicts(): void {',
                 'function _maybeHandleConflicts(): void {\n        return; // Multi-Rice owns shell lifetimes.\n')
    polkit = runtime/'services/PolkitService.qml'
    fallback=polkit_fallback()
    (stage/'POLKIT.json').write_text(json.dumps({'fallback':fallback})+'\n')
    # Prefer iNiR's native agent. Reuse a standalone fallback only if already
    # installed; another rice's agent package must never be replaced.
    if fallback:
        replace_once(polkit,'} else if (component.status === Component.Error) {',
                     '} else if (component.status === Component.Error) {\n                fallbackAgent.running = true;')
        text = polkit.read_text()
        end = text.rfind('\n}')
        polkit.write_text(text[:end]+'\n    Process {\n        id: fallbackAgent\n        command: '+json.dumps([fallback])+'\n    }\n'+text[end:])
    # Keep dynamic palette generation, omit external app restyling/restarts.
    for script in ['applycolor.sh','apply-gtk-theme.sh','apply-spicetify-theme.sh']:
        path = runtime/'scripts/colors'/script
        if path.is_file():
            path.write_text('#!/usr/bin/env bash\n# Multi-Rice: app themes are shared and remain user-managed.\nexit 0\n')
    replace_once(runtime/'scripts/colors/switchwall.sh',
                 '    pkill -f -9 mpvpaper || true',
                 '    : # Other profiles may own mpvpaper; never kill it globally.')
    replace_once(runtime/'scripts/lib/niri-session-env.sh','is-active --quiet niri.service',
                 'is-active --quiet huzaifah-inir.service')
    replace_once(runtime/'scripts/lib/niri-session-env.sh','--value niri.service',
                 '--value huzaifah-inir.service')
    # Put detached external applications outside the shell's private HOME.
    for path in runtime.rglob('*.qml'):
        if path.is_symlink(): continue
        text = path.read_text()
        if 'Quickshell.execDetached(' in text:
            text = text.replace('Quickshell.execDetached(', 'ProfileExec.execDetached(')
            if 'import qs.modules.common.functions\n' not in text:
                lines = text.splitlines(keepends=True)
                index = next(i for i,line in enumerate(lines) if line.startswith('import '))
                lines.insert(index,'import qs.modules.common.functions\n')
                text = ''.join(lines)
        # Scope fixed scratch paths to this runtime, including shell helpers.
        text = text.replace('/tmp/quickshell',str(final/'home/.cache/tmp'))
        text = text.replace('inir.service','huzaifah-inir-shell.service')
        path.write_text(text)
    replace_once(runtime/'services/Hyprsunset.qml',
                 '"--unit=inir-wlsunset.service",',
                 '"--unit=inir-wlsunset.service", "--property=PartOf=huzaifah-inir.service", "--property=After=huzaifah-inir.service",')
    replace_once(runtime/'services/AwwwBackend.qml',
                 'systemd-run --user --quiet --collect --property=Description=',
                 'systemd-run --user --quiet --collect --unit=huzaifah-inir-wallpaper.service --property=PartOf=huzaifah-inir.service --property=After=huzaifah-inir.service --property=Description=')
    shell_exec = runtime/'modules/common/functions/ShellExec.qml'
    replace_once(shell_exec, '            shift 3\n',
                 '            shift 3\n            set -- /usr/bin/python3 "$INIR_PROFILE_ROOT/environment.py" --raw -- "$@"\n')
    shutil.copy2(package/'ProfileExec.qml',runtime/'modules/common/functions/ProfileExec.qml')
    for path in (runtime/'scripts').rglob('*'):
        if path.is_file() and not path.is_symlink():
            try: text = path.read_text()
            except UnicodeDecodeError: continue
            path.write_text(text.replace('/tmp/quickshell',str(final/'home/.cache/tmp'))
                           .replace('inir.service','huzaifah-inir-shell.service'))
    original = runtime/'scripts/inir'
    original.rename(runtime/'scripts/inir-upstream')
    original.write_text('#!/usr/bin/env bash\nexec '+sh_quote(final/'bin/inir')+' "$@"\n')
    original.chmod(0o755)
    (runtime/'scripts/restart-shell.sh').write_text('#!/usr/bin/env bash\nexec systemctl --user restart huzaifah-inir-shell.service\n')
    (runtime/'setup').write_text('#!/usr/bin/env bash\necho "This iNiR profile is managed by Multi-Rice." >&2\nexit 2\n')
    (runtime/'version.json').write_text(json.dumps({'version':VERSION,'commit':REVISION,
        'source':'multi-rice','installMode':'profile','updateStrategy':'package-manager'})+'\n')
    (stage/'bin').mkdir()
    for name in ['environment.py','session.sh','shell.sh','refresh.py']:
        shutil.copy2(package/name,stage/name); (stage/name).chmod(0o755)
    shutil.copy2(package/'inir',stage/'bin/inir'); (stage/'bin/inir').chmod(0o755)
    shutil.copytree(source/'defaults/niri',stage/'niri')
    (stage/'niri/config.d/40-environment.kdl').write_text('environment {\n    XDG_CURRENT_DESKTOP "niri"\n    ELECTRON_OZONE_PLATFORM_HINT "auto"\n}\n')
    (stage/'niri/config.d/50-startup.kdl').write_text('// Clipboard and shell are started by the private iNiR service.\n')
    binds = stage/'niri/config.d/70-binds.kdl'
    replace_once(binds,'Mod+Shift+R { spawn "inir" "region" "recordWithSound"; }',
                 'Mod+Ctrl+Shift+S { spawn "inir" "region" "recordWithSound"; }')
    # Reserve the user's shared player, replacing the upstream mute chord.
    text = binds.read_text()
    import re
    text = re.sub(r'^\s*Mod\+Shift\+M\s+\{[^\n]+\}\s*$', '',text,flags=re.M)
    for chord in ['Mod+O','Mod+I','Mod+P']:
        text = re.sub(r'^\s*'+re.escape(chord)+r'\s+\{[^\n]+\}\s*$', '',text,flags=re.M)
    anchor = '\nbinds {\n'
    if text.count(anchor) != 1: raise RuntimeError('Missing pinned binds block')
    extra = ('    Mod+Shift+D { spawn "/usr/bin/qs" "-p" '+kdl(real_home/'.config/quickshell/multi-rice-switcher/shell.qml')+'; }\n'
             '    Mod+Shift+R { spawn "/usr/bin/python3" '+kdl(final/'refresh.py')+'; }\n'
             '    Mod+Shift+M { spawn '+kdl(real_home/'.local/bin/lumina-player-overlay')+'; }\n'
             '    Mod+O { spawn "playerctl" "play-pause"; }\n'
             '    Mod+I { spawn "playerctl" "previous"; }\n'
             '    Mod+P { spawn "playerctl" "next"; }\n')
    binds.write_text(text.replace(anchor,anchor+extra,1))
    home = stage/'home'
    for name in ['.config','.cache/tmp','.local/state/quickshell/user','.local/share']:
        (home/name).mkdir(parents=True,exist_ok=True)
    (home/'.config/niri').symlink_to('../../niri')
    (home/'.config/quickshell').mkdir()
    (home/'.config/quickshell/inir').symlink_to('../../../runtime')
    (home/'.config/inir').mkdir()
    (home/'.config/illogical-impulse').symlink_to('inir')
    config = {'panelFamily':'iris','enabledPanels':['irisBar','irisBackground','irisPalette',
        'irisControlCenter','irisNotificationPopup','irisOnScreenDisplay','irisSessionScreen',
        'irisLock','irisPolkit'], 'shellUpdates':{'enabled':False},
        'background':{'wallpaperPath':str(final/'runtime/assets/wallpapers/qs-niri.jpg')},
        'appearance':{'typography':{'syncWithSystem':False}},
        'iris':{'appearance':{'materialForApps':False}},
        'apps':{'terminal':'foot','browser':'xdg-open'}}
    (home/'.config/inir/config.json').write_text(json.dumps(config,indent=2)+'\n')
    # Preserve normal user directories without sharing application configuration.
    dirs = real_home/'.config/user-dirs.dirs'
    if dirs.is_file():
        (home/'.config/user-dirs.dirs').write_text(dirs.read_text().replace('$HOME',str(real_home)))
    for name in ['Pictures','Music','Videos','Downloads','Documents','Desktop']:
        (home/name).symlink_to(real_home/name)
    (stage/'SOURCE.json').write_text(json.dumps({'repository':'https://github.com/snowarch/iNiR',
        'commit':REVISION,'version':VERSION,'adapter':'Multi-Rice profile v1'},indent=2)+'\n')
    (runtime/'MULTI-RICE-NOTICE.md').write_text('iNiR by snowarch, GPL-3.0. Pinned '+REVISION+
        '.\nAdapted by Multi-Rice: private state, app environment restore, selected service lifecycle, shared hotkeys, external theme/update isolation.\nOriginal source and adapter source are linked in the installer README.\n')

def sh_quote(value):
    import shlex
    return shlex.quote(str(value))

def kdl(value):
    return json.dumps(str(value))

def metadata_overlay(original):
    marker = '# >>> Multi-Rice iNiR profile v1 >>>'
    if marker in original: raise RuntimeError('iNiR metadata is already registered')
    functions = ['profile_compositor','profile_name','profile_icon','profile_config_path',
                 'profile_ids','profile_ids_for_compositor']
    # Bash function definitions are renamed, preserving the existing profile table.
    # No replacement of Tsugumori or locally added profiles.
    import re
    appended = [marker]
    for name in functions:
        if len(re.findall(r'(?m)^'+name+r'\s*\(\)\s*\{',original)) != 1:
            raise RuntimeError('Unexpected installed metadata function: '+name)
        appended.append('eval "$(declare -f '+name+' | sed \'1s/^'+name+' /inir_original_'+name+' /\')"')
    appended += [
        'profile_compositor() { if [[ "$1" == inir ]]; then echo niri; else inir_original_profile_compositor "$@"; fi; }',
        'profile_name() { if [[ "$1" == inir ]]; then echo '+DISPLAY_NAME+'; else inir_original_profile_name "$@"; fi; }',
        'profile_icon() { if [[ "$1" == inir ]]; then echo "◌"; else inir_original_profile_icon "$@"; fi; }',
        'profile_config_path() { if [[ "$2" == inir ]]; then [[ -f "$1/inir/READY" && -f "$1/inir/niri/config.kdl" ]] || return 1; printf "%s\\n" "$1/inir/niri"; else inir_original_profile_config_path "$@"; fi; }',
        'profile_ids() { inir_original_profile_ids; printf "%s\\n" inir; }',
        'profile_ids_for_compositor() { local wanted="$1" profile; while IFS= read -r profile; do [[ "$(profile_compositor "$profile" 2>/dev/null || true)" == "$wanted" ]] && printf "%s\\n" "$profile"; done < <(profile_ids); }',
        '# <<< Multi-Rice iNiR profile v1 <<<']
    return original.rstrip()+'\n\n'+'\n'.join(appended)+'\n'

def session_route(original):
    anchor = '    niri)\n'
    if original.count(anchor) != 1 or 'inir_root=' in original:
        raise RuntimeError('Unknown Multi-Rice session route; preserving it')
    insertion = ('        inir_root="$HOME/.local/share/desktop-profiles/inir"\n'
                 '        if [[ "$profile" == inir ]]; then\n'
                 '            [[ -f "$inir_root/READY" && -x "$inir_root/session.sh" ]] || { echo "iNiR is incomplete" >&2; exit 1; }\n'
                 '            cmd=(/usr/bin/bash "$inir_root/session.sh")\n'
                 '        else\n')
    start = original.index(anchor)+len(anchor)
    end = original.index('        ;;',start)
    return original[:start]+insertion+original[start:end]+'        fi\n'+original[end:]
