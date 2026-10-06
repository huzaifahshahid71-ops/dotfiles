#!/usr/bin/env python3
"""Review host storage after publication/testing; does not delete anything."""
import json
from pathlib import Path
import shutil
import stat


def main():
    home=Path.home();seen=set();rows=[]
    targets=sorted(home.glob('multi-rice-v6-*'))
    targets += [home/'Downloads/sumi-v6-build-prep',home/'VMs',home/'.cache/huzaifah-multi-rice',Path('/var/cache/pacman/pkg')]
    for root in targets:
        if root.is_symlink() or not root.exists():continue
        blocks=0;files=0;errors=0
        for path in ([root] if root.is_file() else root.rglob('*')):
            try:
                info=path.lstat()
                if not stat.S_ISREG(info.st_mode):continue
                key=(info.st_dev,info.st_ino)
                if key in seen:continue
                seen.add(key);blocks+=info.st_blocks*512;files+=1
            except OSError:errors+=1
        keep=root.name in ('multi-rice-v6-appearance-r2','sumi-v6-build-prep')
        row={'path':str(root),'unique_inode_allocated_bytes':blocks,'files':files,'read_errors':errors,
             'review':'keep current release/repair sources' if keep else 'review after clean VM acceptance'}
        rows.append(row);print(f'{blocks/1024**3:6.2f} GiB  {root}',flush=True)
    report=home/'Downloads/sumi-storage-audit.json'
    if report.is_symlink():raise RuntimeError('Existing report symlink preserved')
    report.write_text(json.dumps({'schema':1,'home_free_bytes':shutil.disk_usage(home).free,'rows':rows,
                                 'note':'Hard-link inodes counted once across listed paths; Btrfs shared extents/snapshots may affect actual recovery. No files removed.'},indent=2)+'\n')
    print('REPORT:',report,flush=True)


if __name__=='__main__':main()
