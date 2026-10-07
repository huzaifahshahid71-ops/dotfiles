import hashlib
import json
import os
from pathlib import Path
import subprocess
import time

HOME = Path.home()
KIT = Path(__file__).resolve().parent
DEV = HOME/'Downloads/MULTI RICE DEVELOPMENT'
OUTPUT = HOME/'multi-rice-v6-desktop-r3'
REPO = 'huzaifahshahid71-ops/dotfiles'
TAG = 'v6.0.0'
BRANCH = 'v6.0-tahoe-dev'
BASE = f'https://github.com/{REPO}/releases/download/{TAG}/'

def sha(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream,'sha256').hexdigest()

def safe(path):
    for item in (path,*path.parents):
        if item.is_symlink(): raise RuntimeError('Existing symlink retained: '+str(item))

def write(path,data,mode=0o644):
    safe(path);path.parent.mkdir(parents=True,exist_ok=True)
    temporary=path.with_name(path.name+'.r3-new');safe(temporary)
    if temporary.exists(): raise RuntimeError('Interrupted temporary retained: '+str(temporary))
    with temporary.open('xb') as stream:
        stream.write(data);stream.flush();os.fsync(stream.fileno())
    temporary.chmod(mode);os.replace(temporary,path)

def save(path,value): write(path,(json.dumps(value,indent=2)+'\n').encode())

def run(args,label,timeout=1200,cwd=None,env=None):
    print(label,flush=True)
    with (OUTPUT/'build.log').open('a') as log:
        log.write('\n'+label+'\n');log.flush()
        process=subprocess.Popen([str(x) for x in args],stdout=log,stderr=log,cwd=cwd,env=env,start_new_session=True)
        start=last=time.monotonic()
        try:
            while process.poll() is None:
                now=time.monotonic()
                if now-start>timeout: raise RuntimeError(label+' timed out; log retained')
                if now-last>=15:
                    print(f'{label}: {int(now-start)}s; log: {OUTPUT / "build.log"}',flush=True);last=now
                time.sleep(0.25)
            if process.returncode: raise RuntimeError(label+' failed; inspect '+str(OUTPUT/'build.log'))
        finally:
            if process.poll() is None:
                import signal
                os.killpg(process.pid,signal.SIGTERM)
                try:process.wait(timeout=5)
                except subprocess.TimeoutExpired:os.killpg(process.pid,signal.SIGKILL);process.wait()

def api(endpoint,payload=None,method=None):
    args=['gh','api',endpoint]
    if method:args+=['--method',method]
    elif payload is not None:args+=['--method','POST']
    if payload is not None:args+=['--input','-']
    r=subprocess.run(args,input=json.dumps(payload) if payload is not None else None,capture_output=True,text=True,
                     env=dict(os.environ,GH_PROMPT_DISABLED='1'),timeout=90)
    if r.returncode:raise RuntimeError('GitHub operation failed: '+r.stderr.strip())
    return json.loads(r.stdout) if r.stdout.strip() else None

def assets(identifier):
    result={};page=1
    while True:
        rows=api(f'repos/{REPO}/releases/{identifier}/assets?per_page=100&page={page}')
        result.update({r['name']:r for r in rows})
        if len(rows)<100:return result
        page+=1

def record(path): return {'asset':path.name,'bytes':path.stat().st_size,'sha256':sha(path),'url':BASE+path.name}

def matches(asset,expected):
    return bool(asset and asset.get('state')=='uploaded' and asset.get('size')==expected['bytes']
                and asset.get('digest')=='sha256:'+expected['sha256'])

def server_record(asset):
    digest=asset.get('digest') or ''
    if not digest.startswith('sha256:') or len(digest)!=71 or asset.get('state')!='uploaded':
        raise RuntimeError('Server SHA-256 unavailable: '+asset['name'])
    return {'asset':asset['name'],'bytes':asset['size'],'sha256':digest[7:],'url':BASE+asset['name']}
