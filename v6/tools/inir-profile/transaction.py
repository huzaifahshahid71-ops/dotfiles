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

def record_targets(changes,backup,*,allow_symlinks=()):
    records=[]
    for i,(path,data,mode) in enumerate(changes):
        link=path.is_symlink()
        if (link and path not in allow_symlinks) or (not link and path.exists() and not path.is_file()):
            raise RuntimeError('Managed target is not a regular file: '+str(path))
        record={'path':str(path),'existed':link or path.exists(),'installedSha256':sha(data)}
        if link:
            target=str(path.readlink())
            record.update(kind='symlink',linkTarget=target,priorSha256=sha(b'link:'+os.fsencode(target)))
        elif record['existed']:
            saved=backup/str(i); saved.write_bytes(path.read_bytes())
            record.update(backup=str(saved),priorSha256=digest(saved),mode=path.stat().st_mode & 0o777)
        records.append(record)
    return records

def verify_records(records,installed):
    for r in records:
        path=Path(r['path'])
        link=path.is_symlink()
        current=sha(b'link:'+os.fsencode(path.readlink())) if link else digest(path) if path.is_file() else None
        allowed=[r.get('priorSha256'),r['installedSha256']] if installed is None else [r['installedSha256'] if installed else r.get('priorSha256')]
        if (link and r.get('kind')!='symlink') or (not link and path.exists() and not path.is_file()) or current not in allowed:
            raise RuntimeError('Managed file changed; preserved: '+str(path))
        if r['existed'] and r.get('kind')!='symlink' and digest(r['backup']) != r['priorSha256']:
            raise RuntimeError('Recovery copy changed: '+r['backup'])

def restore(records):
    for r in reversed(records):
        path=Path(r['path'])
        if r.get('kind')=='symlink':
            path.parent.mkdir(parents=True,exist_ok=True)
            fd,name=tempfile.mkstemp(prefix='.'+path.name+'-',dir=path.parent)
            os.close(fd); os.unlink(name)
            try:
                os.symlink(r['linkTarget'],name); os.replace(name,path)
            finally:
                if os.path.lexists(name): os.unlink(name)
        elif r['existed']: atomic(path,Path(r['backup']).read_bytes(),r['mode'])
        else: path.unlink(missing_ok=True)
