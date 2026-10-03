#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Add a G16 kernel to the existing custom GRUB submenu without changing defaults."""
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

TITLE = 'G16 Patched'
ID = 'g16-patched'
KERNEL = 'linux-cachyos-g16'
STABLE = 'linux-cachyos-vmdtest'
NODE = re.compile(r"(?m)^\s*(menuentry|submenu)\b[^\n]*?'([^'\n]+)'[^\n]*\{")


def add_entry(text):
    if text.splitlines()[:2] != ['#!/bin/sh', 'exec tail -n +3 $0']:
        raise RuntimeError('Unrecognized custom-menu generator header')
    if TITLE in text or ID in text or 'vmlinuz-'+KERNEL in text:
        raise RuntimeError('A G16 entry already exists; no files changed')
    stable = re.search(r"(?ms)^menuentry 'Linux Stable'[^\n]*\{\n.*?^\}", text)
    advanced = re.search(r"(?ms)^submenu 'Advanced Linux Options'[^\n]*\{\n.*?^\}", text)
    if not stable or not advanced or stable.end() >= advanced.start():
        raise RuntimeError('Expected Stable/Advanced menu structure was not found')
    for title in ['Windows', 'Linux Stable', 'Advanced Linux Options', 'CachyOS Original', 'CachyOS LTS', 'UEFI']:
        if [name for _, name in NODE.findall(text)].count(title) != 1:
            raise RuntimeError('Missing or repeated menu title: '+title)
    entry = stable.group()
    for prefix in ['vmlinuz-', 'initramfs-']:
        if entry.count(prefix+STABLE) != 1:
            raise RuntimeError('Stable kernel/initramfs paths differ from expected layout')
    entry = entry.replace("menuentry 'Linux Stable'", "menuentry '"+TITLE+"' --id '"+ID+"'", 1)
    entry = entry.replace('vmlinuz-'+STABLE, 'vmlinuz-'+KERNEL)
    entry = entry.replace('initramfs-'+STABLE, 'initramfs-'+KERNEL)
    insert = '\n'+'\n'.join('    '+line if line else '' for line in entry.splitlines())+'\n'
    candidate = text[:advanced.end()-1]+insert+text[advanced.end()-1:]
    old = NODE.findall(text)
    new = [node for node in NODE.findall(candidate) if node != ('menuentry', TITLE)]
    if old != new:
        raise RuntimeError('Existing menu order changed unexpectedly')
    return candidate


def preserve_classes(old, new):
    """Retain the theme classes already attached to existing generated menu nodes."""
    classes = {}
    for line in old.splitlines():
        found = NODE.search(line)
        if found:
            classes[found.groups()] = re.findall(r'--class\s+(evangelion-index-\d+)\b', line)
    result = []
    for line in new.splitlines(keepends=True):
        found = NODE.search(line)
        if found:
            for name in classes.get(found.groups(), []):
                if name not in line:
                    line = line.replace(found.group(1), found.group(1)+' --class '+name, 1)
            if found.groups() == ('menuentry', TITLE) and any(classes.values()):
                if not re.search(r'--class\s+evangelion-index-\d+\b', line):
                    line = line.replace('menuentry', 'menuentry --class evangelion-index-03', 1)
        result.append(line)
    return ''.join(result)


