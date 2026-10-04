#!/usr/bin/env python3
"""Publish a local wallpaper collection as individual assets and a full ZIP."""
import argparse
import base64
import hashlib
import html
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time
from urllib.parse import quote
import zipfile

REPO = 'huzaifahshahid71-ops/multi-rice-wallpapers'
MARKER = '<!-- multi-rice-wallpapers:managed -->'
EXTENSIONS = {'.jpg', '.jpeg', '.png', '.webp', '.avif', '.gif', '.bmp',
              '.tif', '.tiff', '.jxl', '.heic', '.heif', '.svg'}
LIMIT = 2 * 1024**3


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def save(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix='.publish-', dir=path.parent)
    try:
        with os.fdopen(fd, 'wb') as stream:
            stream.write(data)
        os.replace(temporary, path)
    finally:
        Path(temporary).unlink(missing_ok=True)


def inventory(source):
    if source.is_symlink() or not source.is_dir():
        raise RuntimeError('Choose a regular wallpaper directory, not a symlink')
    entries, skipped = [], 0
    for directory, folders, files in os.walk(source, followlinks=False):
        folders[:] = sorted(f for f in folders if not f.startswith('.') and not (Path(directory)/f).is_symlink())
        for name in sorted(files):
            path = Path(directory)/name
            if name.startswith('.') or path.is_symlink() or path.suffix.lower() not in EXTENSIONS or not path.is_file():
                skipped += 1
                continue
            original_stat = path.stat()
            size = original_stat.st_size
            if not 0 < size < LIMIT:
                raise RuntimeError('Empty image or release asset too large: '+str(path))
            relative = path.relative_to(source).as_posix()
            if any(ord(c) < 32 for c in relative):
                raise RuntimeError('Unsupported control character in filename')
            checksum = digest(path)
            current_stat = path.stat()
            if (original_stat.st_size, original_stat.st_mtime_ns, original_stat.st_ino, original_stat.st_dev) != (current_stat.st_size, current_stat.st_mtime_ns, current_stat.st_ino, current_stat.st_dev):
                raise RuntimeError('Source changed during inventory: '+relative)
            ident = hashlib.sha256((relative+'\0'+checksum).encode()).hexdigest()[:20]
            stem = re.sub(r'[^a-zA-Z0-9_-]+', '-', path.stem).strip('-')[:55] or 'wallpaper'
            entries.append({'path': relative, 'bytes': size, 'sha256': checksum,
                            'id': ident, 'asset': ident+'-'+stem+path.suffix.lower()})
    entries.sort(key=lambda e: e['path'])
    if not entries:
        raise RuntimeError('No supported image files found')
    if len(entries)+3 > 1000:
        raise RuntimeError('Collection exceeds one release asset count limit')
    if len({e['asset'] for e in entries}) != len(entries):
        raise RuntimeError('Asset filename collision')
    return entries, skipped


