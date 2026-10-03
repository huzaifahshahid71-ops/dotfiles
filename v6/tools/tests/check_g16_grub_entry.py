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


if __name__ == '__main__':
    run()
