"""Single-window payload installation: validated plan, native auth, receipts."""
import argparse
import json
import os
from pathlib import Path
import pwd
import re
import shutil
import subprocess
import sys
import tempfile
import time
import uuid

from core import PROFILES, SetupError, no_symlink_parents, relative_path, sha256
from maintenance import copy_object, fingerprint, finalize, snapshot, write_json, restore
from staging import HOME_TOKEN, USER_TOKEN


def event(message, stage="install", **extra):
    print(json.dumps({"protocol": 1, "stage": stage, "message": message, **extra}), flush=True)


def command(arguments, stage="validate", environment=None):
    process = subprocess.Popen(arguments, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, text=True, env=environment)
    for line in process.stdout:
        event(line.rstrip(), stage)
    if process.wait():
        raise SetupError("Operation failed: " + str(arguments[0]))


def system_call(action, request, helper, callback=event):
    request_path = request["request_path"]
    write_json(request_path, {key: value for key, value in request.items() if key != "request_path"})
    process = subprocess.Popen(["/usr/bin/pkexec", "/usr/bin/python3", str(helper), action, str(request_path)],
                               stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    result = None
    failure = None
    for line in process.stdout:
        try:
            record = json.loads(line)
        except ValueError:
            callback(line.rstrip(), "authentication")
            continue
        if not isinstance(record, dict) or record.get("protocol") != 1:
            raise SetupError("Invalid system progress record.")
        callback(record.get("message", "System operation"), record.get("stage", "system"),
                 **{key: value for key, value in record.items() if key not in ("protocol", "message", "stage")})
        if record.get("result") == "system-complete":
            result = record
        if record.get("result") == "failed" or record.get("severity") == "error":
            failure = record.get("message")
    if process.wait() or not result:
        raise SetupError((failure or "System operation did not complete.") + " Backups were retained.")
    return result


def validate_plan(payload, home):
    plan = json.loads((payload / "plan.json").read_text())
    if plan.get("schema") != 1 or plan.get("version") != "6.0.0" or plan.get("profiles") != PROFILES:
        raise SetupError("The payload plan does not describe the twelve-profile release.")
    files = plan["user_files"]
    paths = [str(relative_path(record["path"])) for record in files] + [str(relative_path(x["path"])) for x in plan["user_links"]]
    from maintenance import valid_paths
    valid_paths(paths)
    for record in files:
        source = payload / str(relative_path(record["source"]))
        no_symlink_parents(source)
        if not source.is_file() or source.stat().st_size != record["bytes"] or sha256(source) != record["sha256"]:
            raise SetupError("User source verification failed: " + record["path"])
        if record["mode"] not in (0o644, 0o755):
            raise SetupError("Unsupported user source mode.")
    # Templates are generated code containing a literal home pathname. Reject
    # nonstandard shell metacharacters instead of interpolating them into code.
    if not re.fullmatch(r"/[A-Za-z0-9_./-]+", str(home)):
        raise SetupError("This installer currently requires a home path without spaces or shell metacharacters.")
    for link in plan["user_links"]:
        target = link["target"].replace(HOME_TOKEN, str(home))
        if not Path(target).is_absolute() or not Path(target).is_relative_to(home):
            raise SetupError("A user discovery link points outside the user's home.")
        if link['path'] in ('.config/hypr','.config/niri'):
            raise SetupError('Selected compositor links are managed by the transaction, not the payload.')
    if plan.get('private_python') and plan['private_python'].get('abi') != sys.implementation.cache_tag:
        raise SetupError('The candidate private Python extension ABI differs from this system Python.')
    return plan


def validate_native(payload, plan, callback=event, run=subprocess.run):
    """Resolve dependencies through the system loader without running binaries."""
    loader = Path("/usr/lib/ld-linux-x86-64.so.2")
    if not loader.is_file():
        raise SetupError("The system x86_64 dynamic linker is missing.")
    checked, seen, failures = 0, set(), []
    # clavis-shell adds these directories to LD_LIBRARY_PATH at launch. Use
    # the same verified payload libraries while checking the staged runtime;
    # never borrow another profile's modules or existing home configuration.
    clavis_prefix = ".local/share/desktop-profiles/clavis/"
    qml_prefix = clavis_prefix + "support/qml/Clavis/"
    clavis_libraries = ":".join(sorted({str((payload / r["source"]).parent)
        for r in plan["user_files"] if r["path"].startswith(qml_prefix)
        and r["path"].endswith(".so")}))
    deadline = time.monotonic() + 180
    for record in plan["user_files"]:
        source = payload / record["source"]
        with source.open("rb") as stream:
            header = stream.read(64)
            if len(header) < 64 or header[:6] != b"\x7fELF\x02\x01" or int.from_bytes(header[16:18], "little") not in (2, 3):
                continue
            table = int.from_bytes(header[32:40], "little")
            entry_size = int.from_bytes(header[54:56], "little")
            count = int.from_bytes(header[56:58], "little")
            if count > 4096 or (count and entry_size < 56):
                raise SetupError("Malformed native ELF program table: " + record["path"])
            needed = False
            for index in range(count):
                stream.seek(table + index * entry_size)
                entry = stream.read(56)
                if len(entry) != 56:
                    raise SetupError("Truncated native ELF program table: " + record["path"])
                if int.from_bytes(entry[:4], "little") == 2:  # PT_DYNAMIC
                    offset = int.from_bytes(entry[8:16], "little")
                    size = int.from_bytes(entry[32:40], "little")
                    if size > 1024 * 1024 or size % 16:
                        raise SetupError("Malformed native ELF dynamic table: " + record["path"])
                    stream.seek(offset)
                    dynamic = stream.read(size)
                    if len(dynamic) != size:
                        raise SetupError("Truncated native ELF dynamic table: " + record["path"])
                    needed = any(int.from_bytes(dynamic[i:i+8], "little") == 1 for i in range(0, size, 16))
            if not needed:
                continue
        # ELF64 little-endian shared objects/executables only; static binaries
        # have no shared object dependencies and need no loader resolution.
        identity = (record["sha256"], str(source.parent))
        if identity in seen:
            continue
        if time.monotonic() >= deadline:
            raise SetupError("Native runtime linkage check exceeded three minutes; desktop configuration was not replaced.")
        seen.add(identity)
        arguments = [str(loader), "--list"]
        if record["path"].startswith(clavis_prefix) and clavis_libraries:
            arguments += ["--library-path", clavis_libraries]
        arguments.append(str(source))
        try:
            result = run(arguments, stdin=subprocess.DEVNULL,
                         capture_output=True, text=True, timeout=min(30, max(1, deadline-time.monotonic())))
        except subprocess.TimeoutExpired as error:
            raise SetupError("Native runtime linkage query timed out: " + record["path"]) from error
        checked += 1
        if result.returncode:
            failures.append(record["path"] + ": " + (result.stderr or result.stdout).strip()[-1000:])
        if checked % 20 == 0:
            callback("Checked native runtime linkage " + str(checked), "validate")
    if failures:
        raise SetupError("Native runtime libraries are incompatible; desktop configuration was not replaced:\n" +
                         "\n".join(failures[:12]))
    callback("Native runtime linkage checked: " + str(checked), "validate")


def install(payload, options, home, root_caller=system_call, callback=event, verify_runtime=True):
    if (options.get("protocol") != 1 or options.get("version") != "6.0.0" or options.get("action") != "install" or
        options.get("home") != str(home) or options.get("profiles") != list(PROFILES) or
        any(options.get(key) is not False for key in ("hardware_changes", "grub", "remove_packages"))):
        raise SetupError("Unsupported or ambiguous installation options.")
    plan = validate_plan(payload, home)
    files = [record for record in plan["user_files"] if not record.get("init") or
             not (home / record["path"]).exists()]
    links = [dict(link) for link in plan["user_links"]]
    active_path = home / ".config/desktop-profile/active"
    selected = active_path.read_text().strip() if active_path.is_file() else "sayconlun"
    if selected not in PROFILES:
        selected = "sayconlun"
    # Existing configuration discovery is retained through the same selected
    # profile; no compositor is started or stopped by this transaction.
    links.append({"path": ".config/hypr", "target": HOME_TOKEN + "/.local/share/desktop-profiles/" +
                  (selected if list(PROFILES).index(selected) < 8 else "sayconlun") + "/hypr"})
    links.append({"path": ".config/niri", "target": HOME_TOKEN + "/.local/share/desktop-profiles/" +
                  (selected if list(PROFILES).index(selected) >= 8 else "jaqc") + "/niri"})
    paths = [record["path"] for record in files] + [record["path"] for record in links]
    inir = home / '.local/share/desktop-profiles/inir'
    colors = inir / 'home/.local/state/quickshell/user/generated/colors.json'
    if plan.get('private_python'):
        paths.append(str((inir / 'venv').relative_to(home)))
        if not colors.exists():
            paths.append(str(colors.relative_to(home)))
    if ".config/desktop-profile/active" not in paths:
        paths.append(".config/desktop-profile/active")
    receipt_path = snapshot(home, paths)
    callback("Configuration backup verified", "backup", receipt=str(receipt_path))
    request = {"home": str(home), "uid": os.getuid(), "payload": str(payload),
               "request_path": receipt_path.parent / "system-request.json"}
    system_id = None
    replacements = receipt_path.parent / "during-install"
    replacements.mkdir()
    changed = []
    try:
        result = root_caller("install", request, Path(__file__).parent / "system_transaction.py", callback)
        system_id = result["system_id"]
        data = json.loads(receipt_path.read_text())
        data["system_id"] = system_id
        write_json(receipt_path, data)
        if verify_runtime:
            validate_native(payload, plan, callback)
        for index, record in enumerate(files):
            path = home / record["path"]
            no_symlink_parents(path.parent)
            path.parent.mkdir(parents=True, exist_ok=True)
            source = payload / record["source"]
            data = source.read_bytes()
            if record.get("template"):
                data = data.replace(HOME_TOKEN.encode(), str(home).encode()).replace(USER_TOKEN.encode(), home.name.encode())
            temporary = path.with_name(path.name + ".install-" + uuid.uuid4().hex)
            temporary.write_bytes(data)
            temporary.chmod(record["mode"])
            saved = replacements / f"{len(changed):05d}"
            if path.exists() or path.is_symlink():
                os.rename(path, saved)
            changed.append((path, saved))
            os.replace(temporary, path)
            callback(record["path"], "files", completed=index + 1, total=len(files))
        for link in links:
            path = home / link["path"]
            no_symlink_parents(path.parent)
            path.parent.mkdir(parents=True, exist_ok=True)
            saved = replacements / f"{len(changed):05d}"
            if path.exists() or path.is_symlink():
                os.rename(path, saved)
            changed.append((path, saved))
            path.symlink_to(link["target"].replace(HOME_TOKEN, str(home)))
        if not active_path.is_file() or active_path.read_text().strip() != selected:
            saved = replacements / f"{len(changed):05d}"
            if active_path.exists() or active_path.is_symlink():
                os.rename(active_path, saved)
            changed.append((active_path, saved))
            active_path.parent.mkdir(parents=True, exist_ok=True)
            active_path.write_text(selected + "\n")
        if plan.get('private_python'):
            venv = inir / 'venv'
            no_symlink_parents(venv.parent)
            saved = replacements / f'{len(changed):05d}'
            if venv.exists() or venv.is_symlink():
                os.rename(venv,saved)
            changed.append((venv,saved))
            command([sys.executable,'-m','venv','--without-pip','--system-site-packages',str(venv)])
            site = venv / f'lib/python{sys.version_info.major}.{sys.version_info.minor}/site-packages'
            site.mkdir(parents=True,exist_ok=True)
            (site / 'multi-rice-eclipse.pth').write_text(str(inir / 'python') + '\n')
            command([str(venv / 'bin/python'),'-c',
                     'import importlib.metadata as m; assert m.version("materialyoucolor") == "3.0.4"'])
            if not colors.exists():
                changed.append((colors,replacements / f'{len(changed):05d}'))
                colors.parent.mkdir(parents=True,exist_ok=True)
                command([str(venv / 'bin/python'),str(inir / 'runtime/scripts/colors/generate_colors_material.py'),
                         '--color','#7c8cd8','--mode','dark','--json-output',str(colors)])
                if not isinstance(json.loads(colors.read_text()),dict):
                    raise SetupError('Eclipse initial color generation failed.')
        if verify_runtime:
            command(["/usr/bin/systemctl", "--user", "daemon-reload"])
            for profile in list(PROFILES)[8:]:
                base = home / ".local/share/desktop-profiles" / profile
                binary = base / "native/bin/niri" if profile == "clavis" else Path("/usr/bin/niri")
                config = base / ("native/niri/config.kdl" if profile == "clavis" else "niri/config.kdl")
                command([str(binary), "validate", "--config", str(config)])
        finalize(receipt_path)
        # The small launcher and artwork are managed user files in the plan,
        # so their installation and rollback participate in the same receipt.
        callback("Desktop configuration installed; reboot when ready", "complete", result="installed",
                 receipt=str(receipt_path), system_id=system_id)
        return receipt_path
    except Exception:
        # Retain every changed object. Return the previous configuration even
        # when failure happened before a complete user receipt could be finalized.
        for path, saved in reversed(changed):
            if path.exists() or path.is_symlink():
                retained = replacements / ("failed-" + uuid.uuid4().hex)
                os.rename(path, retained)
            if saved.exists() or saved.is_symlink():
                os.rename(saved, path)
        if system_id:
            request["system_id"] = system_id
            root_caller("restore", request, Path(__file__).parent / "system_transaction.py", callback)
        receipt = json.loads(receipt_path.read_text())
        receipt["status"] = "failed"
        write_json(receipt_path, receipt)
        raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("options", type=Path)
    parser.add_argument("--payload", type=Path, required=True)
    args = parser.parse_args()
    home = Path(pwd.getpwuid(os.getuid()).pw_dir)
    if os.getuid() == 0 or os.environ.get("HOME") != str(home):
        raise SetupError("Run the installer as the desktop user in their normal home.")
    no_symlink_parents(args.options)
    options = json.loads(args.options.read_text())
    install(args.payload.resolve(strict=True), options, home)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, SetupError) as error:
        event(str(error), severity="error", result="failed")
        sys.exit(1)
