"""Root-only package/file transaction used behind the existing setup window.

The CLI always operates on /. The alternate root in the Python API exists for
disposable transaction tests and is never accepted from a request or argument.
"""
import argparse
import json
import os
from pathlib import Path
import pwd
import re
import shutil
import subprocess
import sys
import uuid

from core import SetupError, no_symlink_parents, relative_path, sha256
from maintenance import copy_object, fingerprint, write_json
import package_policy

ALLOWED = {"usr/local/bin/multi-rice-session", "usr/local/bin/ambxst", "usr/local/bin/axctl",
           "usr/share/wayland-sessions/huzaifah-multi-rice.desktop",
           "usr/local/libexec/multi-rice-sddm.py", "usr/local/share/multi-rice-sddm/catalog.json",
           "usr/local/libexec/multi-rice-grub.py", "usr/local/bin/eva", "usr/local/share/evangelion/LICENSE"}
RECOVERY = Path("var/backups/huzaifah-multi-rice/v6")
MAINTENANCE = Path("/usr/local/lib/huzaifah-multi-rice-v6")


def event(message, stage="system", **extra):
    print(json.dumps({"protocol": 1, "stage": stage, "message": message, **extra}), flush=True)


def run_lines(arguments, callback=event):
    process = subprocess.Popen(arguments, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, text=True)
    for line in process.stdout:
        callback(line.rstrip(), stage="packages")
    code = process.wait()
    if code:
        raise SetupError("System operation failed with exit status " + str(code))


def package_query(arguments):
    result = subprocess.run(["/usr/bin/pacman", *arguments], capture_output=True, text=True, check=True)
    return dict(line.split(" ", 1) for line in result.stdout.splitlines())


