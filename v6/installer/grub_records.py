"""Keep existing Evangelion ownership records aligned with managed file updates."""
import json
import os
from pathlib import Path
import shutil
from core import SetupError, no_symlink_parents, sha256
from maintenance import fingerprint, copy_object

MANAGER='var/lib/evangelion-grub/manager.json'
STATE='var/lib/evangelion-grub/state.json'
PARSER='var/lib/evangelion-grub/boot/boot-console.awk'
LIBRARY='usr/local/share/evangelion/bin/boot-console.awk'
SCOPE={MANAGER,STATE,PARSER}


def destination(root,relative):
    if relative not in SCOPE:raise SetupError('GRUB metadata recovery scope differs')
    path=root/relative;no_symlink_parents(path)
    if path.exists() and not path.is_file():raise SetupError('Existing GRUB metadata object retained')
    if root==Path('/'):
        for parent in (path,*path.parents):
            if parent.exists() and (parent.stat().st_uid!=0 or parent.stat().st_mode&0o022):
                raise SetupError('GRUB metadata ownership differs: '+str(parent))
    return path


def prepare(root,state,files):
    changes={};rows={r['path']:(i,r) for i,r in enumerate(files)}
    manager=destination(root,MANAGER)
    if manager.exists():
        value=json.loads(manager.read_text());owned=value.get('files')
        if not isinstance(owned,dict):raise SetupError('Evangelion manager ownership differs')
        updated=False
        for relative,(_,record) in rows.items():
            if relative not in owned or record['before']==record['installed']:continue
            if record['before'].get('kind')!='file' or owned[relative]!=record['before']['sha256']:
                raise SetupError('Edited Evangelion manager file retained: '+relative)
            owned[relative]=record['installed']['sha256'];updated=True
        if updated:changes[MANAGER]=(json.dumps(value,indent=2)+'\n').encode()
    parser=destination(root,PARSER)
    if parser.exists() and LIBRARY in rows:
        index,_=rows[LIBRARY];data=(state/'staged'/f'{index:04d}').read_bytes()
        if data!=parser.read_bytes():
            installed=destination(root,STATE);value=json.loads(installed.read_text());owned=value.get('boot_files')
            if not isinstance(owned,dict) or owned.get(PARSER)!=sha256(parser):
                raise SetupError('Edited Evangelion runtime parser retained')
            import hashlib
            owned[PARSER]=hashlib.sha256(data).hexdigest()
            changes[PARSER]=data;changes[STATE]=(json.dumps(value,indent=2)+'\n').encode()
    if not changes:return None
    result={'schema':1,'files':[]};base=state/'grub-records';(base/'before').mkdir(parents=True);(base/'staged').mkdir()
    for index,(relative,data) in enumerate(changes.items()):
        path=destination(root,relative);before=fingerprint(path);copy_object(path,base/'before'/str(index))
        staged=base/'staged'/str(index);staged.write_bytes(data);staged.chmod(before['mode'])
        result['files'].append({'path':relative,'before':before,'installed':fingerprint(staged),'index':index})
    return result


def checked(record):
    if record.get('schema')!=1:raise SetupError('GRUB metadata receipt differs')
    for index,row in enumerate(record['files']):
        if row.get('index')!=index or row['path'] not in SCOPE or any(row[p].get('kind')!='file' for p in ('before','installed')):
            raise SetupError('GRUB metadata receipt scope differs')


def conflicts(root,state,record):
    if not record:return []
    checked(record);result=[]
    for row in record['files']:
        if fingerprint(destination(root,row['path']))!=row['installed']:result.append(row['path'])
        if fingerprint(state/'grub-records/before'/str(row['index']))!=row['before']:
            raise SetupError('GRUB metadata backup differs')
    return result


def change(root,state,record,phase,persist=lambda:None,partial=False):
    if not record:return
    checked(record)
    for row in record['files']:
        if partial and not row.get('committed'):continue
        path=destination(root,row['path']);current=fingerprint(path)
        if current not in (row['before'],row['installed']):raise SetupError('Edited GRUB metadata retained: '+row['path'])
        source=state/'grub-records'/('before' if phase=='before' else 'staged')/str(row['index'])
        if phase=='installed' and not source.exists():
            # Restore rollback retains the installed metadata inside the
            # protected recovery directory, even after staging was discarded.
            source=state/'grub-records/installed'/str(row['index'])
        if fingerprint(source)!=row[phase]:raise SetupError('GRUB metadata recovery bytes differ')
        retained=state/'grub-records/installed';retained.mkdir(exist_ok=True)
        if phase=='installed' and not (retained/str(row['index'])).exists():copy_object(source,retained/str(row['index']))
        temporary=path.with_name(path.name+'.sumi-records-new');no_symlink_parents(temporary)
        if temporary.exists():raise SetupError('GRUB metadata temporary preserved')
        shutil.copy2(source,temporary);os.replace(temporary,path);row['committed']=phase=='installed';persist()
