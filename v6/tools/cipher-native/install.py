#!/usr/bin/env python3
"""Promote the approved Cipher Genie runtime into the normal Multi-Rice login."""
import argparse
import base64
from contextlib import ExitStack
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

PACKAGE = Path(__file__).resolve().parent
HOME = Path.home()
BASE = HOME/'.local/share/desktop-profiles'
SOURCE = BASE/'cipher-genie-session'
PROFILE = BASE/'clavis'
NATIVE = PROFILE/'native'
SYSTEM = Path('/usr/local/bin/multi-rice-session')
SESSION_SHA = 'db47b4d7cdf2706cda1980165a2e12fc6bfd5d2a408723683d310ccd1c05728b'
STOCK_ROUTE_SHA = '148688425ea20c0fc31d7c39cf5eedab4a082e208410e5d5bf1d66240b72604f'
OLD_UNIT = 'huzaifah-cipher-genie.service'
OLD_SHELL = 'huzaifah-cipher-genie-shell.service'
UNIT = 'huzaifah-cipher-native.service'
SHELL = 'huzaifah-cipher-native-shell.service'

def sha(data):
    return hashlib.sha256(data).hexdigest()

def digest(path):
    return sha(Path(path).read_bytes())

def run(args, *, timeout=30, env=None):
    p = subprocess.run(list(map(str,args)), capture_output=True, text=True,
                       timeout=timeout, env=env)
    if p.returncode:
        raise RuntimeError((p.stderr or p.stdout).strip() or 'Command failed: '+str(args[0]))
    return p.stdout.strip()

def atomic(path, data, mode=0o644):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix='.'+path.name+'-', dir=path.parent)
    try:
        with os.fdopen(fd,'wb') as out:
            out.write(data); out.flush(); os.fsync(out.fileno())
        os.chmod(name, mode); os.replace(name, path)
    finally:
        if os.path.exists(name): os.unlink(name)

def rewrite(text, source_binary):
    return (text.replace(str(SOURCE), str(NATIVE))
            .replace(str(source_binary), str(NATIVE/'bin/niri'))
            .replace(OLD_SHELL, SHELL).replace(OLD_UNIT, UNIT)
            .replace('Cipher Genie (test)', 'Huzaifah Multi-Rice (Cipher)'))

def native_session(text, binary):
    text = rewrite(text, binary)
    if text.count('BINARY=') != 1: raise RuntimeError('Unexpected compositor launcher.')
    text = re.sub(r'^BINARY=.*$', 'BINARY='+shlex.quote(str(NATIVE/'bin/niri')), text, flags=re.M)
    old = 'CIPHER_GTK_BUTTONS_CSS)'
    if text.count(old) != 1: raise RuntimeError('GTK variable restoration is missing.')
    text = text.replace(old, 'CIPHER_GTK_BUTTONS_CSS CIPHER_NATIVE_RUNTIME)', 1)
    anchor = '    systemctl --user unset-environment QT_WAYLAND_DISABLE_WINDOWDECORATION\n'
    if text.count(anchor) != 1: raise RuntimeError('Unexpected environment activation.')
    text = text.replace(anchor, anchor+
        '    export CIPHER_NATIVE_RUNTIME="$ROOT/buttons"\n'
        '    systemctl --user set-environment "CIPHER_NATIVE_RUNTIME=$CIPHER_NATIVE_RUNTIME"\n', 1)
    # Refuse overlapping stock, production, or test compositor services.
    text = text.replace('for unit in niri.service "$UNIT"; do',
                        'for unit in niri.service '+OLD_UNIT+' "$UNIT"; do', 1)
    # The compositor itself and its children need the production music selector.
    anchor = '    export NIRI_CONFIG="$ROOT/niri/config.kdl"'
    text = text.replace(anchor, '    export CIPHER_NATIVE_RUNTIME="$ROOT/buttons"\n'+anchor, 1)
    if str(SOURCE) in text: raise RuntimeError('Launcher still depends on the test directory.')
    return text

