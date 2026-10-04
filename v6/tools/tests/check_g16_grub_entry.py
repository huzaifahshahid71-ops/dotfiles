#!/usr/bin/env python3
"""Check custom-menu insertion, class preservation and failure rollback."""
import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import tempfile
from unittest.mock import patch

script = Path(__file__).resolve().parents[1]/'g16-grub-entry.py'
spec = importlib.util.spec_from_file_location('g16_grub_entry', script)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

fixture = '''#!/bin/sh
exec tail -n +3 $0
menuentry 'Windows' --class windows {
    chainloader /efi/Microsoft/Boot/bootmgfw.efi
}
menuentry 'Linux Stable' --class cachyos {
    search --fs-uuid --set=root example-root
    linux /@/boot/vmlinuz-linux-cachyos-vmdtest root=UUID=example-root rw rootflags=subvol=@ nowatchdog
    initrd /@/boot/initramfs-linux-cachyos-vmdtest.img
}
submenu 'Advanced Linux Options' --class cachyos {
    menuentry 'CachyOS Original' --class cachyos {
        linux /@/boot/vmlinuz-linux-cachyos
    }
    menuentry 'CachyOS LTS' --class cachyos {
        linux /@/boot/vmlinuz-linux-cachyos-lts
    }
}
menuentry 'UEFI' {
    fwsetup
}
'''


def generated(text):
    return 'set default="0"\n'+'\n'.join(text.splitlines()[2:])+'\n'


def run():
    candidate = module.add_entry(fixture)
    assert "menuentry 'Linux Stable' --class cachyos" in candidate
    assert fixture[fixture.index("menuentry 'Linux Stable'"):fixture.index("submenu 'Advanced Linux Options'")] in candidate
    assert candidate.index("'CachyOS LTS'") < candidate.index("'G16 Patched'") < candidate.index("'UEFI'")
    assert 'root=UUID=example-root rw rootflags=subvol=@ nowatchdog' in candidate
    for malformed in [candidate, fixture.replace("'Linux Stable'", "'Other'"), fixture.replace('exec tail -n +3 $0', 'exec unknown')]:
        try:
            module.add_entry(malformed)
            raise AssertionError('unsupported input accepted')
        except RuntimeError:
            pass
    old = generated(fixture)
    indexes = iter([1, 2, 3, 1, 2, 4])
    decorated = []
    for line in old.splitlines(keepends=True):
        found = module.NODE.search(line)
        if found:
            line = line.replace(found.group(1), found.group(1)+' --class evangelion-index-0'+str(next(indexes)), 1)
        decorated.append(line)
    old = ''.join(decorated)
    new = module.preserve_classes(old, generated(candidate))
    assert 'menuentry --class evangelion-index-03 \'G16 Patched\'' in new
    assert module.preserve_classes(old, new) == new
    for line in old.splitlines():
        if module.NODE.search(line):
            assert line in new
    print('PASS: insertion preserves Stable boot settings, old order and theme classes; repeat/unknown input rejected')
    for fail in [False, True]:
        with tempfile.TemporaryDirectory(prefix='g16-grub-fixture-') as directory:
            base = Path(directory)
            source = base/'etc/grub.d/40_custom'
            cfg = base/'boot/grub/grub.cfg'
            source.parent.mkdir(parents=True)
            cfg.parent.mkdir(parents=True)
            (base/'var/backups').mkdir(parents=True)
            source.write_text(fixture)
            source.chmod(0o755)
            cfg.write_text(old)
            for name in ['vmlinuz-linux-cachyos-g16', 'initramfs-linux-cachyos-g16.img']:
                (base/'boot'/name).write_text('installed boot file fixture')
            def local(value):
                value = os.fspath(value)
                return base/value.lstrip('/') if value.startswith(('/boot', '/etc/grub.d', '/var/backups')) else Path(value)
            def command(argv, **kwargs):
                if argv[0] == 'grub-mkconfig':
                    if fail:
                        raise subprocess.CalledProcessError(1, argv)
                    Path(argv[2]).write_text(generated(source.read_text()))
                return subprocess.CompletedProcess(argv, 0, '', '')
            with patch.object(module, 'Path', local), patch.object(module.os, 'geteuid', return_value=0), \
                 patch.object(module.shutil, 'which', side_effect=lambda name:name), \
                 patch.object(module.subprocess, 'run', side_effect=command), patch.object(sys, 'argv', ['helper', '--apply']):
                try:
                    module.main()
                    assert not fail
                except subprocess.CalledProcessError:
                    assert fail
            if fail:
                assert source.read_text() == fixture and cfg.read_text() == old
            else:
                assert source.read_text() == candidate and cfg.read_text() == new
            backups = list((base/'var/backups').glob('g16-grub-*'))
            assert len(backups) == 1 and (backups[0]/'menu-script').read_text() == fixture
            assert (backups[0]/'grub.cfg').read_text() == old
    print('PASS: success publishes staged config; generation failure restores source/config and retains backups')
    print('GRUB parser validation and boot checks run on the host; command calls are mocked here')


