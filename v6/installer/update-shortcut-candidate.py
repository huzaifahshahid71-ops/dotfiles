#!/usr/bin/env python3
"""Update shortcut labels in an assembled candidate without copying packages."""
import argparse,hashlib,io,json,os,tempfile,zipfile
from pathlib import Path
from core import SetupError,no_symlink_parents

ROOT=Path(__file__).resolve().parent
TARGET='.local/share/multi-rice-shortcuts/catalog.py'

def digest(data):return hashlib.sha256(data).hexdigest()

def atomic(path,data,mode=0o644):
    fd,name=tempfile.mkstemp(dir=path.parent,prefix='.'+path.name+'-')
    try:
        with os.fdopen(fd,'wb') as stream:stream.write(data);stream.flush();os.fsync(stream.fileno())
        os.chmod(name,mode);os.replace(name,path)
    finally:Path(name).unlink(missing_ok=True)

def update(candidate,toolkit,report_zip):
    planpath=candidate/'payload/plan.json';reportpath=candidate.parent/'assembly-report.json'
    for path in (candidate,planpath,reportpath,report_zip):no_symlink_parents(path)
    planbytes=planpath.read_bytes();reportbytes=reportpath.read_bytes()
    plan=json.loads(planbytes);report=json.loads(reportbytes)
    if plan.get('schema')!=1 or plan.get('version')!='6.0.0' or report.get('status')!='candidate-appdir':raise SetupError('Expected assembled v6 candidate')
    if report.get('plan_sha256')!=digest(planbytes):raise SetupError('Candidate plan changed; preserved')
    matches=[row for row in plan['user_files'] if row['path']==TARGET]
    if len(matches)!=1 or matches[0]['source']!='home/'+TARGET:raise SetupError('Expected one shared shortcut catalog')
    row=matches[0];target=candidate/'payload'/row['source'];no_symlink_parents(target)
    old=target.read_bytes()
    if digest(old)!=row['sha256'] or len(old)!=row['bytes']:raise SetupError('Candidate shortcut source changed; preserved')
    manifest=json.loads((toolkit/'payload-manifest.json').read_text());new=(toolkit/'catalog.py').read_bytes()
    if digest(new)!=manifest['files']['catalog.py']:raise SetupError('Shortcut update checksum differs')
    if old==new:print('ALREADY UPDATED: assembled candidate shortcut labels');return
    if report_zip.exists():
        with zipfile.ZipFile(report_zip) as archive:
            previous=json.loads(archive.read('assembly-report.json'))
        if previous.get('plan_sha256')!=report['plan_sha256']:raise SetupError('Downloads report describes a different candidate; preserved')
    row.update(sha256=digest(new),bytes=len(new))
    newplan=(json.dumps(plan,indent=2)+'\n').encode()
    report['plan_sha256']=digest(newplan)
    report.setdefault('release_features',{})['shortcut_labels']='Real source actions override generic Lua descriptions'
    newreport=(json.dumps(report,indent=2)+'\n').encode()
    zipped=io.BytesIO()
    with zipfile.ZipFile(zipped,'w',zipfile.ZIP_DEFLATED) as archive:archive.writestr('assembly-report.json',newreport)
    changes={target:new,planpath:newplan,reportpath:newreport,report_zip:zipped.getvalue()}
    before={path:(path.read_bytes(),path.stat().st_mode & 0o777) if path.exists() else None for path in changes}
    if before[target][0]!=old or before[planpath][0]!=planbytes or before[reportpath][0]!=reportbytes:raise SetupError('Candidate changed during preparation; preserved')
    backup=Path(tempfile.mkdtemp(prefix='shortcut-labels-backup-',dir=candidate.parent))
    for index,(path,saved) in enumerate(before.items()):
        if saved is not None:(backup/str(index)).write_bytes(saved[0])
    (backup/'receipt.json').write_text(json.dumps([{'path':str(path),'backup':str(i) if before[path] is not None else None} for i,path in enumerate(changes)],indent=2)+'\n')
    done=[]
    try:
        for path,data in changes.items():atomic(path,data,before[path][1] if before[path] is not None else 0o644);done.append(path)
    except BaseException:
        for path in reversed(done):
            if before[path] is None:path.unlink(missing_ok=True)
            else:atomic(path,*before[path])
        raise
    print('UPDATED: candidate shortcut labels; package archives retained')
    print('Backup:',backup);print('Updated assembly report:',report_zip)

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--candidate',type=Path,required=True);args=parser.parse_args()
    if os.getuid()==0:parser.error('Run as the build user without sudo')
    try:update(args.candidate.expanduser().absolute(),ROOT/'build-support/shortcut-menu',Path.home()/'Downloads/multi-rice-v6-assembly-report.zip')
    except (OSError,ValueError,KeyError,SetupError,zipfile.BadZipFile) as error:raise SystemExit('Candidate shortcut update stopped: '+str(error))
