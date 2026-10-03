#!/usr/bin/env python3
"""Prepare/install private Qt, Lumina and Foot controls for the existing Genie login."""
import argparse
import configparser
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import runpy
import shlex
import shutil
import subprocess
import sys
import tempfile
import time

PACKAGE = Path(__file__).resolve().parent
BASE = Path.home()/'.local/share/desktop-profiles'
ROOT = BASE/'cipher-genie-session'
EXPECTED_SESSION = '982f6442fa7511ce5f3975abdfa4b0186dd9da2ab5eae0c9176b85f30adb0d88'
FOOT_COMMIT = 'ab33c9a19d626f8d0ac0bd1adfdba21946ada948'
BUTTON_VARS = ['QT_PLUGIN_PATH','QT_WAYLAND_DECORATION','QT_QPA_PLATFORM',
               'QT_WAYLAND_DISABLE_WINDOWDECORATION','CIPHER_GENIE_BUTTONS']

def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def run(args, *, cwd=None, env=None, timeout=300, capture=False):
    print('+',shlex.join(list(map(str,args))),flush=True)
    p = subprocess.run(list(map(str,args)),cwd=cwd,env=env,timeout=timeout,
                       capture_output=capture,text=True)
    if p.returncode:
        raise RuntimeError((p.stderr or p.stdout or '').strip() if capture else 'Command failed; see output above.')
    return (p.stdout or '').strip()

def atomic(path,data,mode=0o644):
    path=Path(path);path.parent.mkdir(parents=True,exist_ok=True)
    fd,name=tempfile.mkstemp(prefix='.'+path.name+'-',dir=path.parent)
    try:
        with os.fdopen(fd,'wb') as f:
            f.write(data);f.flush();os.fsync(f.fileno())
        os.chmod(name,mode);os.replace(name,path)
    finally:
        if os.path.exists(name):os.unlink(name)

def patch_session(original):
    """Modify the recovered launcher only at explicit, checked insertion points."""
    points = [
        '    export NIRI_CONFIG="$ROOT/niri/config.kdl"',
        '# Systemd-launched shell/app helpers need the fork CLI and copied config too.',
        'cleanup() {',
        'status=0\nsystemctl --user --wait start "$UNIT" || status=$?']
    for point in points:
        if original.count(point)!=1:raise RuntimeError('Unsupported session launcher layout; preserved.')
    text=original.replace(points[0],
        '    source "$ROOT/buttons/session-env.sh"\n'+points[0],1)
    snapshot='''# BEGIN CIPHER BUTTONS: snapshot every manager variable we temporarily change.
button_vars=(QT_PLUGIN_PATH QT_WAYLAND_DECORATION QT_QPA_PLATFORM QT_WAYLAND_DISABLE_WINDOWDECORATION CIPHER_GENIE_BUTTONS)
declare -A button_old=() button_had=()
while IFS= read -r setting; do
    for name in "${button_vars[@]}"; do
        if [[ "$setting" == "$name="* ]]; then
            button_had["$name"]=1
            button_old["$name"]="${setting#*=}"
        fi
    done
done < <(systemctl --user show-environment)
# END CIPHER BUTTONS
'''
    text=text.replace(points[1],snapshot+points[1],1)
    restore='''    # Restore both previously-set and previously-unset Qt/marker variables.
    for name in "${button_vars[@]}"; do
        if [[ "${button_had[$name]:-0}" == 1 ]]; then
            systemctl --user set-environment "$name=${button_old[$name]}" || true
        else
            systemctl --user unset-environment "$name" || true
        fi
    done
'''
    restore_point='    if $had_config; then systemctl --user set-environment "NIRI_CONFIG=$old_config"; else systemctl --user unset-environment NIRI_CONFIG; fi\n'
    if text.count(restore_point)!=1:raise RuntimeError('Unsupported environment cleanup layout; preserved.')
    text=text.replace(restore_point,restore_point+restore,1)
    activation='''# Enable decorations only after the matching private Qt binaries pass.
source "$ROOT/buttons/session-env.sh"
if [[ "${CIPHER_GENIE_BUTTONS:-}" == 1 ]]; then
    systemctl --user set-environment "QT_PLUGIN_PATH=$QT_PLUGIN_PATH" "QT_WAYLAND_DECORATION=$QT_WAYLAND_DECORATION" "QT_QPA_PLATFORM=$QT_QPA_PLATFORM" CIPHER_GENIE_BUTTONS=1
    systemctl --user unset-environment QT_WAYLAND_DISABLE_WINDOWDECORATION
fi
'''
    return text.replace(points[3],activation+points[3],1)

