"""Unique revision assets first; replace the verified public launcher last."""
import hashlib
import base64
import json
import os
from pathlib import Path
from common import KIT, OUTPUT, REPO, TAG, BRANCH, BASE, sha, save, write, run, api, assets, record, matches

MARKER='<!-- sumi-desktop-r3 -->'

def upload(path):
    run(['gh','release','upload',TAG,path,'--repo',REPO],'Upload '+path.name,1800,
        env=dict(os.environ,GH_PROMPT_DISABLED='1'))

def switch_launcher(identifier,expected,prior,old_file,new_file):
    name='ONLINE-INSTALL-v6.sh';current=assets(identifier).get(name)
    if matches(current,expected):return
    if not matches(current,prior):raise RuntimeError('Public launcher was changed by another release; retained')
    if record(old_file)['sha256']!=prior['sha256'] or old_file.stat().st_size!=prior['bytes']:
        raise RuntimeError('Verified previous launcher bytes missing')
    # Recheck just before replacement. All revision assets already verified.
    if assets(identifier).get(name)!=current:raise RuntimeError('Concurrent launcher update retained')
    api(f'repos/{REPO}/releases/assets/{current["id"]}',method='DELETE')
    try:
        upload(new_file)
        if not matches(assets(identifier).get(name),expected):raise RuntimeError('New launcher digest not confirmed')
    except Exception:
        latest=assets(identifier).get(name)
        if matches(latest,expected):return
        if latest is None:upload(old_file)
        raise

def commit_source():
    # Only the collector filter, release tools and source-level launch fixes are
    # new. The public r2 backend and GUI source are preserved on the branch.
    paths={'v6/installer/assemble-candidate.py':(OUTPUT/'sources/assemble-candidate.py').read_text(),
           'v6/installer/desktop_defaults.py':(KIT/'desktop_defaults.py').read_text(),
           'v6/installer/release.json':(OUTPUT/'release-r3.json').read_text(),
           'v6/install-online.sh':(OUTPUT/'ONLINE-INSTALL-v6-r3.sh').read_text()}
    for p in KIT.rglob('*'):
        if p.is_file() and '__pycache__' not in p.parts:
            # Verified VM launch files use home tokens in the release payload.
            # Keep binary shader additions in the source archive, not API text.
            paths['v6/tools/desktop-release/'+p.relative_to(KIT).as_posix()]=p.read_text()
    identity=hashlib.sha256(json.dumps(paths,sort_keys=True).encode()).hexdigest()
    marker=OUTPUT/'source-commit.json'
    if marker.exists():
        old=json.loads(marker.read_text())
        if old['identity']!=identity:raise RuntimeError('Publication source changed; retained')
        return old['commit']
    head=api(f'repos/{REPO}/git/ref/heads/{BRANCH}')['object']['sha']
    current_assembler=api(f'repos/{REPO}/contents/v6/installer/assemble-candidate.py?ref={head}')
    observed=base64.b64decode(current_assembler['content']).decode()
    if observed not in ((KIT/'fixtures/published-assembler.py').read_text(),paths['v6/installer/assemble-candidate.py']):
        raise RuntimeError('Development-branch assembler changed since review; preserved')
    base=api(f'repos/{REPO}/git/commits/{head}')['tree']['sha']
    tree=api(f'repos/{REPO}/git/trees',{'base_tree':base,'tree':[
        {'path':path,'type':'blob','mode':'100755' if path.endswith('.sh') else '100644','content':content}
        for path,content in sorted(paths.items())]})
    commit=api(f'repos/{REPO}/git/commits',{'message':'Bundle verified Crimson UI, Cipher search and Aether icon fixes in Sumi v6 r3',
                                        'tree':tree['sha'],'parents':[head]})['sha']
    api(f'repos/{REPO}/git/refs/heads/{BRANCH}',{'sha':commit,'force':False},'PATCH')
    save(marker,{'identity':identity,'commit':commit,'branch':BRANCH});return commit

def publish(files,prior,previous_launcher):
    if api('user')['login']!='huzaifahshahid71-ops':raise RuntimeError('GitHub CLI account differs from the repository owner')
    release=api(f'repos/{REPO}/releases/tags/{TAG}')
    if release.get('draft') or release.get('prerelease'):raise RuntimeError('Expected the established stable release')
    records={p.name:record(p) for p in files};marker=OUTPUT/'publication-assets.json'
    if marker.exists() and json.loads(marker.read_text())!=records:raise RuntimeError('Prepared upload bytes changed; retained')
    save(marker,records)
    canonical=OUTPUT/'ONLINE-INSTALL-v6.sh'
    write(canonical,(OUTPUT/'ONLINE-INSTALL-v6-r3.sh').read_bytes(),0o755)
    expected=record(canonical);current=assets(release['id'])
    if not (matches(current.get(canonical.name),prior) or matches(current.get(canonical.name),expected)):
        raise RuntimeError('Public one-command launcher differs from r2; retained')
    for path in files:
        if path.name in current and not matches(current[path.name],records[path.name]):
            raise RuntimeError('Existing r3 release asset differs; retained: '+path.name)
    commit=commit_source()
    for index,path in enumerate(files,1):
        current=assets(release['id'])
        if path.name not in current:
            if path.stat().st_size>=2*1024**3:raise RuntimeError('Release asset exceeds two GiB')
            print(f'Asset {index}/{len(files)}',flush=True);upload(path)
        if not matches(assets(release['id']).get(path.name),records[path.name]):raise RuntimeError('Uploaded digest not confirmed; rerun to resume')
        print(f'Verified {index}/{len(files)}: {path.name}',flush=True)
    # Rollback uses the canonical name; the unique r2 asset is never removed.
    rollback=OUTPUT/'rollback/ONLINE-INSTALL-v6.sh';write(rollback,previous_launcher.read_bytes(),0o755)
    switch_launcher(release['id'],expected,prior,rollback,canonical)
    fresh=api(f'repos/{REPO}/releases/{release["id"]}');body=fresh.get('body') or ''
    command='curl -fsSL '+BASE+canonical.name+' | bash'
    if MARKER not in body:
        addition=MARKER+'\n## Desktop fixes — r3\n\nThe one-command installer includes the nine omitted Crimson wallpaper-picker UI sources, Cipher Super+Space routed to its running shell, and Aether launch settings that resolve Papirus app icons. All three fixes were accepted in a fresh CachyOS VM. The r2 backend, SDDM and quiet GRUB repairs, MacTahoe icons, Lumina assets, 12 rices, 74 login cards, eight GRUB cards and fast 631-wallpaper downloader are retained.\n\n```sh\n'+command+'\n```\n\nFor the revised offline image, use `release-r3.json` and `assemble-v6-r3.py`. Source: `'+BRANCH+'` at `'+commit+'`. The newly assembled r3 image has passed payload/GUI/protocol checks; a new installation of that combined image has not yet been accepted. Earlier revision assets remain available.\n\n'
        api(f'repos/{REPO}/releases/{release["id"]}',{'body':addition+body},'PATCH')
    if not matches(assets(release['id']).get(canonical.name),expected):raise RuntimeError('Final public launcher verification failed')
    save(OUTPUT/'published.json',{'status':'published','revision':'desktop-r3','release':release['html_url'],
                               'assets':dict(records,**{canonical.name:expected}),'source_commit':commit,'command':command})
    print('PUBLISHED DESKTOP r3:',release['html_url'],flush=True)
    print('ONE COMMAND:',command,flush=True)
