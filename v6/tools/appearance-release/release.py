#!/usr/bin/env python3
"""Build the exported appearance fixes, then optionally publish the revision."""
import argparse
import fcntl
import os
from pathlib import Path
import subprocess
import sys
import traceback
import zipfile
from bundle import KIT, HOME, ROOT, OUTPUT, build, safe, sha


def report(error=None):
    target=HOME/'Downloads/sumi-v6-appearance-release-report.zip';safe(target)
    with zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED) as z:
        if error:
            z.writestr('error.txt',str(error)+'\n')
            z.writestr('traceback.txt',traceback.format_exc())
            for name in ('payload_backend.py','system_transaction.py','package-release.py'):
                path=ROOT/name
                if path.is_file() and not path.is_symlink() and path.stat().st_size<1000000:
                    z.write(path,'retained-sources/'+name)
        manifest=ROOT/'lumina-assets-repair/lumina-assets-5aef042f384b/manifest.json'
        if manifest.is_file() and not manifest.is_symlink() and manifest.stat().st_size<200000:
            z.write(manifest,'retained/lumina-manifest.json')
        for name in ('inputs.json','build-result.json','packaging.log','source-commit.json','published.json'):
            path=OUTPUT/name
            if path.is_file():z.write(path,name)
    print('REPORT:',target,flush=True)


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--publish',action='store_true');args=parser.parse_args()
    if os.geteuid()==0:raise RuntimeError('Run on the host as your normal user')
    for line in (KIT/'KIT-SHA256SUMS').read_text().splitlines():
        expected,relative=line.split('  ',1);path=Path(relative)
        if path.is_absolute() or '..' in path.parts:raise RuntimeError('Kit checksum path differs')
        safe(KIT/path)
        if sha(KIT/path)!=expected:raise RuntimeError('Kit source checksum differs: '+relative)
    lock=HOME/'.cache/sumi-appearance-release.lock';safe(lock);lock.parent.mkdir(parents=True,exist_ok=True)
    with lock.open('a') as stream:
        fcntl.flock(stream,fcntl.LOCK_EX|fcntl.LOCK_NB)
        checks=subprocess.run([sys.executable,'-m','unittest','discover','-s',str(KIT),'-p','test_revision.py','-v'],capture_output=True,text=True,timeout=60)
        if checks.returncode:raise RuntimeError('Revision regression failed:\n'+checks.stdout+checks.stderr)
        print(checks.stderr,flush=True)
        files,original=build()
        # These fixtures execute the actual revised root helper against a
        # temporary root, including the earlier unchanged-SDDM restore fix.
        source=OUTPUT/'sources'
        subprocess.run([sys.executable,str(KIT/'test_restore_guard.py'),str(source/'system_transaction.py')],
                       env=dict(os.environ,PYTHONPATH=str(source)),check=True,timeout=60)
        if args.publish:
            from publish import publish
            publish(files,original)
        else:print('Build ready. Publish with the same command plus --publish.',flush=True)
        report()


if __name__=='__main__':
    try:main()
    except Exception as error:
        print('Appearance release stopped:',error,file=sys.stderr,flush=True);report(error);sys.exit(1)
