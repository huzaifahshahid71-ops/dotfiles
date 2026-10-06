#!/usr/bin/env python3
"""Guarded repair of the SDDM restore check; does not edit receipts or themes."""
import argparse
import ast
import hashlib
import os
from pathlib import Path
import stat
import tempfile

OLD = """        if any(record['path']=='usr/local/share/multi-rice-sddm/catalog.json' for record in receipt['files']) and (self.root/'usr/local/share/multi-rice-sddm/selected.json').exists():
            conflicts.append('Login theme selection: use Sumi Deck > LOGIN > Restore previous login until the original selection is restored, then retry uninstall')
"""
NEW = """        # A reinstall may restore identical SDDM files while selection history
        # remains active. This is safe: no theme asset or manager is changed.
        # Keep the selection guard if any managed SDDM file would change/remove.
        sddm_files = [record for record in receipt['files']
                      if record['path'] == 'usr/local/libexec/multi-rice-sddm.py'
                      or record['path'].startswith('usr/local/share/multi-rice-sddm/')]
        if (any(record['path'] == 'usr/local/share/multi-rice-sddm/catalog.json'
                for record in sddm_files)
                and any(record['before'] != record['installed'] for record in sddm_files)
                and (self.root/'usr/local/share/multi-rice-sddm/selected.json').exists()):
            conflicts.append('Login theme selection: restore the prior login selection before changing or removing its managed theme files')
"""


def patched(text):
    if NEW in text and OLD not in text:
        return text
    if text.count(OLD) != 1:
        raise RuntimeError('Restore guard differs from the reviewed version; no change made')
    result = text.replace(OLD, NEW, 1)
    ast.parse(result)
    return result


def apply(path):
    path = Path(path)
    for p in (path, *path.parents):
        if p.is_symlink():
            raise RuntimeError('Symlink preserved: ' + str(p))
    info = path.stat()
    if not stat.S_ISREG(info.st_mode):
        raise RuntimeError('Expected regular Python file')
    if os.getuid() == 0 and (info.st_uid != 0 or info.st_mode & 0o022):
        raise RuntimeError('Privileged helper ownership or permissions differ')
    before = path.read_bytes()
    after = patched(before.decode()).encode()
    if before == after:
        print('ALREADY FIXED:', path, flush=True)
        return
    backup = path.with_name(path.name + '.before-login-restore-' + hashlib.sha256(before).hexdigest()[:16])
    if backup.exists():
        if backup.is_symlink() or backup.read_bytes() != before:
            raise RuntimeError('Existing patch backup differs; preserved')
    else:
        with backup.open('xb') as out:
            out.write(before)
            out.flush()
            os.fsync(out.fileno())
        backup.chmod(stat.S_IMODE(info.st_mode))
    fd, name = tempfile.mkstemp(prefix='.' + path.name + '-', dir=path.parent)
    try:
        with os.fdopen(fd, 'wb') as out:
            out.write(after)
            out.flush()
            os.fsync(out.fileno())
        os.chmod(name, stat.S_IMODE(info.st_mode))
        if path.read_bytes() != before:
            raise RuntimeError('Helper changed during patch; no replacement made')
        os.replace(name, path)
    finally:
        Path(name).unlink(missing_ok=True)
    print('FIXED:', path, flush=True)
    print('Backup:', backup, flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('target', type=Path)
    args = parser.parse_args()
    if args.target == Path('/usr/local/lib/huzaifah-multi-rice-v6/system_transaction.py') and os.getuid() != 0:
        parser.error('The VM helper repair requires the authentication prompt')
    apply(args.target)
