#!/usr/bin/env python3
"""Register pinned iNiR in an existing Multi-Rice installation, without switching."""
import argparse
import base64
import fcntl
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile

from adapt import REVISION, VERSION, metadata_overlay, prepare, session_route
from environment import private_env
from transaction import atomic, digest, record_targets, restore, sha, verify_records

PACKAGE=Path(__file__).resolve().parent
HOME=Path.home()
BASE=HOME/'.local/share/desktop-profiles'
ROOT=BASE/'inir'
SYSTEM=Path('/usr/local/bin/multi-rice-session')
METADATA=HOME/'.local/share/desktop-switcher/profile-metadata.sh'
LOCAL_ROUTE=HOME/'.local/bin/multi-rice-session'
UNIT='huzaifah-inir.service'
SHELL='huzaifah-inir-shell.service'
# Keep the working Quickshell/Niri packages; never install iNiR's conflicting meta-package.
PACKAGES=['qt6-5compat','qt6-imageformats','qt6-multimedia','qt6-quicktimeline',
          'kirigami','syntax-highlighting','qt6-webengine','layer-shell-qt',
          'ttf-material-symbols-variable','ttf-roboto-flex','ttf-jetbrains-mono-nerd',
          'noto-fonts-emoji','python-numpy','python-pillow','python-pip',
          'jq','fish','foot','fuzzel','wl-clipboard','cliphist','brightnessctl','playerctl',
          'libnotify','grim','slurp','curl','rsync','xdg-utils','xdg-user-dirs','wlsunset',
          'polkit-gnome','swayidle','swaylock','xwayland-satellite',
          'xdg-desktop-portal-gnome','xdg-desktop-portal-gtk']

def run(args, *, timeout=45, env=None):
    print('+ '+shlex.join(list(map(str,args))),flush=True)
    p=subprocess.run(list(map(str,args)),capture_output=True,text=True,timeout=timeout,env=env)
    if p.returncode: raise RuntimeError((p.stderr or p.stdout).strip() or 'Command failed')
    return p.stdout.strip()

def prerequisites(install_deps):
    for file in [METADATA,SYSTEM,HOME/'.local/bin/multi-rice-control',
                 HOME/'.local/bin/desktop-switch',HOME/'.local/bin/lumina-player-overlay']:
        if file.is_symlink() or not file.is_file(): raise RuntimeError('Expected installed regular file: '+str(file))
    if any(char in str(HOME) for char in ['"',"'",'\\','\n','%']):
        raise RuntimeError('This adapter requires a home path without quotes, backslashes, newlines or percent signs')
    for binary in ['/usr/bin/niri','/usr/bin/qs','/usr/bin/git','/usr/bin/dbus-run-session']:
        if not os.access(binary,os.X_OK): raise RuntimeError('Required existing runtime is missing: '+binary)
    # Query current packages before changing profile files. Optional installation
    # is explicit on the command line and never installs/replaces Quickshell.
    check=subprocess.run(['pacman','-T',*PACKAGES],capture_output=True,text=True)
    if check.returncode not in [0,127]: raise RuntimeError(check.stderr.strip() or 'pacman dependency query failed')
    missing=check.stdout.split()
    if missing and install_deps:
        result=subprocess.run(['sudo','pacman','-S','--needed',*missing])
        if result.returncode: raise RuntimeError('Dependency installation stopped; profiles are unchanged')
        check=subprocess.run(['pacman','-T',*PACKAGES],capture_output=True,text=True)
        missing=check.stdout.split()
    if missing: raise RuntimeError('Missing dependencies. Rerun with --install-deps, or install: '+shlex.join(missing))
    if ROOT.exists() or ROOT.is_symlink(): raise RuntimeError('iNiR already exists; use --status or --rollback')
    run(['systemctl','--user','show-environment'])

