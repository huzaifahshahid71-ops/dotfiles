"""Exercise real promotion transactions, profile dispatch and login cleanup.

Usage: python3 tests/check_integration.py RECOVERED_SESSION BUTTONS_PACKAGE GTK_PACKAGE
Native GUI/build checks are performed by the installer on the laptop.
"""
import importlib.util
import json
import os
from pathlib import Path
import runpy
import shutil
import socket
import subprocess
import sys

PACKAGE = Path(__file__).resolve().parents[1]
recovered, buttons_pkg, gtk_pkg = map(Path,sys.argv[1:])

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    module=importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    return module

sys.argv=['check_integration.py',str(recovered)]
fixture=runpy.run_path(str(buttons_pkg/'tests/check_integration.py'))
gtk=load('gtk',gtk_pkg/'install.py')
promote=load('promote',PACKAGE/'install.py')
system=load('system_route',PACKAGE/'system-route.py')
root=fixture['root']; home=fixture['home']; profile=fixture['profile']
source_session=root/'session.sh'
binary=fixture['binary']
# Recreate the approved source fixture after the underlying regression checks.
binary.write_text('''#!/usr/bin/python3
import os,sys,json
from pathlib import Path
if '--version' in sys.argv: print('niri 26.04 (c1a5a2f)'); sys.exit(0)
if 'validate' in sys.argv:
 if len(sys.argv)!=4 or sys.argv[1:3]!=['validate','--config']:
  print("error: unexpected argument 'validate' found",file=sys.stderr); sys.exit(2)
 p=Path(sys.argv[sys.argv.index('--config')+1]); text=p.read_text()
 assert 'off' in text
 assert (p.parent/'clavis/effects.kdl').is_file()
 sys.exit(0)
Path('''+repr(str(fixture['captured']))+''').write_text(json.dumps(dict(os.environ)))
raise SystemExit(int(os.environ.get('FAKE_NIRI_EXIT','0')))
'''); binary.chmod(0o755)
source_session.write_text(fixture['wrapper'])
gtk.ROOT=root; gtk.ASSETS=root/'buttons/gtk-controls'
gtk.SESSION_SHA=gtk.sha(source_session.read_bytes())
(root/'buttons/installed.json').write_text(json.dumps({'records':[{'path':str(source_session),'installedSha256':gtk.SESSION_SHA}]}))
gtk.install()
for name in ['qt5','qt6']:
    assert (root/'buttons'/name).is_dir()
shutil.copytree(buttons_pkg/'payload/qt-source',root/'buttons/qt-source')
shutil.copytree(buttons_pkg/'payload/lumina-music',root/'buttons/lumina-music')
(root/'buttons/foot').mkdir()
foot=root/'buttons/foot/foot'; foot.write_text('#!/bin/sh\nexit 0\n'); foot.chmod(0o755)
fallback=root/'original-music'; fallback.write_text('#!/bin/sh\nprintf original-music\n'); fallback.chmod(0o755)
state=json.loads((root/'buttons/runtime.json').read_text())
state.update(footSha256=promote.digest(foot),musicFallback=str(fallback),qs='/usr/bin/true')
(root/'buttons/runtime.json').write_text(json.dumps(state))
(root/'niri/clavis').mkdir(parents=True)
effects=profile/'niri/effects.kdl'; effects.write_text('// included setting\n')
(root/'niri/clavis/effects.kdl').symlink_to(effects)
(root/'niri/config.kdl').write_text('layout {\n focus-ring {\n  // Disable the blue outline.\n  off\n }\n border { off; }\n}\ninclude "clavis/effects.kdl"\n')
# The fixture follows Niri's CLI: root options conflict with subcommands.
p=subprocess.run([binary,'--config',root/'niri/config.kdl','validate'],capture_output=True,text=True)
assert p.returncode==2 and "unexpected argument 'validate'" in p.stderr
subprocess.run([binary,'validate','--config',root/'niri/config.kdl'],check=True)
print('PASS: CLI regression rejects root --config plus validate and accepts validate --config.')
(root/'shell-private').mkdir()
(root/'shell-private/dock.qml').write_text('import QtQuick\n// '+str(root)+'/shell-private\n')
(root/'shell.sh').write_text('#!/bin/bash\nROOT='+str(root)+'\nsource "$ROOT/buttons/session-env.sh"\nexec /usr/bin/true\n')
units=home/'.config/systemd/user'; units.mkdir(parents=True)
for old,path in [(promote.OLD_UNIT,'session.sh'),(promote.OLD_SHELL,'shell.sh')]:
    (units/old).write_text('[Unit]\nDescription=Cipher native Genie test\nWants='+promote.OLD_SHELL+'\n[Service]\nExecStart=/usr/bin/bash "'+str(root/path)+'"'+(' --compositor' if path=='session.sh' else '')+'\n')
