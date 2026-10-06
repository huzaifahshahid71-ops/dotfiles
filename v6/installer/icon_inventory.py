"""Copy the observed MacTahoe packs with verified bytes and bounded symlinks."""
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import stat
import tempfile
import zipfile

THEMES = ('MacTahoe','MacTahoe-dark','MacTahoe-light')


def sha(data):return hashlib.sha256(data).hexdigest()


def regular_target(path):
    for parent in (path,*path.parents):
        if parent.is_symlink():raise RuntimeError('Existing icon/config symlink retained: '+str(parent))
    if path.exists() and not path.is_file():raise RuntimeError('Existing non-file retained: '+str(path))


def atomic(path,data,mode=0o644):
    regular_target(path);path.parent.mkdir(parents=True,exist_ok=True)
    fd,name=tempfile.mkstemp(prefix='.'+path.name+'-',dir=path.parent)
    try:
        with os.fdopen(fd,'wb') as stream:stream.write(data);stream.flush();os.fsync(stream.fileno())
        os.chmod(name,mode);os.replace(name,path)
    finally:Path(name).unlink(missing_ok=True)


def pack(home,output):
    folder=home/'.local/share/icons'
    roots=[(folder/name).resolve(strict=True) for name in THEMES]
    for root in roots:
        if not root.is_relative_to(folder.resolve()) or not (root/'index.theme').is_file():
            raise RuntimeError('Expected complete host MacTahoe icon pack')
    records=[];total=0
    def walk(path,relative,ancestors):
        resolved=path.resolve(strict=True)
        if not any(resolved.is_relative_to(root) for root in roots):
            raise RuntimeError('Icon symlink leaves the MacTahoe packs: '+str(path))
        if resolved.is_dir():
            if resolved in ancestors:raise RuntimeError('Icon directory symlink cycle: '+str(path))
            for child in sorted(path.iterdir()):yield from walk(child,relative/child.name,ancestors|{resolved})
        elif resolved.is_file():yield relative,resolved
        else:raise RuntimeError('Unexpected icon special file: '+str(path))
    with zipfile.ZipFile(output,'x',zipfile.ZIP_DEFLATED,compresslevel=3) as archive:
        for name in THEMES:
            for relative,source in walk(folder/name,PurePosixPath(name),set()):
                if source.stat().st_size>16*1024**2:raise RuntimeError('Unexpected oversized icon: '+str(source))
                data=source.read_bytes();total+=len(data)
                if total>1024**3:raise RuntimeError('Icon pack exceeds the reviewed one-GiB size budget')
                archive.writestr(str(relative),data)
                records.append({'path':str(relative),'bytes':len(data),'sha256':sha(data)})
                if len(records)%2000==0:print('Prepared icon files:',len(records),flush=True)
        manifest={'schema':1,'themes':list(THEMES),'files':records,'bytes':total}
        archive.writestr('manifest.json',json.dumps(manifest,indent=2))
    print('PREPARED:',len(records),'MacTahoe icon files;',round(total/1024**2,1),'MiB uncompressed',flush=True)
    return manifest


def inventory(archive):
    if archive.getinfo('manifest.json').file_size>32*1024**2:raise RuntimeError('Oversized icon manifest')
    manifest=json.loads(archive.read('manifest.json'))
    if manifest.get('schema')!=1 or manifest.get('themes')!=list(THEMES):raise RuntimeError('Unknown icon manifest')
    records=manifest['files'];seen=set();total=0
    for record in records:
        path=PurePosixPath(record['path'])
        if path.is_absolute() or '..' in path.parts or not path.parts or path.parts[0] not in THEMES or len(path.parts)<2:
            raise RuntimeError('Out-of-scope icon entry')
        if str(path) in seen:raise RuntimeError('Duplicate icon manifest entry')
        seen.add(str(path));total+=record['bytes']
        member=archive.getinfo(str(path))
        if stat.S_ISLNK(member.external_attr>>16) or member.file_size!=record['bytes'] or member.file_size>16*1024**2:
            raise RuntimeError('Icon member size/type differs')
    names=archive.namelist()
    if len(names)!=len(set(names)) or set(names)!=seen|{'manifest.json'} or total>1024**3 or total!=manifest['bytes']:
        raise RuntimeError('Icon archive inventory differs')
    if not {name+'/index.theme' for name in THEMES}.issubset(seen):raise RuntimeError('Incomplete theme indexes')
    return manifest


def install(home,archive_path,receipt):
    destination=home/'.local/share/icons'
    with zipfile.ZipFile(archive_path) as archive:
        manifest=inventory(archive)
        if shutil.disk_usage(home).free<manifest['bytes']*2+128*1024**2:
            raise RuntimeError('Insufficient VM space to stage the icon pack')
        # Validate every source and collision before adding anything.
        for record in manifest['files']:
            path=destination/record['path'];regular_target(path)
            data=archive.read(record['path'])
            if sha(data)!=record['sha256']:raise RuntimeError('Icon checksum differs: '+record['path'])
            if path.exists() and sha(path.read_bytes())!=record['sha256']:
                raise RuntimeError('Different existing icon retained: '+str(path))
        receipt['icons_added']=[]
        for record in manifest['files']:
            path=destination/record['path']
            if not path.exists():
                atomic(path,archive.read(record['path']))
                receipt['icons_added'].append(record)
        receipt['icon_manifest']=manifest
        return manifest