def record_targets(changes, backup):
    records = []
    for i,(path,data,mode) in enumerate(changes):
        if path.is_symlink() or (path.exists() and not path.is_file()):
            raise RuntimeError('Managed target is not a regular file: '+str(path))
        record = {'path':str(path), 'existed':path.exists(), 'installedSha256':sha(data)}
        if record['existed']:
            original = path.read_bytes(); saved = backup/str(i); saved.write_bytes(original)
            record.update(backup=str(saved), priorSha256=sha(original), mode=path.stat().st_mode & 0o777)
        records.append(record)
    return records

def verify_records(records, installed):
    for r in records:
        path = Path(r['path'])
        if path.is_symlink(): raise RuntimeError('Managed target became a symlink: '+str(path))
        expected = r['installedSha256'] if installed else r.get('priorSha256')
        if expected:
            if not path.is_file() or digest(path) != expected:
                raise RuntimeError('Managed file changed; preserved: '+str(path))
        elif path.exists(): raise RuntimeError('Managed target appeared; preserved: '+str(path))
        if r['existed'] and digest(r['backup']) != r['priorSha256']:
            raise RuntimeError('Recovery copy changed: '+r['backup'])

def restore(records):
    for r in reversed(records):
        path = Path(r['path'])
        if r['existed']: atomic(path, Path(r['backup']).read_bytes(), r['mode'])
        else: path.unlink(missing_ok=True)

def system_write(state, action):
    request = dict(state['system'], action=action)
    p = subprocess.run(['sudo','/usr/bin/python3',str(PACKAGE/'system-route.py')],
                       input=json.dumps(request), text=True)
    if p.returncode: raise RuntimeError('System launcher update failed; see output above.')

def check_source():
    for path in [SOURCE/'session.sh', SOURCE/'shell.sh', SYSTEM]:
        if path.is_symlink() or not path.is_file():
            raise RuntimeError('Expected regular file is missing: '+str(path))
    if digest(SOURCE/'session.sh') != SESSION_SHA:
        raise RuntimeError('The tested Qt+GTK launcher changed; preserved.')
    route = (PACKAGE/'multi-rice-session').read_bytes()
    if digest(SYSTEM) not in [STOCK_ROUTE_SHA,sha(route)]:
        raise RuntimeError('The normal Multi-Rice launcher differs from the reviewed version; preserved.')
    local_route = HOME/'.local/bin/multi-rice-session'
    if local_route.exists() and (local_route.is_symlink() or digest(local_route) not in [STOCK_ROUTE_SHA,sha(route)]):
        raise RuntimeError('The user Multi-Rice launcher differs; preserved.')
    # Ask the running compositor for capabilities, without reading titles or app data.
    runtime = runpy.run_path(str(SOURCE/'buttons/runtime.py'), run_name='promotion_guard')
    runtime['require_genie']()
    state = runtime['check_qt']()
    if digest(SOURCE/'buttons/foot/foot') != state['footSha256']:
        raise RuntimeError('The approved private Foot changed.')
    gtk = SOURCE/'buttons/gtk-controls'
    manifest = json.loads((gtk/'manifest.json').read_text())
    if manifest['diameterCssPx'] != 10: raise RuntimeError('Expected the approved smaller GTK controls.')
    run([sys.executable,gtk/'guard.py'])
    binary_lines = re.findall(r'^BINARY=(.+)$',(SOURCE/'session.sh').read_text(),re.M)
    if len(binary_lines) != 1: raise RuntimeError('Unable to resolve the tested compositor.')
    words = shlex.split(binary_lines[0])
    if len(words) != 1: raise RuntimeError('Unexpected compositor path.')
    binary = Path(words[0])
    compositor_sha = digest(binary)
    version = run([binary,'--version'])
    if 'c1a5a2f' not in version: raise RuntimeError('The tested Genie compositor revision differs.')
    if digest(binary) != compositor_sha: raise RuntimeError('The compositor changed during validation.')
    state['sourceNiriSha256'] = compositor_sha
    return binary, state, route

