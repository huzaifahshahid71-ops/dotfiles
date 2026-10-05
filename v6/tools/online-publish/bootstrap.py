import fcntl
import hashlib
import json
import os
from pathlib import Path
import shutil
import sys
import tarfile
import tempfile
import time
import urllib.request

BASE='https://github.com/huzaifahshahid71-ops/dotfiles/releases/download/v6.0.0/'
INFO_NAME='online-installer-r1.json'
INFO_SHA256='@INFO_SHA256@'
INFO_BYTES=int('@INFO_BYTES@')


def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda:stream.read(1024*1024),b''):h.update(chunk)
    return h.hexdigest()


def safe_path(root,value):
    p=Path(value)
    if p.is_absolute() or not p.parts or '..' in p.parts:raise RuntimeError('Unsafe installer path')
    return root/p


def ordinary(path):
    for p in (path,*path.parents):
        if p.is_symlink():raise RuntimeError('Installer cache symlink preserved: '+str(p))


def fetch(record,folder):
    name=record['asset']
    if Path(name).name!=name or record['url']!=BASE+name:raise RuntimeError('Unexpected installer asset URL')
    target=folder/name;ordinary(target)
    if target.is_file() and target.stat().st_size==record['bytes'] and sha(target)==record['sha256']:return target
    if target.exists():raise RuntimeError('Existing installer cache file differs; preserved: '+name)
    temporary=target.with_name(name+'.partial');ordinary(temporary)
    print('Download:',name,flush=True)
    total=0;last=time.monotonic()
    with urllib.request.urlopen(record['url'],timeout=90) as response,temporary.open('wb') as output:
        while chunk:=response.read(1024*1024):
            total+=len(chunk)
            if total>record['bytes']:raise RuntimeError('Installer asset exceeds recorded size')
            output.write(chunk)
            if time.monotonic()-last>=15:
                print('Downloaded',round(total/1024**2,1),'MiB',flush=True);last=time.monotonic()
    if total!=record['bytes'] or sha(temporary)!=record['sha256']:raise RuntimeError('Installer download checksum differs')
    os.replace(temporary,target)
    return target


def valid_runtime(runtime,records):
    if not runtime.is_dir():return False
    expected={r['path'] for r in records}
    actual={str(p.relative_to(runtime)) for p in runtime.rglob('*') if p.is_file() or p.is_symlink()}
    if actual!=expected:return False
    for record in records:
        p=safe_path(runtime,record['path'])
        if 'link' in record:
            if not p.is_symlink() or os.readlink(p)!=record['link'] or not p.resolve().is_relative_to(runtime.resolve()):return False
        elif p.is_symlink() or not p.is_file() or sha(p)!=record['sha256']:return False
    return True


def main():
    if os.geteuid()==0:raise RuntimeError('Run as your desktop user, without sudo')
    if not (os.environ.get('WAYLAND_DISPLAY') or os.environ.get('DISPLAY')):
        raise RuntimeError('Run this command in a terminal inside your graphical desktop session')
    if os.uname().machine!='x86_64':raise RuntimeError('This installer is for x86_64')
    root=Path.home()/'.cache/huzaifah-multi-rice/online-launcher/v6.0.0-r1'
    ordinary(root);root.mkdir(parents=True,exist_ok=True,mode=0o700)
    lockpath=root/'.launch.lock';ordinary(lockpath)
    with lockpath.open('a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        info=fetch({'asset':INFO_NAME,'bytes':INFO_BYTES,'sha256':INFO_SHA256,'url':BASE+INFO_NAME},root)
        data=json.loads(info.read_text())
        if data.get('version')!='6.0.0' or data.get('wallpaper_count')!=631:raise RuntimeError('Installer metadata differs')
        archive=fetch(data['gui'],root)
        manifest=fetch(data['manifest'],root)
        runtime=root/data['runtime_directory']
        if Path(data['runtime_directory']).name!=data['runtime_directory']:raise RuntimeError('Unsafe runtime name')
        ordinary(runtime)
        if not valid_runtime(runtime,data['records']):
            if runtime.exists():raise RuntimeError('Cached runtime differs; preserved. Use a fresh launcher cache directory.')
            if shutil.disk_usage(root).free<data['unpacked_bytes']+128*1024**2:
                raise RuntimeError('Insufficient space to extract the setup GUI')
            pending=Path(tempfile.mkdtemp(prefix='.extract-',dir=root))
            try:
                with tarfile.open(archive,'r:xz') as tar:tar.extractall(pending,filter='data')
                fresh=pending/data['runtime_directory']
                if not valid_runtime(fresh,data['records']):raise RuntimeError('Extracted GUI checksum differs')
                os.replace(fresh,runtime)
            finally:shutil.rmtree(pending)
        print('Verified Sumi online installer. Opening setup…',flush=True)
        env=dict(os.environ)
        for name in ('QT_PLUGIN_PATH','QML2_IMPORT_PATH','QML_IMPORT_PATH','PYTHONPATH','PYTHONHOME','QT_QPA_PLATFORM_PLUGIN_PATH'):
            env.pop(name,None)
        env['QT_QPA_PLATFORM']='wayland' if env.get('WAYLAND_DISPLAY') else 'xcb'
        env['SUMI_SETUP_MANIFEST']=str(manifest)
        os.execve(str(runtime/'SumiSetup'),[str(runtime/'SumiSetup'),'--manifest',str(manifest)],env)


try:main()
except Exception as error:
    print('Sumi launcher stopped:',error,file=sys.stderr);sys.exit(1)
