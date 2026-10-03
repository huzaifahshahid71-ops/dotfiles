#!/usr/bin/env python3
"""Prepare a separate 7.2.8 G16 kernel build; never install packages or alter GRUB."""
import argparse
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys

from apply import BUNDLE, verify_bundle


def adapt_recipe(recipe):
    anchor = 'pkgbase="linux-$_pkgsuffix"'
    hook = '    echo "Setting config..."'
    if recipe.count(anchor) != 1 or recipe.count(hook) != 1 or 'g16-patches' in recipe:
        raise RuntimeError("Upstream recipe structure changed or already adapted; review it first.")
    recipe = recipe.replace(anchor, '# Separate package: retain the working vmdtest kernel.\n'
                            '_pkgsuffix=cachyos-g16\n' + anchor)
    return recipe.replace(hook, '    python3 "$startdir/g16-patches/apply.py" --kernel '
                          '--source "$PWD" --apply || _die "G16 power patch verification failed"\n\n' + hook)


def prepare(destination, prepare_source=False, recipe_dir=None):
    if hasattr(os, "geteuid") and os.geteuid() == 0:
        raise RuntimeError("Run as your ordinary user, without sudo.")
    verify_bundle()
    destination = destination.absolute()
    if destination.exists():
        raise RuntimeError(f"Build directory already exists: {destination}. "
                           "Use --workdir for a new directory, or continue its existing build.")
    destination.mkdir(parents=True)
    shutil.copytree(BUNDLE, destination / "g16-patches", ignore=shutil.ignore_patterns("__pycache__"))
    recipe_dir = recipe_dir.resolve() if recipe_dir else None
    if recipe_dir:
        for name in ("PKGBUILD", "config"):
            if not (recipe_dir / name).is_file() or (recipe_dir / name).is_symlink():
                raise RuntimeError(f"Missing regular upstream recipe file: {recipe_dir / name}")
        (destination / "PKGBUILD").write_text(adapt_recipe((recipe_dir / "PKGBUILD").read_text()))
        shutil.copyfile(recipe_dir / "config", destination / "config")
    else:
        for name in ("PKGBUILD", "config"):
            shutil.copyfile(BUNDLE / "recipes/7.2.8" / name, destination / name)
    result = subprocess.run(["bash", "-n", str(destination / "PKGBUILD")],
                            capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError(result.stderr)
    (destination / "g16-preparation.json").write_text(json.dumps({
        "kernel": "external recipe" if recipe_dir else "7.2.8", "pkgbase": "linux-cachyos-g16",
        "installed": False, "source_prepared": False,
        "original_kernel_preserved": "linux-cachyos-vmdtest",
    }, indent=2) + "\n")
    print(f"Separate build directory: {destination}", flush=True)
    if prepare_source:
        # Explicit no-install/no-syncdeps mode. makepkg may report missing
        # build dependencies; preserve the directory and log for diagnosis.
        env = os.environ.copy()
        for key in list(env):
            if key.startswith("_") and key in {
                "_build_nvidia_open", "_build_zfs", "_build_r8125", "_build_debug",
                "_localmodcfg", "_use_current", "_makenconfig", "_makexconfig",
                "_autofdo", "_propeller", "_processor_opt", "_cpusched", "_use_llvm_lto",
            }:
                env.pop(key)
        argv = ["makepkg", "--nobuild"]
        with (destination / "prepare.log").open("w") as log:
            process = subprocess.Popen(argv, cwd=destination, env=env,
                                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                       text=True, bufsize=1, start_new_session=True)
            try:
                for line in process.stdout:
                    print(line, end="", flush=True)
                    log.write(line)
                code = process.wait()
            except BaseException:
                try:
                    os.killpg(process.pid, signal.SIGTERM)
                except ProcessLookupError:
                    pass
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait()
                raise
        if code:
            raise RuntimeError(f"Source preparation failed ({code}); see {destination / 'prepare.log'}")
        receipt = json.loads((destination / "g16-preparation.json").read_text())
        receipt["source_prepared"] = True
        (destination / "g16-preparation.json").write_text(json.dumps(receipt, indent=2) + "\n")
        print("PASS: signed source preparation and G16 patch stage completed.")
    print("No kernel was installed; GRUB and Windows default were unchanged.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workdir", type=Path,
                        default=Path.home() / "kernel-g16-maintenance" / "7.2.8")
    parser.add_argument("--prepare-source", action="store_true",
                        help="Download/verify/extract the source and run makepkg preparation only")
    parser.add_argument("--recipe-dir", type=Path,
                        help="For a future kernel: reviewed upstream directory containing PKGBUILD and config")
    args = parser.parse_args()
    try:
        prepare(args.workdir, args.prepare_source, args.recipe_dir)
    except (OSError, RuntimeError) as exc:
        parser.exit(1, f"G16 build preparation stopped: {exc}\n")


if __name__ == "__main__":
    main()