def session_env():
    return '''# Loaded only by the Cipher Genie wrapper. A Qt update must not block login.
if /usr/bin/python3 "$ROOT/buttons/runtime.py" --check-qt; then
    export QT_PLUGIN_PATH="$ROOT/buttons/qt6/plugins:$ROOT/buttons/qt5/plugins${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"
    export QT_WAYLAND_DECORATION=whitesur-gtk QT_QPA_PLATFORM=wayland CIPHER_GENIE_BUTTONS=1
    unset QT_WAYLAND_DISABLE_WINDOWDECORATION
else
    echo 'Cipher: private decorations are unavailable; continuing with standard decorations.' >&2
    unset CIPHER_GENIE_BUTTONS
fi
'''

def shell_wrapper(mode):
    return ('#!/usr/bin/env bash\nexec /usr/bin/python3 '+
            shlex.quote(str(ROOT/'buttons/runtime.py'))+' '+mode+' "$@"\n').encode()

def option_flag(source,name):
    optionfile=next((p for p in [source/'meson.options',source/'meson_options.txt'] if p.exists()),None)
    if not optionfile:return None
    match=re.search(r"option\(\s*['\"]"+re.escape(name)+r"['\"](.*?)\)",optionfile.read_text(),re.S)
    if not match:return None
    return '-D'+name+'='+('disabled' if re.search(r"type\s*:\s*['\"]feature['\"]",match.group(1)) else 'false')

def validate_qml(assets,qs):
    for theme in ['GlassPlayer','NexusPlayer','MaterialPlayer']:
        harness=assets/'lumina-music'/('_check-'+theme+'.qml')
        harness.write_text('import QtQuick\nimport Quickshell\nShellRoot {\n'
            'QtObject { id: controller; property bool switching: true; property string currentTheme: "nexus"; function setTheme(t) {} }\n'+
            theme+' { visible: false; ctl: "/usr/bin/true"; themeController: controller }\n'+
            'Timer { interval: 1200; running: true; onTriggered: { console.log("CIPHER_QML_OK '+theme+'"); Qt.quit(); } }\n}\n')
        env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',QSG_RHI_BACKEND='software')
        env.pop('QT_WAYLAND_DECORATION',None)
        try:
            p=subprocess.run([qs,'-p',str(harness),'-n'],env=env,capture_output=True,text=True,timeout=20)
            output=p.stdout+p.stderr
            (assets/('qml-'+theme+'.log')).write_text(output)
            if p.returncode or 'CIPHER_QML_OK '+theme not in output or re.search(
                r'Failed to load|Cannot assign|SyntaxError|ReferenceError|TypeError|Type \w+ unavailable',output):
                raise RuntimeError(theme+' failed its Quickshell load check; inspect '+str(assets/('qml-'+theme+'.log')))
            print('PASS: loaded',theme,'through installed Quickshell.',flush=True)
        finally:
            harness.unlink(missing_ok=True)

