"""Install a verified archive as three managed icon directories."""
import os
from pathlib import Path
import shutil
import zipfile
from core import SetupError, no_symlink_parents, relative_path, sha256
from icon_inventory import inventory, THEMES
from icon_extract import install as extract

PATHS=tuple('.local/share/icons/'+theme for theme in THEMES)


def source(payload,record):
    if not record or record.get('schema')!=1 or record.get('themes')!=list(THEMES):raise SetupError('Icon bundle identity differs')
    if record.get('source')!='assets/mactahoe.zip':raise SetupError('Icon bundle path differs')
    path=payload/relative_path(record['source']);no_symlink_parents(path)
    if not path.is_file() or path.stat().st_size!=record['bytes'] or sha256(path)!=record['sha256']:
        raise SetupError('Icon bundle checksum differs')
    with zipfile.ZipFile(path) as archive:
        data=inventory(archive)
        if len(data['files'])!=record['files'] or data['bytes']!=record['unpacked_bytes']:
            raise SetupError('Icon bundle inventory differs')
    return path


def install(payload,record,home,replacements,changed,callback):
    archive=source(payload,record)
    staged=replacements/'icon-stage';no_symlink_parents(staged);staged.mkdir(mode=0o700)
    def progress(message,**extra):callback(message,'icons',**extra)
    extract(staged,archive,progress)
    for relative in PATHS:
        target=home/relative;no_symlink_parents(target.parent);target.parent.mkdir(parents=True,exist_ok=True)
        old=replacements/f'{len(changed):05d}'
        if target.exists() or target.is_symlink():os.rename(target,old)
        changed.append((target,old));os.replace(staged/relative,target)
    # Only this install's completed temporary extraction is removed.
    shutil.rmtree(staged)
