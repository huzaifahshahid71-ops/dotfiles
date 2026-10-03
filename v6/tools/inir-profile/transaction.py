"""Checksum guarded, atomic user-file changes and exact recovery copies."""
import hashlib
import os
from pathlib import Path
import tempfile

def sha(data): return hashlib.sha256(data).hexdigest()
def digest(path): return sha(Path(path).read_bytes())

def atomic(path,data,mode=0o644):
    path.parent.mkdir(parents=True,exist_ok=True)
    fd,name = tempfile.mkstemp(prefix='.'+path.name+'-',dir=path.parent)
    try:
        with os.fdopen(fd,'wb') as f:
            f.write(data); f.flush(); os.fsync(f.fileno())
        os.chmod(name,mode); os.replace(name,path)
    finally:
        if os.path.exists(name): os.unlink(name)

def record_targets(changes,backup):
    records=[]
    for i,(path,data,mode) in enumerate(changes):
        if path.is_symlink() or (path.exists() and not path.is_file()):
            raise RuntimeError('Managed target is not a regular file: '+str(path))
        record={'path':str(path),'existed':path.exists(),'installedSha256':sha(data)}
        if record['existed']:
            saved=backup/str(i); saved.write_bytes(path.read_bytes())
            record.update(backup=str(saved),priorSha256=digest(saved),mode=path.stat().st_mode & 0o777)
        records.append(record)
    return records

def verify_records(records,installed):
    for r in records:
        path=Path(r['path'])
        current=digest(path) if path.is_file() and not path.is_symlink() else None
        allowed=[r.get('priorSha256'),r['installedSha256']] if installed is None else [r['installedSha256'] if installed else r.get('priorSha256')]
        if path.is_symlink() or (path.exists() and not path.is_file()) or current not in allowed:
            raise RuntimeError('Managed file changed; preserved: '+str(path))
        if r['existed'] and digest(r['backup']) != r['priorSha256']:
            raise RuntimeError('Recovery copy changed: '+r['backup'])

def restore(records):
    for r in reversed(records):
        path=Path(r['path'])
        if r['existed']: atomic(path,Path(r['backup']).read_bytes(),r['mode'])
        else: path.unlink(missing_ok=True)
