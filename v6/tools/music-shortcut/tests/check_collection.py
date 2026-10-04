#!/usr/bin/env python3
"""Exercise source inclusion, boundaries and non-destructive behavior."""
import importlib.util
import json
from pathlib import Path
import tempfile
import zipfile

spec = importlib.util.spec_from_file_location('collector', Path(__file__).parents[1] / 'collect.py')
collector = importlib.util.module_from_spec(spec)
spec.loader.exec_module(collector)

with tempfile.TemporaryDirectory() as temporary:
    base = Path(temporary)
    home = base / 'desktop-user'
    home.mkdir()
    root = home / '.local/share/desktop-profiles'
    def write(path, data):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(data)
    for name in collector.PROFILES:
        write(root / name / 'hypr/hyprland.lua', '-- ' + name)
    write(home / '.config/desktop-profile/active', 'sayconlun\n')
    (home / '.config/hypr').symlink_to(root / 'sayconlun/hypr')
    player = home / '.local/share/player-sources'
    write(player / 'shell.qml', 'import QtQuick\n')
    write(player / 'GlassPlayer.qml', 'Item {}\n')
    write(player / 'settings.json', '{"private":true}')
    (home / '.config/quickshell').mkdir()
    (home / '.config/quickshell/lumina-player').symlink_to(player)
    write(home / '.local/bin/lumina-player-overlay', '#!/bin/sh\nexec qs -p "' + str(home / '.config/quickshell/lumina-player/shell.qml') + '"\n')
    fallback = root / 'cipher-buttons-backup-abc/2'
    write(fallback, '#!/bin/sh\nexit 0\n')
    write(root / 'clavis/native/buttons/runtime.json', json.dumps({'musicFallback': str(fallback), 'privateState': 'never copy'}))
    write(root / 'sayconlun/hypr/before-old.lua', 'old config excluded')
    write(base / 'outside.lua', 'outside home excluded')
    (root / 'sayconlun/hypr/outside.lua').symlink_to(base / 'outside.lua')
    before = {str(p): p.read_bytes() for p in home.rglob('*') if p.is_file()}
    output = home / 'Downloads/music.zip'
    report = collector.collect(home, output)
    assert len(report['profiles']) == 12
    assert all(p['directory_present'] for p in report['profiles'].values())
    paths = {f['path'] for f in report['files']}
    assert fallback.relative_to(home).as_posix() in paths
    assert '.local/share/player-sources/shell.qml' in paths
    assert '.local/share/player-sources/GlassPlayer.qml' in paths
    assert not any('settings.json' in p or 'runtime.json' in p or 'before-old' in p or 'outside.lua' in p for p in paths)
    assert report['active_profile'] == 'sayconlun'
    for path, content in before.items():
        assert Path(path).read_bytes() == content
    with zipfile.ZipFile(output) as archive:
        assert json.loads(archive.read('report.json')) == report
        assert all(not p.startswith('/') and '..' not in Path(p).parts for p in archive.namelist())
    original = output.read_bytes()
    try:
        collector.collect(home, output)
    except RuntimeError:
        pass
    else:
        raise AssertionError('Existing output was overwritten')
    assert output.read_bytes() == original
print('PASS: twelve profiles, symlinked music sources, exact fallback; private state/outside paths excluded; originals and existing output retained.')