def prepare(stage, binary, state):
    (stage/'bin').mkdir()
    # The tested Dock/shell may carry private QML or native imports beside shell.sh.
    # Preserve these runtime files as well as the known app-controls directories.
    skip = {'bin','buttons','niri','logs','session.sh','shell.sh','receipt.json'}
    for path in SOURCE.iterdir():
        if path.name in skip or path.name.startswith('.') or 'backup' in path.name or 'rolled-back' in path.name:
            continue
        if path.is_dir():
            shutil.copytree(path,stage/path.name,ignore=shutil.ignore_patterns('__pycache__','*.log','*.lock'))
        elif path.is_file(): shutil.copy2(path,stage/path.name)
    if (SOURCE/'bin').is_dir():
        shutil.copytree(SOURCE/'bin',stage/'bin',dirs_exist_ok=True)
    for path in stage.rglob('*'):
        if path.is_file():
            content = path.read_bytes()
            if path.suffix in {'.sh','.qml','.js','.kdl','.json','.conf'} or content.startswith(b'#!'):
                path.write_text(rewrite(content.decode(),binary))
    shutil.copy2(binary,stage/'bin/niri')
    if digest(stage/'bin/niri') != state['sourceNiriSha256']:
        raise RuntimeError('The compositor changed while copying; preserving the current login.')
    buttons = stage/'buttons'; buttons.mkdir()
    for name in ['qt5','qt6','qt-source','foot','lumina-music','gtk-controls']:
        shutil.copytree(SOURCE/'buttons'/name,buttons/name,
            ignore=shutil.ignore_patterns('__pycache__','*.log','*.lock','installed.json','chrome-controls-preview-*'))
    for name in ['runtime.py','session-env.sh','probe-qt5','probe-qt6']:
        shutil.copy2(SOURCE/'buttons'/name,buttons/name)
    fallback = Path(state['musicFallback'])
    if not fallback.is_file(): raise RuntimeError('Original player fallback is missing.')
    shutil.copy2(fallback,buttons/'music-original.sh')
    state = dict(state, musicFallback=str(NATIVE/'buttons/music-original.sh'))
    (buttons/'runtime.json').write_text(json.dumps(state,indent=2)+'\n')
    shutil.copytree(SOURCE/'niri',stage/'niri',ignore=shutil.ignore_patterns('*.focus-ring-backup-*','*.bak'))
    # Copy through source symlinks so settings and includes survive independently.
    for path in (stage/'niri').rglob('*.kdl'):
        path.write_text(rewrite(path.read_text(),binary))
    config = (stage/'niri/config.kdl').read_text()
    if not re.search(r'focus-ring\s*\{\s*(?://[^\n]*\n\s*)*off\b',config):
        raise RuntimeError('The approved focus-ring-off setting is missing; run the border fix first.')
    for name in ['session.sh','shell.sh']:
        original = (SOURCE/name).read_text()
        updated = native_session(original,binary) if name == 'session.sh' else rewrite(original,binary)
        if str(SOURCE) in updated: raise RuntimeError('Shell still depends on test files.')
        (stage/name).write_text(updated); (stage/name).chmod(0o755)
        run(['bash','-n',stage/name])
    for mode in ['foot','music']:
        script = '#!/usr/bin/env bash\nexec /usr/bin/python3 '+shlex.quote(str(NATIVE/'buttons/runtime.py'))+' --'+mode+' "$@"\n'
        name = 'foot' if mode == 'foot' else 'lumina-player-overlay'
        (stage/'bin'/name).write_text(script); (stage/'bin'/name).chmod(0o755)
    # Absolute include paths must resolve inside the stage during validation.
    configs = {p:p.read_text() for p in (stage/'niri').rglob('*.kdl')}
    try:
        for path,text in configs.items(): path.write_text(text.replace(str(NATIVE),str(stage)))
        run([stage/'bin/niri','validate','--config',stage/'niri/config.kdl'])
    finally:
        for path,text in configs.items(): path.write_text(text)
    run([sys.executable,buttons/'runtime.py','--check-qt'])
    run([sys.executable,buttons/'gtk-controls/guard.py'])
    run([buttons/'foot/foot','--check-config','--override=csd.preferred=client',
         '--override=csd.size=28','--override=csd.button-width=24','--override=csd.hide-when-maximized=no'])

