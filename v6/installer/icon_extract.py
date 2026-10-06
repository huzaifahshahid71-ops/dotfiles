"""Resume verified icon imports from a local archive without per-file fsync."""
import ctypes
import hashlib
import os
from pathlib import Path
import shutil
import tempfile
import time
import zipfile
from icon_inventory import inventory, regular_target, sha


def file_sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def local_archive(source, destination, expected, progress):
    regular_target(source); regular_target(destination)
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists():
        if file_sha(destination) != expected:
            raise RuntimeError('Different local archive retained')
        return destination
    if shutil.disk_usage(destination.parent).free < source.stat().st_size + 128 * 1024**2:
        raise RuntimeError('Not enough VM space for the compressed icon archive')
    fd, temporary = tempfile.mkstemp(prefix='.icons-', dir=destination.parent)
    digest = hashlib.sha256(); copied = 0; last = 0
    try:
        with source.open('rb') as incoming, os.fdopen(fd, 'wb') as outgoing:
            while chunk := incoming.read(4 * 1024**2):
                outgoing.write(chunk); digest.update(chunk); copied += len(chunk)
                if time.monotonic() - last > 2:
                    progress('Copy compressed archive into VM cache', copied_bytes=copied,
                             total_bytes=source.stat().st_size)
                    last = time.monotonic()
            outgoing.flush(); os.fsync(outgoing.fileno())
        if digest.hexdigest() != expected:
            raise RuntimeError('Compressed icon archive checksum differs; no icons changed')
        os.chmod(temporary, 0o600)
        os.link(temporary, destination)  # Never replace an existing cache object.
    finally:
        Path(temporary).unlink(missing_ok=True)
    return destination


def sync_directory(path):
    # One filesystem flush after the batch, rather than 165,000 individual syncs.
    fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY)
    try:
        libc = ctypes.CDLL(None, use_errno=True)
        if libc.syncfs(fd):
            raise OSError(ctypes.get_errno(), 'Icon batch filesystem flush failed')
    finally:
        os.close(fd)


def install(home, archive_path, progress):
    destination = home / '.local/share/icons'
    with zipfile.ZipFile(archive_path) as archive:
        manifest = inventory(archive)
        records = manifest['files']; total = len(records); groups = {}
        parents = set(); existing = {}; hashes = {}; last = 0
        # Check every archive member and every collision before adding files.
        for count, record in enumerate(records, 1):
            path = destination / record['path']
            if path.parent not in parents:
                for parent in (path.parent, *path.parent.parents):
                    if parent.is_symlink() or parent.exists() and not parent.is_dir():
                        raise RuntimeError('Existing icon directory retained: ' + str(parent))
                parents.add(path.parent)
            if path.is_symlink() or path.exists() and not path.is_file():
                raise RuntimeError('Existing non-regular icon retained: ' + str(path))
            data = archive.read(record['path'])
            if sha(data) != record['sha256']:
                raise RuntimeError('Icon archive checksum differs: ' + record['path'])
            if path.exists():
                info = path.stat()
                key = (info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns, info.st_ctime_ns)
                if key not in hashes: hashes[key] = file_sha(path)
                if hashes[key] != record['sha256']:
                    raise RuntimeError('Different existing icon retained: ' + str(path))
                existing[record['path']] = True
            groups.setdefault((record['sha256'], record['bytes']), []).append(record)
            if time.monotonic() - last > 2 or count == total:
                progress('Verify archive and existing icons', verified=count, total=total,
                         existing=len(existing))
                last = time.monotonic()
        unique_bytes = sum(size for _, size in groups)
        if shutil.disk_usage(home).free < unique_bytes + 128 * 1024**2:
            raise RuntimeError('Insufficient VM space for unique icon contents')
        for parent in sorted(parents):
            parent.mkdir(parents=True, exist_ok=True)
        done = added = reused = 0; last = 0
        # Equal-content files share immutable ordinary-file data. Existing icons
        # never become donors, so editing an old icon cannot affect new aliases.
        for group in groups.values():
            pending = [r for r in group if r['path'] not in existing]
            if pending:
                donor = destination / pending[0]['path']
                data = archive.read(pending[0]['path'])
                fd, temporary = tempfile.mkstemp(prefix='.sumi-icon-', dir=donor.parent)
                try:
                    with os.fdopen(fd, 'wb') as outgoing:
                        outgoing.write(data)
                    os.chmod(temporary, 0o644)
                    for record in pending:
                        target = destination / record['path']
                        os.link(temporary, target)  # EEXIST preserves a concurrent edit.
                        added += 1
                finally:
                    Path(temporary).unlink(missing_ok=True)
            reused += len(group) - len(pending); done += len(group)
            if time.monotonic() - last > 2 or done == total:
                progress('Import verified icons', completed=done, total=total,
                         added=added, reused=reused)
                last = time.monotonic()
        progress('Flush completed icon batch', completed=total, total=total, added=added, reused=reused)
        sync_directory(destination)
    return {'total': total, 'added': added, 'reused': reused, 'unique_contents': len(groups),
            'bytes': manifest['bytes']}
