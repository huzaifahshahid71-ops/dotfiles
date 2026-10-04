#!/usr/bin/env python3
"""One Lumina Music launch path for the twelve Multi-Rice desktops."""
import argparse
import fcntl
import json
import os
from pathlib import Path
import pwd
import runpy
import signal
import subprocess
import sys

ROOT = Path(__file__).resolve().parent


def application_environment(incoming, home):
    env = dict(incoming)
    if env.get('INIR_APP_ENV_JSON'):
        snapshot = json.loads(env['INIR_APP_ENV_JSON'])
        if snapshot.get('HOME') != str(home):
            raise RuntimeError('The Eclipse application environment belongs to a different home.')
        allowed = ('HOME XDG_CONFIG_HOME XDG_CACHE_HOME XDG_STATE_HOME XDG_DATA_HOME '
                   'XDG_DATA_DIRS GSETTINGS_BACKEND QT_SCALE_FACTOR QT_SCALE_FACTOR_ROUNDING_POLICY '
                   'QT_LOGGING_RULES QT_QPA_PLATFORMTHEME QT_STYLE_OVERRIDE QS_DISABLE_CRASH_HANDLER').split()
        for key in allowed:
            value = snapshot.get(key)
            if value is None:
                env.pop(key, None)
            elif isinstance(value, str):
                env[key] = value
            else:
                raise RuntimeError('Invalid Eclipse application environment.')
        for key in list(env):
            if key.startswith('INIR_') or key == 'ILLOGICAL_IMPULSE_VIRTUAL_ENV':
                env.pop(key)
    if env.get('HOME') != str(home):
        raise RuntimeError('Launch Lumina Music as the desktop user in their normal home.')
    env['QS_APP_ID'] = 'io.huzaifah.LuminaMusic'
    return env


def prepare(home, incoming):
    env = application_environment(incoming, home)
    ctl = home / '.local/bin/lumina-music-ctl'
    if not ctl.is_file() or not os.access(ctl, os.X_OK):
        raise RuntimeError('The existing music backend is missing: ' + str(ctl))
    native = home / '.local/share/desktop-profiles/clavis/native/buttons'
    cipher = env.get('CIPHER_GENIE_BUTTONS') == '1' and env.get('CIPHER_NATIVE_RUNTIME') == str(native)
    if cipher:
        # Preserve the existing native compatibility/capability checks. Do not
        # call runtime.music(), whose old process/launcher route is separate.
        original = dict(os.environ)
        try:
            os.environ.clear()
            os.environ.update(env)
            runtime = runpy.run_path(str(native / 'runtime.py'), run_name='music_compatibility_guard')
            runtime['require_genie']()
            env = runtime['environment']()
            env['QS_APP_ID'] = 'io.huzaifah.LuminaMusic'
        finally:
            os.environ.clear()
            os.environ.update(original)
    shell = ROOT / ('native' if cipher else 'overlay') / 'shell.qml'
    if not shell.is_file():
        raise RuntimeError('Managed music UI is missing: ' + str(shell))
    return env, shell


def launch(qs, shell, env, cache):
    cache.mkdir(parents=True, exist_ok=True, mode=0o700)
    with (cache / 'open.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        ipc = subprocess.run([qs, '-p', str(shell), 'ipc', 'call', 'luminaMusic', 'show'],
                             env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                             timeout=8)
        if ipc.returncode == 0:
            print('Lumina Music is open.')
            return
        with (cache / 'launch.log').open('a') as log:
            process = subprocess.Popen([qs, '-p', str(shell), '-n', '-d'],
                                       env=env, stdout=log, stderr=log, start_new_session=True)
            try:
                code = process.wait(timeout=20)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGTERM)
                try:
                    process.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait()
                raise RuntimeError('Music UI startup timed out; see ' + str(cache / 'launch.log'))
            if code:
                raise RuntimeError('Music UI could not start; see ' + str(cache / 'launch.log'))
        print('Lumina Music opened.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    home = Path(pwd.getpwuid(os.getuid()).pw_dir)
    env, shell = prepare(home, os.environ)
    qs = '/usr/bin/qs'
    if not Path(qs).is_file():
        raise RuntimeError('Quickshell is missing.')
    if args.check:
        print('READY:', shell)
        return
    launch(qs, shell, env, home / '.cache/multi-rice-music')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print('Lumina Music:', error, file=sys.stderr)
        sys.exit(1)