def prepare(source, cache):
    if source.resolve() == cache.resolve() or source.resolve() in cache.resolve().parents or cache.resolve() in source.resolve().parents:
        raise RuntimeError('Source and preparation cache must be separate directories')
    entries, skipped = inventory(source)
    snapshot = hashlib.sha256(json.dumps(entries, sort_keys=True, ensure_ascii=False).encode()).hexdigest()
    tag = 'wallpapers-'+snapshot[:16]
    folder = cache/tag
    if folder.is_symlink() or cache.is_symlink():
        raise RuntimeError('Cache directory must not be a symlink')
    folder.mkdir(parents=True, exist_ok=True, mode=0o700)
    total = sum(e['bytes'] for e in entries)
    if shutil.disk_usage(folder).free < total*2 + 64*1024**2:
        # Already-complete staging can still be reused with little free space.
        if not (folder/'prepared.json').is_file():
            raise RuntimeError(f'Need about {total*2/1024**3:.2f} GiB free for image copies and ZIP')
    print(f'Collection: {len(entries)} images, {total/1024**3:.2f} GiB; {skipped} other/hidden/symlink files skipped', flush=True)
    print('Preparation: '+str(folder), flush=True)
    assets = folder/'assets'
    if assets.is_symlink():
        raise RuntimeError('Unexpected asset-directory symlink')
    assets.mkdir(exist_ok=True)
    for i, entry in enumerate(entries, 1):
        destination = assets/entry['asset']
        if destination.is_symlink():
            raise RuntimeError('Unexpected staged symlink')
        if not destination.is_file() or digest(destination) != entry['sha256']:
            src = source/entry['path']
            fd, temporary = tempfile.mkstemp(prefix='.image-', dir=assets)
            os.close(fd)
            try:
                shutil.copyfile(src, temporary)
                if digest(Path(temporary)) != entry['sha256']:
                    raise RuntimeError('Source changed during preparation: '+entry['path'])
                os.replace(temporary, destination)
            finally:
                Path(temporary).unlink(missing_ok=True)
        if i == 1 or i % 25 == 0 or i == len(entries):
            print(f'Staged {i}/{len(entries)} images', flush=True)
    archive = assets/'multi-rice-wallpapers-full.zip'
    receipt = folder/'prepared.json'
    previous = json.loads(receipt.read_text()) if receipt.is_file() else {}
    if not archive.is_file() or previous.get('archive_sha256') != digest(archive):
        fd, temporary = tempfile.mkstemp(prefix='.pack-', dir=assets)
        os.close(fd)
        try:
            with zipfile.ZipFile(temporary, 'w', compression=zipfile.ZIP_STORED, allowZip64=True) as packed:
                for entry in entries:
                    info = zipfile.ZipInfo('Wallpapers/'+entry['path'], date_time=(1980,1,1,0,0,0))
                    info.external_attr = 0o100644 << 16
                    with (assets/entry['asset']).open('rb') as src, packed.open(info, 'w', force_zip64=True) as dst:
                        shutil.copyfileobj(src, dst, length=1024**2)
            if Path(temporary).stat().st_size >= LIMIT:
                raise RuntimeError('Full ZIP exceeds the release limit; split-pack support is required')
            os.replace(temporary, archive)
        finally:
            Path(temporary).unlink(missing_ok=True)
    base = f'https://github.com/{REPO}/releases/download/{tag}/'
    for entry in entries:
        entry['url'] = base+quote(entry['asset'], safe='')
        entry['collections'] = ['full']
    manifest = {'schema': 1, 'repository': REPO, 'tag': tag, 'snapshot_sha256': snapshot,
                'default_destination': 'Pictures/Wallpapers', 'wallpapers': entries,
                'packs': {'full': {'asset': archive.name, 'bytes': archive.stat().st_size,
                         'sha256': digest(archive), 'url': base+archive.name}}}
    save(assets/'wallpapers-manifest.json', (json.dumps(manifest, ensure_ascii=False, indent=2)+'\n').encode())
    names = [e['asset'] for e in entries]+[archive.name, 'wallpapers-manifest.json']
    save(assets/'SHA256SUMS', ''.join(digest(assets/name)+'  '+name+'\n' for name in names).encode())
    names.append('SHA256SUMS')
    expected = {name: {'bytes': (assets/name).stat().st_size, 'sha256': digest(assets/name)} for name in names}
    save(receipt, json.dumps({'snapshot': snapshot, 'archive_sha256': manifest['packs']['full']['sha256'], 'assets': expected}, indent=2).encode())
    return folder, manifest, expected


class GitHub:
    def __init__(self):
        if not shutil.which('gh'):
            raise RuntimeError('Install GitHub CLI: sudo pacman -S --needed github-cli')
        self.last_write = 0

    def command(self, arguments, data=None, optional=False, write=False):
        if write:
            time.sleep(max(0, 1.1-(time.monotonic()-self.last_write)))
            self.last_write = time.monotonic()
        env = dict(os.environ, GH_HOST='github.com', GH_PROMPT_DISABLED='1')
        result = subprocess.run(['gh', *arguments], input=data, env=env,
                                capture_output=True, text=True, timeout=3600)
        if result.returncode:
            if optional and ('HTTP 404' in result.stderr or '(404)' in result.stderr):
                return None
            context = 'api '+arguments[3] if arguments[0] == 'api' else ' '.join(arguments[:2])
            raise RuntimeError('GitHub '+context+': '+(result.stderr.strip() or 'command failed'))
        return result.stdout

    def api(self, endpoint, payload=None, optional=False, pages=False, method=None):
        args = ['api', '--hostname', 'github.com', endpoint]
        if pages:
            args += ['--paginate', '--slurp']
        if payload is not None:
            args += ['--method', method or 'PUT', '--input', '-']
        elif method:
            args += ['--method', method]
        result = self.command(args, json.dumps(payload) if payload is not None else None,
                              optional, write=payload is not None or method == 'DELETE')
        return json.loads(result) if result else None


