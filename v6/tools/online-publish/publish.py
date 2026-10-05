#!/usr/bin/env python3
"""Add the accepted fast online GUI/launcher to v6.0.0 without replacing existing assets."""
import fcntl
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import zipfile

HOME=Path.home()
KIT=Path(__file__).resolve().parent
ROOT=HOME/'Downloads/sumi-v6-build-prep'
TEST=HOME/'multi-rice-v6-wallpaper-fast-test'
FINAL=HOME/'multi-rice-v6-release-final'
OUTPUT=HOME/'multi-rice-v6-online-public-r1'
REPO='huzaifahshahid71-ops/dotfiles'
TAG='v6.0.0'
BRANCH='v6.0-tahoe-dev'
BASE='https://github.com/'+REPO+'/releases/download/'+TAG+'/'
GUI='sumi-setup-v6.0.0-online-r1-x86_64.tar.xz'
RUNTIME='sumi-setup-v6.0.0-online-r1'
MARKER='<!-- sumi-fast-online-r1 -->'


def sha(path):
    h=hashlib.sha256()
    with Path(path).open('rb') as stream:
        for chunk in iter(lambda:stream.read(1024*1024),b''):h.update(chunk)
    return h.hexdigest()


def write(path,obj):
    path.write_text(json.dumps(obj,indent=2)+'\n')


def api(endpoint,payload=None,method=None,optional=False):
    args=['gh','api',endpoint]
    if payload is not None:args+=['--method',method or 'POST','--input','-']
    p=subprocess.run(args,input=json.dumps(payload) if payload is not None else None,capture_output=True,text=True,
                     env=dict(os.environ,GH_PROMPT_DISABLED='1'),timeout=120)
    if p.returncode:
        if optional and '404' in p.stderr:return None
        raise RuntimeError(p.stderr.strip())
    return json.loads(p.stdout)


def assets(identifier):
    result={};page=1
    while True:
        rows=api('repos/'+REPO+'/releases/'+str(identifier)+'/assets?per_page=100&page='+str(page))
        result.update({r['name']:r for r in rows})
        if len(rows)<100:return result
        page+=1


def source_commit(bootstrap):
    paths={'v6/installer/core.py':(ROOT/'core.py').read_text(),
           'v6/installer/app.py':(ROOT/'app.py').read_text(),
           'v6/install-online.sh':bootstrap.read_text()}
    for p in KIT.iterdir():
        if p.is_file():paths['v6/tools/online-publish/'+p.name]=p.read_text()
    old=HOME/'Downloads/sumi-v6-wallpaper-fast-fix-v1'
    for name in ('fast_function.py','patch_sources.py','test_fast.py'):
        paths['v6/tools/wallpaper-fast-fix/'+name]=(old/name).read_text()
    identity=hashlib.sha256(json.dumps(paths,sort_keys=True).encode()).hexdigest()
    saved=OUTPUT/'source-commit.json'
    if saved.exists():
        data=json.loads(saved.read_text())
        if data['identity']!=identity:raise RuntimeError('Prepared publication source changed')
        return data['commit']
    head=api('repos/'+REPO+'/git/ref/heads/'+BRANCH)['object']['sha']
    base=api('repos/'+REPO+'/git/commits/'+head)['tree']['sha']
    tree=api('repos/'+REPO+'/git/trees',{'base_tree':base,'tree':[
        {'path':p,'type':'blob','mode':'100755' if p.endswith('.sh') else '100644','content':text} for p,text in sorted(paths.items())]})
    commit=api('repos/'+REPO+'/git/commits',{'message':'Publish accepted fast Sumi online installer and one-command launcher',
                                        'tree':tree['sha'],'parents':[head]})['sha']
    api('repos/'+REPO+'/git/refs/heads/'+BRANCH,{'sha':commit,'force':False},method='PATCH')
    write(saved,{'identity':identity,'commit':commit,'branch':BRANCH})
    print('Source updated on',BRANCH,commit,flush=True)
    return commit


