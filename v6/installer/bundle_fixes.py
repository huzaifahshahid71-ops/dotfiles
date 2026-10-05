"""Carry the verified Eclipse and wallpaper fixes into the RC5 payload."""
import hashlib
import json
import os
from pathlib import Path
import tempfile

from eclipse_defaults import ECLIPSE_CONFIGS, render_defaults
from eclipse_launchers import PROFILE, read_inputs
from staging import HOME_TOKEN, portable

def replace(payload, rows, relative, data, mode=0o644, **flags):
    target = Path(payload)/'home'/relative
    target.parent.mkdir(parents=True,exist_ok=True)
    fd, temporary = tempfile.mkstemp(dir=target.parent,prefix='.bundle-')
    try:
        with os.fdopen(fd,'wb') as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(temporary,mode)
        os.replace(temporary,target)
    finally:
        Path(temporary).unlink(missing_ok=True)
    rows[relative] = dict(rows.get(relative,{}),path=relative,source='home/'+relative,
                          bytes=len(data),sha256=hashlib.sha256(data).hexdigest(),mode=mode,
                          template=HOME_TOKEN.encode() in data,**flags)

def apply(payload, rows, root):
    root = Path(root)
    settings = [p for p in ECLIPSE_CONFIGS if p in rows]
    if not settings:
        raise ValueError('Eclipse initial settings are missing from the candidate')
    for relative in settings:
        row = rows[relative]
        data = render_defaults((Path(payload)/row['source']).read_bytes())
        replace(payload,rows,relative,data,row.get('mode',0o644),init=True)
    addon = root/'build-support/eclipse-launcher'
    manifest = read_inputs(addon)
    for item in manifest['files']:
        relative = item['path']
        if relative in rows:
            continue
        data = (addon/'home'/relative).read_bytes()
        data, _ = portable(data,'/home/gamer')
        replace(payload,rows,relative,data,0o755)
    pin = json.loads((root/'wallpapers.json').read_text())
    if pin.get('tag')!='wallpapers-0aa529a78a8430dc' or pin.get('wallpaper_count')!=631:
        raise ValueError('The bundle must use the verified 631-image wallpaper release')
    required = [PROFILE+'runtime/settings.qml',PROFILE+'runtime/waffleSettings.qml',
                PROFILE+'runtime/scripts/inir',PROFILE+'runtime/scripts/inir-upstream',
                '.local/bin/refresh-rate-ctl',
                '.local/share/desktop-profiles/sayconlun/support/bin/rice-wallpaper',
                '.local/share/desktop-profiles/sayconlun/support/quickshell/lumina/assets/wallpapers/multi-rice-default.png']
    missing = [name for name in required if name not in rows]
    if missing:
        raise ValueError('Final bundle lacks verified runtime inputs: '+', '.join(missing))
    checks = {'wallpapers':631,'wallpaper_tag':pin['tag'],'eclipse_family':'waffle',
              'eclipse_launchers':len(manifest['files']),'required_runtime_files':len(required)}
    print('PASS: final candidate includes Eclipse settings launchers, Waffle layout, shared refresh helper and 631-image wallpaper pin',flush=True)
    return checks
