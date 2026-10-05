#!/usr/bin/env python3
"""Correct the cache audit and resume the existing preparation, without installs."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import pwd
import shutil
import subprocess
import sys
import zipfile

from core import SetupError, no_symlink_parents, relative_path, sha256

ROOT = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('prepare_host', ROOT / 'prepare-host.py')
prepare = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prepare)


def resume(output, home):
    no_symlink_parents(output)
    if not output.is_relative_to(home):
        raise SetupError('Preparation must be inside your home.')
    report_file = output / 'build-report.json'
    report = json.loads(report_file.read_text())
    if report.get('schema') != 1 or report.get('version') != '6.0.0' or report.get('status') != 'preparation-only':
        raise SetupError('Not a v6 preparation report.')
    expected = {name: record['version'] for name, record in report['cached_packages'].items()}
    expected.update(line.split(' ', 1) for line in report['missing_archives'])
    if len(expected) != report['package_count']:
        raise SetupError('The original package snapshot is incomplete.')
    database = prepare.read_database(Path('/var/lib/pacman/local'))
    drift = [name for name, version in expected.items()
             if name not in database or database[name]['VERSION'][0] != version]
    if drift:
        raise SetupError('Installed package snapshot changed; retained preparation: ' + ', '.join(sorted(drift)))
    prepare.progress('Rechecking exact archives, including epoch-bearing filenames')
    found, missing = prepare.cache_archives([Path('/var/cache/pacman/pkg'), home / '.cache/paru'],
                                          database, sorted(expected))
    records = json.loads((output / 'packages.json').read_text())
    indexed = {record['name']: record for record in records}
    space = sum(path.stat().st_size for name, path in found.items() if name not in indexed)
    if shutil.disk_usage(output).free < space + 256 * 1024**2:
        raise SetupError('Insufficient space to stage remaining archives.')
    for index, (name, source) in enumerate(sorted(found.items()), 1):
        if name in indexed:
            destination = output / str(relative_path(indexed[name]['source']))
            no_symlink_parents(destination)
            if not destination.is_file() or destination.stat().st_size != indexed[name]['bytes'] or sha256(destination) != indexed[name]['sha256']:
                raise SetupError('Previously staged package changed: ' + name)
        else:
            destination = output / 'packages' / source.name
            no_symlink_parents(destination)
            source_hash = sha256(source)
            if not destination.exists():
                shutil.copyfile(source, destination)
            if sha256(destination) != source_hash:
                raise SetupError('Archive copy differs; retained for diagnosis: ' + name)
            indexed[name] = {'name': name, 'version': expected[name], 'source': 'packages/' + source.name,
                             'bytes': destination.stat().st_size, 'sha256': source_hash}
            from maintenance import write_json
            write_json(output / 'packages.json', [indexed[item] for item in sorted(indexed)])
            prepare.progress('Staged previously unrecognized archive: ' + source.name)
        if index % 25 == 0 or index == len(found):
            prepare.progress(f'Verified staged archives {index}/{len(found)}')
    # Private Clavis libraries are supplied by the source layer. They must not
    # be mistaken for missing distribution packages. Record verified candidates;
    # full loader resolution is still an AppImage/runtime validation gate.
    layer = json.loads((output / 'sources/source-layer.json').read_text())
    private, missing_system = {}, []
    for library in report.get('missing_system_libraries', []):
        candidates = []
        for record in layer['files']:
            if Path(record['path']).name != library:
                continue
            path = output / 'sources/home' / str(relative_path(record['path']))
            no_symlink_parents(path)
            if path.is_file() and sha256(path) == record['sha256']:
                candidates.append(record['path'])
        if candidates:
            private[library] = candidates
        else:
            missing_system.append(library)
    report['private_library_candidates'] = private
    report['missing_system_libraries'] = missing_system
    # Gather facts for the old target name; do not install or guess a provider.
    candidates = {}
    for name, fields in database.items():
        if any(word in name for word in ('caelestia', 'midnight')):
            files = prepare.run(['/usr/bin/pacman', '-Qlq', name])
            candidates[name] = {'version': fields['VERSION'][0], 'provides': fields.get('PROVIDES', []),
                                'shell_entrypoints': [line for line in files.splitlines()
                                                     if line.endswith('/shell.qml') or line.startswith('/usr/bin/')]}
    report['legacy_shell_candidates'] = candidates
    report['missing_archives'] = missing
    report['staged_packages'] = len(indexed)
    report['cached_packages'] = {name: {'version': expected[name], 'filename': path.name,
                                       'bytes': path.stat().st_size} for name, path in sorted(found.items())}
    report['audit_revision'] = 2
    from maintenance import write_json
    write_json(output / 'packages.json', [indexed[name] for name in sorted(indexed)])
    write_json(report_file, report)
    destination = home / 'Downloads/multi-rice-v6-build-report-v2.zip'
    no_symlink_parents(destination)
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists():
        raise SetupError('Updated report already exists; retained corrected preparation: ' + str(destination))
    with zipfile.ZipFile(destination, 'w', zipfile.ZIP_DEFLATED) as archive:
        archive.write(report_file, 'build-report.json')
    prepare.progress(f'READY: staged {len(indexed)}/{len(expected)} snapshot archives; missing {len(missing)}')
    prepare.progress('REPORT: ' + str(destination))
    prepare.progress('No package installation, download or desktop change was performed.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--preparation', type=Path, required=True)
    args = parser.parse_args()
    home = Path(pwd.getpwuid(os.getuid()).pw_dir).resolve()
    if os.getuid() == 0 or os.environ.get('HOME') != str(home):
        raise SetupError('Run as the normal desktop user, without sudo.')
    resume(args.preparation.expanduser().absolute(), home)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, SetupError, subprocess.TimeoutExpired) as error:
        prepare.progress('Resume stopped: ' + str(error))
        sys.exit(1)