def unit_changes(binary):
    changes = []
    for old,new in [(OLD_UNIT,UNIT),(OLD_SHELL,SHELL)]:
        path = HOME/'.config/systemd/user'/old
        if path.is_symlink() or not path.is_file(): raise RuntimeError('Test service is missing: '+old)
        text = rewrite(path.read_text(),binary).replace('native Genie test','native Genie').replace('for native Genie test','for native Genie')
        # systemd expands percent specifiers even in quoted ExecStart arguments.
        if '%' in str(NATIVE): raise RuntimeError('A percent sign in the home path requires a separate adapter.')
        changes.append((path.parent/new,text.encode(),0o644))
    return changes

def install():
    if NATIVE.exists() or NATIVE.is_symlink():
        raise RuntimeError('Production Cipher already exists; use --status or --rollback.')
    binary,state,route = check_source()
    PROFILE.mkdir(parents=True,exist_ok=True)
    stage = Path(tempfile.mkdtemp(prefix='.native-stage-',dir=PROFILE))
    backup = Path(tempfile.mkdtemp(prefix='cipher-native-backup-',dir=BASE))
    try:
        prepare(stage,binary,state)
        global_music = HOME/'.local/bin/lumina-player-overlay'
        if global_music.is_symlink() or not global_music.is_file(): raise RuntimeError('Player launcher is missing or a symlink.')
        (stage/'original-launchers').mkdir()
        shutil.copy2(global_music,stage/'original-launchers/lumina-player-overlay')
        dispatcher = ('#!/usr/bin/env bash\n'
            'if [[ "${CIPHER_GENIE_BUTTONS:-}" == 1 && "${CIPHER_NATIVE_RUNTIME:-}" == '+shlex.quote(str(NATIVE/'buttons'))+' ]]; then\n'
            '    exec /usr/bin/python3 '+shlex.quote(str(NATIVE/'buttons/runtime.py'))+' --music "$@"\n'
            'fi\nexec '+shlex.quote(str(NATIVE/'original-launchers/lumina-player-overlay'))+' "$@"\n').encode()
        changes = unit_changes(binary)+[(global_music,dispatcher,0o755),
                    (HOME/'.local/bin/multi-rice-session',route,0o755)]
        records = record_targets(changes,backup)
        receipt = {'format':1,'status':'pending','records':records,'backup':str(backup),
                   'source':str(SOURCE),'compositorSha256':digest(stage/'bin/niri'),
                   'system':{'priorSha256':digest(SYSTEM),'installedSha256':sha(route),
                             'contentBase64':base64.b64encode(route).decode()}}
        (stage/'installed.json').write_text(json.dumps(receipt,indent=2)+'\n')
        verify_records(records,False)
        os.replace(stage,NATIVE)
        written = []
        try:
            run([NATIVE/'bin/niri','validate','--config',NATIVE/'niri/config.kdl'])
            for record,(path,data,mode) in zip(records,changes):
                atomic(path,data,mode); written.append(record)
            run(['systemctl','--user','daemon-reload'])
            # Check real service parsing before enabling the normal entry.
            run(['systemd-analyze','--user','verify',*[p for p,_,_ in changes[:2]]])
            atomic(NATIVE/'READY',b'Cipher native runtime format 1\n')
            system_write(receipt,'install')
            receipt['status'] = 'installed'
            atomic(NATIVE/'installed.json',(json.dumps(receipt,indent=2)+'\n').encode())
        except BaseException:
            # The system route might have committed before sudo was interrupted.
            if digest(SYSTEM) == receipt['system']['installedSha256'] and receipt['system']['priorSha256'] != digest(SYSTEM):
                system_write(receipt,'rollback')
            restore(written)
            (NATIVE/'READY').unlink(missing_ok=True)
            run(['systemctl','--user','daemon-reload'])
            retained = backup/'failed-native'; os.replace(NATIVE,retained)
            raise
    finally:
        if stage.exists(): shutil.rmtree(stage)
    print('Installed native Genie, Qt/GTK controls, Foot and Lumina for normal Cipher.')
    print('Backups:',backup)
    print('No running compositor or shell was restarted.')
    print('Close Chrome normally, log out, select Huzaifah Multi-Rice, and log in with Cipher selected.')
    print('Keep Chrome Appearance on GTK and system title bar disabled.')