def fetch_source():
    source=BASE/('.inir-source-'+REVISION[:12])
    if source.is_symlink(): raise RuntimeError('Source cache is a symlink')
    if not source.exists():
        source.mkdir()
        run(['git','-C',source,'init'])
        run(['git','-C',source,'remote','add','origin','https://github.com/snowarch/iNiR.git'])
        run(['git','-C',source,'fetch','--depth=1','origin',REVISION],timeout=600)
        run(['git','-C',source,'checkout','--detach','FETCH_HEAD'])
    if run(['git','-C',source,'rev-parse','HEAD']) != REVISION:
        raise RuntimeError('Source cache is incomplete or at another revision; preserved: '+str(source))
    if run(['git','-C',source,'status','--porcelain','--untracked-files=all']):
        raise RuntimeError('Source cache was edited; preserved: '+str(source))
    if (source/'VERSION').read_text().strip() != VERSION: raise RuntimeError('Pinned source version differs')
    return source

def units():
    # No enable links to default.target or niri.service: the selected login owns these units.
    command='"'+str(ROOT/'session.sh')+'" --compositor'
    shell_command='"'+str(ROOT/'shell.sh')+'"'
    compositor=f'''[Unit]
Description=Huzaifah Multi-Rice (iNiR)
BindsTo=graphical-session.target
Before=graphical-session.target
Wants=graphical-session.target {SHELL}
After=graphical-session-pre.target
Before=xdg-desktop-autostart.target

[Service]
Type=notify
ExecStart=/usr/bin/bash {command}
TimeoutStopSec=10
KillMode=control-group
'''
    shell=f'''[Unit]
Description=iNiR selected-profile shell
PartOf={UNIT}
Requisite={UNIT}
After={UNIT}
Before=xdg-desktop-autostart.target
StartLimitIntervalSec=30
StartLimitBurst=3

[Service]
Type=dbus
BusName=org.kde.StatusNotifierWatcher
ExecStart=/usr/bin/bash {shell_command}
Restart=on-failure
RestartSec=5
TimeoutStopSec=15
KillMode=control-group
LimitCORE=0
'''
    return [(HOME/'.config/systemd/user'/UNIT,compositor.encode(),0o644),
            (HOME/'.config/systemd/user'/SHELL,shell.encode(),0o644)]

def create_venv():
    run(['/usr/bin/python3','-m','venv','--system-site-packages',ROOT/'venv'],timeout=120)
    run([ROOT/'venv/bin/python','-m','pip','install','--disable-pip-version-check',
         '--no-input','materialyoucolor==3.0.4'],timeout=600)
    generated=ROOT/'home/.local/state/quickshell/user/generated'
    generated.mkdir(parents=True,exist_ok=True)
    run([ROOT/'venv/bin/python',ROOT/'runtime/scripts/colors/generate_colors_material.py',
         '--color','#7c8cd8','--mode','dark','--json-output',generated/'colors.json'],timeout=45)
    if not isinstance(json.loads((generated/'colors.json').read_text()),dict):
        raise RuntimeError('Color generator did not return an object')

