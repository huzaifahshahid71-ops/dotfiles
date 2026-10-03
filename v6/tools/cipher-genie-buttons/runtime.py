#!/usr/bin/env python3
"""Private Cipher launchers and runtime compatibility guard."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import socket
import subprocess
import sys

ROOT = Path(__file__).resolve().parent

def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def command(args):
    p = subprocess.run(list(map(str, args)), capture_output=True, text=True, timeout=15)
    if p.returncode:
        raise RuntimeError(p.stderr.strip() or p.stdout.strip() or 'Command failed: ' + str(args[0]))
    return p.stdout.strip()

def check_qt():
    state = json.loads((ROOT/'runtime.json').read_text())
    for major, data in state['qt'].items():
        plugin = ROOT/data['plugin']
        probe = ROOT/data['probe']
        if digest(plugin) != data['pluginSha256'] or digest(probe) != data['probeSha256']:
            raise RuntimeError('Private Qt build changed; keep default decorations until repaired.')
        if command([probe, '--version']) != data['version']:
            raise RuntimeError('Qt was updated; matching decoration rebuild is required.')
        command([probe, '--verify-plugin', plugin])
    return state

def environment():
    check_qt()
    env = dict(os.environ)
    paths = [str(ROOT/('qt'+major+'/plugins')) for major in ('6','5')]
    if env.get('QT_PLUGIN_PATH'):
        paths.append(env['QT_PLUGIN_PATH'])
    env.update(QT_PLUGIN_PATH=':'.join(paths), QT_WAYLAND_DECORATION='whitesur-gtk',
               QT_QPA_PLATFORM='wayland', CIPHER_GENIE_BUTTONS='1')
    env.pop('QT_WAYLAND_DISABLE_WINDOWDECORATION', None)
    return env

def require_genie():
    address = os.environ.get('NIRI_SOCKET')
    if not address:
        raise RuntimeError('Run the live test in the working Cipher Genie session.')
    with socket.socket(socket.AF_UNIX) as s:
        s.settimeout(5)
        s.connect(address)
        s.sendall(b'"Capabilities"\n')
        data = bytearray()
        while b'\n' not in data and len(data) < 65536:
            part = s.recv(4096)
            if not part:
                break
            data.extend(part)
    caps = json.loads(data.split(b'\n')[0]).get('Ok', {}).get('Capabilities', {})
    if not caps.get('window_minimization') or 'genie' not in caps.get('window_minimization_effects', []):
        raise RuntimeError('The active compositor does not advertise native Genie.')
    return caps

def music():
    state = json.loads((ROOT/'runtime.json').read_text())
    env = environment()
    env['QS_APP_ID'] = 'io.huzaifah.LuminaMusic'
    # -n permits one private configuration independent of other Quickshell rices.
    # flock plus PID check prevents duplicate player backends on repeated shortcuts.
    import fcntl
    lock = open(ROOT/'music.lock','a')
    fcntl.flock(lock, fcntl.LOCK_EX)
    pidfile = ROOT/'music-pid.json'
    if pidfile.exists():
        try:
            old = json.loads(pidfile.read_text())
            pid = int(old['pid'])
            cmdline = Path('/proc/'+str(pid)+'/cmdline').read_bytes().split(b'\0')
            if str(ROOT/'lumina-music/shell.qml').encode() in cmdline:
                print('Lumina is already open; restore it from the Cipher Dock.')
                return
        except (OSError, ValueError, KeyError, json.JSONDecodeError):
            pass
    log = open(ROOT/'music.log','a')
    p = subprocess.Popen([state['qs'], '-p', str(ROOT/'lumina-music/shell.qml'), '-n'],
                         env=env, stdout=log, stderr=log, start_new_session=True)
    pidfile.write_text(json.dumps({'pid':p.pid})+'\n')
    print('Lumina Music opened. Use its title-bar controls; log:', ROOT/'music.log')

def main():
    if len(sys.argv) < 2:
        raise RuntimeError('Expected --check-qt, --foot, --music or --preview.')
    mode, args = sys.argv[1], sys.argv[2:]
    if mode == '--check-qt':
        check_qt()
        return
    state = json.loads((ROOT/'runtime.json').read_text())
    if mode == '--foot':
        if os.environ.get('CIPHER_GENIE_BUTTONS') != '1':
            os.execv('/usr/bin/foot', ['/usr/bin/foot']+args)
        os.execv(str(ROOT/'foot/foot'), [str(ROOT/'foot/foot'),
            '--override=csd.preferred=client', '--override=csd.size=28',
            '--override=csd.button-width=24', '--override=csd.hide-when-maximized=no',
            '--override=csd.color=ff242428', '--override=csd.button-color=ffdddde6']+args)
    elif mode == '--qt-test':
        require_genie()
        env = environment()
        probe = str(ROOT/state['qt']['6']['probe'])
        os.execve(probe, [probe], env)
    elif mode == '--music':
        if os.environ.get('CIPHER_GENIE_BUTTONS') != '1':
            fallback = state.get('musicFallback')
            if not fallback:
                raise RuntimeError('The original player launcher was not present.')
            os.execv(fallback, [fallback]+args)
        require_genie()
        music()
    elif mode == '--preview':
        require_genie()
        env = environment()
        log = open(ROOT/'preview.log','a')
        qtprobe = ROOT/state['qt']['6']['probe']
        subprocess.Popen([str(qtprobe)], env=env, stdout=log, stderr=log, start_new_session=True)
        subprocess.Popen([sys.executable, str(ROOT/'runtime.py'), '--foot'],
                         env=env, stdout=log, stderr=log, start_new_session=True)
        os.environ.update(env)
        music()
        print('Opened Qt, Foot and Lumina previews. Test yellow → Dock restore, green → restore, red → close.')
        print('No session restart is needed for these previews. Log:', ROOT/'preview.log')
    else:
        raise RuntimeError('Unknown mode: '+mode)

if __name__ == '__main__':
    try:
        main()
    except Exception as e:
        print('Cipher buttons:',e,file=sys.stderr)
        sys.exit(1)