def prepare():
    sys.path.insert(0,str(ROOT))
    spec=importlib.util.spec_from_file_location('online_packager',ROOT/'package-release.py')
    pack=importlib.util.module_from_spec(spec);spec.loader.exec_module(pack)
    runtime=TEST/'runtime/SumiSetup'
    records=pack.runtime_records(runtime)
    if records!=json.loads((TEST/'gui-complete.json').read_text()):raise RuntimeError('VM-tested fast GUI differs from its recorded hashes')
    for name in ('core.py','app.py','wallpapers.json'):
        if sha(runtime/'source'/name)!=sha(ROOT/name):raise RuntimeError('Current source differs from accepted GUI: '+name)
    if 'SUMI_WALLPAPER_ZIP_PACKS_V1' not in (ROOT/'core.py').read_text():raise RuntimeError('Fast downloader is missing')
    if '302 images' in (ROOT/'app.py').read_text():raise RuntimeError('Old wallpaper label remains')
    pin=json.loads((ROOT/'wallpapers.json').read_text())
    if pin.get('wallpaper_count')!=631:raise RuntimeError('Wallpaper pin differs')
    original=json.loads((FINAL/'published.json').read_text())
    manifest=FINAL/'release.json'
    if sha(manifest)!=original['assets']['release.json']['sha256']:raise RuntimeError('Published payload manifest differs')
    identity={'gui_stamp':sha(TEST/'gui-complete.json'),'manifest':sha(manifest),
              'kit':{p.name:sha(p) for p in KIT.iterdir() if p.is_file()}}
    marker=OUTPUT/'inputs.json'
    if OUTPUT.exists():
        if not marker.exists() or json.loads(marker.read_text())!=identity:raise RuntimeError('Prepared online publication inputs differ; retained')
    else:OUTPUT.mkdir(mode=0o700);write(marker,identity)
    archive=OUTPUT/GUI
    def stable(info):
        info.mtime=0;info.uid=0;info.gid=0;info.uname='';info.gname='';return info
    print('Compress accepted fast online GUI',flush=True)
    temporary=archive.with_name(archive.name+'.partial')
    with tarfile.open(temporary,'w:xz',dereference=False,preset=1) as tar:tar.add(runtime,arcname=RUNTIME,filter=stable)
    os.replace(temporary,archive)
    info=OUTPUT/'online-installer-r1.json'
    data={'schema':1,'version':TAG.removeprefix('v'),'wallpaper_count':631,'runtime_directory':RUNTIME,
          'gui':{'asset':GUI,'bytes':archive.stat().st_size,'sha256':sha(archive),'url':BASE+GUI},
          'manifest':dict(original['assets']['release.json'],asset='release.json',url=BASE+'release.json'),
          'records':records,'unpacked_bytes':sum(p.stat().st_size for p in runtime.rglob('*') if p.is_file() and not p.is_symlink()),
          'validation':'VM fast full download (631 images), online installation, cleanup and reboot accepted'}
    write(info,data)
    python=(KIT/'bootstrap.py').read_text().replace('@INFO_SHA256@',sha(info)).replace('@INFO_BYTES@',str(info.stat().st_size))
    compile(python,'published-bootstrap','exec')
    script=OUTPUT/'ONLINE-INSTALL-v6.sh'
    script.write_text('#!/usr/bin/env bash\nset -euo pipefail\ncommand -v python3 >/dev/null || { echo "Python 3 is required" >&2; exit 1; }\npython3 - <<\'SUMI_ONLINE_PY\'\n'+python+'\nSUMI_ONLINE_PY\n')
    script.chmod(0o755)
    subprocess.run(['bash','-n',str(script)],check=True)
    source=OUTPUT/'sumi-online-source-v6.0.0-r1.zip'
    with zipfile.ZipFile(source,'w',zipfile.ZIP_DEFLATED) as z:
        for p in sorted(runtime.rglob('*')):
            if p.is_file() and not p.is_symlink() and p.is_relative_to(runtime/'source'):
                z.write(p,'source/'+str(p.relative_to(runtime/'source')))
        for p in KIT.iterdir():
            if p.is_file():z.write(p,'online-publish/'+p.name)
    files=[archive,info,script,source]
    sums=OUTPUT/'ONLINE-r1-SHA256SUMS'
    sums.write_text(''.join(sha(p)+'  '+p.name+'\n' for p in files));files.append(sums)
    return files,original


