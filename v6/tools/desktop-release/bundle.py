"""Reuse published r2 backend/GUI and add only the accepted desktop repairs."""
from concurrent.futures import ThreadPoolExecutor
import importlib.util
import json
import os
from pathlib import Path
import shutil
import sys
import tarfile
import urllib.request
import zipfile
from common import HOME, DEV, KIT, OUTPUT, REPO, TAG, BASE, sha, safe, write, save, run, api, assets, record, server_record, matches
from fixes import apply, collector, crimson_sources

IMAGE='multi-rice-v6.0.0-r3-x86_64.AppImage'
RUNTIME='sumi-setup-v6.0.0-online-r3'

def download(expected,folder):
    name=expected['asset']
    if Path(name).name!=name or expected['url']!=BASE+name:raise RuntimeError('Unexpected release asset URL')
    target=folder/name;safe(target)
    if target.exists():
        if target.is_file() and target.stat().st_size==expected['bytes'] and sha(target)==expected['sha256']:return target
        raise RuntimeError('Existing downloaded asset differs; retained: '+name)
    temporary=target.with_name(name+'.partial');safe(temporary)
    print('Download:',name,flush=True)
    h=__import__('hashlib').sha256();total=0;last=__import__('time').monotonic()
    with urllib.request.urlopen(expected['url'],timeout=90) as response,temporary.open('wb') as stream:
        while chunk:=response.read(1024**2):
            total+=len(chunk)
            if total>expected['bytes']:raise RuntimeError('Download exceeds expected size')
            h.update(chunk);stream.write(chunk)
            now=__import__('time').monotonic()
            if now-last>=15:print(f'{name}: {total/1024**2:.1f} MiB',flush=True);last=now
    if total!=expected['bytes'] or h.hexdigest()!=expected['sha256']:raise RuntimeError('Download checksum differs: '+name)
    os.replace(temporary,target);return target

def locate(name,required):
    candidates=[HOME/name,DEV/name]
    if DEV.is_dir():candidates+=sorted(DEV.glob('*/'+name))
    return next((p for p in candidates if (p/required).is_file()),None)

def addon():
    name='sumi-v6-build-prep'
    roots=[DEV/name,HOME/'Downloads'/name,DEV]
    if DEV.is_dir():roots+=sorted(DEV.glob('*/'+name))
    matches_found=[]
    expected=(KIT/'verified/crimson-manifest.json').read_text()
    for root in roots:
        for m in root.glob('crimson-repair/*/manifest.json'):
            safe(m)
            if json.loads(m.read_text())==json.loads(expected):matches_found.append(m.parent)
    if not matches_found:raise RuntimeError('Retained verified Crimson additions missing. Keep sumi-v6-build-prep/crimson-repair under MULTI RICE DEVELOPMENT.')
    selected=matches_found[0]
    crimson_sources(selected)  # Check retained bytes before downloads or payload scanning.
    return selected

def extract_source(archive,target):
    if target.exists():safe(target);shutil.rmtree(target)
    target.mkdir()
    with zipfile.ZipFile(archive) as z:
        for item in z.infolist():
            p=Path(item.filename)
            if p.is_absolute() or '..' in p.parts or (item.external_attr>>16)&0o170000==0o120000:
                raise RuntimeError('Unsafe published source archive path')
            if not p.parts or p.parts[0]!='installer' or item.is_dir():continue
            if '__pycache__' in p.parts:continue
            destination=target/Path(*p.parts[1:]);write(destination,z.read(item))
    if not (target/'package-release.py').is_file():raise RuntimeError('Published packager source missing')

def valid_runtime(runtime,records):
    expected={r['path'] for r in records}
    actual={p.relative_to(runtime).as_posix() for p in runtime.rglob('*') if p.is_file() or p.is_symlink()}
    if actual!=expected:return False
    for r in records:
        p=Path(r['path'])
        if p.is_absolute() or '..' in p.parts:return False
        file=runtime/p
        if 'link' in r:
            if not file.is_symlink() or os.readlink(file)!=r['link'] or not file.resolve().is_relative_to(runtime.resolve()):return False
        elif file.is_symlink() or not file.is_file() or sha(file)!=r['sha256']:return False
    return True

def obtain_runtime(metadata,archive):
    root=OUTPUT/'base-runtime';runtime=root/metadata['runtime_directory']
    if runtime.exists():
        if not valid_runtime(runtime,metadata['records']):raise RuntimeError('Retained base GUI runtime differs')
        return runtime
    root.mkdir(exist_ok=True)
    with tarfile.open(archive,'r:xz') as tar:tar.extractall(root,filter='data')
    if not valid_runtime(runtime,metadata['records']):raise RuntimeError('Published GUI checksum differs')
    return runtime

