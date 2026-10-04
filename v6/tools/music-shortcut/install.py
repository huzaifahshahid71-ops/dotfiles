#!/usr/bin/env python3
"""Install Super+Shift+M and the shared music launcher without restarting a desktop."""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import pwd
import re
import shlex
import shutil
import signal
import subprocess
import tempfile

PACKAGE = Path(__file__).resolve().parent
HYPR = ['caelestia', 'end4', 'ambxst', 'dms', 'serpantinum', 'noctalia', 'sayconlun', 'tsugumori']
NIRI = ['jaqc/niri/config.kdl', 'clavis/niri/config.kdl', 'clavis/native/niri/config.kdl',
        'nixri/niri/config.kdl', 'inir/niri/config.d/70-binds.kdl']
BEGIN = '-- BEGIN HUZAIFAH LUMINA MUSIC SHORTCUT'
END = '-- END HUZAIFAH LUMINA MUSIC SHORTCUT'


def digest(data):
    return hashlib.sha256(data).hexdigest()


def checked(path, home):
    if path.is_symlink() or not path.is_file() or not path.resolve().is_relative_to(home.resolve()):
        raise RuntimeError('Expected an installed regular source inside the desktop home: ' + str(path))
    return path.read_bytes()


def lua_patch(text, launcher):
    block = (BEGIN + '\ndo\n    hl.unbind("SUPER + SHIFT + M")\n'
             '    hl.bind("SUPER + SHIFT + M", hl.dsp.exec_cmd(' +
             json.dumps(shlex.quote(str(launcher)), ensure_ascii=False) +
             '), { description = "Music: Lumina Music" })\nend\n' + END)
    if BEGIN in text or END in text:
        if text.count(BEGIN) != 1 or text.count(END) != 1:
            raise RuntimeError('Ambiguous existing music binding block; preserved.')
        start, stop = text.index(BEGIN), text.index(END) + len(END)
        if stop < start:
            raise RuntimeError('Malformed music binding block; preserved.')
        return text[:start] + block + text[stop:]
    return text.rstrip() + '\n\n' + block + '\n'


def niri_patch(text, launcher):
    pattern = r'(?m)^([ \t]*)"?Mod\+Shift\+M"?(?=[ \t])[^\n]*\{[^\n]*\}[ \t]*$'
    matches = list(re.finditer(pattern, text))
    if len(matches) != 1:
        raise RuntimeError('Expected exactly one existing Mod+Shift+M binding; preserved.')
    match = matches[0]
    line = match.group(1) + 'Mod+Shift+M hotkey-overlay-title="Lumina Music" { spawn ' + json.dumps(str(launcher), ensure_ascii=False) + '; }'
    return text[:match.start()] + line + text[match.end():]


def make_plan(home):
    profiles = home / '.local/share/desktop-profiles'
    launcher = home / '.local/bin/huzaifah-lumina-music'
    root = home / '.local/share/multi-rice-music'
    changes = []
    for profile in HYPR:
        path = profiles / profile / 'hypr/hyprland.lua'
        old = checked(path, home)
        changes.append((path, lua_patch(old.decode(), launcher).encode(), 0o644))
    for relative in NIRI:
        path = profiles / relative
        old = checked(path, home)
        changes.append((path, niri_patch(old.decode(), launcher).encode(), 0o644))
    manifest = json.loads((PACKAGE / 'payload-manifest.json').read_text())
    for relative, sha in manifest['files'].items():
        source = PACKAGE / relative
        data = source.read_bytes()
        if digest(data) != sha:
            raise RuntimeError('Installer payload differs: ' + relative)
        destination = root / relative.removeprefix('payload/') if relative.startswith('payload/') else root / relative
        changes.append((destination, data, 0o755 if relative.endswith('.py') else 0o644))
    wrapper = ('#!/usr/bin/env bash\nexec /usr/bin/python3 ' + shlex.quote(str(root / 'launcher.py')) + ' "$@"\n').encode()
    for name in ['huzaifah-lumina-music', 'lumina-player-overlay']:
        changes.append((home / '.local/bin' / name, wrapper, 0o755))
    private_alias = profiles / 'clavis/native/bin/lumina-player-overlay'
    if private_alias.exists():
        checked(private_alias, home)
        changes.append((private_alias, wrapper, 0o755))
    return changes


