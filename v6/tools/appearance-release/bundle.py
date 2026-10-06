"""Build a new revision from the pinned final payload and exported VM repairs."""
import importlib.util
import json
import os
import re
from pathlib import Path
import shutil
import sys
import tarfile
import zipfile
from patch_sources import backend, transaction, grub_manager
from boot_fixes import quiet_generator, cipher_settings
from icon_inventory import inventory

HOME=Path.home();KIT=Path(__file__).resolve().parent
ROOT=HOME/'Downloads/sumi-v6-build-prep'
FINAL=HOME/'multi-rice-v6-release-final'
FAST=HOME/'multi-rice-v6-wallpaper-fast-test'
OUTPUT=HOME/'multi-rice-v6-appearance-r2'
IMAGE='multi-rice-v6.0.0-r2-x86_64.AppImage'
RUNTIME='sumi-setup-v6.0.0-online-r2'
BASE='https://github.com/huzaifahshahid71-ops/dotfiles/releases/download/v6.0.0/'
MODULES=('login_defaults.py','grub_records.py','icon_bundle.py','icon_inventory.py','icon_extract.py')
LUMINA_BASE='.local/share/desktop-profiles/sayconlun/support/'
LUMINA_FILES=frozenset(
    [LUMINA_BASE+'rofi/'+name for name in
     ('colors.rasi','config.rasi','launcher.rasi','menu.rasi','theme.rasi','wallpaper.rasi')]
    +[LUMINA_BASE+'matugen/templates/'+name for name in
      ('btop.theme','cava.conf','fastfetch.jsonc','foot.ini','gtk.css',
       'hyprland-colors.lua','hyprland-live.lua','hyprlock-colors.conf',
       'kde.colors','kitty.conf','palette.css','qt6ct.conf','quickshell.json','rofi.rasi')])


def safe(path):
    for item in (path,*path.parents):
        if item.is_symlink():raise RuntimeError('Existing symlink preserved: '+str(item))


def sha(path):
    import hashlib
    with path.open('rb') as stream:return hashlib.file_digest(stream,'sha256').hexdigest()


def write(path,data,mode=0o644):
    safe(path);path.parent.mkdir(parents=True,exist_ok=True)
    temporary=path.with_name(path.name+'.r2-new');safe(temporary)
    if temporary.exists():raise RuntimeError('Interrupted temporary retained: '+str(temporary))
    with temporary.open('xb') as out:out.write(data);out.flush();os.fsync(out.fileno())
    temporary.chmod(mode);os.replace(temporary,path)


def save(path,data):write(path,(json.dumps(data,indent=2)+'\n').encode())


def link(a,b):
    try:os.link(a,b)
    except OSError:shutil.copy2(a,b)
    return b


def module(name,path):
    spec=importlib.util.spec_from_file_location(name,path);value=importlib.util.module_from_spec(spec);spec.loader.exec_module(value);return value


def row(payload,rows,relative,data,init=False):
    record=rows.get(relative,{})
    source=record.get('source','home/'+relative)
    write(payload/source,data,record.get('mode',0o644))
    rows[relative]=dict(record,path=relative,source=source,bytes=len(data),sha256=sha(payload/source),
                       mode=record.get('mode',0o644),template=b'@MULTI_RICE_HOME@' in data,init=init)


def validate_lumina(manifest,lumina):
    """Validate the complete exported collection, including existing templates."""
    if manifest.get('schema')!=1 or not isinstance(manifest.get('files'),list):
        raise RuntimeError('Lumina export manifest schema differs')
    records=manifest['files'];paths=[r.get('path') for r in records]
    if len(paths)!=len(set(paths)):raise RuntimeError('Duplicate Lumina asset path')
    if set(paths)!=LUMINA_FILES:
        missing=sorted(LUMINA_FILES-set(paths));extra=sorted(set(paths)-LUMINA_FILES)
        raise RuntimeError('Lumina export inventory differs: missing='+repr(missing)+'; extra='+repr(extra))
    for r in records:
        path=Path(r['path']);source=Path(r['source'])
        if source.is_absolute() or '..' in source.parts or str(source)!='home/'+str(path):
            raise RuntimeError('Lumina source path differs')
        file=lumina/source;safe(file)
        if not file.is_file() or file.stat().st_size!=r['bytes'] or sha(file)!=r['sha256']:
            raise RuntimeError('Lumina asset checksum differs: '+r['path'])