def promotion_checks():
    existing = module.add_entry(fixture)
    promoted = module.promote_entries(existing)
    assert module.NODE.findall(promoted) == module.PROMOTED
    assert module.promote_entries(promoted) == promoted
    module.validate_promotion(generated(existing), generated(promoted))
    for old_title, new_title in module.RENAMES.items():
        before = module.menu_blocks(existing)[old_title]
        after = module.menu_blocks(promoted)[new_title]
        if before['kind'] == 'menuentry':
            assert module.boot_body(before) == module.boot_body(after)
    for title, index in [('Windows',1),('Linux G16',2),('Advanced Linux Options',3),
                         ('CachyOS',1),('CachyOS LTS',2),('Linux Stable (older kernel)',3),('BIOS',4)]:
        assert '--class evangelion-index-0'+str(index) in module.menu_blocks(promoted)[title]['block'].splitlines()[0]
    for bad in [fixture, existing.replace('vmlinuz-linux-cachyos-g16','vmlinuz-other'),
                existing+'\nset timeout=1\n', existing.replace("    menuentry 'CachyOS Original'", "    set timeout=1\n    menuentry 'CachyOS Original'")]:
        try:
            module.promote_entries(bad)
            raise AssertionError('Unsupported promotion accepted')
        except RuntimeError:
            pass
    print('PASS: promotion preserves boot commands, Windows first, old kernel fallback, requested hierarchy and theme indexes')

    for failure in [None, 'generation', 'boot-command', 'default', 'syntax']:
        with tempfile.TemporaryDirectory(prefix='g16-promote-fixture-') as directory:
            base = Path(directory)
            source = base/'etc/grub.d/40_custom'
            cfg = base/'boot/grub/grub.cfg'
            source.parent.mkdir(parents=True)
            cfg.parent.mkdir(parents=True)
            (base/'var/backups').mkdir(parents=True)
            source.write_text(existing)
            source.chmod(0o755)
            old = generated(existing)
            cfg.write_text(old)
            for name in ['vmlinuz-linux-cachyos-g16', 'initramfs-linux-cachyos-g16.img']:
                (base/'boot'/name).write_text('installed boot file fixture')
            def local(value):
                value = os.fspath(value)
                return base/value.lstrip('/') if value.startswith(('/boot', '/etc/grub.d', '/var/backups')) else Path(value)
            calls = []
            def command(argv, **kwargs):
                calls.append(argv)
                if argv[0] == 'grub-mkconfig':
                    if failure == 'generation':
                        raise subprocess.CalledProcessError(1, argv)
                    text = generated(source.read_text())
                    if failure == 'boot-command':
                        text = text.replace('nowatchdog','changed-boot-arg',1)
                    if failure == 'default':
                        text = text.replace('default="0"','default="1"',1)
                    Path(argv[2]).write_text(text)
                if argv[0] == 'grub-script-check' and failure == 'syntax' and len(calls) > 1:
                    return subprocess.CompletedProcess(argv, 1, '', 'injected syntax failure')
                return subprocess.CompletedProcess(argv, 0, '', '')
            with patch.object(module, 'Path', local), patch.object(module.os, 'geteuid', return_value=0), \
                 patch.object(module.shutil, 'which', side_effect=lambda name:name), \
                 patch.object(module.subprocess, 'run', side_effect=command), \
                 patch.object(sys, 'argv', ['helper', '--promote', '--apply']):
                try:
                    module.main()
                    assert failure is None
                except (RuntimeError, subprocess.CalledProcessError):
                    assert failure is not None
                if failure is None:
                    assert source.read_text() == promoted and cfg.read_text() == generated(promoted)
                    calls.clear()
                    module.main()
                    assert not any(c[0]=='grub-mkconfig' for c in calls)
            if failure:
                assert source.read_text() == existing and cfg.read_text() == old
            backups = list((base/'var/backups').glob('g16-grub-*'))
            assert len(backups) == 1
            assert (backups[0]/'menu-script').read_text() == existing
            assert (backups[0]/'grub.cfg').read_text() == old
    print('PASS: promotion publishes once; generation, boot-command, default and syntax failures restore both files')


if __name__ == '__main__':
    run()
    promotion_checks()