def validate_runtime():
    run(['/usr/bin/niri','validate','--config',ROOT/'niri/config.kdl'])
    for file in [ROOT/'session.sh',ROOT/'shell.sh',ROOT/'bin/inir']:
        run(['/usr/bin/bash','-n',file])
    # Compile components, without creating the iNiR desktop or acquiring its bus names.
    # A private bus, offscreen renderer and private HOME prevent interference with Cipher.
    harness=ROOT/'runtime/multi-rice-check.qml'
    harness.write_text('''import QtQuick
import Quickshell
ShellRoot {
    Component.onCompleted: {
        const names = ["shell.qml", "settings.qml", "welcome.qml"]
        for (const name of names) {
            const component = Qt.createComponent(Quickshell.shellPath(name), Component.PreferSynchronous)
            if (component.status !== Component.Ready) {
                console.error("INIR_COMPONENT_FAILURE: " + name + "\\n" + component.errorString())
                Qt.quit()
                return
            }
        }
        console.log("INIR_COMPONENTS_READY")
        Qt.quit()
    }
}
''')
    env=private_env(ROOT,os.environ)
    for key in ['NIRI_SOCKET','WAYLAND_DISPLAY','DISPLAY','HYPRLAND_INSTANCE_SIGNATURE','DBUS_SESSION_BUS_ADDRESS']:
        env.pop(key,None)
    env.update(QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',QSG_RHI_BACKEND='software')
    try:
        result=subprocess.run(['/usr/bin/dbus-run-session','--','/usr/bin/qs','-p',str(harness)],
                              capture_output=True,text=True,timeout=60,env=env)
        output=result.stdout+'\n'+result.stderr
        atomic(ROOT/'logs/qml-component-check.log',output.encode())
        if result.returncode or 'INIR_COMPONENTS_READY' not in output or 'INIR_COMPONENT_FAILURE' in output:
            raise RuntimeError('iNiR QML component check failed:\n'+output[-10000:])
    finally: harness.unlink(missing_ok=True)
    print('PASS: Niri config and non-instantiating QML component checks',flush=True)

def system_write(state,action):
    request=dict(state['system'],action=action)
    result=subprocess.run(['sudo','/usr/bin/python3',str(PACKAGE/'system-route.py')],
                          input=json.dumps(request),text=True)
    if result.returncode: raise RuntimeError('System login route update failed')

def install(install_deps=False):
    prerequisites(install_deps)
    previous_catalog=run([HOME/'.local/bin/multi-rice-control','list']).splitlines()
    source=fetch_source()
    stage=Path(tempfile.mkdtemp(prefix='.inir-stage-',dir=BASE))
    backup=Path(tempfile.mkdtemp(prefix='inir-backup-',dir=BASE))
    os.chmod(stage,0o700); os.chmod(backup,0o700)
    try:
        print('Preparing isolated iNiR '+VERSION,flush=True)
        prepare(source,stage,ROOT,PACKAGE,HOME)
        metadata=metadata_overlay(METADATA.read_text()).encode()
        current_route=SYSTEM.read_bytes()
        # Accept the audited Cipher route as well as stock. Unknown local additions are preserved.
        if sha(current_route) not in json.loads((PACKAGE/'routes.json').read_text())['acceptedSha256']:
            raise RuntimeError('System Multi-Rice route differs from the reviewed stock/Cipher routes; preserved')
        route=session_route(current_route.decode()).encode()
        if LOCAL_ROUTE.exists() and (LOCAL_ROUTE.is_symlink() or LOCAL_ROUTE.read_bytes() != current_route):
            raise RuntimeError('Local and system session routes differ; preserved')
        preview=source/'docs/images/iris-2.32-principal.webp'
        changes=units()+[(LOCAL_ROUTE,route,0o755),
                         (HOME/'.local/share/desktop-switcher/previews/inir.webp',preview.read_bytes(),0o644),
                         (METADATA,metadata,0o644)]
        records=record_targets(changes,backup)
        state={'format':1,'status':'pending','sourceCommit':REVISION,'records':records,
               'backup':str(backup),'system':{'priorSha256':sha(current_route),
               'installedSha256':sha(route),'contentBase64':base64.b64encode(route).decode()}}
        atomic(stage/'installed.json',(json.dumps(state,indent=2)+'\n').encode(),0o600)
        os.replace(stage,ROOT)
        try:
            create_venv()
            validate_runtime()
            # Parse pending units before publication, without starting either service.
            candidate=ROOT/'pending-units'; candidate.mkdir()
            for path,data,mode in changes[:2]: atomic(candidate/path.name,data,mode)
            run(['systemd-analyze','--user','verify',*[candidate/path.name for path,_,_ in changes[:2]]])
            shutil.rmtree(candidate)
            verify_records(records,False)
            for path,data,mode in changes:
                atomic(path,data,mode)
            run(['systemctl','--user','daemon-reload'])
            # Verify backend discovery preserves the rest of the catalog.
            listing=run([HOME/'.local/bin/multi-rice-control','list']).splitlines()
            if not any(row.startswith('inir|iNiR|◌|niri|false|') for row in listing):
                raise RuntimeError('Backend did not discover prepared iNiR')
            before=[row.split('|')[:5] for row in previous_catalog]
            after=[row.split('|')[:5] for row in listing if not row.startswith('inir|')]
            if before != after: raise RuntimeError('Existing profile catalog changed during registration')
            system_write(state,'install')
            atomic(ROOT/'READY',b'iNiR selected-profile adapter v1\n')
            state['status']='installed'
            atomic(ROOT/'installed.json',(json.dumps(state,indent=2)+'\n').encode(),0o600)
        except BaseException:
            # A signal can arrive between an atomic file commit and the next
            # Python statement. Recover every before/after target, not only the
            # writes that were acknowledged by the loop.
            verify_records(records,None)
            if digest(SYSTEM) == state['system']['installedSha256']:
                system_write(state,'rollback')
            restore(records)
            (ROOT/'READY').unlink(missing_ok=True)
            run(['systemctl','--user','daemon-reload'])
            retained=backup/'failed-profile'; os.replace(ROOT,retained)
            print('Preparation retained for diagnosis: '+str(retained),file=sys.stderr)
            raise
    finally:
        if stage.exists(): shutil.rmtree(stage)
    print('INSTALLED: iNiR is available in Sumi Deck. Current profile was not changed.')
    print('Select iNiR, then log in through Huzaifah Multi-Rice.')
    print('Backup: '+str(backup))

def rollback():
    state=json.loads((ROOT/'installed.json').read_text())
    active=(HOME/'.config/desktop-profile/active')
    if active.is_file() and active.read_text().strip() == 'inir':
        raise RuntimeError('Select another rice and log out of iNiR before rollback')
    for unit in [UNIT,SHELL]:
        if subprocess.run(['systemctl','--user','--quiet','is-active',unit]).returncode == 0:
            raise RuntimeError('iNiR is still running; log out first')
    verify_records(state['records'],True if state['status']=='installed' else None)
    if digest(SYSTEM) not in [state['system']['priorSha256'],state['system']['installedSha256']]:
        raise RuntimeError('System launcher was edited after installation; preserved')
    current=[(Path(r['path']),Path(r['path']).read_bytes() if Path(r['path']).exists() else None,
              Path(r['path']).stat().st_mode & 0o777 if Path(r['path']).exists() else 0o644)
             for r in state['records']]
    system_write(state,'rollback')
    try:
        restore(state['records'])
        run(['systemctl','--user','daemon-reload'])
    except BaseException:
        for path,data,mode in current:
            if data is None: path.unlink(missing_ok=True)
            else: atomic(path,data,mode)
        system_write(state,'install')
        raise
    retained=Path(tempfile.mkdtemp(prefix='inir-retained-',dir=BASE)); retained.rmdir()
    os.replace(ROOT,retained)
    print('ROLLED BACK: previous profile table and login routes restored. Retained: '+str(retained))

def status():
    state=json.loads((ROOT/'installed.json').read_text())
    verify_records(state['records'],True if state['status']=='installed' else None)
    if digest(SYSTEM) != state['system']['installedSha256']: raise RuntimeError('System login route differs')
    print('profile=inir\nversion='+VERSION+'\nstatus='+state['status'])
    print(run([HOME/'.local/bin/multi-rice-control','list']))

def main():
    p=argparse.ArgumentParser(description=__doc__)
    modes=p.add_mutually_exclusive_group(required=True)
    for mode in ['install','rollback','status']: modes.add_argument('--'+mode,action='store_true')
    p.add_argument('--install-deps',action='store_true',help='Install missing official Arch dependencies, keeping existing Quickshell/Niri')
    a=p.parse_args()
    if os.geteuid() == 0: raise RuntimeError('Run as your normal user; only dependencies and the system route use sudo')
    if not BASE.is_dir(): raise RuntimeError('Existing Multi-Rice profile root is missing')
    with (BASE/'.inir-install.lock').open('a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        if a.install: install(a.install_deps)
        elif a.rollback: rollback()
        else: status()

if __name__ == '__main__':
    try: main()
    except Exception as error:
        print('iNiR installation stopped: '+str(error),file=sys.stderr)
        print('No desktop or shell restart was requested.',file=sys.stderr)
        sys.exit(1)
