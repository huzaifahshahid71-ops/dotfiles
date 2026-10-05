import ast
import hashlib
import os
from pathlib import Path
import shutil
import tempfile

HERE = Path(__file__).resolve().parent


def core_text(text):
    if 'SUMI_WALLPAPER_ZIP_PACKS_V1' in text:
        return text
    node = next((n for n in ast.parse(text).body if isinstance(n, ast.FunctionDef) and n.name == 'online_wallpapers'), None)
    if node is None or [a.arg for a in node.args.args] != ['pin', 'collection', 'destination', 'cache', 'callback']:
        raise RuntimeError('Wallpaper downloader signature differs; preserved')
    lines = text.splitlines(keepends=True)
    old = ''.join(lines[node.lineno-1:node.end_lineno])
    if 'data["wallpapers"]' not in old and "data['wallpapers']" not in old:
        raise RuntimeError('Unknown wallpaper downloader implementation; preserved')
    if '_online_wallpapers_individual' in text:
        raise RuntimeError('Unexpected existing downloader fallback; preserved')
    new = old.replace('def online_wallpapers(', 'def _online_wallpapers_individual(', 1)
    new += '\n\n' + (HERE/'fast_function.py').read_text().rstrip() + '\n'
    result = ''.join(lines[:node.lineno-1]) + new + ''.join(lines[node.end_lineno:])
    ast.parse(result)
    return result


def app_text(text):
    old = '''                self.wallpaper_choice.addItem("Download a selection · 36 images", "selection")
                self.wallpaper_choice.addItem("Download the full collection · 302 images", "full")'''
    new = '''                wallpaper_pin = json.loads((HERE / "wallpapers.json").read_text())
                self.wallpaper_choice.addItem(
                    f"Download a selection · {len(wallpaper_pin['selection_ids'])} images", "selection")
                self.wallpaper_choice.addItem(
                    f"Download the full collection · {wallpaper_pin['wallpaper_count']} images", "full")'''
    if new in text and old not in text:
        return text
    if text.count(old) != 1:
        raise RuntimeError('Wallpaper choice labels differ; preserved')
    result = text.replace(old, new, 1)
    ast.parse(result)
    return result


def apply(path, transform):
    path = Path(path)
    if path.is_symlink():raise RuntimeError('Source symlink preserved')
    before = path.read_bytes()
    after = transform(before.decode()).encode()
    if before == after:
        print('ALREADY PATCHED:',path,flush=True);return
    backup = path.with_name(path.name+'.before-wallpaper-packs-'+hashlib.sha256(before).hexdigest()[:16])
    if backup.exists():
        if backup.is_symlink() or backup.read_bytes()!=before:raise RuntimeError('Patch backup differs')
    else:shutil.copy2(path,backup)
    fd, name = tempfile.mkstemp(prefix='.'+path.name+'-',dir=path.parent)
    try:
        with os.fdopen(fd,'wb') as output:output.write(after)
        os.chmod(name,path.stat().st_mode & 0o777)
        if path.read_bytes()!=before:raise RuntimeError('Source changed during patch')
        os.replace(name,path)
    finally:Path(name).unlink(missing_ok=True)
    print('PATCHED:',path,flush=True)
