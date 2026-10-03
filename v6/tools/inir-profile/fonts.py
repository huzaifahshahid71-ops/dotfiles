"""Verified, process-private font assets; never install into the user's font path."""
import hashlib
import json
from pathlib import Path
import urllib.request


def prepare_font(package, runtime):
    package=Path(package)
    manifest=json.loads((package/'font-manifest.json').read_text())
    target=Path(runtime)/'assets/fonts/roboto-flex'
    target.mkdir(parents=True,exist_ok=True)
    files=manifest['files']
    if {item['name'] for item in files}!={'RobotoFlex.ttf','OFL.txt'} or len(files)!=2:
        raise RuntimeError('Unexpected private font manifest')
    for item in files:
        bundled=package/'assets/fonts/roboto-flex'/item['name']
        if bundled.is_file():
            data=bundled.read_bytes()
        else:
            # ZIP releases include these files; a source checkout uses the same pin.
            print('Fetching pinned private font asset: '+item['name'],flush=True)
            with urllib.request.urlopen(item['url'],timeout=45) as response:
                data=response.read(item['size']+1)
        if len(data)!=item['size'] or hashlib.sha256(data).hexdigest()!=item['sha256']:
            raise RuntimeError('Private font checksum differs: '+item['name'])
        (target/item['name']).write_bytes(data)
    (target/'source-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