def publish(files,original):
    release=api('repos/'+REPO+'/releases/tags/'+TAG)
    if release.get('draft') or release.get('prerelease'):raise RuntimeError('Expected the existing stable public v6.0.0 release')
    current=assets(release['id'])
    # Verify that the existing twelve stable assets are untouched.
    for name,expected in original['assets'].items():
        asset=current.get(name)
        if not asset or asset['size']!=expected['bytes'] or asset.get('digest')!='sha256:'+expected['sha256']:
            raise RuntimeError('Existing release asset differs: '+name)
    expected={p.name:{'bytes':p.stat().st_size,'sha256':sha(p)} for p in files}
    marker=OUTPUT/'publication-assets.json'
    if marker.exists() and json.loads(marker.read_text())!=expected:raise RuntimeError('Prepared online assets changed; retained')
    write(marker,expected)
    # Validate any partial prior uploads before modifying the release or branch.
    for name,record in expected.items():
        if name in current and (current[name]['size']!=record['bytes'] or current[name].get('digest')!='sha256:'+record['sha256']):
            raise RuntimeError('Existing online revision asset differs; preserved: '+name)
    commit=source_commit(OUTPUT/'ONLINE-INSTALL-v6.sh')
    for index,path in enumerate(files,1):
        current=assets(release['id'])
        if path.name not in current:
            print('Upload',str(index)+'/'+str(len(files)),path.name,flush=True)
            subprocess.run(['gh','release','upload',TAG,str(path),'--repo',REPO],check=True,
                           env=dict(os.environ,GH_PROMPT_DISABLED='1'),timeout=1800)
        asset=assets(release['id']).get(path.name);record=expected[path.name]
        if not asset or asset['size']!=record['bytes'] or asset.get('digest')!='sha256:'+record['sha256'] or asset.get('state')!='uploaded':
            raise RuntimeError('Online asset verification incomplete; rerun to resume')
        print('Verified',str(index)+'/'+str(len(files)),path.name,flush=True)
    # Advertise only after every added asset has passed the server checksum check.
    body=release.get('body') or ''
    command='curl -fsSL '+BASE+'ONLINE-INSTALL-v6.sh | bash'
    addition=MARKER+'\n## One-command online installer\n\nRun in a graphical desktop terminal as your normal user:\n\n```sh\n'+command+'\n```\n\nThis launcher opens the tested fast online setup, checks GUI/payload-manifest hashes, and offers all 631 wallpapers through three parallel ZIP-pack downloads. Choose the full collection in setup to download them. Source: `'+commit+'` on `'+BRANCH+'`. The original offline AppImage and all existing assets are unchanged.\n\n'
    if MARKER not in body:
        api('repos/'+REPO+'/releases/'+str(release['id']),{'body':addition+body},method='PATCH')
    final=api('repos/'+REPO+'/releases/'+str(release['id']))
    if MARKER not in (final.get('body') or ''):raise RuntimeError('Online installation instructions were not saved')
    write(OUTPUT/'published.json',{'release':final['html_url'],'source_commit':commit,'assets':expected,'command':command})
    print('UPDATED ONLINE INSTALLER:',final['html_url'],flush=True)
    print('ONE COMMAND:',command,flush=True)


def main():
    if os.geteuid()==0:raise RuntimeError('Run as gamer without sudo')
    if not shutil.which('gh'):raise RuntimeError('GitHub CLI is required')
    if api('user')['login']!='huzaifahshahid71-ops':raise RuntimeError('GitHub CLI account differs')
    checks=subprocess.run([sys.executable,str(KIT/'test_publish.py')],capture_output=True,text=True,timeout=60)
    if checks.returncode:raise RuntimeError('Publication regression check failed:\n'+checks.stdout+checks.stderr)
    print('PASS: publication resume, asset preservation and verified online launcher checks',flush=True)
    lock=HOME/'.cache/sumi-online-publish.lock';lock.parent.mkdir(parents=True,exist_ok=True)
    with lock.open('a') as handle:
        fcntl.flock(handle,fcntl.LOCK_EX|fcntl.LOCK_NB)
        files,original=prepare()
        publish(files,original)


if __name__=='__main__':
    try:main()
    except Exception as error:
        print('Online publication stopped:',error,file=sys.stderr)
        report=HOME/'Downloads/sumi-v6-online-publication-report.zip'
        with zipfile.ZipFile(report,'w',zipfile.ZIP_DEFLATED) as out:
            out.writestr('error.txt',str(error)+'\n')
            for name in ('inputs.json','source-commit.json','publication-assets.json'):
                if (OUTPUT/name).is_file():out.write(OUTPUT/name,name)
        print('REPORT:',report,flush=True);sys.exit(1)
