#!/usr/bin/env python3
"""Exercise all installed profile routes, recovery and launcher selection."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
from unittest.mock import patch

PACKAGE = Path(__file__).parents[1]


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


installer = module('installer', PACKAGE / 'install.py')
launcher = module('launcher', PACKAGE / 'launcher.py')
fixture = Path(os.environ.get('MUSIC_HOST_FIXTURE', 'music-host-sources/home')).resolve()
assert fixture.is_dir(), 'Pass MUSIC_HOST_FIXTURE with the collected host home tree.'


def fixture_home(base):
    home = base / 'desktop-user'
    shutil.copytree(fixture, home)
    (home / '.local/bin/lumina-music-ctl').write_text('#!/bin/sh\nexit 0\n')
    (home / '.local/bin/lumina-music-ctl').chmod(0o755)
    private_alias = home / '.local/share/desktop-profiles/clavis/native/bin/lumina-player-overlay'
    private_alias.parent.mkdir(parents=True, exist_ok=True)
    private_alias.write_text('#!/bin/sh\nexec python3 ../buttons/runtime.py --music\n')
    private_alias.chmod(0o755)
    return home


def snapshot(home):
    return {p.relative_to(home).as_posix(): (p.read_bytes(), p.stat().st_mode & 0o777)
            for p in home.rglob('*') if p.is_file()}


with tempfile.TemporaryDirectory() as temporary:
    home = fixture_home(Path(temporary))
    before = snapshot(home)
    changes = installer.make_plan(home)
    assert len([p for p, _, _ in changes if p.suffix == '.lua']) == 8
    assert len([p for p, _, _ in changes if p.suffix == '.kdl']) == 5
    compiler = shutil.which('luac') or shutil.which('texluac')
    assert compiler
    for i, (path, data, _) in enumerate(changes):
        if path.suffix == '.lua':
            file = Path(temporary) / ('config-' + str(i) + '.lua')
            file.write_bytes(data)
            subprocess.run([compiler, '-p', str(file)], check=True, capture_output=True)
            text = data.decode()
            assert text.count(installer.BEGIN) == 1 and text.count(installer.END) == 1
            assert str(home / '.local/bin/huzaifah-lumina-music') in text
            original = path.read_text()
            start, end = original.index(installer.BEGIN), original.index(installer.END) + len(installer.END)
            assert text[:start] == original[:start]
            assert text.endswith(original[end:])
        if path.suffix == '.kdl':
            text = data.decode()
            assert text.count('spawn ' + json.dumps(str(home / '.local/bin/huzaifah-lumina-music'))) == 1
            assert installer.niri_patch(text, home / '.local/bin/huzaifah-lumina-music') == text
    installer.install(home, validator=lambda *_: None, reload_desktop=False)
    assert (home / '.local/share/desktop-profiles/clavis/native/bin/lumina-player-overlay').read_bytes() == (home / '.local/bin/lumina-player-overlay').read_bytes()
    state = json.loads((home / '.local/share/multi-rice-music/receipt.json').read_text())
    assert all(installer.current_matches(r, True) for r in state['records'])
    installed = snapshot(home)
    installer.install(home, validator=lambda *_: (_ for _ in ()).throw(AssertionError('Unexpected revalidation')), reload_desktop=False)
    assert snapshot(home) == installed
    # Refuse recovery before touching anything if one managed file was edited.
    edited = home / '.local/bin/lumina-player-overlay'
    edited.write_text(edited.read_text() + '# user edit\n')
    changed = snapshot(home)
    try:
        installer.rollback(home)
    except RuntimeError:
        pass
    else:
        raise AssertionError('Changed launcher was overwritten')
    assert snapshot(home) == changed
    edited.write_bytes(installed[edited.relative_to(home).as_posix()][0])
    with patch.dict(os.environ, {}, clear=True):
        installer.rollback(home)
    for relative, data in before.items():
        path = home / relative
        assert (path.read_bytes(), path.stat().st_mode & 0o777) == data, relative
    assert not (home / '.local/bin/huzaifah-lumina-music').exists()

with tempfile.TemporaryDirectory() as temporary:
    home = fixture_home(Path(temporary))
    before = snapshot(home)
    atomic = installer.atomic
    count = [0]
    def fail_once(*args):
        count[0] += 1
        if count[0] == 4:
            raise OSError('Injected fourth write failure')
        return atomic(*args)
    with patch.object(installer, 'atomic', side_effect=fail_once):
        try:
            installer.install(home, validator=lambda *_: None, reload_desktop=False)
        except OSError:
            pass
        else:
            raise AssertionError('Injected failure did not stop installation')
    for relative, data in before.items():
        path = home / relative
        assert (path.read_bytes(), path.stat().st_mode & 0o777) == data
    assert not (home / '.local/share/multi-rice-music/receipt.json').exists()

with tempfile.TemporaryDirectory() as temporary:
    home = fixture_home(Path(temporary))
    (home / '.local/share/desktop-profiles/inir/niri/config.d/70-binds.kdl').unlink()
    before = snapshot(home)
    try:
        installer.install(home, validator=lambda *_: None, reload_desktop=False)
    except RuntimeError:
        pass
    else:
        raise AssertionError('Missing profile source was ignored')
    assert snapshot(home) == before

with tempfile.TemporaryDirectory() as temporary:
    home = fixture_home(Path(temporary))
    oldroot = launcher.ROOT
    try:
        launcher.ROOT = PACKAGE / 'payload'
        real = {'HOME': str(home), 'WAYLAND_DISPLAY': 'wayland-1', 'XDG_CONFIG_HOME': str(home / '.config')}
        for profile in installer.HYPR + ['jaqc', 'nixri', 'inir']:
            env, shell = launcher.prepare(home, real)
            assert shell == PACKAGE / 'payload/overlay/shell.qml'
            assert env['QS_APP_ID'] == 'io.huzaifah.LuminaMusic'
        private = dict(real, HOME=str(home / '.local/share/desktop-profiles/inir/home'),
                       XDG_CONFIG_HOME='/private/config', INIR_APP_ENV_JSON=json.dumps(real),
                       INIR_PRIVATE_CONTEXT='yes')
        env, shell = launcher.prepare(home, private)
        assert env['HOME'] == str(home) and env['XDG_CONFIG_HOME'] == real['XDG_CONFIG_HOME']
        assert not any(k.startswith('INIR_') for k in env)
        native = home / '.local/share/desktop-profiles/clavis/native/buttons'
        called = []
        with patch.object(launcher.runpy, 'run_path', return_value={
            'require_genie': lambda: called.append('capabilities'),
            'environment': lambda: dict(os.environ, QT_WAYLAND_DECORATION='whitesur-gtk'),
        }):
            prior_env = dict(os.environ)
            env, shell = launcher.prepare(home, dict(real, CIPHER_GENIE_BUTTONS='1', CIPHER_NATIVE_RUNTIME=str(native)))
        assert called == ['capabilities'] and shell == PACKAGE / 'payload/native/shell.qml'
        assert env['QT_WAYLAND_DECORATION'] == 'whitesur-gtk' and dict(os.environ) == prior_env
        # Existing IPC avoids another qs start. Cold start retains -n protection.
        cache = home / '.cache/test-launch'
        with patch.object(launcher.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0)), patch.object(launcher.subprocess, 'Popen') as popen:
            launcher.launch('/usr/bin/qs', shell, env, cache)
            popen.assert_not_called()
        with patch.object(launcher.subprocess, 'run', return_value=subprocess.CompletedProcess([], 1)), patch.object(launcher.subprocess, 'Popen') as popen:
            popen.return_value.wait.return_value = 0
            launcher.launch('/usr/bin/qs', shell, env, cache)
            assert popen.call_args.args[0][-2:] == ['-n', '-d']
            assert 'hyprctl' not in popen.call_args.args[0]
    finally:
        launcher.ROOT = oldroot

print('PASS: actual 12-profile sources; eight Lua syntax checks; five Niri binding rewrites; repeat/rollback/write-failure/missing-profile checks; Eclipse home restoration; guarded Cipher selection; duplicate launch prevention.')
print('Host Niri and Quickshell runtime validation is performed by install.py; this remote fixture has no graphical compositor.')
