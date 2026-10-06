"""Publish unique r2 assets; update the established launcher last."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
from bundle import KIT, ROOT, OUTPUT, BASE, sha, save

REPO='huzaifahshahid71-ops/dotfiles';TAG='v6.0.0';BRANCH='v6.0-tahoe-dev'
MARKER='<!-- sumi-appearance-r2 -->'


def api(endpoint,payload=None,method=None):
    args=['gh','api',endpoint]
    if method:args+=['--method',method]
    elif payload is not None:args+=['--method','POST']
    if payload is not None:args+=['--input','-']
    result=subprocess.run(args,input=json.dumps(payload) if payload is not None else None,
                          capture_output=True,text=True,env=dict(os.environ,GH_PROMPT_DISABLED='1'),timeout=120)
    if result.returncode:raise RuntimeError('GitHub operation stopped: '+result.stderr.strip())
    return json.loads(result.stdout) if result.stdout.strip() else None


def assets(identifier):
    result={};page=1
    while True:
        rows=api(f'repos/{REPO}/releases/{identifier}/assets?per_page=100&page={page}')
        result.update({r['name']:r for r in rows})
        if len(rows)<100:return result
        page+=1


def matches(asset,record):
    return bool(asset and asset.get('size')==record['bytes'] and asset.get('digest')=='sha256:'+record['sha256']
                and asset.get('state')=='uploaded')


def upload(path):
    subprocess.run(['gh','release','upload',TAG,str(path),'--repo',REPO],check=True,
                   env=dict(os.environ,GH_PROMPT_DISABLED='1'),timeout=1800)


def commit_source():
    paths={}
    for path in (OUTPUT/'sources').glob('*.py'):paths['v6/installer/'+path.name]=path.read_text()
    paths['v6/installer/release.json']=(OUTPUT/'release-r2.json').read_text()
    paths['v6/install-online.sh']=(OUTPUT/'ONLINE-INSTALL-v6-r2.sh').read_text()
    for path in KIT.rglob('*'):
        if path.is_file() and '__pycache__' not in path.parts:paths['v6/tools/appearance-release/'+path.relative_to(KIT).as_posix()]=path.read_text()
    identity=hashlib.sha256(json.dumps(paths,sort_keys=True).encode()).hexdigest();marker=OUTPUT/'source-commit.json'
    if marker.exists():
        saved=json.loads(marker.read_text())
        if saved['identity']!=identity:raise RuntimeError('Previously prepared release source changed')
        return saved['commit']
    head=api(f'repos/{REPO}/git/ref/heads/{BRANCH}')['object']['sha']
    tree=api(f'repos/{REPO}/git/commits/{head}')['tree']['sha']
    revised=api(f'repos/{REPO}/git/trees',{'base_tree':tree,'tree':[
        {'path':p,'type':'blob','mode':'100755' if p.endswith('.sh') else '100644','content':data} for p,data in sorted(paths.items())]})
    commit=api(f'repos/{REPO}/git/commits',{'message':'Bundle fresh-machine SDDM, quiet GRUB, MacTahoe and Lumina fixes in Sumi v6 r2',
                                         'tree':revised['sha'],'parents':[head]})['sha']
    api(f'repos/{REPO}/git/refs/heads/{BRANCH}',{'sha':commit,'force':False},'PATCH')
    save(marker,{'identity':identity,'commit':commit,'branch':BRANCH});return commit


def switch_launcher(identifier,current,expected,prior,old_file,new_file):
    name='ONLINE-INSTALL-v6.sh';asset=current.get(name)
    if matches(asset,expected):return
    if not matches(asset,prior):raise RuntimeError('Existing one-command launcher differs; preserved')
    if not old_file.is_file() or sha(old_file)!=prior['sha256']:raise RuntimeError('Verified previous launcher is missing; update stopped')
    # Unique revision assets are already available. Only the known launcher is
    # replaced, after verifying its old digest and retaining rollback bytes.
    api(f'repos/{REPO}/releases/assets/{asset["id"]}',method='DELETE')
    try:
        upload(new_file)
        if not matches(assets(identifier).get(name),expected):raise RuntimeError('New launcher checksum not confirmed')
    except Exception:
        latest=assets(identifier).get(name)
        if latest and matches(latest,expected):return
        if latest is None:upload(old_file)
        raise


def publish(files,original):
    if not shutil.which('gh'):raise RuntimeError('GitHub CLI gh is required on the host')
    if api('user')['login']!='huzaifahshahid71-ops':raise RuntimeError('GitHub CLI account differs')
    release=api(f'repos/{REPO}/releases/tags/{TAG}')
    if release.get('draft') or release.get('prerelease'):raise RuntimeError('Expected the established stable v6.0.0 release')
    previous=Path.home()/'multi-rice-v6-online-public-r1'
    prior=json.loads((previous/'published.json').read_text())['assets']
    records={p.name:{'bytes':p.stat().st_size,'sha256':sha(p)} for p in files}
    name='ONLINE-INSTALL-v6.sh';new_file=OUTPUT/name
    from bundle import write
    write(new_file,(OUTPUT/'ONLINE-INSTALL-v6-r2.sh').read_bytes(),0o755)
    new={'bytes':new_file.stat().st_size,'sha256':sha(new_file)}
    current=assets(release['id'])
    for filename,record in {**original['assets'],**prior}.items():
        if filename==name:
            if not matches(current.get(filename),record) and not matches(current.get(filename),new):raise RuntimeError('Existing public launcher differs; preserved')
        elif not matches(current.get(filename),record):raise RuntimeError('Existing public asset differs: '+filename)
    for filename,record in records.items():
        if filename in current and not matches(current[filename],record):raise RuntimeError('Existing r2 asset differs; preserved: '+filename)
    marker=OUTPUT/'publication-assets.json'
    if marker.exists() and json.loads(marker.read_text())!=records:raise RuntimeError('Prepared publication assets differ')
    save(marker,records);commit=commit_source()
    for index,path in enumerate(files,1):
        current=assets(release['id'])
        if path.name not in current:
            if path.stat().st_size>=2*1024**3:raise RuntimeError('Release asset exceeds two GiB')
            print(f'Upload {index}/{len(files)}: {path.name}',flush=True);upload(path)
        if not matches(assets(release['id']).get(path.name),records[path.name]):raise RuntimeError('Asset verification not complete; rerun to resume')
        print(f'Verified {index}/{len(files)}: {path.name}',flush=True)
    switch_launcher(release['id'],assets(release['id']),new,prior[name],previous/name,new_file)
    fresh=api(f'repos/{REPO}/releases/{release["id"]}');body=fresh.get('body') or ''
    command='curl -fsSL '+BASE+name+' | bash'
    addition=MARKER+'\n## Fresh-machine fixes — appearance r2\n\nThe one-command installer now uses the revised payload: receipt-backed SDDM selection for next boot, quiet GRUB arguments retained across theme changes, complete MacTahoe icons and Lumina launcher/palette assets. All 12 rices, 74 login cards, eight GRUB cards and the fast 631-wallpaper downloader are retained.\n\n```sh\n'+command+'\n```\n\nThe source is pinned on `'+BRANCH+'` at `'+commit+'`. The repair was accepted after reboot in a fresh CachyOS VM; a new clean installation acceptance run is next. Original offline/r1 assets remain available. For the revised offline build, download `release-r2.json` and run `assemble-v6-r2.py` in the same directory.\n\n'
    if MARKER not in body:api(f'repos/{REPO}/releases/{release["id"]}',{'body':addition+body},'PATCH')
    if not matches(assets(release['id']).get(name),new):raise RuntimeError('Final launcher verification failed')
    save(OUTPUT/'published.json',{'status':'published','revision':'appearance-r2','release':release['html_url'],
                               'assets':dict(records,**{name:new}),'source_commit':commit,'command':command,'clean_vm_test':'pending'})
    print('PUBLISHED APPEARANCE r2:',release['html_url'],flush=True)
    print('ONE COMMAND:',command,flush=True)
