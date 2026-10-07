"""Only the three VM-accepted changes; retain all other payload records."""
import ast
import hashlib
import json
import zipfile
from pathlib import Path
from common import KIT, sha, safe, write, save
from desktop_defaults import desktop_defaults

TOKEN='@MULTI_RICE_HOME@'
PREFIX='env QT_QPA_PLATFORMTHEME=qt6ct QS_ICON_THEME=Papirus-Dark '
CRIMSON='.local/src/ambxst/modules/widgets/dashboard/wallpapers/'

def portable(data): return data.replace(b'/home/gamer',TOKEN.encode())

def assembler(source):
    marker='# Multi-Rice: preserve Crimson wallpaper-picker UI sources'
    if marker in source:compile(source,'assemble-candidate.py','exec');return source
    tree=ast.parse(source)
    functions=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='production_path']
    if len(functions)!=1 or [a.arg for a in functions[0].args.args]!=['relative']:
        raise RuntimeError('Unknown assembler retained')
    f=functions[0]
    if not any(isinstance(n,ast.Call) and isinstance(n.func,ast.Name) and n.func.id=='relative_path' for n in ast.walk(f)):
        raise RuntimeError('Assembler path validation differs')
    index=f.body[0].lineno-1
    if isinstance(f.body[0],ast.Expr) and isinstance(f.body[0].value,ast.Constant) and isinstance(f.body[0].value.value,str):index=f.body[0].end_lineno
    block='''    # Multi-Rice: preserve Crimson wallpaper-picker UI sources
    from pathlib import PurePosixPath as _CrimsonPath
    _crimson_path = _CrimsonPath(relative)
    if relative.startswith("modules/widgets/dashboard/wallpapers/") and (
        _crimson_path.suffix.lower() in {".qml", ".js", ".mjs", ".qsb", ".frag", ".vert", ".glsl", ".svg", ".png", ".webp"}
        or _crimson_path.name == "qmldir"
    ):
        relative = relative.replace("/wallpapers/", "/wallpaper-ui/", 1)
'''
    lines=source.splitlines(keepends=True);lines.insert(index,block);updated=''.join(lines)
    compile(updated,'assemble-candidate.py','exec');return updated

def collector(source):
    source=assembler(source)
    marker='# Multi-Rice: retain VM-accepted Aether and Cipher launch settings'
    if marker in source:compile(source,'assemble-candidate.py','exec');return source
    tree=ast.parse(source)
    classes=[n for n in tree.body if isinstance(n,ast.ClassDef) and n.name=='Layer']
    if len(classes)!=1:raise RuntimeError('Unknown assembler staging class retained')
    functions=[n for n in classes[0].body if isinstance(n,ast.FunctionDef) and n.name=='add']
    if len(functions)!=1:raise RuntimeError('Unknown assembler staging function retained')
    anchors=[n for n in ast.walk(functions[0]) if isinstance(n,ast.Assign) and isinstance(n.value,ast.Call)
             and isinstance(n.value.func,ast.Name) and n.value.func.id=='portable']
    if len(anchors)!=1:raise RuntimeError('Unknown portable staging declaration retained')
    line=anchors[0]
    lines=source.splitlines(keepends=True);indent=lines[line.lineno-1][:len(lines[line.lineno-1])-len(lines[line.lineno-1].lstrip())]
    lines.insert(line.end_lineno,indent+marker+'\n'+indent+'from desktop_defaults import desktop_defaults\n'+indent+'data = desktop_defaults(relative, data)\n')
    result=''.join(lines);compile(result,'assemble-candidate.py','exec');return result

def verified_changes():
    result=[]
    for name in ('cipher','aether'):
        manifest=json.loads((KIT/'verified'/f'{name}-manifest.json').read_text())
        for row in manifest['files']:
            path=row['path'];data=(KIT/'verified/home'/path).read_bytes()
            if sha(KIT/'verified/home'/path)!=row['sha256']:raise RuntimeError('Verified repair source differs')
            after=portable(data)
            if name=='aether':
                if not path.startswith('.local/share/desktop-profiles/caelestia/hypr/') or path.endswith('.lua') is False:
                    raise RuntimeError('Unexpected Aether path')
                before=portable(data.replace(PREFIX.encode(),b''))
                if hashlib.sha256(data.replace(PREFIX.encode(),b'')).hexdigest()!=row['before_sha256']:
                    raise RuntimeError('Aether delta differs')
            else:
                if path!='.local/share/desktop-profiles/clavis/native/niri/config.kdl':raise RuntimeError('Unexpected Cipher path')
                new=b'spawn "/usr/bin/qs" "-p" "/home/gamer/.local/share/desktop-profiles/clavis/support/quickshell/clavis" "ipc" "call" "spotlight" "toggle"'
                old=b'spawn "qs" "-c" "clavis" "ipc" "call" "spotlight" "toggle"'
                if data.count(new)!=1:raise RuntimeError('Cipher delta differs')
                original=data.replace(new,old)
                if hashlib.sha256(original).hexdigest()!=row['before_sha256']:raise RuntimeError('Cipher delta differs')
                before=portable(original)
            result.append((path,before,after,row['mode']))
    if len(result)!=3:raise RuntimeError('Expected the three accepted configuration files')
    return result