def readme(manifest):
    base = f'https://github.com/{REPO}/releases/download/{manifest["tag"]}/'
    lines = [MARKER, '# Huzaifah Multi-Rice Wallpapers', '',
             f'{len(manifest["wallpapers"])} images. Download individually below or get the complete collection.', '',
             f'[Download all wallpapers]({base}multi-rice-wallpapers-full.zip) · [Manifest]({base}wallpapers-manifest.json) · [SHA-256 checksums]({base}SHA256SUMS)', '',
             'The ZIP contains a `Wallpapers/` folder. The v6 installer uses `~/Pictures/Wallpapers`.', '',
             'Images retain their original authors’ rights. No blanket license is granted over the collection.', '',
             '| Wallpaper | Size | Download |', '| --- | --- | --- |']
    for entry in manifest['wallpapers']:
        title = '<code>'+html.escape(entry['path']).replace('|','&#124;').replace('\n',' ')+'</code>'
        lines.append(f'| {title} | {entry["bytes"]/1024**2:.2f} MiB | [Image]({entry["url"]}) |')
    return '\n'.join(lines)+'\n'


def set_readme(gh, text, new=False):
    endpoint = f'repos/{REPO}/contents/README.md'
    current = gh.api(endpoint, optional=True)
    if current:
        old = base64.b64decode(current['content']).decode()
        if not new and MARKER not in old:
            raise RuntimeError('Existing README is not owned by this publisher; preserved')
        if old == text:
            return
    payload = {'message': 'Update wallpaper download index', 'content': base64.b64encode(text.encode()).decode()}
    if current:
        payload['sha'] = current['sha']
    gh.api(endpoint, payload)


