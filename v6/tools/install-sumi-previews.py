#!/usr/bin/env python3
"""Offline, reversible update of Sumi Deck screenshots only."""
import argparse
from datetime import datetime
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import uuid

HERE = Path(__file__).resolve().parent
ASSETS = HERE.parents[1] / "dual-rice/desktop-switcher/previews"
HOME = Path(os.environ.get("HUZAIFAH_PREVIEW_HOME", Path.home()))
DECK = (HOME / ".local/share/desktop-switcher/themes/sumi-deck/DotsBrowser.qml").resolve()
PREVIEWS = HOME / ".local/share/desktop-switcher/previews"
STATE = Path(os.environ.get("XDG_STATE_HOME", HOME / ".local/state")) / "huzaifah-switcher/preview-backups"


def digest(data):
    return hashlib.sha256(data).hexdigest()


def atomic_write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=".sumi-", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(data)
        os.chmod(temporary, 0o644)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def preflight():
    if not DECK.is_file():
        raise ValueError(f"Installed Sumi Deck not found: {DECK}")
    spec = importlib.util.spec_from_file_location("sumi_preview_patch", HERE / "patch-sumi-previews.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    patched = module.patch(DECK.read_text(encoding="utf-8")).encode("utf-8")
    manifest_data = (ASSETS / "previews.json").read_bytes()
    manifest = json.loads(manifest_data)
    updates = {DECK: patched, PREVIEWS / "previews.json": manifest_data}
    for entry in manifest["profiles"]:
        name = entry["file"]
        if name != entry["id"] + ".webp" or Path(name).name != name:
            raise ValueError("Unsafe filename in preview manifest")
        data = (ASSETS / name).read_bytes()
        if digest(data) != entry["sha256"] or data[:4] != b"RIFF" or data[8:12] != b"WEBP":
            raise ValueError(f"Preview integrity check failed: {name}")
        updates[PREVIEWS / name] = data
    for path in updates:
        if path.is_symlink():
            raise ValueError(f"Refusing to overwrite a preview symlink: {path}")
        if path.exists() and not path.is_file():
            raise ValueError(f"Expected a regular file: {path}")
    formatter = shutil.which("qmlformat")
    if not formatter and Path("/usr/lib/qt6/bin/qmlformat").is_file():
        formatter = "/usr/lib/qt6/bin/qmlformat"
    if formatter:
        with tempfile.TemporaryDirectory(prefix="sumi-qml-check-") as directory:
            candidate = Path(directory) / "DotsBrowser.qml"
            candidate.write_bytes(patched)
            subprocess.run([formatter, "-i", str(candidate)], check=True, capture_output=True, text=True)
        print("PASS: QML syntax validated by qmlformat")
    else:
        print("NOTE: qmlformat unavailable; live Quickshell verification remains")
    print(f"PASS: installed Sumi Deck and {len(manifest['profiles'])} preview checksums")
    return updates


def install():
    updates = preflight()
    if all(path.is_file() and path.read_bytes() == data for path, data in updates.items()):
        print("Already installed; nothing changed.")
        return
    snapshot = STATE / (datetime.now().strftime("%Y%m%d-%H%M%S") + "-" + uuid.uuid4().hex[:8])
    snapshot.mkdir(parents=True)
    records = []
    originals = {}
    for index, (path, data) in enumerate(updates.items()):
        original = path.read_bytes() if path.is_file() else None
        originals[path] = original
        backup_name = f"{index:02d}.original"
        if original is not None:
            (snapshot / backup_name).write_bytes(original)
        records.append({"path": str(path), "present": original is not None,
                        "backup": backup_name, "installed_sha256": digest(data)})
    atomic_write(snapshot / "snapshot.json", json.dumps(records, indent=2).encode())
    try:
        for path, data in updates.items():
            atomic_write(path, data)
        atomic_write(STATE / "latest", str(snapshot).encode())
    except Exception:
        for path, data in originals.items():
            if data is None:
                path.unlink(missing_ok=True)
            else:
                atomic_write(path, data)
        raise
    print("INSTALLED: Sumi Deck artwork and eleven desktop previews")
    print(f"Backup: {snapshot}")
    print("Close Sumi Deck, then reopen with Super+Shift+D. No desktop restart required.")


def rollback():
    snapshot = Path((STATE / "latest").read_text()).resolve(strict=True)
    if snapshot.parent != STATE.resolve():
        raise ValueError("Invalid snapshot location")
    records = json.loads((snapshot / "snapshot.json").read_text())
    allowed = {DECK, PREVIEWS / "previews.json"}
    allowed.update(PREVIEWS / (p + ".webp") for p in
                   ("sayconlun", "caelestia", "end4", "ambxst", "dms", "noctalia",
                    "serpantinum", "tsugumori", "jaqc", "clavis", "nixri"))
    restorations = []
    for record in records:
        path = Path(record["path"])
        if path not in allowed or path.is_symlink():
            raise ValueError(f"Unexpected rollback target: {path}")
        if not path.is_file() or digest(path.read_bytes()) != record["installed_sha256"]:
            raise ValueError(f"File changed after installation; refusing to overwrite: {path}")
        backup = snapshot / record["backup"]
        if backup.parent != snapshot:
            raise ValueError("Invalid backup filename")
        restorations.append((path, backup.read_bytes() if record["present"] else None))
    for path, data in restorations:
        if data is None:
            path.unlink()
        else:
            atomic_write(path, data)
    (STATE / "latest").unlink()
    print("ROLLED BACK: previous Sumi Deck and preview files restored")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group(required=True)
    modes.add_argument("--check", action="store_true")
    modes.add_argument("--install", action="store_true")
    modes.add_argument("--rollback", action="store_true")
    args = parser.parse_args()
    try:
        if args.install:
            install()
        elif args.rollback:
            rollback()
        else:
            preflight()
    except (ValueError, OSError, subprocess.CalledProcessError) as exc:
        raise SystemExit(f"ERROR: {exc}")


if __name__ == "__main__":
    main()
