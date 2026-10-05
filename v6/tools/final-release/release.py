#!/usr/bin/env python3
"""Build, verify and publish v6.0.0 from the tested RC5 host inputs."""
import argparse
import fcntl
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tarfile
import zipfile
from restore_guard import patched, apply

KIT=Path(__file__).resolve().parent
HOME=Path.home()
ROOT=HOME/'Downloads/sumi-v6-build-prep'
PREVIOUS=HOME/'multi-rice-v6-packaged-rc5-final'
OUTPUT=HOME/'multi-rice-v6-release-final'
REPO='huzaifahshahid71-ops/dotfiles'
BRANCH='v6.0-tahoe-dev'
TAG='v6.0.0'
IMAGE='multi-rice-v6.0.0-x86_64.AppImage'
RC5_SHA='8a9a0ce16b638e9edebc4b6c9ca36f70e45c3758d17e170fff0311b69566ceff'
PLAN_SHA='a8600069b154ab2f9377b3260486c9a387c5426bad23e46134a4e6b647a898dc'


def sha(path):
    result=hashlib.sha256()
    with Path(path).open('rb') as stream:
        for chunk in iter(lambda:stream.read(1024*1024),b''):result.update(chunk)
    return result.hexdigest()


def write(path,value):
    temp=path.with_name(path.name+'.new')
    temp.write_text(json.dumps(value,indent=2)+'\n')
    os.replace(temp,path)