def addons():
    appearance=ROOT/'appearance-repair/appearance-auth-b5ac73e71a25';safe(appearance)
    state=json.loads((appearance/'checkpoint.json').read_text())
    if state.get('status')!='prepared-next-boot' or state.get('icons',{}).get('total')!=164921:
        raise RuntimeError('Expected the verified, exported appearance repair')
    lumina=ROOT/'lumina-assets-repair/lumina-assets-5aef042f384b';safe(lumina)
    manifest=json.loads((lumina/'manifest.json').read_text())
    validate_lumina(manifest,lumina)
    archive=appearance/'icons.zip';safe(archive)
    with zipfile.ZipFile(archive) as z:data=inventory(z)
    if len(data['files'])!=164921 or data['bytes']!=603730520:raise RuntimeError('The retained icon collection differs')
    return appearance,lumina,manifest,data


def prepare_output(identity):
    """Resume a changed kit only before any candidate or release asset exists."""
    marker=OUTPUT/'inputs.json';safe(OUTPUT);safe(marker)
    if not OUTPUT.exists():
        if shutil.disk_usage(OUTPUT.parent).free<6*1024**3:
            raise RuntimeError('This separate build needs at least 6 GiB host space')
        OUTPUT.mkdir(mode=0o700);save(marker,identity);return
    if not marker.is_file():raise RuntimeError('Existing r2 build has no input identity; preserved')
    previous=json.loads(marker.read_text())
    if previous==identity:return
    if {k:v for k,v in previous.items() if k!='kit'}!={k:v for k,v in identity.items() if k!='kit'}:
        raise RuntimeError('Existing r2 build uses different source/repair inputs; preserved')
    for item in OUTPUT.iterdir():
        safe(item)
        if item.name=='sources' and item.is_dir():continue
        if item.name=='inputs.json':continue
        if re.fullmatch(r'inputs-before-kit-[0-9a-f]{16}\.json',item.name) and item.is_file():continue
        raise RuntimeError('Existing r2 build has candidate/release output; different kit preserved: '+item.name)
    backup=OUTPUT/('inputs-before-kit-'+sha(marker)[:16]+'.json')
    if backup.exists():
        if backup.read_bytes()!=marker.read_bytes():raise RuntimeError('Previous input backup differs; preserved')
    else:write(backup,marker.read_bytes())
    save(marker,identity)
    print('Resume early source-preparation failure with corrected kit; retained inputs unchanged',flush=True)


def candidate(source,appearance,lumina,manifest,icons,runtime_names=()):
    old=FINAL/'candidate/AppDir';report=json.loads((old.parent/'assembly-report.json').read_text())
    if sha(old/'payload/plan.json')!=report['plan_sha256']:raise RuntimeError('Retained final candidate plan differs')
    target=OUTPUT/'candidate/AppDir';stamp=OUTPUT/'candidate-ready.json'
    if stamp.exists():
        if json.loads(stamp.read_text())['plan_sha256']!=sha(target/'payload/plan.json'):raise RuntimeError('Retained revised candidate differs')
        return target
    if target.exists():
        # This directory belongs exclusively to this revision's interrupted build.
        safe(target);shutil.rmtree(target)
    shutil.copytree(old,target,copy_function=link,symlinks=True)
    payload=target/'payload';plan=json.loads((payload/'plan.json').read_text());rows={r['path']:r for r in plan['user_files']}
    for record in manifest['files']:row(payload,rows,record['path'],(lumina/record['source']).read_bytes())
    relative='.config/clavis/config.json'
    if any(l['path']=='.config/clavis' for l in plan['user_links']):raise RuntimeError('Cipher discovery link overlaps initial settings; source review required')
    old_config=(payload/rows[relative]['source']).read_bytes() if relative in rows else None
    row(payload,rows,relative,cipher_settings(old_config),init=True)
    # The archive stays one managed object; its three extracted directories are
    # snapshot/restored as directories, not 164,921 progress events.
    for relative in list(rows):
        if any(relative=='.local/share/icons/'+t or relative.startswith('.local/share/icons/'+t+'/') for t in icons['themes']):
            (payload/rows.pop(relative)['source']).unlink()
    archive=payload/'assets/mactahoe.zip';archive.parent.mkdir(exist_ok=True)
    if archive.exists():raise RuntimeError('Unexpected existing icon bundle')
    link(appearance/'icons.zip',archive)
    record={'path':'.local/share/multi-rice-assets/mactahoe.zip','source':'assets/mactahoe.zip',
            'bytes':archive.stat().st_size,'sha256':sha(archive),'mode':0o644,'template':False,'init':False}
    rows[record['path']]=record
    plan['icon_bundle']=dict(schema=1,source=record['source'],bytes=record['bytes'],sha256=record['sha256'],
                             themes=icons['themes'],files=len(icons['files']),unpacked_bytes=icons['bytes'])
    plan['login_defaults']='sddm-next-boot-v1'
    required={'usr/local/share/evangelion/bin/boot-console.awk':quiet_generator,
              'usr/local/share/evangelion/bin/install.sh':grub_manager}
    done=set()
    for record in plan['system_files']:
        if record['path'] in required:
            path=payload/record['source'];write(path,required[record['path']](path.read_text()).encode(),record['mode'])
            record.update(bytes=path.stat().st_size,sha256=sha(path));done.add(record['path'])
    if done!=set(required):raise RuntimeError('Pinned Evangelion manager sources are missing')
    plan['user_files']=list(rows.values())
    for filename in dict.fromkeys(('payload_backend.py','system_transaction.py',*MODULES,*runtime_names)):
        relative='.local/share/multi-rice-setup/runtime/'+filename
        if filename in MODULES or relative in rows:row(payload,rows,relative,(source/filename).read_bytes())
    plan['user_files']=list(rows.values());save(payload/'plan.json',plan)
    for name in MODULES:write(target/'backend'/name,(source/name).read_bytes())
    for name in ('payload_backend.py','system_transaction.py'):write(target/'backend'/name,(source/name).read_bytes())
    report.update(plan_sha256=sha(payload/'plan.json'),files=len(rows),appearance_revision='r2',
                  appearance_fixes={'login_manager':'SDDM next boot, receipt-backed restore','grub':'owned quiet arguments and patched filter',
                                    'icons':len(icons['files']),'lumina_assets':len(manifest['files'])})
    save(target.parent/'assembly-report.json',report);save(stamp,{'plan_sha256':report['plan_sha256']})
    return target


