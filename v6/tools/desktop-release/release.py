#!/usr/bin/env python3
import argparse
import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys
import traceback
import zipfile
from common import HOME,KIT,OUTPUT,sha,safe

def report(error=None):
    target=HOME/'Downloads/sumi-v6-desktop-release-report.zip';safe(target);target.parent.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED) as z:
        if error:z.writestr('error.txt',str(error));z.writestr('traceback.txt',traceback.format_exc())
        for name in ('inputs.json','build.log','packaging.log','build-result.json','source-commit.json','published.json'):
            path=OUTPUT/name
            if path.is_file():z.write(path,name)
        for name in ('plan.json',):
            path=OUTPUT/'candidate/AppDir/payload'/name
            if path.is_file():z.write(path,'candidate/'+name)
        # Include just the three relevant staged config inputs if another source
        # guard stops, so the next report can show an exact diff.
        for path in ('.local/share/desktop-profiles/clavis/native/niri/config.kdl',
                     '.local/share/desktop-profiles/caelestia/hypr/hyprland/execs.lua',
                     '.local/share/desktop-profiles/caelestia/hypr/hyprland/keybinds.lua'):
            source=OUTPUT/'candidate/AppDir/payload/home'/path
            if source.is_file() and not source.is_symlink() and source.stat().st_size<100000:
                z.write(source,'candidate/home/'+path)
    print('REPORT:',target,flush=True)

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--publish',action='store_true');parser.add_argument('--appimagetool',type=Path)
    args=parser.parse_args()
    if os.geteuid()==0:raise RuntimeError('Run on the HOST as your normal user, without sudo')
    for line in (KIT/'KIT-SHA256SUMS').read_text().splitlines():
        digest,name=line.split('  ',1);p=Path(name)
        if p.is_absolute() or '..' in p.parts:raise RuntimeError('Unsafe kit checksum path')
        safe(KIT/p)
        if sha(KIT/p)!=digest:raise RuntimeError('Kit checksum differs: '+name)
    lock=HOME/'.cache/sumi-desktop-release-r3.lock';safe(lock);lock.parent.mkdir(parents=True,exist_ok=True)
    with lock.open('a') as stream:
        fcntl.flock(stream,fcntl.LOCK_EX|fcntl.LOCK_NB)
        subprocess.run([sys.executable,'-m','unittest','discover','-s',KIT,'-p','test_revision.py','-v'],check=True,timeout=60)
        from bundle import build
        files,prior,old_launcher=build(args.appimagetool)
        if args.publish:
            from publish import publish
            publish(files,prior,old_launcher)
        else:print('Build ready. Rerun with --publish to upload and switch the public launcher.',flush=True)
    report()

if __name__=='__main__':
    try:main()
    except Exception as error:
        print('Desktop release stopped:',error,file=sys.stderr,flush=True);report(error);sys.exit(1)
