"""Exercise actual installer writes/rollback and real Bash manager restoration."""
from pathlib import Path
import tempfile,importlib.util,json,hashlib,os,subprocess,shutil
pkg=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('installer',pkg/'install.py');mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
fixture=Path(tempfile.mkdtemp(prefix='cipher-integration-'))
home=fixture/'home';home.mkdir();root=home/'.local/share/desktop-profiles/cipher-genie-session';(root/'bin').mkdir(parents=True)
# Original session text is supplied as an argument to avoid bundling private recovery data.
import sys
original=Path(sys.argv[1]).read_text()
mod.ROOT=root
orig_home=Path.home
Path.home=classmethod(lambda cls:home)
try:
 session=root/'session.sh';session.write_text(original);session.chmod(0o755)
 global_music=home/'.local/bin/lumina-player-overlay';global_music.parent.mkdir(parents=True);global_music.write_text('#!/bin/sh\nprintf original\n');global_music.chmod(0o755)
 oldfoot=root/'bin/foot';oldfoot.write_text('#!/bin/sh\nprintf originalfoot\n');oldfoot.chmod(0o755)
 originals={p:(p.read_bytes(),p.stat().st_mode&0o777) for p in [session,global_music,oldfoot]}
 stage=fixture/'stage';assets=stage/'assets';assets.mkdir(parents=True)
 (assets/'runtime.json').write_text('{}')
 (stage/'session-patched.sh').write_text(mod.patch_session(original))
 (stage/'ready.json').write_text(json.dumps({'assets':str(assets),'sessionSha256':mod.digest(session)}))
 mod.install(stage)
 assert (root/'buttons/installed.json').exists()
 state=json.loads((root/'buttons/runtime.json').read_text());assert Path(state['musicFallback']).read_bytes()==originals[global_music][0]
 for r in json.loads((root/'buttons/installed.json').read_text())['records']:assert mod.digest(r['path'])==r['installedSha256']
 # A user edit must block rollback before touching any managed target.
 changed=home/'.local/share/applications/io.huzaifah.LuminaMusic.desktop';old=changed.read_bytes();changed.write_text('user modification\n')
 try:mod.rollback();raise AssertionError('rollback accepted user edit')
 except RuntimeError:pass
 assert session.read_text()!=original
 changed.write_bytes(old);mod.rollback()
 for p,(data,mode) in originals.items():assert p.read_bytes()==data and p.stat().st_mode&0o777==mode
 assert not (root/'bin/lumina-player-overlay').exists()
 assert not (home/'.local/share/applications/cipher-qt-traffic-test.desktop').exists()
 print('PASS: actual installer writes, fallback backup, user-edit protection and byte/mode-exact rollback.')
 # An injected write failure must restore every previously changed launcher.
 stage2=fixture/'stage2';assets2=stage2/'assets';assets2.mkdir(parents=True);(assets2/'runtime.json').write_text('{}')
 (stage2/'session-patched.sh').write_text(mod.patch_session(original));(stage2/'ready.json').write_text(json.dumps({'assets':str(assets2),'sessionSha256':mod.digest(session)}))
 orig_atomic=mod.atomic;count=[0]
 def fail_third(path,data,mode=0o644):
  count[0]+=1
  if count[0]==3:raise OSError('injected write failure')
  return orig_atomic(path,data,mode)
 mod.atomic=fail_third
 try:mod.install(stage2);raise AssertionError('failure was swallowed')
 except OSError:pass
 finally:mod.atomic=orig_atomic
 for p,(data,mode) in originals.items():assert p.read_bytes()==data
 assert not (root/'buttons').exists()
 print('PASS: partial-install write failure restores previously changed files.')
finally:Path.home=orig_home
# Real generated session.sh with a fake systemd manager and a fake niri executable.
profile=home/'.local/share/desktop-profiles/clavis';(profile/'niri').mkdir(parents=True)
(home/'.config').mkdir();(home/'.config/niri').symlink_to(profile/'niri')
(root/'buttons').mkdir();shutil.copyfile(pkg/'runtime.py',root/'buttons/runtime.py')
qt={}
for major in ['6','5']:
 probe=root/'buttons'/('probe-qt'+major);probe.write_text('#!/bin/sh\nif [ "$1" = --version ]; then echo '+major+'.0.0; fi\n');probe.chmod(0o755)
 plugin=root/'buttons'/('qt'+major+'/plugins/wayland-decoration-client/test.so');plugin.parent.mkdir(parents=True);plugin.write_bytes(b'fixture')
 qt[major]={'probe':probe.name,'plugin':str(plugin.relative_to(root/'buttons')),'version':major+'.0.0','pluginSha256':mod.digest(plugin),'probeSha256':mod.digest(probe)}