def load_module(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
    return mod


def changed_copy(source,target,data=None):
    target.parent.mkdir(parents=True,exist_ok=True)
    temporary=target.with_name(target.name+'.final-new')
    if temporary.exists() or temporary.is_symlink():raise RuntimeError('Unexpected temporary file: '+str(temporary))
    if data is None:shutil.copy2(source,temporary)
    else:temporary.write_bytes(data);temporary.chmod(source.stat().st_mode & 0o777)
    os.replace(temporary,target)


def run(args,**kw):
    return subprocess.run([str(x) for x in args],check=True,**kw)


def gh(args,payload=None,optional=False):
    env=dict(os.environ,GH_PROMPT_DISABLED='1')
    result=subprocess.run(['gh',*args],input=json.dumps(payload) if payload is not None else None,
                          capture_output=True,text=True,env=env,timeout=1800)
    if result.returncode:
        if optional and '404' in result.stderr:return None
        raise RuntimeError('GitHub operation failed: '+result.stderr.strip())
    return json.loads(result.stdout) if result.stdout.strip() else None


def api(endpoint,payload=None,optional=False):
    args=['api',endpoint]
    if payload is not None:args+=['--method','POST','--input','-']
    return gh(args,payload,optional)


def build():
    sys.path.insert(0,str(ROOT))
    if not ROOT.is_dir():raise RuntimeError('Retained build sources are missing')
    apply(ROOT/'system_transaction.py')
    pack=load_module('final_packager',ROOT/'package-release.py')
    pack.IMAGE=IMAGE
    pack.BACKEND_FILES=tuple(dict.fromkeys((*pack.BACKEND_FILES,'eclipse_defaults.py')))
    candidate=PREVIOUS/'candidate/AppDir'
    print('Verify tested RC5 image and payload identity',flush=True)
    old_manifest=json.loads((PREVIOUS/'release.json').read_text())
    old_image=PREVIOUS/old_manifest['image']['asset']
    if sha(old_image)!=RC5_SHA or old_manifest['image']['sha256']!=RC5_SHA:
        raise RuntimeError('RC5 AppImage differs from the tested build')
    if sha(candidate/'payload/plan.json')!=PLAN_SHA:
        raise RuntimeError('RC5 payload differs from the tested plan')
    for name in pack.BACKEND_FILES:
        old=candidate/'backend'/name
        current=ROOT/name
        if name=='system_transaction.py':
            if patched(old.read_text())!=current.read_text():
                raise RuntimeError('System helper has changes beyond the tested restore fix')
        elif sha(old)!=sha(current):
            raise RuntimeError('Backend changed since RC5: '+name)
    gui=PREVIOUS/'runtime/SumiSetup'
    if pack.runtime_records(gui)!=json.loads((PREVIOUS/'gui-complete.json').read_text()):
        raise RuntimeError('RC5 GUI runtime differs from its recorded hashes')
    for name in pack.GUI_FILES:
        if sha(gui/'source'/name)!=sha(ROOT/name):raise RuntimeError('GUI source changed since RC5: '+name)
    for source in (ROOT/'assets').glob('*.webp'):
        if sha(source)!=sha(gui/'source/assets'/source.name):raise RuntimeError('GUI artwork changed since RC5')
    identity={'rc5_sha256':RC5_SHA,'rc5_plan_sha256':PLAN_SHA,
              'backend':{n:sha(ROOT/n) for n in pack.BACKEND_FILES},
              'gui_stamp_sha256':sha(PREVIOUS/'gui-complete.json'),
              'kit':{p.name:sha(p) for p in KIT.iterdir() if p.is_file()}}
    marker=OUTPUT/'final-inputs.json'
    if OUTPUT.exists():
        if not marker.is_file() or json.loads(marker.read_text())!=identity:
            raise RuntimeError('Retained final output has different inputs; preserved')
    else:
        if shutil.disk_usage(OUTPUT.parent).free<8*1024**3:raise RuntimeError('Final build needs 8 GiB free on the host')
        OUTPUT.mkdir(mode=0o700);write(marker,identity)
    updated=OUTPUT/'candidate/AppDir'
    stamp=OUTPUT/'candidate-complete.json'
    if not stamp.exists():
        if (OUTPUT/'candidate').exists():shutil.rmtree(OUTPUT/'candidate')
        def link_copy(a,b):
            try:os.link(a,b)
            except OSError:shutil.copy2(a,b)
            return b
        shutil.copytree(candidate,updated,copy_function=link_copy,symlinks=True)
        plan=json.loads((updated/'payload/plan.json').read_text())
        changed=[]
        for record in plan['user_files']:
            if record['path']=='.local/share/multi-rice-setup/runtime/system_transaction.py':
                path=updated/'payload'/record['source']
                data=patched(path.read_text()).encode()
                if data!=path.read_bytes():
                    changed_copy(path,path,data)
                    record.update(bytes=len(data),sha256=sha(path));changed.append(record['path'])
        if changed:write(updated/'payload/plan.json',plan)
        for name in pack.BACKEND_FILES:changed_copy(ROOT/name,updated/'backend'/name)
        report=json.loads((candidate.parent/'assembly-report.json').read_text())
        report['plan_sha256']=sha(updated/'payload/plan.json')
        report['final_delta']={'backend':'SDDM unchanged-file restore guard only','user_files':changed}
        write(updated.parent/'assembly-report.json',report)
        write(stamp,{'plan_sha256':report['plan_sha256']})
    if json.loads(stamp.read_text())['plan_sha256']!=sha(updated/'payload/plan.json'):
        raise RuntimeError('Retained final candidate plan changed')
    plan,assembly=pack.verify_candidate(updated,OUTPUT)
    print('Check final restore helper regression cases',flush=True)
    run([sys.executable,KIT/'test_restore_guard.py',ROOT/'system_transaction.py'],env=dict(os.environ,PYTHONPATH=str(ROOT)))
    runtime=OUTPUT/'runtime/SumiSetup'
    runtime_stamp=OUTPUT/'gui-complete.json'
    if runtime_stamp.exists():
        if pack.runtime_records(runtime)!=json.loads(runtime_stamp.read_text()):raise RuntimeError('Retained final GUI changed')
    else:
        if runtime.exists():shutil.rmtree(runtime)
        shutil.copytree(gui,runtime,symlinks=True)
        pack.run([runtime/'SumiSetup','--offline','--screenshot',OUTPUT/'sumi-runtime.png'],
                 OUTPUT,'Render verified final Sumi GUI',60,env=dict(os.environ,QT_QPA_PLATFORM='offscreen'))
        if not (OUTPUT/'sumi-runtime.png').is_file() or (OUTPUT/'sumi-runtime.png').stat().st_size<1000:
            raise RuntimeError('Final GUI render failed')
        write(runtime_stamp,pack.runtime_records(runtime))
    image=pack.build_image(updated,runtime,OUTPUT,assembly)
    if sha(OUTPUT/'packed.AppDir/backend/system_transaction.py')!=sha(ROOT/'system_transaction.py'):
        raise RuntimeError('Packed restore helper differs')
    parts=pack.split_image(image,OUTPUT)
    manifest=pack.make_manifest(image,parts,plan)
    manifest['validation']='RC5 desktop/login/GRUB and restore accepted in existing CachyOS VM; final backend regression and GUI/hash checks'
    write(OUTPUT/'release.json',manifest)
    pack.load_manifest(OUTPUT/'release.json')
    write(runtime/'release.json',manifest)
    for offline in (True,False):
        path=runtime/('launch-offline.sh' if offline else 'launch-online.sh')
        path.write_text(pack.launcher(offline));path.chmod(0o755)
    write(runtime_stamp,pack.runtime_records(runtime))
    print('Check the final packaged backend in the VM (temporary test files only)',flush=True)
    shared=HOME/'VMs/vm-share/v6-final-release-check'
    shared.mkdir(parents=True,exist_ok=True)
    for name in ('core.py','maintenance.py','package_policy.py','system_transaction.py'):
        shutil.copy2(OUTPUT/'packed.AppDir/backend'/name,shared/name)
    for name in ('restore_guard.py','test_restore_guard.py'):shutil.copy2(KIT/name,shared/name)
    guest_path='/home/gamer/hostshare/v6-final-release-check'
    check='PYTHONPATH='+shlex.quote(guest_path)+' python3 '+shlex.quote(guest_path+'/test_restore_guard.py')+' '+shlex.quote(guest_path+'/system_transaction.py')
    run(['vmrun',check],timeout=120)
    print('Prepare release assets',flush=True)
    for name in ('assemble-v6.py','RELEASE-v6.0.0.md'):shutil.copy2(KIT/name,OUTPUT/name)
    archive=OUTPUT/'sumi-setup-v6.0.0-x86_64.tar.xz'
    def stable_tar(info):
        info.mtime=0;info.uid=0;info.gid=0;info.uname='';info.gname=''
        return info
    with tarfile.open(archive,'w:xz',dereference=False,preset=3) as tar:
        tar.add(runtime,arcname='sumi-setup-v6.0.0',filter=stable_tar)
    source_archive=OUTPUT/'sumi-installer-source-v6.0.0.zip'
    with zipfile.ZipFile(source_archive,'w',zipfile.ZIP_DEFLATED) as source_zip:
        for path in sorted(ROOT.glob('*.py')):source_zip.write(path,'installer/'+path.name)
        for name in ('gui-build-requirements.txt','wallpapers.json','release.json'):
            source_zip.write(ROOT/name,'installer/'+name)
        for path in sorted((ROOT/'assets').glob('*.webp')):source_zip.write(path,'installer/assets/'+path.name)
        for path in sorted(KIT.iterdir()):
            if path.is_file():source_zip.write(path,'release-tools/'+path.name)
    report={'status':'verified-final-build','version':TAG,'image':manifest['image'],
            'plan_sha256':assembly['plan_sha256'],'source_rc5_sha256':RC5_SHA,
            'release_features':assembly['release_features'],'gui_render':True,
            'host_restore_regressions':8,'vm_final_backend_regressions':8,
            'acceptance':'User confirmed all 12 desktops/shortcuts/configs, GRUB/login themes and receipt ff9e3630bcb14696b6e4017864a014d0 restore',
            'delta':assembly['final_delta'],'published':False}
    write(OUTPUT/'final-verification.json',report)
    assets=[*parts,OUTPUT/'release.json',archive,source_archive,OUTPUT/'assemble-v6.py',OUTPUT/'RELEASE-v6.0.0.md',OUTPUT/'final-verification.json']
    sums=OUTPUT/'SHA256SUMS'
    sums.write_text(''.join(sha(p)+'  '+p.name+'\n' for p in [image,*assets]))
    assets.append(sums)
    print('VERIFIED FINAL BUILD:',image,flush=True)
    return assets


def source_commit():
    marker=OUTPUT/'publication-source.json'
    files={str('v6/installer/'+p.name):p.read_text() for p in ROOT.glob('*.py')}
    for name in ('wallpapers.json','gui-build-requirements.txt'):files['v6/installer/'+name]=(ROOT/name).read_text()
    for p in KIT.iterdir():
        if p.is_file():files['v6/tools/final-release/'+p.name]=p.read_text()
    identity=hashlib.sha256(json.dumps(files,sort_keys=True).encode()).hexdigest()
    if marker.exists():
        record=json.loads(marker.read_text())
        if record['source_sha256']!=identity:raise RuntimeError('Publication source changed; preserved')
        return record['commit']
    ref=api('repos/'+REPO+'/git/ref/heads/'+BRANCH)
    head=ref['object']['sha']
    base=api('repos/'+REPO+'/git/commits/'+head)['tree']['sha']
    tree=api('repos/'+REPO+'/git/trees',{'base_tree':base,'tree':[
        {'path':path,'mode':'100644','type':'blob','content':content} for path,content in sorted(files.items())]})
    if tree['sha']==base:commit=head
    else:
        commit=api('repos/'+REPO+'/git/commits',{'message':'Release Sumi v6.0.0 with validated login restore guard','tree':tree['sha'],'parents':[head]})['sha']
        # Non-forced update fails if another writer moved the branch divergently.
        gh(['api','repos/'+REPO+'/git/refs/heads/'+BRANCH,'--method','PATCH','--input','-'],{'sha':commit,'force':False})
    write(marker,{'source_sha256':identity,'commit':commit,'branch':BRANCH})
    print('Release source pinned on',BRANCH,commit,flush=True)
    return commit


def all_releases():
    pages=gh(['api','repos/'+REPO+'/releases?per_page=100','--paginate','--slurp'])
    return [row for page in pages for row in page]


def release_assets(identifier):
    pages=gh(['api','repos/'+REPO+'/releases/'+str(identifier)+'/assets?per_page=100','--paginate','--slurp'])
    return {row['name']:row for page in pages for row in page}


def publish(assets):
    if not shutil.which('gh'):raise RuntimeError('GitHub CLI gh is required')
    if api('user')['login']!='huzaifahshahid71-ops':raise RuntimeError('GitHub CLI account differs from the repository owner')
    records={p.name:{'bytes':p.stat().st_size,'sha256':sha(p)} for p in assets}
    marker=OUTPUT/'publication-assets.json'
    if marker.exists() and json.loads(marker.read_text())!=records:
        raise RuntimeError('Previously prepared publication assets differ; preserved')
    write(marker,records)
    releases=[r for r in all_releases() if r['tag_name']==TAG]
    if len(releases)>1:raise RuntimeError('Multiple releases use the requested tag')
    release=releases[0] if releases else None
    if release and not release.get('draft'):
        uploaded=release_assets(release['id'])
        if set(uploaded)!=set(records) or any(uploaded[n].get('digest')!='sha256:'+r['sha256'] or uploaded[n]['size']!=r['bytes'] for n,r in records.items()):
            raise RuntimeError('Existing public v6.0.0 differs; no modification made')
        print('ALREADY PUBLISHED:',release['html_url'],flush=True);return
    commit=source_commit()
    notes=(OUTPUT/'RELEASE-v6.0.0.md').read_text()
    if release:
        if '<!-- sumi-v6-final-release-v1 -->' not in (release.get('body') or ''):
            raise RuntimeError('Existing v6.0.0 draft is not owned by this workflow')
        saved=OUTPUT/'publication-release.json'
        if saved.exists() and json.loads(saved.read_text())['id']!=release['id']:raise RuntimeError('Draft identity changed')
    else:
        tag=api('repos/'+REPO+'/git/ref/tags/'+TAG,optional=True)
        if tag and not (tag['object']['type']=='commit' and tag['object']['sha']==commit):
            raise RuntimeError('Existing v6.0.0 tag points elsewhere; no change made')
        release=api('repos/'+REPO+'/releases',{'tag_name':TAG,'target_commitish':commit,
                    'name':'Huzaifah Multi-Rice v6.0.0 — Sumi','body':notes,'draft':True,'prerelease':False})
    write(OUTPUT/'publication-release.json',{'id':release['id'],'commit':commit})
    for index,path in enumerate(assets,1):
        uploaded=release_assets(release['id'])
        current=uploaded.get(path.name)
        expected=records[path.name]
        if current:
            if current.get('digest')!='sha256:'+expected['sha256'] or current['size']!=expected['bytes'] or current.get('state')!='uploaded':
                raise RuntimeError('Existing draft asset differs; preserved: '+path.name)
        else:
            if path.stat().st_size>=2*1024**3:raise RuntimeError('Asset exceeds release limit: '+path.name)
            print('Upload',str(index)+'/'+str(len(assets)),path.name,flush=True)
            run(['gh','release','upload',TAG,path,'--repo',REPO],env=dict(os.environ,GH_PROMPT_DISABLED='1'),timeout=1800)
            current=release_assets(release['id']).get(path.name)
            if not current or current.get('digest')!='sha256:'+expected['sha256'] or current['size']!=expected['bytes'] or current.get('state')!='uploaded':
                raise RuntimeError('Uploaded checksum/size is not verified yet; rerun to resume')
        print('Verified',str(index)+'/'+str(len(assets)),path.name,flush=True)
    uploaded=release_assets(release['id'])
    if set(uploaded)!=set(records):raise RuntimeError('Draft contains unexpected assets; retained for review')
    existing_tag=api('repos/'+REPO+'/git/ref/tags/'+TAG,optional=True)
    if existing_tag and (existing_tag['object']['type']!='commit' or existing_tag['object']['sha']!=commit):
        raise RuntimeError('Draft tag target differs; draft retained')
    if release.get('target_commitish') not in (commit,BRANCH):
        raise RuntimeError('Draft source target differs; draft retained')
    run(['gh','release','edit',TAG,'--repo',REPO,'--draft=false','--latest'])
    final=api('repos/'+REPO+'/releases/'+str(release['id']))
    if final.get('draft') or final.get('prerelease'):raise RuntimeError('Release is not public stable yet')
    tag=api('repos/'+REPO+'/git/ref/tags/'+TAG)
    if tag['object']['type']!='commit' or tag['object']['sha']!=commit:raise RuntimeError('Published tag target differs')
    write(OUTPUT/'published.json',{'url':final['html_url'],'commit':commit,'assets':records})
    print('PUBLISHED:',final['html_url'],flush=True)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--publish',action='store_true',help='After verification, publish v6.0.0 using the host GitHub CLI')
    args=parser.parse_args()
    if os.geteuid()==0:raise RuntimeError('Run as gamer, without sudo')
    lock=HOME/'.cache/sumi-v6-final-release.lock'
    lock.parent.mkdir(parents=True,exist_ok=True)
    with lock.open('a') as handle:
        fcntl.flock(handle,fcntl.LOCK_EX|fcntl.LOCK_NB)
        if args.publish:
            if not shutil.which('gh'):raise RuntimeError('GitHub CLI gh is required')
            if api('user')['login']!='huzaifahshahid71-ops':raise RuntimeError('GitHub CLI account differs')
        assets=build()
        if args.publish:publish(assets)
        else:print('Publication disabled; rerun with --publish to publish the verified build')


if __name__=='__main__':
    try:main()
    except Exception as error:
        print('Release stopped:',error,file=sys.stderr,flush=True)
        report=HOME/'Downloads/sumi-v6-final-release-report.zip'
        with zipfile.ZipFile(report,'w',zipfile.ZIP_DEFLATED) as archive:
            archive.writestr('error.txt',str(error)+'\n')
            for name in ('packaging.log','final-verification.json','publication-release.json','published.json'):
                path=OUTPUT/name
                if path.is_file():archive.write(path,name)
        print('REPORT:',report,flush=True)
        sys.exit(1)
