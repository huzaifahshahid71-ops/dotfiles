#!/usr/bin/env python3
"""Collect the revised install checks through the new CachyVM bridge."""
import json
from pathlib import Path
import subprocess
import sys
import zipfile
from bundle import safe, write


def main():
    home=Path.home();root=home/'VMs/CachyVM';safe(root/'active.json')
    name=json.loads((root/'active.json').read_text())['name']
    if not isinstance(name,str) or Path(name).name!=name or name in ('.','..'):raise RuntimeError('CachyVM selection differs')
    target=root/name/'shared/verify-release-r2.py';write(target,Path(__file__).with_name('verify_guest.py').read_bytes(),0o600)
    run=subprocess.run(['vmrun-cachy','python3 /mnt/cachyvm/verify-release-r2.py'],capture_output=True,text=True,timeout=180)
    report=home/'Downloads/sumi-v6-r2-new-vm-report.zip';safe(report)
    with zipfile.ZipFile(report,'w',zipfile.ZIP_DEFLATED) as z:
        z.writestr('checks.raw.txt',run.stdout);z.writestr('bridge.stderr.txt',run.stderr)
        try:
            data=json.loads(run.stdout[run.stdout.index('{'):]);z.writestr('checks.json',json.dumps(data,indent=2))
        except ValueError:pass
    print(run.stdout,flush=True);print('REPORT:',report,flush=True)
    if run.returncode:raise RuntimeError('VM checks reported a failure; report retained')


if __name__=='__main__':
    try:main()
    except Exception as error:raise SystemExit('Fresh revision check stopped: '+str(error))