def publish(gh, folder, manifest, expected):
    owner = REPO.split('/')[0]
    login = gh.api('user')['login']
    if login.lower() != owner.lower():
        raise RuntimeError(f'GitHub CLI is signed in as {login}; expected {owner}. Use gh auth switch or gh auth login')
    repository = gh.api(f'repos/{REPO}', optional=True)
    new = repository is None
    if new:
        gh.command(['repo','create',REPO,'--public','--add-readme','--description',
                    'Wallpapers for Huzaifah Multi-Rice — individual images and complete packs'], write=True)
        repository = gh.api(f'repos/{REPO}')
        set_readme(gh, MARKER+'\n# Huzaifah Multi-Rice Wallpapers\n\nThe first collection is being uploaded.\n', new=True)
    if repository.get('private') or repository.get('archived'):
        raise RuntimeError('Expected an active public wallpaper repository; its settings were preserved')
    current = gh.api(f'repos/{REPO}/contents/README.md', optional=True)
    if current and MARKER not in base64.b64decode(current['content']).decode():
        raise RuntimeError('Existing repository is not managed by this publisher')
    tag = manifest['tag']
    marker = MARKER+' snapshot='+manifest['snapshot_sha256']
    def find_release():
        # The tag endpoint returns published releases, not an untagged draft.
        # Authenticated release listing includes drafts, identified by tag_name.
        pages = gh.api(f'repos/{REPO}/releases?per_page=100', pages=True)
        matches = [item for page in pages for item in page if item.get('tag_name') == tag]
        if len(matches) > 1:
            raise RuntimeError('Repeated collection release tags; preserved')
        return matches[0] if matches else None
    release = find_release()
    if release is None:
        notes = folder/'release-notes.md'
        save(notes, (marker+'\n\nIndividual wallpapers, the full ZIP, installer manifest and SHA-256 checksums.\n').encode())
        gh.command(['release','create',tag,'--repo',REPO,'--draft','--title',
                    f'Multi-Rice Wallpapers — {len(manifest["wallpapers"])} images',
                    '--target',repository['default_branch'],'--notes-file',str(notes)], write=True)
        release = find_release()
        if release is None:
            raise RuntimeError('Created draft is not yet visible in the release list; rerun to continue')
    print(f'Release: {tag} (ID {release["id"]}, '+('draft' if release['draft'] else 'published')+')', flush=True)
    if marker not in (release.get('body') or ''):
        raise RuntimeError('Existing release is not owned by this collection; preserved')
    def asset_list():
        pages = gh.api(f'repos/{REPO}/releases/{release["id"]}/assets?per_page=100', pages=True)
        items = [asset for page in pages for asset in page]
        if len({asset['name'] for asset in items}) != len(items):
            raise RuntimeError('Duplicate remote assets require review')
        return {asset['name']: asset for asset in items}
    remote = asset_list()
    if set(remote)-set(expected):
        raise RuntimeError('Unexpected assets exist in this managed release; preserved')
    for i, (name, info) in enumerate(expected.items(), 1):
        asset = remote.get(name)
        if asset and asset.get('state') == 'starter' and asset.get('size') == 0 and release['draft']:
            gh.api(f'repos/{REPO}/releases/assets/{asset["id"]}', method='DELETE')
            asset = None
        reused = asset is not None
        if asset is None:
            if not release['draft']:
                raise RuntimeError('Published collection is incomplete; no assets overwritten')
            print(f'Uploading {i}/{len(expected)}: {name} ({info["bytes"]/1024**2:.2f} MiB)', flush=True)
            gh.command(['release','upload',tag,str(folder/'assets'/name),'--repo',REPO], write=True)
            remote = asset_list()
            asset = remote.get(name)
        if not asset or asset.get('size') != info['bytes'] or asset.get('digest') != 'sha256:'+info['sha256'] or asset.get('state') != 'uploaded':
            raise RuntimeError('Remote size/SHA-256 verification failed for '+name+'; release remains uncompleted. Rerun to retry or report the error.')
        print(f'Verified {i}/{len(expected)}'+(' (already uploaded)' if reused else ''), flush=True)
    if release['draft']:
        gh.command(['release','edit',tag,'--repo',REPO,'--draft=false'], write=True)
    set_readme(gh, readme(manifest))
    save(folder/'PUBLISHED.json', json.dumps({'repository':REPO,'tag':tag,'assets':len(expected)},indent=2).encode())
    print('PUBLISHED: https://github.com/'+REPO, flush=True)
    print('Collection: https://github.com/'+REPO+'/releases/tag/'+tag, flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=Path.home()/'Pictures/Wallpapers')
    parser.add_argument('--cache', type=Path, default=Path.home()/'.local/share/multi-rice-wallpaper-publish')
    parser.add_argument('--upload', action='store_true', help='Create the public wallpaper repository and publish the collection')
    args = parser.parse_args()
    print('Wallpaper publisher 1.1 — draft-aware resume', flush=True)
    if os.geteuid() == 0:
        raise RuntimeError('Run as your desktop user, without sudo')
    gh = GitHub() if args.upload else None
    if gh:
        try:
            login = gh.api('user')['login']
        except RuntimeError:
            raise RuntimeError('GitHub sign-in unavailable. Run gh auth login --hostname github.com --git-protocol https --web, then retry')
        if login.lower() != REPO.split('/')[0].lower():
            raise RuntimeError('Wrong GitHub account: '+login)
    folder, manifest, expected = prepare(args.source.absolute(), args.cache.absolute())
    if gh:
        publish(gh, folder, manifest, expected)
    else:
        print('PREPARED: rerun with --upload to publish. Nothing was uploaded.')


if __name__ == '__main__':
    try:
        main()
    except (OSError, RuntimeError, ValueError, subprocess.SubprocessError, KeyboardInterrupt) as error:
        raise SystemExit('Wallpaper publication stopped: '+str(error)+'\nPrepared files and completed uploads are retained. Rerun the same command to continue.')
