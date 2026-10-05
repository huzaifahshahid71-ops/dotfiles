#!/usr/bin/env python3
"""Prepare release inputs without installing packages or changing the desktop.

Run as the normal desktop user. Writes only the specified preparation directory
and a small report ZIP. Never invokes sudo, sync, upgrade, reboot or GitHub.
"""
import argparse
from collections import defaultdict, deque
import json
import os
from pathlib import Path
import platform
import pwd
import re
import shutil
import subprocess
import sys
import zipfile

from core import SetupError, relative_path, sha256
from staging import stage_collection, portable

ROOT = Path(__file__).resolve().parent


def progress(message):
    print(message, flush=True)


def run(arguments, timeout=20):
    process = subprocess.run(arguments, stdin=subprocess.DEVNULL, capture_output=True,
                             text=True, timeout=timeout, env={**os.environ, "LC_ALL": "C"})
    if process.returncode:
        raise SetupError("Command failed: " + str(arguments[0]) + "\n" + process.stderr[-2000:])
    return process.stdout.strip()


def read_database(database):
    packages = {}
    for file in sorted(database.glob("*/desc")):
        fields, field = defaultdict(list), None
        for line in file.read_text().splitlines():
            if line.startswith("%") and line.endswith("%"):
                field = line.strip("%")
            elif not line:
                field = None
            elif field:
                fields[field].append(line)
        if fields.get("NAME"):
            packages[fields["NAME"][0]] = dict(fields)
    return packages


def split_dependency(spec):
    match = re.fullmatch(r"([^<>=]+)(>=|<=|=|>|<)?(.*)", spec)
    if not match:
        raise SetupError("Invalid package dependency: " + spec)
    return match.groups()


def resolve_closure(packages, targets, compare):
    providers = defaultdict(list)
    for name, fields in packages.items():
        providers[name].append((name, fields['VERSION'][0]))
        for provided in fields.get('PROVIDES', []):
            virtual, operator, version = split_dependency(provided)
            providers[virtual].append((name, version if operator == '=' else None))

    def resolve(spec):
        name, operator, expected = split_dependency(spec)
        candidates = sorted(set(providers.get(name, [])), key=lambda x: (x[0] != name, x[0]))
        for actual, version in candidates:
            if not operator:
                return actual
            if version is None:
                continue
            result = compare(version, expected)
            if {'=': result == 0, '>=': result >= 0, '<=': result <= 0,
                '>': result > 0, '<': result < 0}[operator]:
                return actual
        return None

    closure, missing, mapping = set(), set(), {}
    queue = deque()
    for target in targets:
        resolved = resolve(target)
        if resolved:
            queue.append(resolved)
            mapping[target] = resolved
        else:
            missing.add('target:' + target)
    while queue:
        name = queue.popleft()
        if name in closure:
            continue
        closure.add(name)
        for dependency in packages[name].get('DEPENDS', []):
            resolved = resolve(dependency)
            if resolved:
                queue.append(resolved)
            else:
                missing.add(name + ':' + dependency)
    return sorted(closure), sorted(missing), mapping


def cache_archives(roots, packages, closure):
    # Exact filename filters keep metadata reads bounded to this snapshot;
    # old/unrelated cache archives are not read or copied.
    candidates = defaultdict(list)
    prefixes = {name + '-' + version + '-': name for name in closure
                for version in {packages[name]['VERSION'][0],
                                packages[name]['VERSION'][0].split(':', 1)[-1]}}
    count = 0
    for root in roots:
        if not root.is_dir():
            continue
        for directory, children, files in os.walk(root, followlinks=False):
            children[:] = sorted(x for x in children if x not in ('.git', 'src', 'pkg'))
            for filename in sorted(files):
                if not re.search(r'\.pkg\.tar\.(zst|xz|gz)$', filename):
                    continue
                path = Path(directory) / filename
                if path.is_symlink():
                    continue
                for prefix, name in prefixes.items():
                    if filename.startswith(prefix):
                        candidates[name].append(path)
                        count += 1
                if count > 10000:
                    raise SetupError('Package cache scan exceeded its limit.')
    found, missing = {}, []
    for index, name in enumerate(closure, 1):
        expected = name + ' ' + packages[name]['VERSION'][0]
        for candidate in candidates[name]:
            try:
                metadata = run(['/usr/bin/pacman', '-Qp', '--', str(candidate)])
            except (OSError, subprocess.TimeoutExpired, SetupError):
                continue
            if metadata == expected:
                found[name] = candidate
                break
        if name not in found:
            missing.append(expected)
        if index % 25 == 0 or index == len(closure):
            progress(f'Checked cached packages {index}/{len(closure)}')
    return found, missing


