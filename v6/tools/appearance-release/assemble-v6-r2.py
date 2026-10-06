#!/usr/bin/env python3
"""Download missing v6 parts, verify each, and assemble the final AppImage."""
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import os
from pathlib import Path
import shutil
import urllib.request

BASE='https://github.com/huzaifahshahid71-ops/dotfiles/releases/download/v6.0.0/'


def digest(path):
    h=hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda:stream.read(1024*1024),b''):h.update(chunk)
    return h.hexdigest()


def safe(record):
    name=record['asset']
    if Path(name).name!=name or name in ('.','..') or not name:
        raise RuntimeError('Invalid asset name')
    if record.get('url')!=BASE+name:
        raise RuntimeError('Unexpected download URL')
    return Path(name)


def matches(path,record):
    return path.is_file() and not path.is_symlink() and path.stat().st_size==record['bytes'] and digest(path)==record['sha256']


def download(record):
    path=safe(record)
    if matches(path,record):
        print('Verified:',path,flush=True);return path
    if path.exists() or path.is_symlink():
        raise RuntimeError('Existing asset differs; preserved: '+str(path))
    temp=path.with_name(path.name+'.download')
    if temp.is_symlink():raise RuntimeError('Unexpected download symlink')
    print('Downloading:',path,flush=True)
    with urllib.request.urlopen(record['url'],timeout=120) as response,temp.open('wb') as target:
        shutil.copyfileobj(response,target,1024*1024)
    if not matches(temp,record):raise RuntimeError('Download checksum differs: '+str(path))
    os.replace(temp,path)
    print('Verified:',path,flush=True)
    return path


def main():
    manifest=Path('release-r2.json')
    if not manifest.exists():
        with urllib.request.urlopen(BASE+'release-r2.json',timeout=60) as response:
            data=response.read(1024*1024)
        parsed=json.loads(data)
        if parsed.get('version')!='6.0.0':raise RuntimeError('Release version differs')
        manifest.write_bytes(data)
    data=json.loads(manifest.read_text())
    if data.get('version')!='6.0.0' or data.get('status')!='ready':raise RuntimeError('Release is not ready')
    image=safe(data['image'])
    if matches(image,data['image']):
        print('READY:',image);return
    if image.exists() or image.is_symlink():raise RuntimeError('Existing AppImage differs; preserved')
    missing=sum(r['bytes'] for r in data['parts'] if not matches(safe(r),r))
    if shutil.disk_usage('.').free<missing+data['image']['bytes']+128*1024**2:
        raise RuntimeError('Insufficient free space to download and assemble')
    with ThreadPoolExecutor(max_workers=3) as pool:parts=list(pool.map(download,data['parts']))
    temporary=image.with_name(image.name+'.assembling')
    if temporary.is_symlink():raise RuntimeError('Unexpected assembly symlink')
    with temporary.open('wb') as target:
        for part in parts:
            with part.open('rb') as source:shutil.copyfileobj(source,target,1024*1024)
    if not matches(temporary,data['image']):raise RuntimeError('Assembled AppImage checksum differs')
    temporary.chmod(0o755);os.replace(temporary,image)
    print('READY:',image,flush=True)
    print('Run: APPIMAGE_EXTRACT_AND_RUN=1 ./'+image.name)


if __name__=='__main__':main()