global_music=home/'.local/bin/lumina-player-overlay'
global_music.write_text('#!/bin/sh\nprintf original-test-player\n'); global_music.chmod(0o755)
promote.HOME=home; promote.BASE=root.parent; promote.SOURCE=root
promote.PROFILE=profile; promote.NATIVE=profile/'native'
promote.SESSION_SHA=promote.digest(source_session)
system.TARGET=home/'system/multi-rice-session'; system.TARGET.parent.mkdir()
system.TARGET.write_bytes((PACKAGE/'stock-multi-rice-session').read_bytes()); system.TARGET.chmod(0o751)
system.BACKUPS=home/'system/backups'; system.BACKUPS.mkdir()
promote.SYSTEM=system.TARGET
promote.system_write=lambda state,action:system.transact(dict(state['system'],action=action))
initial_system=(system.TARGET.read_bytes(),system.TARGET.stat().st_mode & 0o777)
initial_music=(global_music.read_bytes(),global_music.stat().st_mode & 0o777)
local_route=home/'.local/bin/multi-rice-session'
source_hash=promote.digest(source_session)
fakebin=fixture['fakebin']
control=home/'.local/bin/multi-rice-control'
control.write_text('''#!/bin/bash
case "$2" in clavis|jaqc|nixri) echo target_compositor=niri;; *) echo target_compositor=hyprland;; esac
echo installed=true
'''); control.chmod(0o755)
(home/'.config/desktop-profile').mkdir()
active=home/'.config/desktop-profile/active'
for name in ['niri-session','uwsm','systemd-analyze']:
    p=fakebin/name; p.write_text('#!/bin/sh\nprintf "'+name+'\\n"\n'); p.chmod(0o755)
manager=fixture['manager']; captured=fixture['captured']
fake=fakebin/'systemctl'
text=fake.read_text().replace("'huzaifah-cipher-genie.service' in a", "'huzaifah-cipher-native.service' in a")
text=text.replace(repr(str(root/'session.sh')),repr(str(promote.NATIVE/'session.sh')))
fake.write_text(text)
initial=dict(fixture['initial'],GTK_MODULES='old module with spaces:another',CIPHER_GTK_BUTTONS_CSS='',CIPHER_NATIVE_RUNTIME='previous runtime with spaces')
env=dict(fixture['env'])
os.environ['PATH']=env['PATH']

