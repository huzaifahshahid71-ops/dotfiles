"""Optional theme configuration through the installed, fixed GRUB helper."""
import os
from pathlib import Path
import stat
import subprocess

from core import SetupError, external_environment, no_symlink_parents
from maintenance import write_json

THEMES = (("ayanami", "Ayanami"), ("soryu", "Soryu"), ("penpen", "Pen-Pen"),
          ("seele", "SEELE"), ("eva01", "EVA-01"), ("wunder", "Wunder"),
          ("eva02", "EVA-02"), ("ramiel", "Ramiel"))
HELPER = Path("/usr/local/libexec/multi-rice-grub.py")


def available():
    return Path("/usr/bin/grub-mkconfig").is_file() and Path("/boot/grub/grub.cfg").is_file()


def apply_theme(identifier, callback, run=subprocess.run):
    if identifier not in dict(THEMES):
        raise SetupError("Unregistered GRUB theme.")
    if not available():
        raise SetupError("An existing GRUB installation is required for theme configuration.")
    no_symlink_parents(HELPER)
    info = HELPER.stat()
    if not stat.S_ISREG(info.st_mode) or info.st_uid != 0 or info.st_mode & 0o022:
        raise SetupError("The installed GRUB helper is not a trusted root-owned file.")
    callback({"stage": "grub", "message": "Authenticate to apply the selected GRUB theme…"})
    result = run(["/usr/bin/pkexec", "/usr/bin/python3", "-B", "-I", str(HELPER), "select", identifier],
                 stdin=subprocess.DEVNULL, capture_output=True, text=True,
                 env=external_environment(), timeout=240)
    message = (result.stdout + result.stderr).strip()[-3000:]
    if result.returncode:
        raise SetupError(message or "GRUB theme configuration did not complete.")
    callback({"stage": "grub", "message": message or "GRUB theme configured for the next boot."})
    return {"status": "configured", "theme": identifier, "message": message,
            "restore": "Use Sumi Deck → GRUB THEMES → Restore previous."}


def install_with_theme(install_desktop, identifier, callback, apply=apply_theme):
    # Validate before the desktop transaction. An optional GRUB failure must not
    # send a completed desktop installation back to its install button.
    if identifier and identifier not in dict(THEMES):
        raise SetupError("Unregistered GRUB theme.")
    result = dict(install_desktop(callback))
    outcome = {"status": "retained", "message": "Existing GRUB appearance retained."}
    if identifier:
        try:
            outcome = apply(identifier, callback)
        except (OSError, ValueError, SetupError, subprocess.SubprocessError) as error:
            outcome = {"status": "failed", "theme": identifier, "message": str(error)}
            callback({"stage": "grub", "message": "Desktop installed. GRUB theme step failed: " + str(error)})
    result["grub"] = outcome
    # Keep GRUB's separate recovery information beside the desktop receipt.
    if identifier:
        try:
            write_json(Path(result["receipt"]).parent / "grub-setup.json", outcome)
        except OSError as error:
            callback({"stage": "grub", "message": "Could not save the GRUB step report: " + str(error)})
    return result