def link(a,b):
    try:os.link(a,b)
    except OSError:shutil.copy2(a,b)
    return b

def obtain_candidate(manifest,cache):
    retained=locate('multi-rice-v6-appearance-r2','packed.AppDir/payload/plan.json')
    if retained:
        # r2's staging candidate still contains RC5-era backend modules. The
        # final packed AppDir contains the backend actually used by the image.
        packed=retained/'packed.AppDir'
        target=OUTPUT/'base-candidate/AppDir';stamp=target.parent/'complete.json'
        if stamp.exists():
            if json.loads(stamp.read_text())!=manifest['image']:raise RuntimeError('Retained packaged baseline differs')
            return target
        if target.exists():safe(target);shutil.rmtree(target)
        shutil.copytree(packed,target,copy_function=link,symlinks=True)
        source_report=retained/'candidate/assembly-report.json'
        report=json.loads(source_report.read_text()) if source_report.exists() else {'status':'candidate-appdir','release_features':{'login_cards':74,'grub_cards':8},'plan_sha256':sha(packed/'payload/plan.json')}
        if report['plan_sha256']!=sha(target/'payload/plan.json'):raise RuntimeError('Packed r2 plan differs from its assembly report')
        report['baseline_source']='retained final packed r2 AppDir'
        save(target.parent/'assembly-report.json',report);save(stamp,manifest['image'])
        print('Use final packed r2 payload/backend; retain the earlier staging candidate.',flush=True)
        return target
    extracted=OUTPUT/'base-extracted/squashfs-root'
    stamp=OUTPUT/'base-extracted/complete.json'
    if stamp.exists():
        if json.loads(stamp.read_text())!=manifest['image']:raise RuntimeError('Extraction baseline differs')
        return extracted
    print('Prior candidate was cleaned up; recover the published r2 AppImage.',flush=True)
    image=cache/manifest['image']['asset'];safe(image)
    retained_image=locate('multi-rice-v6-appearance-r2',manifest['image']['asset'])
    if not image.exists() and retained_image:
        original=retained_image/manifest['image']['asset'];safe(original)
        if original.stat().st_size==manifest['image']['bytes'] and sha(original)==manifest['image']['sha256']:
            link(original,image)
    if not image.exists():
        with ThreadPoolExecutor(max_workers=3) as pool:parts=list(pool.map(lambda r:download(r,cache),manifest['parts']))
        temporary=image.with_name(image.name+'.assembling');safe(temporary)
        with temporary.open('wb') as target:
            for part in parts:
                with part.open('rb') as stream:shutil.copyfileobj(stream,target,1024**2)
        if sha(temporary)!=manifest['image']['sha256'] or temporary.stat().st_size!=manifest['image']['bytes']:
            raise RuntimeError('Recovered AppImage checksum differs')
        temporary.chmod(0o755);os.replace(temporary,image)
    if sha(image)!=manifest['image']['sha256']:raise RuntimeError('Recovered AppImage changed')
    root=extracted.parent;root.mkdir(exist_ok=True)
    if extracted.exists():safe(extracted);shutil.rmtree(extracted)
    run([image,'--appimage-extract'],'Extract verified published payload',600,cwd=root)
    save(stamp,manifest['image']);return extracted

def tool(report,explicit=None):
    candidates=[]
    for r in report.get('appimage_packager_candidates',[]):
        old=Path(r['path'])
        for p in (old,DEV/old.name,DEV/old.relative_to(HOME) if old.is_relative_to(HOME) else old):
            if p.is_file() and sha(p)==r['sha256']:return p
    if explicit:candidates.append(Path(explicit).expanduser())
    found=shutil.which('appimagetool')
    if found:candidates.append(Path(found))
    for root in (HOME,DEV):
        candidates.append(root/'dotfiles/installer-appimage-offline/.build/appimagetool-modern-x86_64.AppImage')
    p=next((p for p in candidates if p.is_file()),None)
    if p is None:raise RuntimeError('appimagetool missing. Supply --appimagetool PATH to the retained tool or install appimagetool, then rerun.')
    return p

