#!/usr/bin/env python3
"""Activate the approved GTK3 controls only in the existing Cipher Genie login."""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import runpy
import shutil
import subprocess
import sys
import tempfile
import time

PACKAGE = Path(__file__).resolve().parent
ROOT = Path.home()/'.local/share/desktop-profiles/cipher-genie-session'
ASSETS = ROOT/'buttons/gtk-controls'
SESSION_SHA = '5dd01092fa26404412855ec7e45c1a7a4566eaf588d8a9bf881229371ce209ec'
ENV_SHA = '722ae89a45dd06f5eddd6d577431e49d616f24b814d2402c31aa398e10667ef2'
GTK_VARS = ['GTK_MODULES', 'CIPHER_GTK_PREVIEW', 'CIPHER_GTK_BUTTONS_CSS']

def sha(data):
    return hashlib.sha256(data).hexdigest()

def atomic(path, data, mode):
    fd, name = tempfile.mkstemp(prefix='.'+path.name+'-', dir=path.parent)
    try:
        with os.fdopen(fd, 'wb') as out:
            out.write(data); out.flush(); os.fsync(out.fileno())
        os.chmod(name, mode)
        os.replace(name, path)
    finally:
        if os.path.exists(name): os.unlink(name)

def patch_session(text):
    old = 'button_vars=(QT_PLUGIN_PATH QT_WAYLAND_DECORATION QT_QPA_PLATFORM QT_WAYLAND_DISABLE_WINDOWDECORATION CIPHER_GENIE_BUTTONS)'
    anchor = '    systemctl --user unset-environment QT_WAYLAND_DISABLE_WINDOWDECORATION\n'
    if text.count(old) != 1 or text.count(anchor) != 1:
        raise RuntimeError('Unsupported launcher layout; preserving it.')
    text = text.replace(old, old[:-1]+' '+' '.join(GTK_VARS)+')', 1)
    activation = '# Enable decorations only after the matching private Qt binaries pass.\n'
    if text.count(activation) != 1:
        raise RuntimeError('Unsupported launcher activation point; preserving it.')
    inherit = '''# Preserve manager-provided GTK modules if the login environment has none.
if [[ -z "${GTK_MODULES+x}" && "${button_had[GTK_MODULES]:-0}" == 1 ]]; then
    export GTK_MODULES="${button_old[GTK_MODULES]}"
fi
'''
    text = text.replace(activation, inherit+activation, 1)
    export = '''    if [[ "${CIPHER_GTK_PREVIEW:-}" == 1 ]]; then
        systemctl --user set-environment "GTK_MODULES=$GTK_MODULES" CIPHER_GTK_PREVIEW=1 "CIPHER_GTK_BUTTONS_CSS=$CIPHER_GTK_BUTTONS_CSS"
    fi
'''
    return text.replace(anchor, anchor+export, 1)

def patch_env(text):
    return text+'''
# BEGIN CIPHER GTK CONTROLS: toolkit settings are changed only in each process.
if [[ "${CIPHER_GENIE_BUTTONS:-}" == 1 ]]; then
    if /usr/bin/python3 "$ROOT/buttons/gtk-controls/guard.py"; then
        source "$ROOT/buttons/gtk-controls/environment.sh"
    else
        echo 'Cipher: continuing with standard GTK controls.' >&2
    fi
fi
# END CIPHER GTK CONTROLS
'''

def gtk_env():
    return '''# Source only after the private GTK compatibility guard passes.
module="$ROOT/buttons/gtk-controls/libcipher-gtk3.so"
case ":${GTK_MODULES:-}:" in
    *":$module:"*) ;;
    *) export GTK_MODULES="$module${GTK_MODULES:+:$GTK_MODULES}" ;;
esac
export CIPHER_GTK_PREVIEW=1
export CIPHER_GTK_BUTTONS_CSS="$ROOT/buttons/gtk-controls/buttons.css"
unset module
'''

def records_for(changes, backup):
    records = []
    for i, (path, data, mode) in enumerate(changes):
        if path.is_symlink() or not path.is_file():
            raise RuntimeError('Managed file is missing or a symlink: '+str(path))
        prior = path.read_bytes()
        saved = backup/str(i)
        saved.write_bytes(prior)
        records.append({'path':str(path), 'backup':str(saved),
                        'mode':path.stat().st_mode & 0o777,
                        'priorSha256':sha(prior), 'installedSha256':sha(data)})
    return records

def restore(records):
    for record in reversed(records):
        atomic(Path(record['path']), Path(record['backup']).read_bytes(), record['mode'])

