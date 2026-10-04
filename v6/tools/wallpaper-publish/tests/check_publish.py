#!/usr/bin/env python3
"""Exercise local snapshots, public publication, digest failures and resume."""
import base64
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import zipfile

spec = importlib.util.spec_from_file_location('publisher', Path(__file__).resolve().parents[1]/'publish.py')
p = importlib.util.module_from_spec(spec)
spec.loader.exec_module(p)


class FakeGitHub:
    def __init__(self):
        self.repo = None
        self.readme = None
        self.release = None
        self.assets = {}
        self.commands = []
        self.login = p.REPO.split('/')[0]
        self.fail_after = None
        self.bad_digest = False

    def api(self, endpoint, payload=None, optional=False, pages=False, method=None):
        if endpoint == 'user':
            return {'login':self.login}
        if endpoint == 'repos/'+p.REPO:
            return self.repo
        if endpoint.endswith('/contents/README.md'):
            if payload:
                self.readme = base64.b64decode(payload['content']).decode()
            return {'sha':'fixture-sha','content':base64.b64encode(self.readme.encode()).decode()} if self.readme else None
        if '/releases/tags/' in endpoint:
            return self.release
        if endpoint.endswith('/assets?per_page=100'):
            # More than one page exercises the pagination/flattening path.
            values = list(self.assets.values())
            return [values[:1],values[1:]]
        if method == 'DELETE':
            ident = int(endpoint.rsplit('/',1)[1])
            self.assets = {k:v for k,v in self.assets.items() if v['id']!=ident}
            return None
        raise AssertionError(endpoint)

    def command(self, args, data=None, optional=False, write=False):
        self.commands.append(args)
        if args[:2] == ['repo','create']:
            self.repo = {'private':False,'archived':False,'default_branch':'main'}
            self.readme = '# New repo\n'
        elif args[:2] == ['release','create']:
            notes = Path(args[args.index('--notes-file')+1]).read_text()
            self.release = {'id':1,'draft':True,'body':notes}
        elif args[:2] == ['release','upload']:
            if self.fail_after is not None and len(self.assets)>=self.fail_after:
                raise RuntimeError('injected interrupted upload')
            path = Path(args[3])
            self.assets[path.name] = {'id':len(self.assets)+1,'name':path.name,'size':path.stat().st_size,
                                     'digest':'sha256:'+('0'*64 if self.bad_digest else p.digest(path)), 'state':'uploaded'}
        elif args[:2] == ['release','edit']:
            assert '--draft=false' in args
            self.release['draft'] = False
        else:
            raise AssertionError(args)
        return ''


with tempfile.TemporaryDirectory() as temporary:
    root = Path(temporary)
    source = root/'Wallpapers'
    (source/'nested').mkdir(parents=True)
    (source/'same.png').write_bytes(b'\x89PNG\r\n\x1a\nfirst-image-fixture')
    (source/'nested/same.png').write_bytes(b'\x89PNG\r\n\x1a\nsecond-image-fixture')
    (source/'notes.txt').write_text('non-image data should stay private')
    (source/'linked.jpg').symlink_to(source/'same.png')
    (source/'.hidden.jpg').write_bytes(b'private hidden file')
    before = {str(f.relative_to(source)):f.read_bytes() for f in source.rglob('*') if f.is_file() and not f.is_symlink()}
    folder, manifest, expected = p.prepare(source, root/'cache')
    assert len(manifest['wallpapers']) == 2 and len(expected)==5
    assert len({e['asset'] for e in manifest['wallpapers']}) == 2
    with zipfile.ZipFile(folder/'assets/multi-rice-wallpapers-full.zip') as packed:
        assert packed.namelist() == ['Wallpapers/nested/same.png','Wallpapers/same.png']
        assert packed.testzip() is None
        for name in packed.namelist():
            assert packed.read(name) == (source/name.removeprefix('Wallpapers/')).read_bytes()
    folder2, manifest2, expected2 = p.prepare(source,root/'cache')
    assert (folder2,manifest2,expected2)==(folder,manifest,expected)
    print('PASS: source preservation, nested names, hidden/non-image/symlink exclusions, deterministic full ZIP and cache reuse')

    gh = FakeGitHub()
    gh.fail_after = 2
    try:
        p.publish(gh,folder,manifest,expected)
        raise AssertionError('Expected interruption')
    except RuntimeError as error:
        assert 'interrupted' in str(error)
    assert gh.release['draft'] and len(gh.assets)==2
    gh.fail_after = None
    p.publish(gh,folder,manifest,expected)
    assert not gh.release['draft'] and len(gh.assets)==len(expected)
    assert sum(c[:2]==['release','upload'] for c in gh.commands)==len(expected)+1
    assert p.MARKER in gh.readme and manifest['packs']['full']['url'] in gh.readme
    count = len(gh.commands)
    p.publish(gh,folder,manifest,expected)
    assert len(gh.commands)==count
    print('PASS: draft release, per-asset size/digest checks, interrupted-upload continuation, index and completed-release reuse')

    for scenario in ('wrong-account','private','unmanaged-readme','bad-digest','foreign-release'):
        test = FakeGitHub()
        if scenario=='wrong-account': test.login='someone-else'
        if scenario=='private': test.repo={'private':True,'default_branch':'main'}
        if scenario=='unmanaged-readme':
            test.repo={'private':False,'default_branch':'main'};test.readme='Handwritten content'
        if scenario=='bad-digest': test.bad_digest=True
        if scenario=='foreign-release':
            test.repo={'private':False,'default_branch':'main'};test.readme=p.MARKER
            test.release={'id':3,'draft':True,'body':'unrelated release'}
        try:
            p.publish(test,folder,manifest,expected)
            raise AssertionError('Expected rejection: '+scenario)
        except RuntimeError:
            pass
        assert not any(c[:2]==['release','edit'] for c in test.commands)
    print('PASS: wrong account, private/unmanaged repository, foreign release and corrupt remote digest cannot publish')
    assert before=={str(f.relative_to(source)):f.read_bytes() for f in source.rglob('*') if f.is_file() and not f.is_symlink()}
print('PASS: wallpaper publisher checks (GitHub operations mocked; live upload runs on the host)')