def prepare_identity(identity):
    marker=OUTPUT/'inputs.json';safe(marker)
    if not marker.exists():save(marker,identity);return
    previous=json.loads(marker.read_text())
    if previous==identity:return
    if {k:v for k,v in previous.items() if k!='kit'}!={k:v for k,v in identity.items() if k!='kit'}:
        raise RuntimeError('Existing r3 build has different baseline inputs; retained')
    # Migrate only an early source-preparation failure. Completed candidates,
    # images, upload state and release assets block any kit identity migration.
    allowed={'inputs.json','downloads','sources','base-runtime','base-extracted','build.log','packaging.log'}
    baseline=OUTPUT/'base-candidate'
    if baseline.exists():
        manifest=OUTPUT/'downloads/release-r2.json'
        expected=identity['baseline'].get('release-r2.json',{}) if isinstance(identity['baseline'],dict) else {}
        if not manifest.is_file() or sha(manifest)!=expected.get('sha256'):
            raise RuntimeError('Retained baseline manifest differs; kit migration stopped')
        recorded=json.loads((baseline/'complete.json').read_text())
        if recorded!=json.loads(manifest.read_text())['image']:
            raise RuntimeError('Retained packaged baseline identity differs; kit migration stopped')
        if json.loads((baseline/'assembly-report.json').read_text())['plan_sha256']!=sha(baseline/'AppDir/payload/plan.json'):
            raise RuntimeError('Retained baseline plan differs; kit migration stopped')
        allowed.add('base-candidate')
    if (OUTPUT/'candidate').exists():
        base=baseline/'AppDir' if baseline.exists() else OUTPUT/'base-extracted/squashfs-root'
        candidate=OUTPUT/'candidate/AppDir'
        if {p.name for p in (OUTPUT/'candidate').iterdir()}!={'AppDir'} or not unchanged_tree(base,candidate):
            raise RuntimeError('Interrupted candidate already has changes; different kit retained')
        allowed.add('candidate')
    for path in OUTPUT.iterdir():
        safe(path)
        if path.name in allowed:continue
        if path.is_file() and path.name.startswith('inputs-before-kit-') and path.suffix=='.json':continue
        raise RuntimeError('Existing r3 build has candidate/release output; different kit retained: '+path.name)
    backup=OUTPUT/('inputs-before-kit-'+sha(marker)[:16]+'.json')
    if backup.exists():
        if backup.read_bytes()!=marker.read_bytes():raise RuntimeError('Earlier input backup differs')
    else:write(backup,marker.read_bytes())
    save(marker,identity)
    print('Resume early preparation with corrected kit; verified downloads retained.',flush=True)

def unchanged_tree(original,candidate):
    if not original.is_dir() or not candidate.is_dir():return False
    def files(root):return {p.relative_to(root).as_posix():p for p in root.rglob('*') if p.is_file() or p.is_symlink()}
    before=files(original);after=files(candidate)
    if before.keys()!=after.keys():return False
    for name,p in before.items():
        q=after[name]
        if p.is_symlink() or q.is_symlink():
            if not p.is_symlink() or not q.is_symlink() or os.readlink(p)!=os.readlink(q):return False
        else:
            a=p.stat();b=q.stat()
            if a.st_size!=b.st_size or (a.st_mode&0o777)!=(b.st_mode&0o777):return False
            if (a.st_dev,a.st_ino)!=(b.st_dev,b.st_ino) and sha(p)!=sha(q):return False
    return True

def verify_backend(candidate,source):
    files=sorted((candidate/'backend').glob('*.py'))
    if not files or not (candidate/'backend/core.py').is_file():raise RuntimeError('Packaged backend is missing')
    for p in files:
        if not (source/p.name).is_file() or sha(source/p.name)!=sha(p):
            raise RuntimeError('Published packaged backend/source archive differs: '+p.name)