def prepare():
    if os.geteuid()==0:raise RuntimeError('Run as gamer, without sudo.')
    session=ROOT/'session.sh'
    if not session.is_file() or session.is_symlink() or digest(session)!=EXPECTED_SESSION:
        raise RuntimeError('The recovered session launcher changed or is missing; nothing installed.')
    patch_session(session.read_text())
    for name in ['git','meson','ninja','cc','pkg-config','qs']:
        if not shutil.which(name):raise RuntimeError('Missing build tool: '+name)
    # The original helper verifies receipt, hashes, Qt runtime versions and loadability.
    helper=Path.home()/'Downloads/test-cipher-app-buttons.py'
    if not helper.is_file():raise RuntimeError('Keep the approved test-cipher-app-buttons.py in Downloads.')
    module=runpy.run_path(str(helper),run_name='cipher_preview_library')
    receipt=module['existing']()
    stage=Path(tempfile.mkdtemp(prefix='.cipher-buttons-stage-',dir=BASE))
    print('Preparation directory:',stage,flush=True)
    assets=stage/'assets';assets.mkdir()
    shutil.copyfile(PACKAGE/'runtime.py',assets/'runtime.py')
    shutil.copytree(PACKAGE/'payload/lumina-music',assets/'lumina-music')
    shutil.copytree(PACKAGE/'payload/qt-source',assets/'qt-source')
    state={'format':1,'qt':{},'qs':str(Path(shutil.which('qs')).resolve()),'sourceCommit':FOOT_COMMIT}
    for major in ['6','5']:
        data=receipt['qt'][major]
        plugin=assets/('qt'+major+'/plugins/wayland-decoration-client/libqwhitesurgtkdecorations.so')
        plugin.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(data['plugin'],plugin)
        probe=assets/('probe-qt'+major);shutil.copy2(data['probe'],probe)
        state['qt'][major]={'plugin':str(plugin.relative_to(assets)),'probe':probe.name,
            'version':data['version'],'pluginSha256':digest(plugin),'probeSha256':digest(probe)}
    source=Path(receipt['work'])/'foot-upstream-1.28.0'
    if not source.is_dir():
        source=stage/'foot-upstream'
        run(['git','-c','core.hooksPath=/dev/null','clone','--depth=1','--branch','1.28.0',
             'https://codeberg.org/dnkl/foot.git',source],timeout=120)
    actual=run(['git','-C',source,'rev-parse','HEAD'],capture=True)
    if actual!=FOOT_COMMIT:raise RuntimeError('Foot source revision differs from the inspected input.')
    manifest=json.loads((PACKAGE/'payload/source-manifest.json').read_text())
    if digest(source/'render.c')!=manifest['original_sha256']['foot/render.c']:
        raise RuntimeError('Retained Foot renderer was modified; source preserved.')
    private=stage/'foot-source'
    shutil.copytree(source,private,ignore=shutil.ignore_patterns('.git','build','builddir','build-*','__pycache__'))
    shutil.copyfile(PACKAGE/'payload/foot/render.c',private/'render.c')
    flags=[v for v in [option_flag(private,'docs'),option_flag(private,'terminfo'),option_flag(private,'tests')] if v]
    builddir=stage/'foot-build'
    run(['meson','setup',builddir,private,'--buildtype=release','--wrap-mode=nofallback',*flags])
    run(['ninja','-C',builddir,'-j',str(min(8,os.cpu_count() or 2)),'foot'],timeout=600)
    (assets/'foot').mkdir();shutil.copy2(builddir/'foot',assets/'foot/foot')
    shutil.copyfile(PACKAGE/'payload/foot/LICENSE',assets/'foot/LICENSE')
    shutil.copyfile(PACKAGE/'payload/foot/traffic-lights.patch',assets/'foot/traffic-lights.patch')
    state['footSha256']=digest(assets/'foot/foot')
    run([assets/'foot/foot','--version'],capture=True)
    # Parse real config/overrides without connecting to the display.
    run([assets/'foot/foot','--check-config','--override=csd.preferred=client',
         '--override=csd.size=28','--override=csd.button-width=24',
         '--override=csd.hide-when-maximized=no','--override=csd.color=ff242428',
         '--override=csd.button-color=ffdddde6'])
    validate_qml(assets,state['qs'])
    (assets/'runtime.json').write_text(json.dumps(state,indent=2)+'\n')
    run([sys.executable,assets/'runtime.py','--check-qt'])
    (assets/'session-env.sh').write_text(session_env())
    checkfile=stage/'session-patched.sh';checkfile.write_text(patch_session(session.read_text()))
    run(['bash','-n',checkfile]);run(['bash','-n',assets/'session-env.sh'])
    (stage/'ready.json').write_text(json.dumps({'assets':str(assets),'sessionSha256':digest(session)}))
    print('PASS: private Foot compiled, config parsed, Qt plugins verified, all three Lumina themes loaded.',flush=True)
    return stage

def backup_target(path,backup,index):
    record={'path':str(path),'existed':path.exists() or path.is_symlink()}
    if path.is_symlink():raise RuntimeError('Managed target is a symlink; preserved: '+str(path))
    if record['existed']:
        record['mode']=path.stat().st_mode&0o777
        copy=backup/str(index);shutil.copy2(path,copy)
        record['backup']=str(copy);record['originalSha256']=digest(copy)
    return record

def restore(records):
    for record in reversed(records):
        path=Path(record['path'])
        if record['existed']:
            if digest(record['backup'])!=record['originalSha256']:raise RuntimeError('Backup changed: '+record['backup'])
            atomic(path,Path(record['backup']).read_bytes(),record['mode'])
        else:path.unlink(missing_ok=True)

