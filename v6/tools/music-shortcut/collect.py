#!/usr/bin/env python3
"""Read-only collection of the installed Multi-Rice music and binding sources."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import tempfile
import zipfile

PROFILES = {
    'caelestia': 'Aether', 'end4': 'Obsidian', 'ambxst': 'Crimson',
    'dms': 'Materia', 'serpantinum': 'Aurora', 'noctalia': 'Nocturne',
    'sayconlun': 'Lumina', 'tsugumori': 'Tsugumori', 'jaqc': 'Solstice',
    'clavis': 'Cipher', 'nixri': 'Astra', 'inir': 'Eclipse',
}
MAX_FILE = 2 * 1024 * 1024
MAX_TOTAL = 40 * 1024 * 1024
SKIP = re.compile(r'backup|before-|rolled-back|__pycache__|\.git|node_modules', re.I)


def collect(home, output):
    home = home.resolve()
    root = home / '.local/share/desktop-profiles'
    files, skipped, aliases = {}, [], {}

    def add(path, explicit_launcher=False):
        try:
            resolved = path.resolve(strict=True)
            relative = resolved.relative_to(home).as_posix()
            if not resolved.is_file() or (SKIP.search(relative) and not explicit_launcher):
                return
            if resolved.stat().st_size > MAX_FILE:
                skipped.append({'path': relative, 'reason': 'file size limit'})
                return
            data = resolved.read_bytes()
            data.decode('utf-8')
            if len(data) > MAX_FILE:
                raise RuntimeError('Source changed during collection: ' + relative)
            files[relative] = data
            if path != resolved:
                aliases[str(path.relative_to(home))] = relative
        except (OSError, ValueError, UnicodeDecodeError):
            return

    def config_tree(path):
        if not path.is_dir():
            return
        resolved = path.resolve()
        if not resolved.is_relative_to(home):
            return
        for parent, dirs, names in os.walk(resolved, followlinks=False):
            dirs[:] = [d for d in dirs if not SKIP.search(d)]
            for name in names:
                p = Path(parent) / name
                if p.suffix in {'.lua', '.kdl', '.conf'}:
                    add(p)

    for profile in PROFILES:
        for directory in ['hypr', 'niri']:
            config_tree(root / profile / directory)
        for name in ['session.sh', 'shell.sh']:
            add(root / profile / name)
    config_tree(root / 'clavis/native/niri')
    for directory in ['hypr', 'niri']:
        config_tree(home / '.config' / directory)
    for name in ['lumina-player-overlay', 'desktop-switch', 'multi-rice-session']:
        add(home / '.local/bin' / name)
    for path in [
        home / '.local/share/desktop-switcher/profile-metadata.sh',
        root / 'clavis/native/original-launchers/lumina-player-overlay',
        root / 'clavis/native/buttons/music-original.sh',
        root / 'clavis/native/buttons/runtime.py',
    ]:
        add(path)

    # Follow only explicit music launch targets inside the desktop user's home.
    # Never execute a collected launcher or copy playlists/state/cache/logs.
    for state in [root / 'clavis/native/buttons/runtime.json', root / 'cipher-genie-session/buttons/runtime.json']:
        try:
            fallback = json.loads(state.read_text()).get('musicFallback')
            if isinstance(fallback, str):
                add(Path(fallback), explicit_launcher=True)
        except (OSError, ValueError):
            pass
    referenced_music_dirs = set()
    for _ in range(3):
        for data in list(files.values()):
            text = data.decode('utf-8')
            for match in re.findall(r'(?:/home/[^\s\"\'<>]+|\$HOME/[^\s\"\'<>]+|~/[^\s\"\'<>]+)', text):
                if not re.search(r'lumina|music|player', match, re.I):
                    continue
                match = match.replace('$HOME/', str(home) + '/').replace('~/', str(home) + '/')
                candidate = Path(match.rstrip(';),'))
                if candidate.is_file():
                    add(candidate, explicit_launcher=candidate.suffix != '.qml')
                    if candidate.suffix == '.qml':
                        referenced_music_dirs.add(candidate.parent)
    music_roots = [home / '.config/quickshell', root / 'clavis/native/buttons/lumina-music']
    quickshell = home / '.config/quickshell'
    if quickshell.is_dir():
        music_roots += [p for p in quickshell.iterdir()
                        if re.search(r'lumina[-_](?:music|player)|music[-_]player', p.name, re.I)]
    music_roots += list(referenced_music_dirs)
    for base in music_roots:
        if not base.is_dir() or not base.resolve().is_relative_to(home):
            continue
        for parent, dirs, names in os.walk(base.resolve(), followlinks=False):
            dirs[:] = [d for d in dirs if not SKIP.search(d)]
            for name in names:
                p = Path(parent) / name
                if p.suffix in {'.qml', '.js'} and (
                    base in referenced_music_dirs
                    or re.search(r'lumina[-_](?:music|player)|music[-_]player', str(base), re.I)
                    or re.search(r'lumina[-_](?:music|player)|music[-_]player', str(p), re.I)
                    or name in {'GlassPlayer.qml', 'MaterialPlayer.qml', 'NexusPlayer.qml'}
                ):
                    add(p)
    if sum(map(len, files.values())) > MAX_TOTAL:
        raise RuntimeError('Source collection exceeds 40 MiB; nothing was written.')
    active = home / '.config/desktop-profile/active'
    report = {
        'schema': 1, 'active_profile': active.read_text().strip() if active.is_file() else None,
        'profiles': {p: {'name': name, 'directory_present': (root / p).is_dir()}
                     for p, name in PROFILES.items()},
        'aliases': aliases, 'skipped': skipped,
        'files': [{'path': path, 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}
                  for path, data in sorted(files.items())],
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        raise RuntimeError('Output already exists; choose a new --output path: ' + str(output))
    fd, temporary = tempfile.mkstemp(prefix='.music-sources-', dir=output.parent)
    try:
        os.close(fd)
        with zipfile.ZipFile(temporary, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
            archive.writestr('report.json', json.dumps(report, indent=2) + '\n')
            for path, data in sorted(files.items()):
                archive.writestr('home/' + path, data)
        os.link(temporary, output)
    finally:
        Path(temporary).unlink(missing_ok=True)
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=Path.home() / 'Downloads/multi-rice-music-sources.zip')
    args = parser.parse_args()
    if os.geteuid() == 0:
        parser.error('Run as the desktop user, without sudo.')
    report = collect(Path.home(), args.output.expanduser())
    print('COLLECTED:', args.output.expanduser())
    print('Configuration/launcher/QML sources:', len(report['files']))
    print('No configuration changes, service restarts, package changes or music launch were requested.')


if __name__ == '__main__':
    try:
        main()
    except (OSError, RuntimeError) as error:
        raise SystemExit('Music source collection stopped: ' + str(error))