def build(explicit_tool=None):
    if not shutil.which('gh'):raise RuntimeError('GitHub CLI gh is required for verified published asset metadata')
    repair=addon();safe(OUTPUT)
    if not OUTPUT.exists():
        if shutil.disk_usage(HOME).free<14*1024**3:raise RuntimeError('Allow 14 GiB free for the separate build and optional payload recovery')
        OUTPUT.mkdir(mode=0o700)
    cache=OUTPUT/'downloads';cache.mkdir(exist_ok=True)
    release=api(f'repos/{REPO}/releases/tags/{TAG}')
    current=assets(release['id'])
    names=('release-r2.json','online-installer-r2.json','sumi-installer-source-v6.0.0-r2.zip','ONLINE-INSTALL-v6-r2.sh')
    pinned={name:server_record(current[name]) for name in names}
    if pinned!=json.loads((KIT/'verified/r2-assets.json').read_text()):
        raise RuntimeError('Published r2 baseline differs from the reviewed release; retained')
    manifest_path=download(pinned['release-r2.json'],cache);manifest=json.loads(manifest_path.read_text())
    metadata_path=download(pinned['online-installer-r2.json'],cache);metadata=json.loads(metadata_path.read_text())
    if manifest.get('revision')!='appearance-r2' or manifest.get('version')!='6.0.0' or manifest.get('status')!='ready':
        raise RuntimeError('Expected published appearance-r2 baseline')
    if metadata.get('revision')!='appearance-r2' or metadata.get('wallpaper_count')!=631 or len(manifest['profiles'])!=12:
        raise RuntimeError('Published baseline features differ')
    for r in [*manifest['parts'],metadata['gui'],metadata['manifest']]:
        if not matches(current.get(r['asset']),r):raise RuntimeError('Published baseline asset differs: '+r['asset'])
    identity={'baseline':pinned,'gui':metadata['gui'],'kit':{p.relative_to(KIT).as_posix():sha(p) for p in KIT.rglob('*') if p.is_file() and '__pycache__' not in p.parts}}
    prepare_identity(identity)
    prior_launcher=download(pinned['ONLINE-INSTALL-v6-r2.sh'],cache)
    source_archive=download(pinned['sumi-installer-source-v6.0.0-r2.zip'],cache)
    archive=download(metadata['gui'],cache);original_gui=obtain_runtime(metadata,archive)
    old=obtain_candidate(manifest,cache);source=OUTPUT/'sources';extract_source(source_archive,source)
    verify_backend(old,source)
    write(source/'assemble-candidate.py',collector((source/'assemble-candidate.py').read_text()).encode())
    write(source/'desktop_defaults.py',(KIT/'desktop_defaults.py').read_bytes())
    report_path=old.parent/'assembly-report.json'
    report=json.loads(report_path.read_text()) if report_path.exists() else {'status':'candidate-appdir','release_features':{'login_cards':74,'grub_cards':8},'plan_sha256':sha(old/'payload/plan.json')}
    packaging_tool=tool(report,explicit_tool)
    report['appimage_packager_candidates']=[{'path':str(packaging_tool),'sha256':sha(packaging_tool),'bytes':packaging_tool.stat().st_size}]
    spec=importlib.util.spec_from_file_location('r3_packager',source/'package-release.py');pack=importlib.util.module_from_spec(spec)
    sys.path.insert(0,str(source));spec.loader.exec_module(pack);pack.ROOT=source;pack.IMAGE=IMAGE
    pack.BACKEND_FILES=tuple(sorted(p.name for p in (old/'backend').glob('*.py')))
    fallback='    if [[ -z "$manifest" || ! -f "$manifest" ]]; then manifest="$ROOT/gui/release.json"; fi'
    if fallback not in pack.APPRUN:raise RuntimeError('Unknown packaged launcher retained')
    pack.APPRUN=pack.APPRUN.replace(fallback,
        '    if [[ -z "$manifest" || ! -f "$manifest" ]]; then manifest="$(dirname -- "${APPIMAGE:-$ROOT}")/release-r3.json"; fi\n'
        '    [[ -f "$manifest" ]] || { echo "Place release-r3.json beside this AppImage." >&2; exit 1; }')
    # The recovery candidate has no assembly report; record the verified baseline.
    if not report_path.exists():save(report_path,report)
    pack.verify_candidate(old,HOME)
    target=OUTPUT/'candidate/AppDir';stamp=OUTPUT/'candidate-ready.json'
    if not stamp.exists():
        if target.exists():safe(target);shutil.rmtree(target)
        shutil.copytree(old,target,copy_function=link,symlinks=True)
        plan,changed=apply(target/'payload',repair)
        report.update(plan_sha256=sha(target/'payload/plan.json'),desktop_revision='r3',desktop_fixes=changed)
        save(target.parent/'assembly-report.json',report);save(stamp,{'plan_sha256':report['plan_sha256']})
    if json.loads(stamp.read_text())['plan_sha256']!=sha(target/'payload/plan.json'):raise RuntimeError('Retained r3 candidate differs')
    plan,report=pack.verify_candidate(target,HOME)
    # Backend, packages, system files, links and non-repair files must remain exact.
    verify_preserved(old/'payload/plan.json',target/'payload/plan.json')
    runtime=OUTPUT/'runtime/SumiSetup'
    if not runtime.exists():shutil.copytree(original_gui,runtime,copy_function=link,symlinks=True)
    pack.run([runtime/'SumiSetup','--offline','--screenshot',OUTPUT/'sumi-runtime.png'],OUTPUT,
             'Render retained Sumi GUI',60,env=dict(os.environ,QT_QPA_PLATFORM='offscreen'))
    image=pack.build_image(target,runtime,OUTPUT,report);parts=pack.split_image(image,OUTPUT)
    revised=pack.make_manifest(image,parts,plan);revised['revision']='desktop-r3'
    revised['installed_bytes']+=2*plan['icon_bundle']['unpacked_bytes']
    revised['validation']='Crimson UI, Cipher Super+Space and Aether icons accepted in fresh VM; integrated image checks passed'
    save(OUTPUT/'release-r3.json',revised);pack.load_manifest(OUTPUT/'release-r3.json')
    save(runtime/'release.json',revised)
    for offline in (True,False):write(runtime/('launch-offline.sh' if offline else 'launch-online.sh'),pack.launcher(offline).encode(),0o755)
    records=pack.runtime_records(runtime);runtime_archive=OUTPUT/'sumi-setup-v6.0.0-online-r3-x86_64.tar.xz'
    def stable(info):info.mtime=0;info.uid=0;info.gid=0;info.uname='';info.gname='';return info
    print('Compress retained online setup runtime',flush=True)
    with tarfile.open(runtime_archive,'w:xz',preset=1) as tar:tar.add(runtime,arcname=RUNTIME,filter=stable)
    online={'schema':1,'version':'6.0.0','revision':'desktop-r3','wallpaper_count':631,'runtime_directory':RUNTIME,
            'gui':record(runtime_archive),'manifest':record(OUTPUT/'release-r3.json'),'records':records,
            'unpacked_bytes':sum(p.stat().st_size for p in runtime.rglob('*') if p.is_file() and not p.is_symlink())}
    info=OUTPUT/'online-installer-r3.json';save(info,online)
    bootstrap=(KIT/'bootstrap.py').read_text().replace('@INFO_SHA256@',sha(info)).replace('@INFO_BYTES@',str(info.stat().st_size))
    script="#!/usr/bin/env bash\nset -euo pipefail\npython3 - <<'SUMI_ONLINE_PY'\n"+bootstrap+'\nSUMI_ONLINE_PY\n'
    launcher=OUTPUT/'ONLINE-INSTALL-v6-r3.sh';write(launcher,script.encode(),0o755)
    run(['bash','-n',launcher],'Check one-command launcher syntax',30)
    source_zip=OUTPUT/'sumi-installer-source-v6.0.0-r3.zip'
    with zipfile.ZipFile(source_zip,'w',zipfile.ZIP_DEFLATED) as z:
        for root,prefix in ((source,'installer'),(KIT,'desktop-release')):
            for p in sorted(root.rglob('*')):
                if p.is_file() and '__pycache__' not in p.parts:z.write(p,prefix+'/'+p.relative_to(root).as_posix())
        for r,data in crimson_sources(repair):
            z.writestr('desktop-additions/'+r['source'],data)
    assembly=OUTPUT/'assemble-v6-r3.py';write(assembly,(KIT/'assemble-v6-r3.py').read_bytes(),0o755)
    files=[*parts,OUTPUT/'release-r3.json',runtime_archive,info,launcher,source_zip,assembly]
    sums=OUTPUT/'DESKTOP-r3-SHA256SUMS';write(sums,''.join(sha(p)+'  '+p.name+'\n' for p in [image,*files]).encode());files.append(sums)
    result={'status':'built','revision':'desktop-r3','image':record(image),'files':{p.name:record(p) for p in files},
            'fixes':report['desktop_fixes'],'preserved':'r2 backend, system files, packages, links, 12 profiles, 74 login cards, eight GRUB cards, 631-wallpaper pin',
            'visual_acceptance':'All three constituent fixes accepted by user in fresh VM; newly assembled image not installed yet'}
    save(OUTPUT/'build-result.json',result)
    return files,pinned['ONLINE-INSTALL-v6-r2.sh'],prior_launcher

def verify_preserved(old_path,new_path):
    old=json.loads(old_path.read_text());new=json.loads(new_path.read_text())
    allowed={r[0] for r in __import__('fixes').verified_changes()}
    baseline={r['path']:r for r in old.pop('user_files')};revised={r['path']:r for r in new.pop('user_files')}
    if old!=new:raise RuntimeError('Non-user payload records changed; publication stopped')
    for path,row in baseline.items():
        if path not in allowed and revised.get(path)!=row:raise RuntimeError('Unrelated user file changed: '+path)
    expected={r['path'] for r in json.loads((KIT/'verified/crimson-manifest.json').read_text())['files']}
    if set(revised)-set(baseline) != expected-set(baseline):raise RuntimeError('Unexpected added payload files')