def install():
    if ASSETS.exists() or ASSETS.is_symlink():
        raise RuntimeError('GTK controls are already installed; use --rollback first.')
    session = ROOT/'session.sh'
    envfile = ROOT/'buttons/session-env.sh'
    receipt = ROOT/'buttons/installed.json'
    if any(p.is_symlink() or not p.is_file() for p in [session, envfile, receipt]):
        raise RuntimeError('Install the approved Qt/Foot/Lumina buttons package first.')
    original, original_env = session.read_bytes(), envfile.read_bytes()
    if sha(original) != SESSION_SHA or sha(original_env) != ENV_SHA:
        raise RuntimeError('The installed Cipher launcher changed; preserving it.')
    base = json.loads(receipt.read_text())
    entries = [r for r in base['records'] if r['path'] == str(session)]
    if len(entries) != 1 or entries[0]['installedSha256'] != sha(original):
        raise RuntimeError('The base buttons rollback receipt does not match this launcher.')

    stage = Path(tempfile.mkdtemp(prefix='.gtk-controls-stage-', dir=ROOT))
    try:
        for name in ['buttons.c', 'buttons.css', 'preview.py', 'guard.py']:
            shutil.copy2(PACKAGE/name, stage/name)
        shutil.copytree(PACKAGE/'assets', stage/'assets')
        builder = runpy.run_path(str(stage/'preview.py'), run_name='private_gtk_builder')
        builder['build']()
        (stage/'environment.sh').write_text(gtk_env())
        manifest = {'format':1, 'diameterCssPx':10, 'sha256':{
            p.relative_to(stage).as_posix():sha(p.read_bytes())
            for p in sorted(stage.rglob('*'))
            if p.is_file() and p.suffix != '.pyc'}}
        (stage/'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
        subprocess.run([sys.executable, str(stage/'guard.py')], check=True, timeout=20)
        patched = patch_session(original.decode()).encode()
        patched_env = patch_env(original_env.decode()).encode()
        entries[0]['installedSha256'] = sha(patched)
        # Keep the existing Qt/Foot/Lumina rollback valid after this extension.
        new_receipt = (json.dumps(base, indent=2)+'\n').encode()
        for name, data in [('session-check.sh',patched), ('env-check.sh',patched_env)]:
            check = stage/name; check.write_bytes(data)
            subprocess.run(['bash','-n',str(check)], check=True, timeout=10)
            check.unlink()
        subprocess.run(['bash','-n',str(stage/'environment.sh')], check=True, timeout=10)
        changes = [(envfile, patched_env, envfile.stat().st_mode & 0o777),
                   (receipt, new_receipt, receipt.stat().st_mode & 0o777),
                   (session, patched, session.stat().st_mode & 0o777)]
        backup = Path(tempfile.mkdtemp(prefix='buttons-gtk-backup-'+time.strftime('%Y%m%d-%H%M%S')+'-', dir=ROOT))
        records = records_for(changes, backup)
        (stage/'installed.json').write_text(json.dumps({'format':1,'records':records},indent=2)+'\n')
        # Recheck every input after preparation, before writing any launch files.
        for r in records:
            if sha(Path(r['path']).read_bytes()) != r['priorSha256']:
                raise RuntimeError('A managed file changed during preparation; preserving it.')
        os.replace(stage, ASSETS)
        written = []
        try:
            for r,(path,data,mode) in zip(records,changes):
                atomic(path,data,mode); written.append(r)
        except BaseException:
            restore(written)
            shutil.rmtree(ASSETS)
            raise
    finally:
        if stage.exists(): shutil.rmtree(stage)
    print('Installed 10px GTK3 controls for the next Cipher Genie login.')
    print('Backups:', backup)
    print('Close Chrome normally, then log out and select Cipher Genie (test).')
    print('In your normal Chrome, choose GTK under Appearance if it is not already selected.')

def rollback():
    state = json.loads((ASSETS/'installed.json').read_text())
    records = state['records']
    for r in records:
        path, saved = Path(r['path']), Path(r['backup'])
        if path.is_symlink() or not path.is_file() or sha(path.read_bytes()) != r['installedSha256']:
            raise RuntimeError('A managed file changed after installation; preserving it: '+str(path))
        if saved.is_symlink() or sha(saved.read_bytes()) != r['priorSha256']:
            raise RuntimeError('A backup changed; preserving the installation.')
    current = [(Path(r['path']), Path(r['path']).read_bytes(), Path(r['path']).stat().st_mode & 0o777) for r in records]
    try:
        restore(records)
    except BaseException:
        for path, data, mode in current:
            atomic(path, data, mode)
        raise
    retained = Path(tempfile.mkdtemp(prefix='gtk-controls-rolled-back-', dir=ASSETS.parent))
    retained.rmdir()
    os.replace(ASSETS, retained)
    print('Restored the previous Qt/Foot/Lumina-only Cipher launcher.')
    print('Log out once to finish removing GTK controls from the running session.')

def main():
    parser = argparse.ArgumentParser()
    options = parser.add_mutually_exclusive_group(required=True)
    options.add_argument('--install', action='store_true')
    options.add_argument('--rollback', action='store_true')
    args = parser.parse_args()
    if os.geteuid() == 0: raise RuntimeError('Run as your normal user, without sudo.')
    if not ROOT.is_dir(): raise RuntimeError('The existing Cipher Genie session is missing.')
    with (ROOT/'.buttons-install.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if args.install: install()
        else: rollback()

if __name__ == '__main__':
    try: main()
    except Exception as error:
        print('Cipher GTK installation stopped:', error, file=sys.stderr)
        sys.exit(1)