def atomic(path, data, mode):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix='.' + path.name + '-', dir=path.parent)
    try:
        with os.fdopen(fd, 'wb') as out:
            out.write(data)
            out.flush()
            os.fsync(out.fileno())
        os.chmod(name, mode)
        os.replace(name, path)
    finally:
        Path(name).unlink(missing_ok=True)


def run(args, *, env=None, timeout=30):
    p = subprocess.run(list(map(str, args)), env=env, capture_output=True, text=True, timeout=timeout)
    if p.returncode:
        raise RuntimeError('Validation failed: ' + shlex.join(list(map(str, args))) + '\n' + (p.stderr or p.stdout)[-8000:])
    return p.stdout


def qml_harness(names):
    return '''import QtQuick
import Quickshell
ShellRoot {
    id: root
    property var names: NAMES
    property int index: 0
    property var pending: null
    function finish() {
        if (pending.status === Component.Loading) return
        if (pending.status !== Component.Ready) {
            console.error("MUSIC_COMPONENT_FAILED: " + names[index] + "\\n" + pending.errorString())
            Qt.quit()
            return
        }
        index++
        pending = null
        Qt.callLater(next)
    }
    function next() {
        if (index === names.length) {
            console.log("MUSIC_COMPONENTS_READY")
            Qt.quit()
            return
        }
        pending = Qt.createComponent(Quickshell.shellPath(names[index]), Component.PreferSynchronous)
        if (pending.status === Component.Loading) pending.statusChanged.connect(finish)
        else finish()
    }
    Component.onCompleted: Qt.callLater(next)
}
'''.replace('NAMES', json.dumps(names))


