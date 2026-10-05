"""Coordinate payload-independent user and system configuration recovery."""
import json
import os
from pathlib import Path
import subprocess
import uuid

from core import SetupError, no_symlink_parents, external_environment
from maintenance import copy_object, fingerprint, inspect_receipt, restore, write_json

HELPER = Path("/usr/local/lib/huzaifah-multi-rice-v6/system_transaction.py")


def call_system(action, receipt_path, identifier, home, callback):
    no_symlink_parents(HELPER)
    if not HELPER.is_file() or HELPER.stat().st_uid != 0 or HELPER.stat().st_mode & 0o022:
        raise SetupError("The retained system recovery helper is unavailable or is not root-owned.")
    request = receipt_path.parent / "restore-system-request.json"
    write_json(request, {"uid": os.getuid(), "home": str(home), "system_id": identifier})
    process = subprocess.Popen(["/usr/bin/pkexec", "/usr/bin/python3", str(HELPER), action, str(request)],
                               stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                               text=True, env=external_environment())
    result = None
    for line in process.stdout:
        try:
            event = json.loads(line)
        except ValueError:
            event = {"protocol": 1, "stage": "authentication", "message": line.rstrip()}
        callback(event)
        if event.get("result") == "system-complete":
            result = event
    if process.wait() or not result:
        raise SetupError("System recovery stopped. Configuration and backups were retained.")
    if result.get("conflicts"):
        raise SetupError("Edited system files retained: " + ", ".join(result["conflicts"]))
    return result


def undo_user_restore(receipt_path, home):
    receipt = json.loads(receipt_path.read_text())
    retained = Path(receipt["retained_installed_configuration"])
    if (receipt["status"] != "restored" or retained.parent != receipt_path.parent or
        not retained.name.startswith("replaced-")):
        raise SetupError("Invalid coordinated recovery state.")
    no_symlink_parents(retained)
    for index, entry in enumerate(receipt["paths"]):
        if fingerprint(home / entry["path"]) != entry["before"]:
            raise SetupError("Configuration changed during coordinated recovery: " + entry["path"])
        if fingerprint(retained / f"installed-{index:04d}") != entry["installed"]:
            raise SetupError("Retained installed configuration is missing or corrupt.")
    moved = []
    try:
        for index, entry in enumerate(receipt["paths"]):
            current = home / entry["path"]
            held = retained / ("previous-" + uuid.uuid4().hex)
            if current.exists() or current.is_symlink():
                os.rename(current, held)
            moved.append((current, held))
            installed = retained / f"installed-{index:04d}"
            if installed.exists() or installed.is_symlink():
                copy_object(installed, current)
        receipt["status"] = "installed"
        write_json(receipt_path, receipt)
    except Exception:
        for current, held in reversed(moved):
            if current.exists() or current.is_symlink():
                os.rename(current, retained / ("undo-failed-" + uuid.uuid4().hex))
            if held.exists() or held.is_symlink():
                os.rename(held, current)
        raise


def restore_installation(receipt_path, home, callback, system=call_system):
    receipt_path = Path(receipt_path).absolute()
    receipt, conflicts = inspect_receipt(receipt_path, home)
    if conflicts:
        raise SetupError("Edited user configuration retained: " + ", ".join(conflicts))
    identifier = receipt.get("system_id")
    if identifier:
        system("inspect", receipt_path, identifier, home, callback)
    result = restore(receipt_path, home, callback)
    if identifier:
        try:
            system("restore", receipt_path, identifier, home, callback)
        except Exception:
            undo_user_restore(receipt_path, home)
            raise
    result["message"] = ("User and system desktop configuration restored. Packages were retained."
                         if identifier else "User configuration restored. Packages and system settings were retained.")
    return result