def build():
    if os.geteuid()==0:raise RuntimeError('Build as the normal host user, without sudo')
    appearance,lumina,manifest,icons=addons()
    published=json.loads((FINAL/'published.json').read_text());previous=json.loads((FINAL/'release.json').read_text())
    if sha(FINAL/'release.json')!=published['assets']['release.json']['sha256']:raise RuntimeError('Original published manifest differs')
    print('Verify retained published AppImage and compressed icons',flush=True)
    if sha(FINAL/previous['image']['asset'])!=previous['image']['sha256']:raise RuntimeError('Original published AppImage differs')
    sources={p.name:sha(p) for p in ROOT.glob('*.py')}
    if 'SUMI_WALLPAPER_ZIP_PACKS_V1' not in (ROOT/'core.py').read_text():raise RuntimeError('Fast ZIP wallpaper downloader missing')
    identity={'sources':sources,'icons':sha(appearance/'icons.zip'),'lumina':sha(lumina/'manifest.json'),
              'original_manifest':sha(FINAL/'release.json'),'kit':{p.name:sha(p) for p in KIT.iterdir() if p.is_file()}}
    # Review every source transform before writing build state. This prevents
    # repeated partial preparations when a retained source version differs.
    backend_source=backend((ROOT/'payload_backend.py').read_text())
    transaction_source=transaction((ROOT/'system_transaction.py').read_text())
    compile(backend_source,'payload_backend.py','exec');compile(transaction_source,'system_transaction.py','exec')
    prepare_output(identity)
    source=OUTPUT/'sources';source.mkdir(exist_ok=True)
    for path in ROOT.glob('*.py'):write(source/path.name,path.read_bytes())
    for name in ('wallpapers.json','release.json','gui-build-requirements.txt'):write(source/name,(ROOT/name).read_bytes())
    shutil.copytree(ROOT/'assets',source/'assets',dirs_exist_ok=True)
    catalog='build-support/shortcut-menu/catalog.py';write(source/catalog,(ROOT/catalog).read_bytes())
    write(source/'payload_backend.py',backend_source.encode())
    write(source/'system_transaction.py',transaction_source.encode())
    for name in MODULES:write(source/name,(KIT/name).read_bytes())
    sys.path.insert(0,str(source))
    pack=module('appearance_packager',source/'package-release.py');pack.ROOT=source;pack.IMAGE=IMAGE
    old_fallback='    if [[ -z "$manifest" || ! -f "$manifest" ]]; then manifest="$ROOT/gui/release.json"; fi'
    if old_fallback not in pack.APPRUN:raise RuntimeError('Packaged launcher declaration differs')
    pack.APPRUN=pack.APPRUN.replace(old_fallback,
        '    if [[ -z "$manifest" || ! -f "$manifest" ]]; then manifest="$(dirname -- "${APPIMAGE:-$ROOT}")/release-r2.json"; fi\n'
        '    [[ -f "$manifest" ]] || { echo "Place release-r2.json beside this AppImage, or use the online launcher." >&2; exit 1; }')
    pack.BACKEND_FILES=tuple(dict.fromkeys((*pack.BACKEND_FILES,'eclipse_defaults.py',*MODULES)))
    original_gui=FAST/'runtime/SumiSetup'
    if pack.runtime_records(original_gui)!=json.loads((FAST/'gui-complete.json').read_text()):raise RuntimeError('Accepted fast GUI runtime differs')
    for name in ('core.py','app.py','wallpapers.json'):
        if sha(original_gui/'source'/name)!=sha(ROOT/name):raise RuntimeError('Current GUI source differs from tested fast runtime: '+name)
    candidate_dir=candidate(source,appearance,lumina,manifest,icons,(*pack.GUI_FILES,*pack.BACKEND_FILES))
    plan,report=pack.verify_candidate(candidate_dir,HOME)
    # Check imports and the real patched root receipt regression fixtures.
    pack.run([sys.executable,'-B','-c','import payload_backend,system_transaction,login_defaults,icon_bundle'],OUTPUT,
             'Check revised backend imports',30,cwd=source)
    runtime=OUTPUT/'runtime/SumiSetup'
    if not runtime.exists():shutil.copytree(original_gui,runtime,copy_function=link,symlinks=True)
    pack.run([runtime/'SumiSetup','--offline','--screenshot',OUTPUT/'sumi-runtime.png'],OUTPUT,
             'Render retained fast setup GUI',60,env=dict(os.environ,QT_QPA_PLATFORM='offscreen'))
    image=pack.build_image(candidate_dir,runtime,OUTPUT,report);parts=pack.split_image(image,OUTPUT)
    revised=pack.make_manifest(image,parts,plan);revised['revision']='appearance-r2'
    revised['installed_bytes']+=2*icons['bytes']
    revised['validation']='Fresh VM repair/reboot accepted; integrated revision automated checks passed; new clean VM acceptance pending'
    save(OUTPUT/'release-r2.json',revised);pack.load_manifest(OUTPUT/'release-r2.json')
    save(runtime/'release.json',revised)
    for offline in (True,False):write(runtime/('launch-offline.sh' if offline else 'launch-online.sh'),pack.launcher(offline).encode(),0o755)
    for name in MODULES:write(runtime/'source'/name,(source/name).read_bytes())
    records=pack.runtime_records(runtime)
    archive=OUTPUT/'sumi-setup-v6.0.0-online-r2-x86_64.tar.xz'
    def stable(info):info.mtime=0;info.uid=0;info.gid=0;info.uname='';info.gname='';return info
    print('Compress fast online setup runtime',flush=True)
    with tarfile.open(archive,'w:xz',preset=1) as tar:tar.add(runtime,arcname=RUNTIME,filter=stable)
    def asset(path):return {'asset':path.name,'bytes':path.stat().st_size,'sha256':sha(path),'url':BASE+path.name}
    metadata={'schema':1,'version':'6.0.0','revision':'appearance-r2','wallpaper_count':631,'runtime_directory':RUNTIME,
              'gui':asset(archive),'manifest':asset(OUTPUT/'release-r2.json'),'records':records,
              'unpacked_bytes':sum(p.stat().st_size for p in runtime.rglob('*') if p.is_file() and not p.is_symlink())}
    info=OUTPUT/'online-installer-r2.json';save(info,metadata)
    bootstrap=(KIT/'bootstrap.py').read_text().replace('@INFO_SHA256@',sha(info)).replace('@INFO_BYTES@',str(info.stat().st_size))
    script='#!/usr/bin/env bash\nset -euo pipefail\npython3 - <<\'SUMI_ONLINE_PY\'\n'+bootstrap+'\nSUMI_ONLINE_PY\n'
    write(OUTPUT/'ONLINE-INSTALL-v6-r2.sh',script.encode(),0o755)
    import subprocess
    subprocess.run(['bash','-n',str(OUTPUT/'ONLINE-INSTALL-v6-r2.sh')],check=True)
    source_zip=OUTPUT/'sumi-installer-source-v6.0.0-r2.zip'
    with zipfile.ZipFile(source_zip,'w',zipfile.ZIP_DEFLATED) as z:
        for p in sorted(source.rglob('*')):
            if p.is_file() and '__pycache__' not in p.parts:z.write(p,'installer/'+str(p.relative_to(source)))
        for p in sorted(KIT.rglob('*')):
            if p.is_file() and '__pycache__' not in p.parts:z.write(p,'appearance-release/'+str(p.relative_to(KIT)))
    write(OUTPUT/'assemble-v6-r2.py',(KIT/'assemble-v6-r2.py').read_bytes(),0o755)
    files=[*parts,OUTPUT/'release-r2.json',archive,info,OUTPUT/'ONLINE-INSTALL-v6-r2.sh',source_zip,OUTPUT/'assemble-v6-r2.py']
    sums=OUTPUT/'APPEARANCE-r2-SHA256SUMS';write(sums,''.join(sha(p)+'  '+p.name+'\n' for p in [image,*files]).encode());files.append(sums)
    save(OUTPUT/'build-result.json',{'status':'built','revision':'appearance-r2','files':{p.name:asset(p) for p in files},
                                 'image':asset(image),'fixes':report['appearance_fixes'],'clean_vm_test':'pending'})
    print('BUILT:',image,flush=True)
    return files,published