def validate(home, changes, stage):
    profiles = home / '.local/share/desktop-profiles'
    compiler = shutil.which('luac') or shutil.which('texluac')
    if not compiler:
        raise RuntimeError('Missing Lua syntax checker (luac); install the lua package and rerun.')
    for i, (path, data, _) in enumerate(changes):
        if path.suffix == '.lua':
            candidate = stage / ('lua-' + str(i) + '.lua')
            candidate.write_bytes(data)
            run([compiler, '-p', candidate])
    staged_changes = {path: data for path, data, _ in changes}
    for name in ['jaqc', 'clavis', 'clavis/native', 'nixri', 'inir']:
        source = profiles / name / 'niri'
        destination = stage / 'profiles' / name / 'niri'
        for path in source.rglob('*.kdl'):
            relative = path.relative_to(source)
            target = destination / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(staged_changes.get(path, checked(path, home)))
        binary = profiles / 'clavis/native/bin/niri' if name.startswith('clavis') else Path('/usr/bin/niri')
        if not binary.is_file():
            raise RuntimeError('Installed Niri validator is missing: ' + str(binary))
        run([binary, 'validate', '--config', destination / 'config.kdl'])
    # Compile the shell and each lazy-loaded theme without creating a player,
    # music backend, window, portal registration or live bus service.
    ui = stage / 'ui'
    for mode in ['overlay', 'native']:
        for path in (PACKAGE / 'payload' / mode).glob('*.qml'):
            target = ui / mode / path.name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, target)
    names = [p.relative_to(ui).as_posix() for p in ui.rglob('*.qml')]
    harness = ui / 'component-check.qml'
    harness.write_text(qml_harness(names))
    display = os.environ.get('WAYLAND_DISPLAY', '')
    runtime = os.environ.get('XDG_RUNTIME_DIR', '')
    socket = Path(display) if Path(display).is_absolute() else Path(runtime) / display
    if not display or not socket.is_socket():
        raise RuntimeError('Run from a terminal in the working Wayland desktop, without sudo.')
    env = dict(os.environ)
    for key in ['DBUS_SESSION_BUS_ADDRESS', 'NIRI_SOCKET', 'DISPLAY', 'WAYLAND_SOCKET', 'HYPRLAND_INSTANCE_SIGNATURE',
                'QT_PLUGIN_PATH', 'QT_WAYLAND_DECORATION', 'QT_WAYLAND_DISABLE_WINDOWDECORATION']:
        env.pop(key, None)
    private = stage / 'home'
    private.mkdir()
    env.update(HOME=str(private), XDG_CONFIG_HOME=str(private / '.config'),
               XDG_CACHE_HOME=str(private / '.cache'), XDG_STATE_HOME=str(private / '.local/state'),
               XDG_DATA_HOME=str(private / '.local/share'), QT_QPA_PLATFORM='wayland',
               QT_QUICK_BACKEND='software', QSG_RHI_BACKEND='software', QS_DISABLE_CRASH_HANDLER='1')
    log = stage / 'qml-check.log'
    with log.open('w') as output:
        process = subprocess.Popen(['/usr/bin/dbus-run-session', '--', '/usr/bin/qs', '-p', str(harness)],
                                   env=env, stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
        try:
            code = process.wait(timeout=40)
        except BaseException:
            for sig in [signal.SIGTERM, signal.SIGKILL]:
                try:
                    os.killpg(process.pid, sig)
                except ProcessLookupError:
                    pass
                try:
                    process.wait(timeout=2)
                    break
                except subprocess.TimeoutExpired:
                    pass
            process.wait()
            raise
    text = log.read_text(errors='replace')
    if code or 'MUSIC_COMPONENTS_READY' not in text or 'MUSIC_COMPONENT_FAILED' in text:
        raise RuntimeError('Music QML component validation failed:\n' + text[-8000:])
    print('PASS: eight Lua configs, five Niri config routes and all eight music QML components.')


def current_matches(record, installed):
    path = Path(record['path'])
    expected = record['installedSha256'] if installed else record.get('priorSha256')
    if path.is_symlink():
        return False
    if not expected:
        return not path.exists()
    mode = record['mode'] if installed else record['priorMode']
    return (path.is_file() and digest(path.read_bytes()) == expected
            and path.stat().st_mode & 0o777 == mode)


def recover(records):
    for record in reversed(records):
        path = Path(record['path'])
        if not current_matches(record, True):
            raise RuntimeError('Changed file preserved; automatic recovery stopped: ' + str(path))
        if record['existed']:
            saved = Path(record['backup']).read_bytes()
            if digest(saved) != record['priorSha256']:
                raise RuntimeError('Backup changed; preserved: ' + record['backup'])
            atomic(path, saved, record['priorMode'])
        else:
            path.unlink()


def live_binding():
    if not os.environ.get('HYPRLAND_INSTANCE_SIGNATURE'):
        return 'Niri bindings reload automatically; test Super+Shift+M in this profile.'
    binds = json.loads(run(['hyprctl', '-j', 'binds'], timeout=10))
    matching = [b for b in binds if str(b.get('key', '')).lower() == 'm' and b.get('modmask') == 65]
    if len(matching) != 1 or 'huzaifah-lumina-music' not in str(matching[0].get('arg', '')):
        raise RuntimeError('Live Super+Shift+M does not point to the shared launcher; inspect hyprctl -j binds.')
    return 'PASS: live Hyprland Super+Shift+M routes to the shared player.'


def install(home, validator=validate, reload_desktop=True):
    root = home / '.local/share/multi-rice-music'
    receipt = root / 'receipt.json'
    if receipt.is_file():
        state = json.loads(receipt.read_text())
        if state['status'] == 'installed':
            if not all(current_matches(r, True) for r in state['records']):
                raise RuntimeError('A managed music file changed; preserved. Inspect --status before reinstalling.')
            print('ALREADY INSTALLED: shared Lumina Music shortcut; twelve profiles.')
            return
    changes = make_plan(home)
    for path, _, _ in changes:
        if path.is_symlink() or (path.exists() and not path.is_file()) or not path.parent.resolve().is_relative_to(home.resolve()):
            raise RuntimeError('Managed target is not a regular path inside the desktop home: ' + str(path))
    base = home / '.local/share/desktop-profiles'
    stage = Path(tempfile.mkdtemp(prefix='.music-shortcut-stage-', dir=base))
    backup = None
    try:
        validator(home, changes, stage)
        backup = Path(tempfile.mkdtemp(prefix='music-shortcut-backup-', dir=base))
        records = []
        for i, (path, data, mode) in enumerate(changes):
            if path.exists() and path.read_bytes() == data and path.stat().st_mode & 0o777 == mode:
                continue
            record = {'path': str(path), 'existed': path.exists(), 'installedSha256': digest(data), 'mode': mode}
            if record['existed']:
                old = path.read_bytes()
                saved = backup / str(i)
                saved.write_bytes(old)
                record.update(backup=str(saved), priorSha256=digest(old), priorMode=path.stat().st_mode & 0o777)
            record['data'] = data
            records.append(record)
        if not all(current_matches(r, False) for r in records):
            raise RuntimeError('Sources changed during preparation; nothing installed.')
        installed = []
        try:
            for record in records:
                atomic(Path(record['path']), record['data'], record['mode'])
                installed.append(record)
            state = {'schema': 1, 'status': 'installed', 'backup': str(backup),
                     'records': [{k: v for k, v in r.items() if k != 'data'} for r in records]}
            atomic(receipt, (json.dumps(state, indent=2) + '\n').encode(), 0o600)
        except BaseException:
            recover(installed)
            raise
        print('INSTALLED: Super+Shift+M opens shared Lumina Music in all twelve profiles.')
        print('Backup:', backup)
        if reload_desktop and os.environ.get('HYPRLAND_INSTANCE_SIGNATURE'):
            try:
                run(['hyprctl', 'reload'], timeout=15)
                print(live_binding())
            except (RuntimeError, subprocess.SubprocessError) as error:
                print('Installed files retained. Live binding check:', error)
        print('No desktop restart or music playback change was requested.')
    except BaseException:
        print('Validation/preparation retained:', stage)
        raise
    else:
        shutil.rmtree(stage)


def status(home):
    receipt = home / '.local/share/multi-rice-music/receipt.json'
    if not receipt.is_file():
        raise RuntimeError('Shared music integration is not installed yet.')
    state = json.loads(receipt.read_text())
    print('State:', state['status'])
    for record in state['records']:
        if not current_matches(record, state['status'] == 'installed'):
            raise RuntimeError('Managed file differs: ' + record['path'])
    print('PASS: recorded files and launcher payload hashes.')
    if state['status'] == 'installed':
        print(live_binding())


def rollback(home):
    receipt = home / '.local/share/multi-rice-music/receipt.json'
    state = json.loads(receipt.read_text())
    if state['status'] != 'installed':
        print('ALREADY ROLLED BACK')
        return
    if not all(current_matches(r, True) for r in state['records']):
        raise RuntimeError('Managed file changed; rollback refused and current files preserved.')
    for record in state['records']:
        if record['existed'] and digest(Path(record['backup']).read_bytes()) != record['priorSha256']:
            raise RuntimeError('Backup changed; rollback refused.')
    recover(state['records'])
    state['status'] = 'rolled-back'
    atomic(receipt, (json.dumps(state, indent=2) + '\n').encode(), 0o600)
    if os.environ.get('HYPRLAND_INSTANCE_SIGNATURE'):
        run(['hyprctl', 'reload'], timeout=15)
    print('ROLLED BACK: prior launchers and bindings restored; backup retained.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    actions = parser.add_mutually_exclusive_group(required=True)
    actions.add_argument('--install', action='store_true')
    actions.add_argument('--status', action='store_true')
    actions.add_argument('--rollback', action='store_true')
    args = parser.parse_args()
    if os.geteuid() == 0:
        parser.error('Run as the desktop user, without sudo.')
    home = Path(pwd.getpwuid(os.getuid()).pw_dir)
    lockdir = home / '.cache/multi-rice-music'
    lockdir.mkdir(parents=True, exist_ok=True, mode=0o700)
    with (lockdir / 'install.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if args.install:
            install(home)
        elif args.status:
            status(home)
        else:
            rollback(home)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        raise SystemExit('Music shortcut installation stopped: ' + str(error))