def install(stage):
    ready=json.loads((stage/'ready.json').read_text())
    if digest(ROOT/'session.sh')!=ready['sessionSha256']:raise RuntimeError('Session changed during preparation; preserved.')
    destination=ROOT/'buttons'
    if destination.exists():raise RuntimeError('Buttons already installed; use --preview or --rollback.')
    backup=ROOT/('buttons-backup-'+time.strftime('%Y%m%d-%H%M%S')+'-'+str(os.getpid()));backup.mkdir()
    assets=Path(ready['assets'])
    global_music=Path.home()/'.local/bin/lumina-player-overlay'
    changes=[(ROOT/'bin/foot',shell_wrapper('--foot'),0o755),
        (ROOT/'bin/lumina-player-overlay',shell_wrapper('--music'),0o755),
        (global_music,shell_wrapper('--music'),0o755),
        (Path.home()/'.local/share/applications/cipher-qt-traffic-test.desktop',
         ('[Desktop Entry]\nType=Application\nName=Cipher Qt button test\nIcon=application-x-executable\nNoDisplay=true\nExec=/usr/bin/python3 '+
          shlex.quote(str(ROOT/'buttons/runtime.py'))+' --qt-test\n').encode(),0o644),
        (Path.home()/'.local/share/applications/io.huzaifah.LuminaMusic.desktop',
         ('[Desktop Entry]\nType=Application\nName=Lumina Music\nIcon=multimedia-player\nNoDisplay=true\nExec='+
          shlex.quote(str(global_music))+'\n').encode(),0o644),
        (ROOT/'session.sh',(stage/'session-patched.sh').read_bytes(),0o755)]
    records=[backup_target(path,backup,i) for i,(path,_,_) in enumerate(changes)]
    state=json.loads((assets/'runtime.json').read_text())
    state['musicFallback']=records[2].get('backup')
    (assets/'runtime.json').write_text(json.dumps(state,indent=2)+'\n')
    for record,(_,data,_) in zip(records,changes):record['installedSha256']=hashlib.sha256(data).hexdigest()
    (assets/'installed.json').write_text(json.dumps({'format':1,'records':records,'backup':str(backup)},indent=2)+'\n')
    os.replace(assets,destination)
    written=[]
    try:
        for record,(path,data,mode) in zip(records,changes):
            atomic(path,data,mode);written.append(record)
    except BaseException:
        restore(written);shutil.rmtree(destination);raise
    print('Installed for the next Cipher Genie login. No services restarted and no live environment changed.')
    print('Backup:',backup)
    print('Run --preview now to test Qt, Foot and Lumina in this desktop.')

def rollback():
    dest=ROOT/'buttons';state=json.loads((dest/'installed.json').read_text())
    records=state['records']
    for r in records:
        p=Path(r['path'])
        if not p.is_file() or p.is_symlink() or digest(p)!=r['installedSha256']:
            raise RuntimeError('A managed file changed after installation; preserving it: '+str(p))
        if r['existed'] and digest(r['backup'])!=r['originalSha256']:
            raise RuntimeError('A backup changed; preserving the installation.')
    restore(records)
    # Retain private binaries/logs for review; a renamed directory deactivates the guard.
    retained=ROOT/('buttons-rolled-back-'+time.strftime('%Y%m%d-%H%M%S'))
    os.rename(dest,retained)
    print('Original launchers restored; logs/binaries retained:',retained)
    print('If you logged in with the buttons enabled, log out once to restore that login\'s environment.')

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    group=ap.add_mutually_exclusive_group(required=True)
    for option in ['prepare','install','preview','rollback']:group.add_argument('--'+option,action='store_true')
    args=ap.parse_args()
    if args.preview:
        run([sys.executable,ROOT/'buttons/runtime.py','--preview'],timeout=30);return
    if os.geteuid()==0:raise RuntimeError('Run without sudo.')
    if not ROOT.is_dir():raise RuntimeError('The working Cipher Genie session is missing.')
    with open(ROOT/'.buttons-install.lock','a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        if args.rollback:rollback();return
        if (ROOT/'buttons').exists():raise RuntimeError('Buttons are already installed. Use --preview or --rollback.')
        stage=prepare()
        if args.install:install(stage)
        else:print('Prepared only. The session is unchanged; --install performs fresh validation before activation.')

if __name__=='__main__':
    try:main()
    except Exception as e:
        print('Cipher installation stopped:',e,file=sys.stderr)
        print('No session restart was requested. Preparation/build files are retained for diagnosis.',file=sys.stderr)
        sys.exit(1)
