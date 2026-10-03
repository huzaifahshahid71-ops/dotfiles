#!/usr/bin/env python3
"""Preflight recovered G16 patches; change a source tree only with --apply."""
import argparse
import difflib
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

BUNDLE = Path(__file__).resolve().parent
GROUPS = {
    "kernel": {
        "files": ["drivers/pci/controller/vmd.c", "drivers/pci/pcie/aspm.c", "include/linux/pci.h"],
        "patches": ["0001-vmd-mtl016-complete-backport.patch", "0002-vmd-aspm-host-defaults.patch"],
    },
    "asusctl": {
        "files": ["rog-platform/src/hid_raw.rs"],
        "patches": ["0001-release-hidraw-between-transactions.patch"],
    },
}


def verify_bundle():
    manifest = json.loads((BUNDLE / "manifest.json").read_text())
    for name, expected in manifest["sha256"].items():
        path = BUNDLE / name
        if Path(name).is_absolute() or ".." in Path(name).parts or path.is_symlink():
            raise RuntimeError(f"Invalid bundle path: {name}")
        if hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            raise RuntimeError(f"Bundle file changed: {name}")
    return manifest


def git_apply(tree, patch, check=False, reverse=False):
    argv = ["git", "apply"]
    if check:
        argv.append("--check")
    if reverse:
        argv.append("--reverse")
    argv.append(str(patch))
    return subprocess.run(argv, cwd=tree, text=True, stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE, timeout=30)


def safe_file(root, name):
    path = root / name
    if not path.is_file() or path.is_symlink() or not path.resolve().is_relative_to(root):
        raise RuntimeError(f"Missing or redirected source file: {path}")
    return path


def copy_files(source, destination, names):
    for name in names:
        path = safe_file(source, name)
        target = destination / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, target)


def process(source, group, apply=False):
    verify_bundle()
    source = source.resolve()
    names = GROUPS[group]["files"]
    patches = [BUNDLE / "patches" / group / name for name in GROUPS[group]["patches"]]
    originals = {name: safe_file(source, name).read_bytes() for name in names}
    with tempfile.TemporaryDirectory(prefix="g16-patch-check-") as temporary:
        trial = Path(temporary) / "trial"
        copy_files(source, trial, names)
        # Detect a complete already-applied series in reverse order; overlapping
        # later changes can make an earlier patch's individual reverse check fail.
        complete = True
        for patch in reversed(patches):
            if git_apply(trial, patch, check=True, reverse=True).returncode:
                complete = False
                break
            result = git_apply(trial, patch, reverse=True)
            if result.returncode:
                raise RuntimeError(result.stderr)
        if complete:
            print(f"ALREADY APPLIED: complete {group} patch series")
            return "already-applied"
        shutil.rmtree(trial)
        copy_files(source, trial, names)
        for patch in patches:
            check = git_apply(trial, patch, check=True)
            if check.returncode:
                reverse = git_apply(trial, patch, check=True, reverse=True)
                if reverse.returncode == 0:
                    print(f"ALREADY APPLIED: {patch.name}")
                    continue
                raise RuntimeError(f"Patch needs review: {patch.name}\n{check.stderr}"
                                   "No source files were changed. Do not force the patch.")
            result = git_apply(trial, patch)
            if result.returncode:
                raise RuntimeError(result.stderr)
            print(f"PASS: {patch.name}")
        combined = []
        for name in names:
            if safe_file(source, name).read_bytes() != originals[name]:
                raise RuntimeError(f"Source changed during preflight: {name}")
            before = originals[name].decode().splitlines(True)
            after = (trial / name).read_text().splitlines(True)
            if before != after:
                combined.append(f"diff --git a/{name} b/{name}\n")
                combined.extend(difflib.unified_diff(before, after, fromfile="a/" + name,
                                                    tofile="b/" + name))
        if apply and combined:
            patch = Path(temporary) / "combined.patch"
            patch.write_text("".join(combined))
            check = git_apply(source, patch, check=True)
            if check.returncode:
                raise RuntimeError(check.stderr)
            result = git_apply(source, patch)
            if result.returncode:
                raise RuntimeError(result.stderr)
            for name in names:
                if safe_file(source, name).read_bytes() != (trial / name).read_bytes():
                    raise RuntimeError(f"Unexpected result: {name}")
            print(f"APPLIED: verified {group} series to {source}")
        elif not apply:
            print("CHECK ONLY: source files unchanged")
        return "applied" if apply else "applicable"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    selection = parser.add_mutually_exclusive_group(required=True)
    selection.add_argument("--kernel", action="store_true")
    selection.add_argument("--asusctl", action="store_true")
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    try:
        process(args.source, "kernel" if args.kernel else "asusctl", args.apply)
    except (OSError, RuntimeError, subprocess.TimeoutExpired) as exc:
        parser.exit(1, f"G16 patch preparation stopped: {exc}\n")


if __name__ == "__main__":
    main()