class SystemTransaction:
    def __init__(self, root=Path("/"), execute=run_lines, query=package_query,
                 package_database=None, archive_metadata=None):
        self.root = Path(root).resolve()
        self.execute = execute
        self.query = query
        self.package_database = package_database or (lambda: package_policy.read_database(self.root / "var/lib/pacman/local"))
        self.archive_metadata = archive_metadata or package_policy.archive_metadata

    def destination(self, relative):
        clean=relative_path(relative)
        allowed_theme=(str(clean).startswith(('usr/local/share/multi-rice-sddm/sources/','usr/local/share/multi-rice-sddm/previews/')) and len(clean.parts)>5)
        allowed_grub=(str(clean).startswith(('usr/local/share/evangelion/bin/','usr/local/share/evangelion/docs/','usr/local/share/evangelion/themes/')) and len(clean.parts)>5)
        if relative not in ALLOWED and not allowed_theme and not allowed_grub:
            raise SetupError("System path is outside the desktop installer scope: " + str(relative))
        path = self.root / relative
        no_symlink_parents(path.parent)
        return path

    def state_root(self, uid, identifier):
        if type(uid) is not int or uid <= 0 or not re.fullmatch(r"[0-9a-f]{32}", identifier):
            raise SetupError("Invalid recovery identity.")
        path = self.root / RECOVERY / str(uid) / identifier
        no_symlink_parents(path)
        return path

    def install(self, payload, plan, uid, callback=event):
        if plan.get("schema") != 1 or plan.get("version") != "6.0.0":
            raise SetupError("Unsupported system plan.")
        files, packages = plan.get("system_files", []), plan.get("packages", [])
        if not packages or not files:
            raise SetupError("The system plan is incomplete.")
        destinations = [record["path"] for record in files]
        if len(destinations) != len(set(destinations)):
            raise SetupError("Duplicate system destinations.")
        for record in files:
            self.destination(record["path"])
            if record["mode"] not in (0o644, 0o755):
                raise SetupError("Unsupported system file mode.")
        identifier = uuid.uuid4().hex
        state = self.state_root(uid, identifier)
        state.mkdir(parents=True, mode=0o700)
        state.chmod(0o700)
        (state / "before").mkdir()
        (state / "staged").mkdir()
        (state / "packages").mkdir()
        receipt = {"schema": 1, "version": "6.0.0", "uid": uid, "id": identifier,
                   "status": "prepared", "files": [], "packages_retained": True}
        # Copy into root-owned staging and verify before *any* package/file
        # mutation. Payload cache contents cannot change during the root job.
        try:
            before_packages = self.query(["-Q"])
            receipt["packages_before"] = before_packages
            installed = self.package_database()
            if {name: p["version"] for name, p in installed.items()} != before_packages:
                raise SetupError("Installed package inventory changed during preparation.")
            needed, retained, aliases = package_policy.select(packages, installed)
            needed_names = {record["name"] for record in needed}
            receipt["packages_reused"] = retained
            receipt["package_aliases"] = aliases
            callback(f"Reuse {len(retained)} installed packages; add {len(needed)} missing packages")
            for target, provider in aliases.items():
                callback("Reuse installed Aether provider " + provider + " for " + target)
            for index, record in enumerate(files):
                source = payload / str(relative_path(record["source"]))
                no_symlink_parents(source)
                staged = state / "staged" / f"{index:04d}"
                shutil.copyfile(source, staged)
                staged.chmod(record["mode"])
                if sha256(staged) != record["sha256"]:
                    raise SetupError("System source failed verification: " + record["path"])
                destination = self.destination(record["path"])
                before = fingerprint(destination)
                if before["kind"] == "directory":
                    raise SetupError("Expected a system file, found a directory: " + str(destination))
                if before["kind"] != "absent":
                    copy_object(destination, state / "before" / f"{index:04d}")
                receipt["files"].append({"path": record["path"], "before": before,
                                         "installed": fingerprint(staged)})
            archives = []
            proposed = []
            for index, record in enumerate(packages, 1):
                name = record["name"]
                if ((name.startswith("linux-") and name != "linux-api-headers") or
                    name in ("linux", "linux-lts", "nvidia", "nvidia-open", "nvidia-dkms", "nvidia-open-dkms")):
                    raise SetupError("Kernel/driver changes are outside desktop setup: " + name)
                if name not in needed_names:
                    continue
                source = payload / str(relative_path(record["source"]))
                no_symlink_parents(source)
                if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.+:-]*\.pkg\.tar\.(zst|xz|gz)", source.name):
                    raise SetupError("Invalid package archive name.")
                staged = state / "packages" / source.name
                if staged.exists():
                    raise SetupError("Duplicate package archive.")
                shutil.copyfile(source, staged)
                if staged.stat().st_size != record["bytes"] or sha256(staged) != record["sha256"]:
                    raise SetupError("Package failed verification: " + source.name)
                metadata = self.query(["-Qp", str(staged)])
                if metadata != {record["name"]: record["version"]}:
                    raise SetupError("Package identity differs from the plan: " + source.name)
                info = self.archive_metadata(staged)
                if info["name"] != name or info["version"] != record["version"]:
                    raise SetupError("Archive metadata differs from the plan: " + name)
                proposed.append(info)
                archives.append(str(staged))
                callback("Verified missing package " + source.name, completed=len(archives), total=len(needed))
            package_policy.validate(proposed, installed)
            write_json(state / "receipt.json", receipt)
            # Direct local archive install: no sync database refresh, online
            # repository or shell prompt. Conflicts fail rather than removing
            # a provider with -Rdd. Package changes are recorded and retained.
            if self.query(["-Q"]) != before_packages:
                raise SetupError("Package inventory changed before installation; no package operation was started.")
            if archives:
                preview = self.query(["-U", "--print", "--print-format", "%n %v", "--", *archives])
                expected = {p["name"]: p["version"] for p in proposed}
                if preview != expected:
                    raise SetupError("Pacman proposed unexpected package targets; installation stopped.")
                self.execute(["/usr/bin/pacman", "-U", "--needed", "--noconfirm", "--", *archives], callback)
                receipt["packages_committed"] = True
            after_packages = self.query(["-Q"])
            package_policy.unchanged(before_packages, after_packages)
            if any(after_packages.get(p["name"]) != p["version"] for p in proposed):
                raise SetupError("Pacman did not retain all newly installed package versions.")
            receipt["packages_after"] = after_packages
            receipt["packages_added"] = sorted(set(after_packages) - set(before_packages))
            write_json(state / "receipt.json", receipt)
            for index, record in enumerate(receipt["files"]):
                destination = self.destination(record["path"])
                if fingerprint(destination) != record["before"]:
                    raise SetupError("System configuration changed while preparing: " + record["path"])
                destination.parent.mkdir(parents=True, exist_ok=True)
                temporary = destination.with_name(destination.name + ".multi-rice-" + identifier)
                no_symlink_parents(temporary)
                shutil.copy2(state / "staged" / f"{index:04d}", temporary)
                os.replace(temporary, destination)
                record["committed"] = True
                write_json(state / "receipt.json", receipt)
                callback("Installed " + record["path"], completed=index + 1, total=len(receipt["files"]))
            receipt["status"] = "installed"
            write_json(state / "receipt.json", receipt)
        except Exception:
            self.rollback_committed(state, receipt)
            receipt["status"] = "failed"
            write_json(state / "receipt.json", receipt)
            raise
        finally:
            # Recovery contains receipts/backups, not another permanent copy
            # of all downloaded packages. System package cache remains intact.
            shutil.rmtree(state / "packages", ignore_errors=True)
            shutil.rmtree(state / "staged", ignore_errors=True)
        return identifier

    def rollback_committed(self, state, receipt):
        for index in reversed(range(len(receipt["files"]))):
            record = receipt["files"][index]
            if not record.get("committed"):
                continue
            destination = self.destination(record["path"])
            if fingerprint(destination) != record["installed"]:
                raise SetupError("An installed system file changed; retained: " + record["path"])
            if record["before"]["kind"] == "absent":
                destination.unlink()
            else:
                backup = state / "before" / f"{index:04d}"
                if fingerprint(backup) != record["before"]:
                    raise SetupError("System backup is corrupt: " + record["path"])
                temporary = destination.with_name(destination.name + ".restore-" + receipt["id"])
                no_symlink_parents(temporary)
                copy_object(backup, temporary)
                os.replace(temporary, destination)
            record["committed"] = False

    def inspect(self, uid, identifier):
        state = self.state_root(uid, identifier)
        receipt_path = state / "receipt.json"
        no_symlink_parents(receipt_path)
        receipt = json.loads(receipt_path.read_text())
        if receipt.get("uid") != uid or receipt.get("id") != identifier or receipt.get("version") != "6.0.0":
            raise SetupError("System receipt identity differs.")
        if receipt.get("status") != "installed":
            raise SetupError("System receipt is not ready for restore.")
        conflicts = []
        # A reinstall may restore identical SDDM files while selection history
        # remains active. This is safe: no theme asset or manager is changed.
        # Keep the selection guard if any managed SDDM file would change/remove.
        sddm_files = [record for record in receipt['files']
                      if record['path'] == 'usr/local/libexec/multi-rice-sddm.py'
                      or record['path'].startswith('usr/local/share/multi-rice-sddm/')]
        if (any(record['path'] == 'usr/local/share/multi-rice-sddm/catalog.json'
                for record in sddm_files)
                and any(record['before'] != record['installed'] for record in sddm_files)
                and (self.root/'usr/local/share/multi-rice-sddm/selected.json').exists()):
            conflicts.append('Login theme selection: restore the prior login selection before changing or removing its managed theme files')
        if any(record['path']=='usr/local/bin/eva' and record['before'].get('kind')=='absent' for record in receipt['files']) and (self.root/'var/lib/evangelion-grub/state.json').exists():
            conflicts.append('GRUB selection: restore the prior GRUB appearance with sudo eva uninstall before removing its manager')
        for index, record in enumerate(receipt["files"]):
            destination = self.destination(record["path"])
            if fingerprint(state / "before" / f"{index:04d}") != record["before"]:
                raise SetupError("System backup is missing or corrupt: " + record["path"])
            if fingerprint(destination) != record["installed"]:
                conflicts.append(record["path"])
        return state, receipt, conflicts

    def restore(self, uid, identifier, callback=event):
        state, receipt, conflicts = self.inspect(uid, identifier)
        if conflicts:
            raise SetupError("Edited system files retained; restore stopped: " + ", ".join(conflicts))
        # Retain the installed root files as well. A disk/full/permission error
        # after one restored file can then roll the operation back.
        retained = state / ("replaced-" + uuid.uuid4().hex)
        retained.mkdir(mode=0o700)
        for index, record in enumerate(receipt["files"]):
            copy_object(self.destination(record["path"]), retained / f"{index:04d}")
        completed = []
        try:
            for index, record in enumerate(receipt["files"]):
                destination = self.destination(record["path"])
                if fingerprint(destination) != record["installed"]:
                    raise SetupError("System file changed during restore: " + record["path"])
                completed.append(index)
                if record["before"]["kind"] == "absent":
                    destination.unlink()
                else:
                    temporary = destination.with_name(destination.name + ".restore-" + identifier)
                    no_symlink_parents(temporary)
                    copy_object(state / "before" / f"{index:04d}", temporary)
                    os.replace(temporary, destination)
                callback("Restored " + record["path"], completed=index + 1, total=len(receipt["files"]))
            receipt["status"] = "restored"
            write_json(state / "receipt.json", receipt)
        except Exception:
            for index in reversed(completed):
                destination = self.destination(receipt["files"][index]["path"])
                temporary = destination.with_name(destination.name + ".rollback-" + identifier)
                no_symlink_parents(temporary)
                copy_object(retained / f"{index:04d}", temporary)
                os.replace(temporary, destination)
            raise
        return {"id": identifier, "packages_retained": True}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("install", "inspect", "restore"))
    parser.add_argument("request", type=Path)
    args = parser.parse_args()
    if os.getuid() != 0:
        raise SetupError("System operations require the native authentication prompt.")
    uid = int(os.environ.get("PKEXEC_UID", "0"))
    if uid <= 0:
        raise SetupError("Launch system setup through Polkit as the desktop user.")
    user = pwd.getpwuid(uid)
    no_symlink_parents(args.request)
    request = json.loads(args.request.read_text())
    if request.get("home") != user.pw_dir or request.get("uid") != uid:
        raise SetupError("The request belongs to another desktop user.")
    transaction = SystemTransaction()
    if args.action == "install":
        payload = Path(request["payload"]).resolve(strict=True)
        plan = json.loads((payload / "plan.json").read_text())
        # Retain the small privileged recovery module outside all downloadable
        # cache and configuration rollback paths. Root owns the retained code.
        no_symlink_parents(MAINTENANCE)
        MAINTENANCE.mkdir(parents=True, exist_ok=True)
        MAINTENANCE.chmod(0o755)
        for name in ("core.py", "maintenance.py", "package_policy.py", "system_transaction.py"):
            source = Path(__file__).resolve().parent / name
            temporary = MAINTENANCE / (name + ".new")
            no_symlink_parents(temporary)
            shutil.copyfile(source, temporary)
            temporary.chmod(0o644)
            os.replace(temporary, MAINTENANCE / name)
        # Prepare recovery before changing any package or session route, so a
        # failed maintenance copy cannot leave an unreported system transaction.
        result = {"system_id": transaction.install(payload, plan, uid)}
    elif args.action == "inspect":
        _, _, conflicts = transaction.inspect(uid, request["system_id"])
        result = {"system_id": request["system_id"], "conflicts": conflicts}
    else:
        result = transaction.restore(uid, request["system_id"])
    event("System operation complete", result="system-complete", **result)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, SetupError) as error:
        event(str(error), severity="error", result="failed")
        sys.exit(1)
