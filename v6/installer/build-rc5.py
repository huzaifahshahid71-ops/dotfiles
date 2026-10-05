#!/usr/bin/env python3
"""Build the final RC5 AppImage from retained, verified host inputs."""
import argparse
import importlib.util
import inspect
import json
import os
from pathlib import Path
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parent

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,default=Path.home()/'multi-rice-v6-packaged-rc5-final')
    args = parser.parse_args()
    if os.geteuid()==0:
        raise RuntimeError('Run as gamer, without sudo')
    home = Path.home()
    candidate = home/'multi-rice-v6-packaged-rc4/candidate/AppDir'
    previous = home/'multi-rice-v6-packaged-rc1'
    output = args.output.expanduser().absolute()
    required = [candidate/'payload/plan.json',candidate.parent/'assembly-report.json',
                previous/'release.json',previous/'build-venv/bin/python',
                ROOT/'runtime-repair/manifest.json',ROOT/'runtime-packages/manifest.json',
                ROOT/'build-support/runtime-repair/repair.py',
                ROOT/'build-support/eclipse-launcher/manifest.json',
                ROOT/'build-support/shared-runtime/refresh-rate-ctl',
                ROOT/'package-release.py',ROOT/'repack-compat.py',ROOT/'wallpapers.json']
    missing = [str(p) for p in required if not p.is_file()]
    if missing:
        raise RuntimeError('Retained build inputs are missing: '+', '.join(missing))
    spec = importlib.util.spec_from_file_location('rc5_repack',ROOT/'repack-compat.py')
    repack = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(repack)
    packager = repack.module()
    if 'existing_build' not in inspect.signature(packager.gui_runtime).parameters:
        raise RuntimeError('The retained package-release.py lacks cached-toolchain support')
    from eclipse_launchers import read_inputs
    read_inputs(ROOT/'build-support/eclipse-launcher')
    pin = json.loads((ROOT/'wallpapers.json').read_text())
    if pin.get('tag')!='wallpapers-0aa529a78a8430dc' or pin.get('wallpaper_count')!=631:
        raise RuntimeError('The verified wallpaper pin is missing')
    print('BUILD: RC5 with all retained runtime repairs, Eclipse settings, 74 login cards, eight GRUB cards and the 631-wallpaper pin',flush=True)
    command = [sys.executable,str(ROOT/'repack-compat.py'),'--candidate',str(candidate),
               '--previous',str(previous),'--output',str(output)]
    if output.exists():
        command.append('--resume')
    status = subprocess.run(command,check=False).returncode
    if status:
        return status
    print('READY FOR VM VALIDATION: '+str(output/'multi-rice-v6.0.0-rc5-x86_64.AppImage'),flush=True)
    print('REPORT: '+str(home/'Downloads/multi-rice-v6-compatibility-build-report.zip'),flush=True)
    return 0

if __name__=='__main__':
    try:
        sys.exit(main())
    except (OSError,ValueError,RuntimeError,subprocess.SubprocessError) as error:
        report = Path.home()/'Downloads/multi-rice-v6-compatibility-build-report.zip'
        report.parent.mkdir(parents=True,exist_ok=True)
        with zipfile.ZipFile(report,'w',zipfile.ZIP_DEFLATED) as archive:
            archive.writestr('report.json',json.dumps({'status':'blocked-before-build','error':str(error)},indent=2)+'\n')
        print('RC5 build stopped: '+str(error),file=sys.stderr)
        print('REPORT: '+str(report),flush=True)
        sys.exit(1)
