#!/usr/bin/env python3
"""Check the revised installed payload after reboot; never changes the desktop."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tomllib
import zipfile
import importlib.util

PROFILES=('caelestia','end4','ambxst','dms','serpantinum','noctalia','sayconlun','tsugumori','jaqc','clavis','nixri','inir')


def verify():
    home=Path.home();checks=[]
    script=Path('/mnt/cachyvm/bridge.py')
    if not script.is_file():raise RuntimeError('The configured CachyVM share is missing')
    spec=importlib.util.spec_from_file_location('check_session_bridge',script)
    bridge=importlib.util.module_from_spec(spec);spec.loader.exec_module(bridge)
    environment=bridge.graphical_env()
    def check(label,passed,detail=''):checks.append({'check':label,'passed':bool(passed),'detail':detail})
    def run(args,timeout=15):
        result=subprocess.run(args,capture_output=True,text=True,timeout=timeout,env=environment)
        return result.returncode,result.stdout,result.stderr
    virt=run(['systemd-detect-virt'])[1].strip()
    if virt not in ('kvm','qemu'):raise RuntimeError('Run this check inside the test VM')
    receipt_root=home/'.local/share/huzaifah-multi-rice/v6-installations'
    receipts=sorted(receipt_root.glob('*/receipt.json'),key=lambda p:p.stat().st_mtime,reverse=True)
    latest=json.loads(receipts[0].read_text()) if receipts else {}
    check('Installer receipt',latest.get('status')=='installed',str(receipts[0]) if receipts else 'not found')
    for name in PROFILES:check('Profile: '+name,(home/'.local/share/desktop-profiles'/name).is_dir())
    check('Revised root restore helper',Path('/usr/local/lib/huzaifah-multi-rice-v6/login_defaults.py').is_file()
          and Path('/usr/local/lib/huzaifah-multi-rice-v6/grub_records.py').is_file())
    alias=Path('/etc/systemd/system/display-manager.service')
    check('SDDM next-boot selection',alias.is_symlink() and Path(os.readlink(alias)).name=='sddm.service')
    code,out,err=run(['systemctl','is-active','sddm.service']);check('SDDM running after reboot',code==0 and out.strip()=='active',out.strip() or err.strip())
    code,out,_=run(['systemctl','is-active','greetd.service']);check('Prior greetd is inactive',out.strip() in ('inactive','failed','unknown'),out.strip())
    cmdline=Path('/proc/cmdline').read_text().split()
    check('Quiet boot active','quiet' in cmdline and 'systemd.show_status=false' in cmdline and 'rd.systemd.show_status=false' in cmdline,
          'Select a GRUB theme and reboot before checking' if 'systemd.show_status=false' not in cmdline else '')
    parser=Path('/usr/local/share/evangelion/bin/boot-console.awk')
    check('Quiet GRUB parser',parser.is_file() and 'SUMI_QUIET_BOOT_V1' in parser.read_text())
    manager=Path('/usr/local/share/evangelion/bin/install.sh')
    check('Quiet GRUB theme selection',manager.is_file() and 'SUMI_QUIET_SELECTION_V1' in manager.read_text())
    for name,path,count in [('Login cards',Path('/usr/local/share/multi-rice-sddm/catalog.json'),74),
                            ('GRUB cards',home/'.local/share/multi-rice-grub/catalog.json',8)]:
        data=json.loads(path.read_text()) if path.is_file() else {}
        actual=len(data.get('cards',[]));check(name,actual==count,f'{actual}/{count}')
    config=home/'.config/clavis/config.json';data=json.loads(config.read_text()) if config.is_file() else {}
    check('Cipher MacTahoe selection',data.get('theme',{}).get('iconTheme')=='MacTahoe-dark')
    for name in ('MacTahoe','MacTahoe-dark','MacTahoe-light'):
        check('Icon theme: '+name,(home/'.local/share/icons'/name/'index.theme').is_file())
    archive=home/'.local/share/multi-rice-assets/mactahoe.zip'
    if archive.is_file():
        with zipfile.ZipFile(archive) as z:count=len(json.loads(z.read('manifest.json'))['files'])
    else:count=0
    check('Complete bundled icon inventory',count==164921,str(count))
    base=home/'.local/share/desktop-profiles/sayconlun/support'
    code,out,err=run(['rofi','-no-config','-theme',str(base/'rofi/launcher.rasi'),'-dump-theme'],25)
    check('Lumina Rofi theme',code==0,(err or out)[-1000:])
    config=tomllib.loads((base/'matugen/config.toml').read_text());missing=[]
    for template in config.get('templates',{}).values():
        raw=template['input_path'];path=home/raw[2:] if raw.startswith('~/') else Path(raw)
        if not path.is_file():missing.append(str(path))
    check('Lumina palette templates',not missing,', '.join(missing))
    image=base/'quickshell/lumina/assets/wallpapers/multi-rice-default.png'
    if image.is_file():
        code,out,err=run(['matugen','-c',str(base/'matugen/config.toml'),'image',str(image),'-m','dark',
                          '-t','scheme-tonal-spot','--prefer','saturation','--dry-run','-j','hex','-q'],30)
        check('Lumina palette dry run',code==0,(err or out)[-1000:])
    else:check('Lumina default wallpaper',False)
    return {'schema':1,'revision':'appearance-r2','status':'passed' if all(r['passed'] for r in checks) else 'failed',
            'checks':checks,'manual_checks_pending':['actual login theme','GRUB theme appearance','Cipher app icons','Lumina Super+S and palette UI','other profile UI/shortcuts']}


if __name__=='__main__':
    try:result=verify()
    except Exception as error:result={'schema':1,'status':'failed','error':str(error)}
    print(json.dumps(result,indent=2));sys.exit(0 if result['status']=='passed' else 1)