# Emulate Niri's capability response; compositor/IPC smoke testing is on-device.
sock_path=fixture['fixture']/'caps.sock'
os.environ['NIRI_SOCKET']=str(sock_path)
mock='''import socket
class CapabilitySocket:
 def __init__(self,*args): self.sent=False
 def __enter__(self): return self
 def __exit__(self,*args): pass
 def settimeout(self,value): pass
 def connect(self,address): assert address.endswith('caps.sock')
 def sendall(self,data): assert data==b'"Capabilities"\\n'; self.sent=True
 def recv(self,count):
  assert self.sent
  return b'{"Ok":{"Capabilities":{"window_minimization":true,"window_minimization_effects":["genie"]}}}\\n'
socket.socket=CapabilitySocket
'''
mockdir=fixture['fixture']/'mock-ipc'; mockdir.mkdir()
(mockdir/'sitecustomize.py').write_text(mock)
old_socket=socket.socket
exec(mock)
env['PYTHONPATH']=str(mockdir)
try:
    promote.install()
    assert promote.digest(source_session)==source_hash
    assert (promote.NATIVE/'READY').is_file()
    assert not (promote.NATIVE/'niri/clavis/effects.kdl').is_symlink()
    assert (promote.NATIVE/'shell-private/dock.qml').is_file()
    assert str(root) not in (promote.NATIVE/'shell-private/dock.qml').read_text()
    assert promote.digest(promote.NATIVE/'bin/niri')==promote.digest(binary)
    assert str(root) not in (promote.NATIVE/'session.sh').read_text()
    assert system.TARGET.read_bytes()==local_route.read_bytes()
    print('PASS: actual promotion copies independent runtime/settings and publishes only the normal Cipher route.')

    def route(profile_id,dry=True):
        active.write_text(profile_id+'\n')
        p=subprocess.run(['bash',str(local_route),*(['--dry-run'] if dry else [])],env=env,capture_output=True,text=True,timeout=30)
        assert p.returncode==0,(p.stdout,p.stderr)
        return p.stdout
    assert str(promote.NATIVE/'session.sh') in route('clavis')
    for other in ['jaqc','nixri']:
        assert 'command=niri-session' in route(other)
        assert route(other,False).strip()=='niri-session'
    assert 'command=uwsm start -e -D Hyprland hyprland.desktop' in route('caelestia')
    assert route('caelestia',False).strip()=='uwsm'
    (promote.NATIVE/'READY').unlink()
    assert 'command=niri-session' in route('clavis')
    (promote.NATIVE/'READY').write_text('ready\n')
    print('PASS: real dispatch starts Cipher native, stock Solstice/Astra, unchanged Hyprland, and stock Cipher when native is absent.')

    # Remove the test runtime and original compositor to prove production independence.
    retained=root.with_name('temporarily-retained-test'); root.rename(retained)
    retained_binary=binary.with_name('retained-niri'); binary.rename(retained_binary)
    try:
        manager.write_text(json.dumps(initial)); captured.unlink(missing_ok=True)
        route('clavis',False)
        child=json.loads(captured.read_text()); actual=json.loads(manager.read_text())
        assert child['CIPHER_NATIVE_RUNTIME']==str(promote.NATIVE/'buttons')
        assert child['CIPHER_GENIE_BUTTONS']=='1'
        assert child['QT_WAYLAND_DECORATION']=='whitesur-gtk'
        assert child['CIPHER_GTK_PREVIEW']=='1'
        assert str(promote.NATIVE/'buttons/gtk-controls/libcipher-gtk3.so') in child['GTK_MODULES']
        for name in fixture['mod'].BUTTON_VARS+gtk.GTK_VARS+['PATH','NIRI_CONFIG','CIPHER_NATIVE_RUNTIME']:
            assert actual.get(name)==initial.get(name),(name,actual,initial)
        # Exercise both the real production router and the saved non-Cipher route.
        assert subprocess.check_output([global_music],env=env,text=True).strip()=='original-test-player'
        music_env=dict(child,NIRI_SOCKET=str(sock_path))
        p=subprocess.run([global_music],env=music_env,capture_output=True,text=True,timeout=20)
        assert p.returncode==0 and 'Lumina Music opened' in p.stdout,(p.stdout,p.stderr)
        print('PASS: actual normal login works with test files removed, scopes controls/music, and restores all manager values.')
        # Failed native startup must also clean the manager environment.
        manager.write_text(json.dumps(initial))
        p=subprocess.run(['bash',str(local_route)],env=dict(env,FAKE_NIRI_EXIT='42'),capture_output=True,text=True,timeout=30)
        assert p.returncode==42
        actual=json.loads(manager.read_text())
        for name in fixture['mod'].BUTTON_VARS+gtk.GTK_VARS+['PATH','NIRI_CONFIG','CIPHER_NATIVE_RUNTIME']:
            assert actual.get(name)==initial.get(name)
        print('PASS: failed production compositor startup restores every Qt/GTK/runtime manager variable.')
    finally:
        retained.rename(root); retained_binary.rename(binary)

    # Reject user-edited shared targets before restoring any file.
    prior=global_music.read_bytes(); global_music.write_bytes(prior+b'# user edit\n')
    try: promote.rollback(); raise AssertionError('Rollback accepted user edit')
    except RuntimeError: pass
    assert system.TARGET.read_bytes()==local_route.read_bytes()
    global_music.write_bytes(prior)
    promote.rollback()
    assert (system.TARGET.read_bytes(),system.TARGET.stat().st_mode & 0o777)==initial_system
    assert (global_music.read_bytes(),global_music.stat().st_mode & 0o777)==initial_music
    assert not local_route.exists()
    assert not (units/promote.UNIT).exists()
    assert promote.digest(source_session)==source_hash
    print('PASS: guarded rollback restores byte/mode-exact user and system launchers without touching the test session.')

    old_atomic=promote.atomic; counter=[0]
    def fail_second(path,data,mode=0o644):
        counter[0]+=1
        if counter[0]==2: raise OSError('injected user write failure')
        return old_atomic(path,data,mode)
    promote.atomic=fail_second
    try: promote.install(); raise AssertionError('Write failure ignored')
    except OSError: pass
    finally: promote.atomic=old_atomic
    assert not promote.NATIVE.exists()
    assert global_music.read_bytes()==initial_music[0] and system.TARGET.read_bytes()==initial_system[0]
    assert not (units/promote.UNIT).exists()
    print('PASS: interrupted user writes restore completed writes before the system route is activated.')

    orig_system_write=promote.system_write
    def commit_then_fail(state,action):
        orig_system_write(state,action)
        if action=='install': raise OSError('injected interruption after system commit')
    promote.system_write=commit_then_fail
    try: promote.install(); raise AssertionError('System failure ignored')
    except OSError: pass
    finally: promote.system_write=orig_system_write
    assert not promote.NATIVE.exists() and not local_route.exists()
    assert system.TARGET.read_bytes()==initial_system[0] and global_music.read_bytes()==initial_music[0]
    print('PASS: interruption after the system write restores both root and user routes.')

    # Preserve an unreviewed launcher before copying or changing any target.
    system.TARGET.write_bytes(initial_system[0]+b'# local customization\n')
    try: promote.install(); raise AssertionError('Accepted unreviewed system launcher')
    except RuntimeError: pass
    assert not promote.NATIVE.exists()
    print('PASS: promotion refuses an unreviewed system launcher without changing any profile.')
finally:
    socket.socket=old_socket
