"""Small, payload-independent configuration snapshot and guarded restore tool."""
from __future__ import annotations
import hashlib
import json
import os
from pathlib import Path
import shutil
import stat
import uuid

from core import SetupError, no_symlink_parents, relative_path, sha256


def fingerprint(path):
    if path.is_symlink():
        return {"kind": "symlink", "target": os.readlink(path)}
    if not path.exists():
        return {"kind": "absent"}
    if path.is_file():
        return {"kind": "file", "sha256": sha256(path), "mode": stat.S_IMODE(path.stat().st_mode)}
    if not path.is_dir():
        raise SetupError("Unsupported configuration object: " + str(path))
    records = []
    for item in sorted(path.rglob("*")):
        # rglob does not recurse through directory symlinks.
        if item.is_symlink():
            record = {"kind": "symlink", "target": os.readlink(item)}
        elif item.is_file():
            record = fingerprint(item)
        elif item.is_dir():
            record = {"kind": "directory", "mode": stat.S_IMODE(item.stat().st_mode)}
        else:
            raise SetupError("Unsupported configuration object: " + str(item))
        records.append([item.relative_to(path).as_posix(), record])
    digest = hashlib.sha256(json.dumps(records, sort_keys=True).encode()).hexdigest()
    return {"kind": "directory", "sha256": digest, "mode": stat.S_IMODE(path.stat().st_mode)}


def copy_object(source, destination):
    if source.is_symlink():
        destination.symlink_to(os.readlink(source))
    elif source.is_dir():
        shutil.copytree(source, destination, symlinks=True)
    else:
        shutil.copy2(source, destination)


def write_json(path, data):
    temporary = path.with_name(path.name + ".new")
    no_symlink_parents(temporary)
    temporary.write_text(json.dumps(data, indent=2) + "\n")
    temporary.chmod(0o600)
    os.replace(temporary, path)


def root_for(home):
    root = home / ".local/share/huzaifah-multi-rice/v6-installations"
    no_symlink_parents(root)
    root.mkdir(parents=True, exist_ok=True, mode=0o700)
    return root


def valid_paths(paths):
    result = [str(relative_path(x)) for x in paths]
    if len(set(result)) != len(result):
        raise SetupError("Duplicate managed configuration paths.")
    for index, a in enumerate(result):
        if a.startswith((".local/share/huzaifah-multi-rice/", "Pictures/", ".cache/")):
            raise SetupError("Recovery data, wallpapers and caches cannot be managed configuration.")
        for b in result[index + 1:]:
            if a.startswith(b + "/") or b.startswith(a + "/"):
                raise SetupError("Managed configuration paths overlap.")
    return result


def snapshot(home, paths):
    home = home.resolve()
    paths = valid_paths(paths)
    root = root_for(home) / uuid.uuid4().hex
    root.mkdir(mode=0o700)
    (root / "before").mkdir()
    receipt = {"schema": 1, "version": "6.0.0", "home": str(home), "status": "preparing", "paths": []}
    for index, relative in enumerate(paths):
        source = home / relative
        no_symlink_parents(source.parent)
        before = fingerprint(source)
        backup = f"before/{index:04d}"
        if before["kind"] != "absent":
            copy_object(source, root / backup)
            if fingerprint(root / backup) != before or fingerprint(source) != before:
                raise SetupError("Configuration changed during backup: " + relative)
        receipt["paths"].append({"path": relative, "backup": backup, "before": before})
    receipt["status"] = "prepared"
    write_json(root / "receipt.json", receipt)
    return root / "receipt.json"


def finalize(receipt_path):
    receipt = json.loads(receipt_path.read_text())
    if receipt["status"] != "prepared":
        raise SetupError("Backup is not ready for finalization.")
    home = Path(receipt["home"])
    for entry in receipt["paths"]:
        entry["installed"] = fingerprint(home / entry["path"])
    receipt["status"] = "installed"
    write_json(receipt_path, receipt)
    return receipt_path


def inspect_receipt(receipt_path, home):
    home = home.resolve()
    root = root_for(home)
    path = Path(receipt_path).absolute()
    if path.parent.parent != root or path.name != "receipt.json":
        raise SetupError("Select a receipt from this user's v6 installation records.")
    no_symlink_parents(path)
    receipt = json.loads(path.read_text())
    if receipt.get("schema") != 1 or receipt.get("version") != "6.0.0" or receipt.get("home") != str(home):
        raise SetupError("The receipt belongs to a different version or user.")
    if receipt.get("status") != "installed":
        raise SetupError("The installation receipt is not ready for restoration.")
    valid_paths([entry["path"] for entry in receipt["paths"]])
    conflicts = []
    for index, entry in enumerate(receipt["paths"]):
        if entry.get("backup") != f"before/{index:04d}":
            raise SetupError("Invalid backup location.")
        current = home / entry["path"]
        no_symlink_parents(current.parent)
        backup = path.parent / entry["backup"]
        no_symlink_parents(backup.parent)
        if fingerprint(backup) != entry["before"]:
            raise SetupError("The backup is missing or corrupt: " + entry["path"])
        if fingerprint(current) != entry.get("installed"):
            conflicts.append(entry["path"])
    return receipt, conflicts


def restore(receipt_path, home, callback):
    receipt_path = Path(receipt_path).absolute()
    receipt, conflicts = inspect_receipt(receipt_path, home)
    if conflicts:
        raise SetupError("Configurations changed after installation; restore was stopped to preserve them:\n" + "\n".join(conflicts))
    recovery = receipt_path.parent / ("replaced-" + uuid.uuid4().hex)
    recovery.mkdir(mode=0o700)
    completed = []
    try:
        # Stage every valid backup before changing the first configuration.
        for index, entry in enumerate(receipt["paths"]):
            if entry["before"]["kind"] != "absent":
                copy_object(receipt_path.parent / entry["backup"], recovery / f"stage-{index:04d}")
        for index, entry in enumerate(receipt["paths"]):
            current = home / entry["path"]
            current.parent.mkdir(parents=True, exist_ok=True)
            saved = recovery / f"installed-{index:04d}"
            if fingerprint(current) != entry["installed"]:
                raise SetupError("Configuration changed during restore: " + entry["path"])
            if current.exists() or current.is_symlink():
                # These locations are both in HOME. Refuse cross-device moves
                # rather than silently deleting/copying during rollback.
                os.rename(current, saved)
            completed.append((current, saved, recovery / f"stage-{index:04d}"))
            if entry["before"]["kind"] != "absent":
                os.rename(recovery / f"stage-{index:04d}", current)
            callback({"protocol": 1, "stage": "restore", "message": entry["path"],
                      "completed": index + 1, "total": len(receipt["paths"])})
    except Exception:
        for current, saved, stage in reversed(completed):
            if current.exists() or current.is_symlink():
                os.rename(current, stage)
            if saved.exists() or saved.is_symlink():
                os.rename(saved, current)
        raise
    receipt["status"] = "restored"
    receipt["retained_installed_configuration"] = str(recovery)
    write_json(receipt_path, receipt)
    return {"receipt": str(receipt_path), "retained": str(recovery),
            "message": "User configuration restored. Packages and system configuration were retained."}
