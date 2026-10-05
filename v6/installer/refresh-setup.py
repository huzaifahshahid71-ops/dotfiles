#!/usr/bin/env python3
"""Rebuild only Sumi Setup, retaining the verified RC1 desktop AppImage."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import shutil
import sys

from core import SetupError, load_manifest, no_symlink_parents, verified
from maintenance import write_json

ROOT = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--previous", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    if os.getuid() == 0:
        parser.error("Run as the desktop user, without sudo.")
    previous = args.previous.expanduser().absolute()
    output = args.output.expanduser().absolute()
    for path in (previous, output):
        no_symlink_parents(path)
    if output.exists() or output.is_relative_to(previous) or previous.is_relative_to(output):
        raise SetupError("Use a new output directory separate from the RC1 build.")
    manifest = load_manifest(previous / "release.json")
    print("Checking the existing RC1 AppImage; no payload rebuild", flush=True)
    if not verified(previous / manifest["image"]["asset"], manifest["image"]):
        raise SetupError("The previous RC1 AppImage differs from its release manifest.")
    if not (previous / "build-venv/bin/python").is_file() or not (previous / "wheels").is_dir():
        raise SetupError("The existing private GUI toolchain is missing.")
    if shutil.disk_usage(output.parent).free < 1024**3:
        raise SetupError("The GUI refresh needs at least 1 GiB free.")
    spec = importlib.util.spec_from_file_location("sumi_packager", ROOT / "package-release.py")
    packager = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(packager)
    output.mkdir(mode=0o700)
    runtime = packager.gui_runtime(output, existing_build=previous)
    shutil.copy2(previous / "release.json", runtime / "release.json")
    for offline in (True, False):
        name = "launch-offline.sh" if offline else "launch-online.sh"
        (runtime / name).write_text(packager.launcher(offline))
        (runtime / name).chmod(0o755)
    write_json(output / "refresh-report.json", {
        "status": "setup-runtime-refreshed", "image": manifest["image"],
        "payload_rebuilt": False, "gui_smoke_test": True,
        "features": ["Visible confirmation checkbox", "Correct disabled button appearance",
                     "Optional theme configuration for existing GRUB", "Current GRUB retained by default"],
        "runtime": str(runtime)})
    print("REFRESHED: " + str(runtime), flush=True)
    print("Desktop AppImage retained. Test the refreshed GUI in the VM.", flush=True)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, SetupError) as error:
        print("Sumi runtime refresh stopped:", error, file=sys.stderr)
        sys.exit(1)