def rollback():
    receipt = json.loads((NATIVE/'installed.json').read_text())
    for unit in [UNIT,SHELL]:
        p = subprocess.run(['systemctl','--user','--quiet','is-active',unit])
        if p.returncode == 0: raise RuntimeError('Log out of normal Cipher before rollback; run it from the test session or another rice.')
    installed = receipt['status'] == 'installed'
    if installed: verify_records(receipt['records'],True)
    else:
        # Every target may be before or after its write in an interrupted install.
        for r in receipt['records']:
            path=Path(r['path'])
            current=digest(path) if path.is_file() and not path.is_symlink() else None
            if path.is_symlink() or current not in [r.get('priorSha256'),r['installedSha256']]:
                raise RuntimeError('Interrupted target edited; preserved: '+str(path))
            if r['existed'] and digest(r['backup']) != r['priorSha256']: raise RuntimeError('Recovery copy changed.')
    if digest(SYSTEM) not in [receipt['system']['priorSha256'],receipt['system']['installedSha256']]:
        raise RuntimeError('System launcher edited after installation; preserved.')
    current = [(Path(r['path']),Path(r['path']).read_bytes() if Path(r['path']).exists() else None,
                Path(r['path']).stat().st_mode & 0o777 if Path(r['path']).exists() else 0o644) for r in receipt['records']]
    system_write(receipt,'rollback')
    try:
        restore(receipt['records'])
        run(['systemctl','--user','daemon-reload'])
    except BaseException:
        for path,data,mode in current:
            if data is None: path.unlink(missing_ok=True)
            else: atomic(path,data,mode)
        system_write(receipt,'install')
        raise
    retained = Path(tempfile.mkdtemp(prefix='cipher-native-retained-',dir=BASE)); retained.rmdir()
    os.replace(NATIVE,retained)
    print('Restored the previous Multi-Rice entry and player launcher. Retained runtime:',retained)
    print('Cipher Genie (test) remains available.')

def status():
    receipt=json.loads((NATIVE/'installed.json').read_text())
    print('production='+receipt['status'])
    print('runtime='+str(NATIVE))
    print('system_route_matches='+str(digest(SYSTEM)==receipt['system']['installedSha256']).lower())
    print('compositor_matches='+str(digest(NATIVE/'bin/niri')==receipt['compositorSha256']).lower())
    if receipt['status']=='installed': verify_records(receipt['records'],True)

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    group=ap.add_mutually_exclusive_group(required=True)
    for mode in ['install','rollback','status']: group.add_argument('--'+mode,action='store_true')
    args=ap.parse_args()
    if os.geteuid()==0: raise RuntimeError('Run as your normal user; only the system route uses sudo.')
    if args.install and not SOURCE.is_dir(): raise RuntimeError('The tested Cipher Genie session is missing.')
    if not BASE.is_dir(): raise RuntimeError('The Multi-Rice profile root is missing.')
    with ExitStack() as stack:
        lockpaths = [BASE/'.cipher-native-install.lock']
        if SOURCE.is_dir(): lockpaths.append(SOURCE/'.buttons-install.lock')
        for path in lockpaths:
            lock=stack.enter_context(path.open('a'))
            fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        if args.install: install()
        elif args.rollback: rollback()
        else: status()

if __name__=='__main__':
    try: main()
    except Exception as error:
        print('Cipher promotion stopped:',error,file=sys.stderr)
        print('No session restart was requested.',file=sys.stderr)
        sys.exit(1)