(root/'buttons/runtime.json').write_text(json.dumps({'qt':qt}));(root/'buttons/session-env.sh').write_text(mod.session_env())
fakebin=fixture/'fakebin';fakebin.mkdir()
manager=fixture/'manager.json';captured=fixture/'captured.json'
initial={'PATH':str(fakebin)+':/usr/bin:/bin','NIRI_CONFIG':'old config with spaces','QT_PLUGIN_PATH':'prior:/plugins with spaces','QT_QPA_PLATFORM':'xcb','QT_WAYLAND_DISABLE_WINDOWDECORATION':''}
manager.write_text(json.dumps(initial))
binary=fixture/'fake-niri';binary.write_text('#!/usr/bin/python3\nimport os,json\nfrom pathlib import Path\nPath('+repr(str(captured))+').write_text(json.dumps(dict(os.environ)))\n');binary.chmod(0o755)
wrapper=mod.patch_session(original).replace('/home/gamer/.local/share/desktop-profiles/cipher-genie-session',str(root)).replace('/home/gamer/.local/share/desktop-profiles/clavis',str(profile)).replace('/home/gamer/.local/share/desktop-profiles/.cipher-genie-build-SJNw4cPV/source/target/release/niri',str(binary))
(root/'session.sh').write_text(wrapper)
fake=fakebin/'systemctl';fake.write_text('''#!/usr/bin/python3
import sys,json,os,subprocess
from pathlib import Path
file=Path('''+repr(str(manager))+''')
data=json.loads(file.read_text());a=[x for x in sys.argv[1:] if not x.startswith('--')]
cmd=a[0]
if cmd=='show-environment':
 print('\\n'.join(k+'='+v for k,v in data.items()))
elif cmd=='set-environment':
 for x in a[1:]:k,v=x.split('=',1);data[k]=v
elif cmd=='unset-environment':
 for k in a[1:]:data.pop(k,None)
elif cmd=='import-environment':
 for k in a[1:]:data[k]=os.environ[k]
elif cmd=='is-active':sys.exit(1)
elif cmd=='start' and 'huzaifah-cipher-genie.service' in a:
 env=dict(os.environ);env.update(data)
 p=subprocess.run(['bash','''+repr(str(root/'session.sh'))+''','--compositor'],env=env)
 sys.exit(p.returncode)
file.write_text(json.dumps(data))
''');fake.chmod(0o755)
env={'HOME':str(home),'PATH':initial['PATH'],'XDG_RUNTIME_DIR':str(fixture),'LANG':'C.UTF-8'}
p=subprocess.run(['bash',str(root/'session.sh')],env=env,capture_output=True,text=True,timeout=40)
assert p.returncode==0,(p.stdout,p.stderr,(root/'logs/login-startup.log').read_text())
actual=json.loads(manager.read_text());child=json.loads(captured.read_text())
for name in mod.BUTTON_VARS+['PATH','NIRI_CONFIG']:assert actual.get(name)==initial.get(name),(name,actual.get(name),initial.get(name))
assert child['QT_WAYLAND_DECORATION']=='whitesur-gtk' and child['CIPHER_GENIE_BUTTONS']=='1'
assert 'QT_WAYLAND_DISABLE_WINDOWDECORATION' not in child
print('PASS: generated Bash login exports decorations and restores manager values, empty values and unset variables.')
# Runtime mismatch must degrade decorations rather than bounce back to SDDM.
state=json.loads((root/'buttons/runtime.json').read_text());state['qt']['6']['version']='6.99.0';(root/'buttons/runtime.json').write_text(json.dumps(state));manager.write_text(json.dumps(initial));captured.unlink()
p=subprocess.run(['bash',str(root/'session.sh')],env=env,capture_output=True,text=True,timeout=40)
assert p.returncode==0
child=json.loads(captured.read_text());assert 'CIPHER_GENIE_BUTTONS' not in child and child.get('QT_QPA_PLATFORM')=='xcb'
actual=json.loads(manager.read_text())
for name in mod.BUTTON_VARS+['PATH','NIRI_CONFIG']:assert actual.get(name)==initial.get(name)
print('PASS: incompatible Qt guard keeps login working with original environment.')
# The EXIT trap restores manager values when the compositor exits with an error.
state['qt']['6']['version']='6.0.0';(root/'buttons/runtime.json').write_text(json.dumps(state));manager.write_text(json.dumps(initial))
binary.write_text(binary.read_text()+'\nraise SystemExit(42)\n')
p=subprocess.run(['bash',str(root/'session.sh')],env=env,capture_output=True,text=True,timeout=40)
assert p.returncode==42,p.returncode
actual=json.loads(manager.read_text())
for name in mod.BUTTON_VARS+['PATH','NIRI_CONFIG']:assert actual.get(name)==initial.get(name)
print('PASS: failed compositor startup still restores manager environment.')
