#!/usr/bin/env python3
"""Update only the system Multi-Rice entry, with a root-owned recovery copy."""
import base64
import fcntl
import hashlib
import json
import os
from pathlib import Path
import sys
import tempfile

TARGET = Path('/usr/local/bin/multi-rice-session')
BACKUPS = Path('/usr/local/lib/huzaifah-multi-rice/cipher-route-backups')

def sha(data):
    return hashlib.sha256(data).hexdigest()

def atomic(path, data, mode, uid=0, gid=0):
    fd, name = tempfile.mkstemp(prefix='.'+path.name+'-', dir=path.parent)
    try:
        with os.fdopen(fd, 'wb') as out:
            out.write(data); out.flush(); os.fsync(out.fileno())
        os.chmod(name, mode); os.chown(name, uid, gid)
        os.replace(name, path)
    finally:
        if os.path.exists(name): os.unlink(name)

def transact(request):
    if TARGET.is_symlink() or not TARGET.is_file():
        raise RuntimeError('System launcher is missing or a symlink; preserved.')
    prior_sha = request['priorSha256']
    installed_sha = request['installedSha256']
    if any(len(s) != 64 or any(c not in '0123456789abcdef' for c in s)
           for s in [prior_sha, installed_sha]):
        raise RuntimeError('Invalid launcher hash.')
    saved = BACKUPS/(prior_sha+'.json')
    original = TARGET.read_bytes()
    if request['action'] == 'install':
        data = base64.b64decode(request['contentBase64'], validate=True)
        if sha(data) != installed_sha or sha(original) != prior_sha:
            raise RuntimeError('System launcher changed; nothing overwritten.')
        stat = TARGET.stat()
        record = {'priorSha256':prior_sha, 'data':base64.b64encode(original).decode(),
                  'mode':stat.st_mode & 0o777, 'uid':stat.st_uid, 'gid':stat.st_gid}
        if saved.exists():
            old = json.loads(saved.read_text())
            if old != record: raise RuntimeError('Recovery copy differs; preserved.')
        else:
            atomic(saved, (json.dumps(record)+'\n').encode(), 0o600)
        atomic(TARGET, data, 0o755)
    elif request['action'] == 'rollback':
        if sha(original) == prior_sha:
            return  # Also recover an interrupted transaction before the root write.
        if sha(original) != installed_sha:
            raise RuntimeError('System launcher edited after installation; preserved.')
        record = json.loads(saved.read_text())
        data = base64.b64decode(record['data'], validate=True)
        if sha(data) != prior_sha: raise RuntimeError('Recovery copy changed.')
        atomic(TARGET, data, record['mode'], record['uid'], record['gid'])
    else:
        raise RuntimeError('Unsupported action.')

def main():
    if os.geteuid() != 0: raise RuntimeError('This narrowly scoped helper requires sudo.')
    os.umask(0o077)
    BACKUPS.mkdir(parents=True, exist_ok=True)
    with (BACKUPS/'.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        transact(json.load(sys.stdin))
    print('System Multi-Rice route updated.')

if __name__ == '__main__':
    try: main()
    except Exception as error:
        print('Cipher route:', error, file=sys.stderr); sys.exit(1)
