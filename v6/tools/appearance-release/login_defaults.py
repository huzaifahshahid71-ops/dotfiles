"""Receipt-backed SDDM selection for next boot; never restarts a service."""
import os
from pathlib import Path
import stat
import uuid
from core import SetupError, no_symlink_parents
from maintenance import fingerprint

ALIAS='etc/systemd/system/display-manager.service'
TARGET='/usr/lib/systemd/system/sddm.service'


def destination(root,relative):
    path=Path(relative)
    allowed=(relative==ALIAS or len(path.parts)==5 and path.parts[:3]==('etc','systemd','system')
             and path.parts[3].endswith(('.wants','.requires')) and path.name=='greetd.service')
    if path.is_absolute() or '..' in path.parts or not allowed:raise SetupError('Login recovery path differs')
    result=root/path;no_symlink_parents(result.parent);return result


def prepare(root):
    unit=root/TARGET.lstrip('/');no_symlink_parents(unit)
    if (not unit.is_file() or unit.stat().st_mode&0o022 or
        root==Path('/') and unit.stat().st_uid!=0):raise SetupError('Installed SDDM service is missing or writable')
    alias=destination(root,ALIAS);before=fingerprint(alias)
    if before['kind'] not in ('absent','symlink'):raise SetupError('Existing login manager file retained')
    if before['kind']=='symlink' and Path(before['target']).name not in ('greetd.service','sddm.service'):
        raise SetupError('This installer supports next-boot selection from greetd or SDDM; another manager was retained')
    rows=[{'path':ALIAS,'before':before,'installed':{'kind':'symlink','target':TARGET}}]
    base=root/'etc/systemd/system'
    for pattern in ('*.wants/greetd.service','*.requires/greetd.service'):
        for path in sorted(base.glob(pattern)):
            destination(root,path.relative_to(root).as_posix());state=fingerprint(path)
            if state['kind']!='symlink' or Path(state['target']).name!='greetd.service':
                raise SetupError('Custom greetd enablement retained: '+str(path))
            rows.append({'path':path.relative_to(root).as_posix(),'before':state,'installed':{'kind':'absent'}})
    return {'schema':1,'files':rows}


def checked(record):
    if not isinstance(record,dict) or record.get('schema')!=1:raise SetupError('Login recovery record differs')
    paths=[r['path'] for r in record['files']]
    if len(paths)!=len(set(paths)) or ALIAS not in paths:raise SetupError('Login recovery scope differs')
    for row in record['files']:
        for phase in ('before','installed'):
            value=row[phase]
            if value['kind']=='symlink':
                if Path(value['target']).name not in ('greetd.service','sddm.service'):
                    raise SetupError('Login recovery target differs')
            elif value['kind']!='absent':raise SetupError('Login recovery object differs')


def conflicts(root,record,phase='installed',partial=False):
    if not record:return []
    checked(record);result=[]
    for row in record['files']:
        if partial and not row.get('committed'):continue
        if fingerprint(destination(root,row['path']))!=row[phase]:result.append(row['path'])
    return result


def change(root,record,phase,persist=lambda:None,partial=False):
    checked(record)
    for row in record['files']:
        if partial and not row.get('committed'):continue
        path=destination(root,row['path']);source='before' if phase=='installed' else 'installed'
        current=fingerprint(path)
        if current!=row[source] and current!=row[phase]:raise SetupError('Edited login route retained: '+row['path'])
        path.parent.mkdir(parents=True,exist_ok=True)
        temporary=path.with_name('.'+path.name+'-'+uuid.uuid4().hex)
        try:
            if row[phase]['kind']=='absent':path.unlink(missing_ok=True)
            else:
                temporary.symlink_to(row[phase]['target']);os.replace(temporary,path)
        finally:temporary.unlink(missing_ok=True)
        row['committed']=phase=='installed';persist()