def crimson_sources(addon):
    """Read the actual repair's retained ZIP, or a verified extracted export."""
    manifest=json.loads((KIT/'verified/crimson-manifest.json').read_text())
    if len(manifest['files'])!=9:raise RuntimeError('Expected nine accepted Crimson UI sources')
    reviewed=[]
    archive=addon/'addon.zip';safe(archive)
    if archive.exists():
        expected=json.loads((KIT/'verified/crimson-archive.json').read_text())
        if not archive.is_file() or archive.stat().st_size>8*1024**2 or sha(archive)!=expected['sha256']:
            raise RuntimeError('Retained Crimson archive checksum differs')
        with zipfile.ZipFile(archive) as z:
            names=z.namelist();allowed={'manifest.json',*(r['source'] for r in manifest['files'])}
            if len(names)!=len(allowed) or set(names)!=allowed:
                raise RuntimeError('Retained Crimson archive contains duplicate, missing or unexpected members')
            info=z.getinfo('manifest.json')
            if info.file_size>100000 or json.loads(z.read(info))!=manifest:
                raise RuntimeError('Retained Crimson archive manifest differs')
            for row in manifest['files']:
                info=z.getinfo(row['source'])
                if info.is_dir() or (info.external_attr>>16)&0o170000==0o120000:
                    raise RuntimeError('Retained Crimson archive contains a symlink or directory')
                if info.file_size!=row['bytes'] or info.file_size>2*1024**2:
                    raise RuntimeError('Retained Crimson source size differs: '+row['path'])
                reviewed.append((row,z.read(info)))
    else:
        for row in manifest['files']:
            original=addon/row['source'];safe(original)
            if not original.is_file() or original.stat().st_size!=row['bytes']:
                raise RuntimeError('Retained Crimson source checksum differs (missing or size): '+row['path'])
            reviewed.append((row,original.read_bytes()))
    paths=set()
    for row,data in reviewed:
        path=row['path'];relative=Path(path)
        if (not path.startswith(CRIMSON) or '..' in relative.parts or relative.as_posix()!=path
            or path in paths or row['source']!='home/'+path):
            raise RuntimeError('Unreviewed Crimson source path')
        paths.add(path)
        if len(data)!=row['bytes'] or hashlib.sha256(data).hexdigest()!=row['sha256']:
            raise RuntimeError('Retained Crimson source checksum differs: '+path)
    return reviewed

def import_crimson(payload,rows,addon):
    manifest=json.loads((KIT/'verified/crimson-manifest.json').read_text())
    for name,digest in manifest['anchors'].items():
        relative='.local/src/ambxst/'+name
        if relative not in rows or sha(payload/rows[relative]['source'])!=digest:
            raise RuntimeError('Published Crimson source differs: '+name)
    changed=[];reviewed=crimson_sources(addon)
    for row,data in reviewed:
        path=row['path']
        if path in rows:
            target=payload/rows[path]['source']
            if target.read_bytes()!=data:raise RuntimeError('Existing Crimson UI source differs; retained: '+path)
    for row,data in reviewed:
        path=row['path'];source=row['source']
        if path not in rows:
            target=payload/source;write(target,data,row['mode'])
            rows[path]=dict(row);changed.append(path)
    return changed

def apply(payload,addon):
    plan=json.loads((payload/'plan.json').read_text());rows={r['path']:dict(r) for r in plan['user_files']}
    # Review every configuration before any payload write.
    reviewed=[]
    for path,before,after,mode in verified_changes():
        if path not in rows:raise RuntimeError('Configuration absent from published payload: '+path)
        record=rows[path];target=payload/record['source'];safe(target)
        current=target.read_bytes()
        if current not in (before,after):
            expected=json.loads((KIT/'verified/cipher-published-baseline.json').read_text())
            if path!=expected['path']:raise RuntimeError('Published configuration differs from the accepted repair baseline: '+path)
            after=cipher_binding(current)
            new=b'spawn "/usr/bin/qs" "-p" "@MULTI_RICE_HOME@/.local/share/desktop-profiles/clavis/support/quickshell/clavis" "ipc" "call" "spotlight" "toggle"'
            old=b'spawn "qs" "-c" "clavis" "ipc" "call" "spotlight" "toggle"'
            # The pinned published template may already use the correct route.
            original=current if sha(target)==expected['sha256'] else after.replace(new,old,1)
            if (hashlib.sha256(original).hexdigest()!=expected['sha256'] or len(original)!=expected['bytes']
                or record.get('mode')!=expected['mode'] or record.get('template')!=expected['template']):
                raise RuntimeError('Published configuration differs from the accepted repair baseline: '+path)
            # Patch just the known route in the checksum-verified published
            # template. Do not replace it with the installed VM's full config.
        reviewed.append((record,target,after,mode))
    changed=import_crimson(payload,rows,addon)
    for row,target,data,mode in reviewed:
        if target.read_bytes()!=data:write(target,data,mode);changed.append(row['path'])
        row.update(bytes=len(data),sha256=sha(target),mode=mode,template=TOKEN.encode() in data)
    plan['user_files']=list(rows.values());save(payload/'plan.json',plan)
    return plan,changed

def cipher_binding(data):
    import re
    text=data.decode()
    old='spawn "qs" "-c" "clavis" "ipc" "call" "spotlight" "toggle"'
    new='spawn "/usr/bin/qs" "-p" "@MULTI_RICE_HOME@/.local/share/desktop-profiles/clavis/support/quickshell/clavis" "ipc" "call" "spotlight" "toggle"'
    relevant=[line for line in text.splitlines() if re.match(r'^\s*(?:Mod|Super)\+Space\b',line)]
    if len(relevant)==1 and relevant[0].split('//',1)[0].count(new)==1 and text.count(new)==1:return data
    if len(relevant)!=1 or relevant[0].split('//',1)[0].count(old)!=1:
        raise RuntimeError('Published Cipher search binding differs from the accepted repair baseline; configuration retained')
    result=desktop_defaults('.local/share/desktop-profiles/clavis/native/niri/config.kdl',data)
    if result.decode().replace(new,old,1)!=text or result.count(new.encode())!=1:
        raise RuntimeError('Cipher transformation changed more than its search binding')
    return result