def prepare(collection, output, home, stage_packages=False, extra_cache=()):
    if output.exists():
        raise SetupError('Use a new preparation directory; existing work is retained: ' + str(output))
    output.mkdir(parents=True)
    # The kit includes the tested service guard in its original repository path.
    repository = ROOT / 'build-support'
    if not repository.exists():
        repository = ROOT.parents[1]
    progress('Preparing clean twelve-profile sources')
    manifest = stage_collection(collection, output / 'sources', repository)
    spec = json.loads((ROOT / 'build-inputs.json').read_text())
    pins = {record['path']: record for record in spec['native_pins']}
    files = {record['path']: record for record in manifest['files']}
    runtime, missing_runtime, changed_runtime = [], [], []
    progress('Checking compiled runtime components and launchers')
    for relative in spec['runtime_extra_paths']:
        source = home / str(relative_path(relative))
        try:
            resolved = source.resolve(strict=True)
            resolved.relative_to(home)
            if not resolved.is_file():
                raise ValueError('not a regular file')
        except (OSError, ValueError):
            missing_runtime.append(relative)
            continue
        digest = sha256(resolved)
        pin = pins.get(relative)
        if pin and (digest != pin['sha256'] or
                    ('bytes' in pin and resolved.stat().st_size != pin['bytes'])):
            changed_runtime.append(relative)
            continue
        destination = output / 'sources/home' / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        # Large compositor/library files are copied without reading into RAM.
        shutil.copyfile(resolved, destination)
        if sha256(destination) != digest:
            raise SetupError('Runtime changed during copying: ' + relative)
        template = False
        if destination.stat().st_size < 1024 * 1024:
            data, template = portable(destination.read_bytes(), str(home))
            destination.write_bytes(data)
        mode = 0o755 if resolved.stat().st_mode & 0o111 else 0o644
        destination.chmod(mode)
        record = {'path': relative, 'sha256': sha256(destination), 'bytes': destination.stat().st_size,
                  'mode': mode, 'template': template, 'origin': 'host-runtime'}
        files[relative] = record
        runtime.append(record)
    manifest['files'] = sorted(files.values(), key=lambda x: x['path'])
    (output / 'sources/source-layer.json').write_text(json.dumps(manifest, indent=2) + '\n')
    packages = read_database(Path('/var/lib/pacman/local'))
    if not packages:
        raise SetupError('No installed Arch package database found.')
    targets = (ROOT / 'build-targets.txt').read_text().split()
    compare = lambda a, b: int(run(['/usr/bin/vercmp', a, b]))
    closure, unresolved, mapping = resolve_closure(packages, targets, compare)
    # Native libraries may depend on packages not present in old target lists.
    # Check linkage without executing any collected binary (never use ldd).
    native_needed, missing_libraries, unowned_libraries = {}, set(), set()
    library_dirs = [Path('/usr/lib'), Path('/usr/lib32')]
    added = set()
    for record in runtime:
        source = home / record['path']
        with source.open('rb') as stream:
            elf = stream.read(4) == b'\x7fELF'
        if not elf:
            continue
        output_text = run(['/usr/bin/readelf', '-d', str(source)])
        needed = re.findall(r'\(NEEDED\).*\[([^]]+)\]', output_text)
        native_needed[record['path']] = needed
        for library in needed:
            for directory in library_dirs:
                path = directory / library
                if not path.exists():
                    continue
                try:
                    owner = run(['/usr/bin/pacman', '-Qoq', '--', str(path)])
                    added.update(owner.splitlines())
                except SetupError:
                    unowned_libraries.add(library)
                break
            else:
                missing_libraries.add(library)
    closure, unresolved2, _ = resolve_closure(packages, sorted(set(targets) | added), compare)
    unresolved = sorted(set(unresolved + unresolved2))
    roots = [Path('/var/cache/pacman/pkg'), home / '.cache/paru', *extra_cache]
    found, missing_archives = cache_archives(roots, packages, closure)
    progress(f'Exact cached archives found: {len(found)}/{len(closure)}')
    archived = []
    if stage_packages:
        required = sum(path.stat().st_size for path in found.values())
        if shutil.disk_usage(output).free < required + max(1024**3, required // 5):
            raise SetupError('Insufficient space to stage package archives; preparation retained.')
        directory = output / 'packages'
        directory.mkdir()
        for index, (name, source) in enumerate(sorted(found.items()), 1):
            destination = directory / source.name
            shutil.copyfile(source, destination)
            if sha256(destination) != sha256(source):
                raise SetupError('Package copy failed verification: ' + name)
            archived.append({'name': name, 'version': packages[name]['VERSION'][0],
                             'source': 'packages/' + destination.name, 'bytes': destination.stat().st_size,
                             'sha256': sha256(destination)})
            if index % 25 == 0 or index == len(found):
                progress(f'Staged archives {index}/{len(found)}')
        (output / 'packages.json').write_text(json.dumps(archived, indent=2) + '\n')
    # Existence facts only: no external tree or user history is copied.
    external = {path: (home / path).exists() for path in
                ('.local/src/end4-dots', '.config/quickshell/end4-pC', '.local/src/ambxst',
                 '.local/share/serpantinum', '.local/lib/huzaifah/mpv-mpris/mpris.so',
                 '.local/share/desktop-profiles/inir/venv/bin/python')}
    report = {'schema': 1, 'version': '6.0.0', 'status': 'preparation-only',
              'source_files': len(files), 'runtime_components': len(runtime),
              'missing_runtime': missing_runtime, 'changed_pinned_runtime': changed_runtime,
              'package_count': len(closure), 'unresolved_dependencies': unresolved,
              'missing_archives': missing_archives, 'staged_packages': len(archived),
              'resolved_targets': mapping, 'native_dependencies': native_needed,
              'missing_system_libraries': sorted(missing_libraries),
              'unowned_system_libraries': sorted(unowned_libraries),
              'external_runtime_roots': external, 'machine': platform.machine(),
              'cached_packages': {name: {'version': packages[name]['VERSION'][0], 'filename': path.name,
                                       'bytes': path.stat().st_size} for name, path in sorted(found.items())},
              'release_gates': ['External runtime staging', 'Eclipse isolated Python dependencies',
                               'GUI runtime bundle', 'AppImage assembly', 'Fresh VM and upgrade validation',
                               'Optional GRUB implementation', 'Release publication'],
              'changes': 'Only preparation files were written; desktop, packages, services and GRUB unchanged'}
    report_path = output / 'build-report.json'
    report_path.write_text(json.dumps(report, indent=2) + '\n')
    small_zip = home / 'Downloads/multi-rice-v6-build-report.zip'
    small_zip.parent.mkdir(parents=True, exist_ok=True)
    if small_zip.exists():
        small_zip = small_zip.with_name('multi-rice-v6-build-report-' + output.name + '.zip')
    with zipfile.ZipFile(small_zip, 'w', zipfile.ZIP_DEFLATED) as archive:
        archive.write(report_path, 'build-report.json')
    progress('PREPARED: ' + str(output))
    progress('REPORT: ' + str(small_zip))
    progress('No installation, upgrade, desktop restart or publication was performed.')
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--collection', type=Path, default=Path.home() / 'Downloads/multi-rice-v6-release-inputs.zip')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--stage-packages', action='store_true', help='Copy verified cached archives; may require several GiB')
    parser.add_argument('--package-cache', type=Path, action='append', default=[])
    args = parser.parse_args()
    home = Path(pwd.getpwuid(os.getuid()).pw_dir).resolve()
    if os.getuid() == 0 or os.environ.get('HOME') != str(home):
        raise SetupError('Run as the normal desktop user, without sudo.')
    if platform.machine() != 'x86_64' or not Path('/usr/bin/pacman').is_file():
        raise SetupError('Run this helper on the tested x86_64 Arch/CachyOS laptop.')
    output = args.output.expanduser().absolute()
    from core import no_symlink_parents
    no_symlink_parents(output)
    if not output.is_relative_to(home):
        raise SetupError('The preparation directory must be inside your home.')
    prepare(args.collection.expanduser().resolve(strict=True), output, home,
            args.stage_packages, [path.expanduser().resolve(strict=True) for path in args.package_cache])


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, SetupError, subprocess.TimeoutExpired) as error:
        progress('Preparation stopped: ' + str(error))
        sys.exit(1)
