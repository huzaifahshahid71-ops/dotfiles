"""Retain verified Eclipse extensionless script inputs in candidate assembly."""
import hashlib
import json
from pathlib import Path

PROFILE = '.local/share/desktop-profiles/inir/'
COMMIT = 'c08bb928fe71c6a00bfede3e99ef26fb1825ebe2'

def read_inputs(folder):
    folder = Path(folder)
    manifest = json.loads((folder/'manifest.json').read_text())
    if manifest.get('commit') != COMMIT:
        raise ValueError('Eclipse launcher input version differs')
    paths = set()
    for item in manifest['files']:
        relative = Path(item['path'])
        name = relative.as_posix()
        if relative.is_absolute() or '..' in relative.parts or name in paths or not name.startswith(PROFILE+'runtime/scripts/'):
            raise ValueError('Invalid Eclipse launcher input path')
        paths.add(name)
        source = folder/'home'/relative
        source.resolve(strict=True).relative_to(folder.resolve())
        data = source.read_bytes()
        if not data.startswith(b'#!') or hashlib.sha256(data).hexdigest()!=item['sha256']:
            raise ValueError('Eclipse launcher input differs: '+name)
    if not {PROFILE+'runtime/scripts/inir',PROFILE+'runtime/scripts/inir-upstream'} <= paths:
        raise ValueError('Eclipse launcher input is incomplete')
    return manifest

def add_launchers(layer, folder):
    manifest = read_inputs(folder)
    for item in manifest['files']:
        if item['path'] not in layer.files:
            layer.add(Path(folder)/'home'/item['path'],item['path'],expected=item['sha256'],force_mode=0o755)