def atomic_copy(path, data, reference):
    stat = reference.stat()
    fd, name = tempfile.mkstemp(prefix='.'+path.name+'-g16-', dir=path.parent)
    try:
        with os.fdopen(fd, 'wb') as output:
            output.write(data)
            output.flush()
            os.fsync(output.fileno())
        os.chmod(name, stat.st_mode & 0o7777)
        os.chown(name, stat.st_uid, stat.st_gid)
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def check_syntax(checker, text):
    result = subprocess.run([checker], input=text, text=True, capture_output=True)
    if result.returncode:
        raise RuntimeError('GRUB syntax check failed:\n'+result.stdout+result.stderr)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true', help='Back up, update and regenerate the menu')
    args = parser.parse_args()
    if os.geteuid() != 0:
        parser.error('Run with sudo so the protected GRUB files can be checked')
    checker = shutil.which('grub-script-check')
    generator = shutil.which('grub-mkconfig')
    if not checker or not generator:
        raise RuntimeError('grub-script-check and grub-mkconfig must be installed')
    cfg = Path('/boot/grub/grub.cfg')
    if not cfg.is_file() or cfg.is_symlink():
        raise RuntimeError('Expected a regular /boot/grub/grub.cfg')
    for name in ['vmlinuz-'+KERNEL, 'initramfs-'+KERNEL+'.img']:
        path = Path('/boot')/name
        if not path.is_file() or path.stat().st_size == 0:
            raise RuntimeError('Missing installed boot file: '+str(path))
    matches = []
    for path in sorted(Path('/etc/grub.d').iterdir()):
        if path.is_file() and not path.is_symlink() and path.stat().st_mode & 0o111:
            text = path.read_text()
            if "menuentry 'Linux Stable'" in text and "submenu 'Advanced Linux Options'" in text:
                matches.append((path, text))
    if len(matches) != 1:
        raise RuntimeError('Expected one executable custom menu generator; found '+str(len(matches)))
    path, original = matches[0]
    old_cfg = cfg.read_text()
    if NODE.findall(old_cfg)[0] != ('menuentry', 'Windows'):
        raise RuntimeError('Windows is not the first current menu node')
    if not re.search(r'(?m)^\s*set default=[\x22\x27]0[\x22\x27]\s*$', old_cfg):
        raise RuntimeError('Current generated default is not entry 0; no files changed')
    candidate = add_entry(original)
    check_syntax(checker, '\n'.join(candidate.splitlines()[2:])+'\n')
    print('Menu generator:', path)
    print('Entry: Advanced Linux Options > '+TITLE)
    if not args.apply:
        print('CHECK ONLY: no files changed. Run with --apply to install the entry.')
        return
    directory = Path('/var/backups')
    directory.mkdir(exist_ok=True)
    backup = Path(tempfile.mkdtemp(prefix='g16-grub-', dir=directory))
    saved_script, saved_cfg = backup/'menu-script', backup/'grub.cfg'
    shutil.copy2(path, saved_script)
    shutil.copy2(cfg, saved_cfg)
    print('Backup:', backup, flush=True)
    changed = False
    try:
        if path.read_text() != original or cfg.read_text() != old_cfg:
            raise RuntimeError('GRUB files changed during preflight')
        atomic_copy(path, candidate.encode(), saved_script)
        changed = True
        with tempfile.TemporaryDirectory(prefix='.g16-grub-', dir=cfg.parent) as stage:
            staged = Path(stage)/'grub.cfg'
            subprocess.run([generator, '-o', str(staged)], check=True)
            generated = preserve_classes(old_cfg, staged.read_text())
            check_syntax(checker, generated)
            expected = NODE.findall(old_cfg)
            actual = [node for node in NODE.findall(generated) if node != ('menuentry', TITLE)]
            if actual != expected or NODE.findall(generated).count(('menuentry', TITLE)) != 1:
                raise RuntimeError('Generated menu changed existing entries/order')
            if not re.search(r'(?m)^\s*set default=[\x22\x27]0[\x22\x27]\s*$', generated):
                raise RuntimeError('Generated default changed from Windows/entry 0')
            for name in ['vmlinuz-'+KERNEL, 'initramfs-'+KERNEL+'.img']:
                if name not in generated:
                    raise RuntimeError('New boot file absent from generated menu: '+name)
            atomic_copy(cfg, generated.encode(), saved_cfg)
        print('INSTALLED: Advanced Linux Options > '+TITLE)
        print('Windows remains default; Linux Stable and other menu entries are retained.')
        print('No reboot or bootloader reinstall was requested.')
    except BaseException:
        if changed:
            atomic_copy(path, saved_script.read_bytes(), saved_script)
            atomic_copy(cfg, saved_cfg.read_bytes(), saved_cfg)
            print('Original menu script and generated configuration restored.')
        raise


if __name__ == '__main__':
    try:
        main()
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        raise SystemExit('G16 GRUB update stopped: '+str(error))
