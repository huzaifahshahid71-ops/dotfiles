#!/usr/bin/env python3
"""Restore omitted Crimson UI sources in CachyVM and retain build inputs."""
import argparse
import ast
import base64
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import shlex
import subprocess
import sys
import time
import zipfile

MODULE = "modules/widgets/dashboard/wallpapers/"
PREFIX = ".local/src/ambxst/"
ANCHORS = {
    "shell.qml": "e2e82efb68cdc61a1c75e22bf9b3ed91d46b829b497bc3714c97ba85861f07cc",
    "cli.sh": "355e08bd24fec08770d568904ee7a7521bfc4da750ae6d1578face5d611276b2",
}
EXTENSIONS = {".qml", ".js", ".mjs", ".qsb", ".frag", ".vert", ".glsl", ".svg", ".png", ".webp"}
MARKER = "CRIMSON_INSTALL_V1:"
FILTER_MARKER = "# Multi-Rice: preserve Crimson wallpaper-picker UI sources"

def digest(data):
    return hashlib.sha256(data).hexdigest()

def ui_source(relative):
    p = PurePosixPath(relative)
    return (relative.startswith(MODULE) and not {"..", ".git", "cache", "state", "backup", "backups", "tests"}.intersection(p.parts)
            and (p.suffix.lower() in EXTENSIONS or p.name == "qmldir")
            and not any(x in p.name for x in (".before-", ".bak", ".backup", ".old", ".orig")))

def filter_patch(source):
    if FILTER_MARKER in source:
        compile(source, "assemble-candidate.py", "exec")
        return source
    tree = ast.parse(source)
    functions = [n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == "production_path"]
    if len(functions) != 1 or [a.arg for a in functions[0].args.args] != ["relative"]:
        raise RuntimeError("Unknown assembler source; it was retained")
    function = functions[0]
    if not any(isinstance(n, ast.Call) and isinstance(n.func, ast.Name) and n.func.id == "relative_path" for n in ast.walk(function)):
        raise RuntimeError("Assembler path validation differs; source was retained")
    # This changes only the local classifier input. Actual payload paths remain
    # unchanged, and the existing cache/backup filters still run afterward.
    block = '''    # Multi-Rice: preserve Crimson wallpaper-picker UI sources
    from pathlib import PurePosixPath as _CrimsonPath
    _crimson_path = _CrimsonPath(relative)
    if relative.startswith("modules/widgets/dashboard/wallpapers/") and (
        _crimson_path.suffix.lower() in {".qml", ".js", ".mjs", ".qsb", ".frag", ".vert", ".glsl", ".svg", ".png", ".webp"}
        or _crimson_path.name == "qmldir"
    ):
        relative = relative.replace("/wallpapers/", "/wallpaper-ui/", 1)
'''
    insertion = function.body[0].lineno - 1
    if isinstance(function.body[0], ast.Expr) and isinstance(function.body[0].value, ast.Constant) and isinstance(function.body[0].value.value, str):
        insertion = function.body[0].end_lineno
    lines = source.splitlines(keepends=True)
    lines.insert(insertion, block)
    result = "".join(lines)
    compile(result, "assemble-candidate.py", "exec")
    return result

def bundle(source):
    source = Path(source)
    for name, expected in ANCHORS.items():
        if digest((source / name).read_bytes()) != expected:
            raise RuntimeError("Host Crimson source differs from the diagnosed VM: " + name + ". No VM files were changed.")
    root = source / MODULE
    if root.is_symlink() or not root.is_dir():
        raise RuntimeError("Working host Crimson wallpaper-picker source was not found: " + str(root))
    files = {}
    for path in sorted(root.rglob("*")):
        if path.is_symlink():
            raise RuntimeError("Source symlink was retained: " + str(path))
        if path.is_file() and ui_source(path.relative_to(source).as_posix()):
            data = path.read_bytes()
            if len(data) > 2 * 1024**2:
                raise RuntimeError("UI source exceeds the size limit: " + str(path))
            files[PREFIX + path.relative_to(source).as_posix()] = data
    if not files or not any(p.endswith(".qml") for p in files):
        raise RuntimeError("Host wallpaper-picker module has no QML sources")
    if sum(map(len, files.values())) > 8 * 1024**2:
        raise RuntimeError("UI source bundle exceeds 8 MiB")
    records = [{"path": p, "source": "home/" + p, "bytes": len(data), "sha256": digest(data), "mode": 0o644, "template": False, "init": False} for p, data in files.items()]
    manifest = {"schema": 1, "kind": "crimson-wallpaper-ui", "anchors": ANCHORS, "files": records}
    output = io.BytesIO()
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as z:
        for row in records:
            entry = zipfile.ZipInfo(row["source"], (1980, 1, 1, 0, 0, 0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            entry.external_attr = (0o100644 << 16)
            z.writestr(entry, files[row["path"]])
        entry = zipfile.ZipInfo("manifest.json", (1980, 1, 1, 0, 0, 0))
        entry.compress_type = zipfile.ZIP_DEFLATED
        z.writestr(entry, json.dumps(manifest, indent=2) + "\n")
    return output.getvalue(), manifest

INSTALL = r'''
import hashlib, io, json, os, tempfile, zipfile
from pathlib import Path, PurePosixPath
home = Path.home()
prefix = ".local/src/ambxst/modules/widgets/dashboard/wallpapers/"
def sha(data): return hashlib.sha256(data).hexdigest()
def safe(path):
    path.relative_to(home)
    for part in (path, *path.parents):
        if part == home.parent: break
        if part.is_symlink(): raise RuntimeError("Existing symlink preserved: " + str(part))
archive = Path(ARCHIVE)
raw = archive.read_bytes()
if sha(raw) != EXPECTED: raise RuntimeError("Transferred UI archive checksum differs")
active = home / ".config/desktop-profile/active"
if not active.is_file() or active.read_text().strip() != "ambxst":
    raise RuntimeError("Select Crimson before repairing its UI sources")
checked = []
with zipfile.ZipFile(io.BytesIO(raw)) as z:
    names = z.namelist()
    if len(names) != len(set(names)): raise RuntimeError("Duplicate archive member")
    manifest = json.loads(z.read("manifest.json"))
    if manifest.get("schema") != 1 or manifest.get("kind") != "crimson-wallpaper-ui" or manifest.get("anchors") != ANCHORS:
        raise RuntimeError("Unreviewed Crimson archive manifest")
    for name, expected in ANCHORS.items():
        target = home / ".local/src/ambxst" / name
        safe(target)
        if sha(target.read_bytes()) != expected:
            raise RuntimeError("VM Crimson source changed: " + name)
    expected_names = {"manifest.json"}
    paths = set()
    total = 0
    for row in manifest["files"]:
        relative = row["path"]
        parts = PurePosixPath(relative)
        if (not relative.startswith(prefix) or parts.is_absolute() or ".." in parts.parts
            or relative != parts.as_posix() or relative in paths or row.get("source") != "home/" + relative
            or row.get("mode") != 0o644
            or {".git", "cache", "state", "backup", "backups", "tests"}.intersection(parts.parts)
            or any(x in parts.name for x in (".before-", ".bak", ".backup", ".old", ".orig"))
            or not (parts.suffix.lower() in {".qml", ".js", ".mjs", ".qsb", ".frag", ".vert", ".glsl", ".svg", ".png", ".webp"} or parts.name == "qmldir")):
            raise RuntimeError("Unreviewed archive path")
        paths.add(relative)
        info = z.getinfo(row["source"])
        if info.file_size > 2 * 1024**2 or info.file_size != row["bytes"]:
            raise RuntimeError("Source size differs: " + relative)
        total += info.file_size
        if total > 8 * 1024**2: raise RuntimeError("UI archive exceeds size limit")
        if (info.external_attr >> 16) & 0o170000 == 0o120000:
            raise RuntimeError("Archive symlink refused")
        data = z.read(info)
        if sha(data) != row["sha256"]: raise RuntimeError("Source checksum differs: " + relative)
        target = home / relative
        safe(target)
        if target.exists() and (not target.is_file() or sha(target.read_bytes()) != row["sha256"]):
            raise RuntimeError("Different existing file retained: " + relative)
        checked.append((row, data, target))
        expected_names.add(row["source"])
    if set(names) != expected_names or not checked: raise RuntimeError("Archive contains unexpected or missing sources")
receipt = home / ".local/share/huzaifah-multi-rice/crimson-repairs" / EXPECTED[:20] / "receipt.json"
safe(receipt)
receipt.parent.mkdir(parents=True, exist_ok=True)
previous = json.loads(receipt.read_text()) if receipt.is_file() else {}
if previous and (previous.get("schema") != 1 or previous.get("archive_sha256") != EXPECTED):
    raise RuntimeError("Different repair receipt retained")
created = []
try:
    for row, data, target in checked:
        if target.exists(): continue
        safe(target)
        target.parent.mkdir(parents=True, exist_ok=True)
        safe(target)
        temporary = None
        try:
            with tempfile.NamedTemporaryFile(dir=target.parent, prefix=".crimson-", delete=False) as out:
                temporary = Path(out.name)
                out.write(data); out.flush(); os.fchmod(out.fileno(), 0o644); os.fsync(out.fileno())
            safe(target)
            os.link(temporary, target)  # Exclusive, complete-file creation.
            created.append(row)
        finally:
            if temporary is not None: temporary.unlink(missing_ok=True)
    saved_created = {x["path"]: x for x in previous.get("created_files", [])}
    saved_created.update({x["path"]: x for x in created})
    result = {"schema": 1, "status": "sources-added", "archive_sha256": EXPECTED, "receipt": str(receipt), "added": len(created), "verified": len(checked), "created_files": list(saved_created.values())}
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", dir=receipt.parent, prefix=".receipt-", delete=False) as out:
            temporary = Path(out.name)
            json.dump(result, out, indent=2); out.flush(); os.fsync(out.fileno())
        safe(receipt)
        os.replace(temporary, receipt)
    finally:
        if temporary is not None: temporary.unlink(missing_ok=True)
except Exception:
    for row in reversed(created):
        target = home / row["path"]
        if target.is_file() and not target.is_symlink() and sha(target.read_bytes()) == row["sha256"]:
            target.unlink()
    raise
print("CRIMSON_INSTALL_V1:" + json.dumps(result))
'''

TRANSFER = r'''
import base64, hashlib, json, os, tempfile
from pathlib import Path
if len(EXPECTED) != 64 or any(c not in "0123456789abcdef" for c in EXPECTED):
    raise RuntimeError("Unexpected transfer identity")
home = Path.home()
folder = home / ".cache/huzaifah-multi-rice/crimson-repair" / EXPECTED
for path in (folder, *folder.parents):
    if path == home.parent: break
    if path.is_symlink(): raise RuntimeError("Transfer cache symlink retained")
folder.mkdir(parents=True, exist_ok=True)
def add_complete(path, data):
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=folder, prefix=".transfer-", delete=False) as out:
            temporary = Path(out.name)
            out.write(data); out.flush(); os.fsync(out.fileno())
        os.link(temporary, path)
    finally:
        if temporary is not None: temporary.unlink(missing_ok=True)
data = base64.b64decode(DATA, validate=True)
if len(data) > 48 * 1024 or hashlib.sha256(data).hexdigest() != CHUNK_SHA:
    raise RuntimeError("Transfer chunk checksum differs")
part = folder / ("chunk-%04d" % INDEX)
if part.is_symlink(): raise RuntimeError("Transfer chunk symlink retained")
if part.exists():
    if part.read_bytes() != data: raise RuntimeError("Different cached transfer chunk retained")
else:
    add_complete(part, data)
archive = folder / "addon.zip"
if archive.is_symlink(): raise RuntimeError("Cached archive symlink retained")
if INDEX + 1 == COUNT:
    raw = b"".join((folder / ("chunk-%04d" % i)).read_bytes() for i in range(COUNT))
    if hashlib.sha256(raw).hexdigest() != EXPECTED: raise RuntimeError("Transferred archive checksum differs")
    if archive.exists():
        if archive.read_bytes() != raw: raise RuntimeError("Different cached archive retained")
    else:
        add_complete(archive, raw)
print("CRIMSON_INSTALL_V1:" + json.dumps({"archive": str(archive), "chunk": INDEX + 1, "total": COUNT}))
'''


def transfer(bridge, data):
    size = 48 * 1024
    chunks = [data[n:n + size] for n in range(0, len(data), size)]
    for index, chunk in enumerate(chunks):
        code = ("EXPECTED = " + repr(digest(data)) + "\nDATA = " + repr(base64.b64encode(chunk).decode())
                + "\nCHUNK_SHA = " + repr(digest(chunk)) + "\nINDEX = " + repr(index)
                + "\nCOUNT = " + repr(len(chunks)) + "\n" + TRANSFER)
        result = run_bridge(bridge, code)
        print("Transferred UI bundle:", index + 1, "/", len(chunks), flush=True)
    return result["archive"]

def find_prep(home, requested):
    if requested:
        root = requested.expanduser().resolve()
        if not (root / "assemble-candidate.py").is_file():
            raise RuntimeError("Build-prep folder was not found: " + str(root))
        return root
    for root in (home / "Downloads/MULTI RICE DEVELOPMENT/sumi-v6-build-prep", home / "Downloads/sumi-v6-build-prep"):
        if (root / "assemble-candidate.py").is_file(): return root
    return None

def run_bridge(bridge, code):
    result = subprocess.run([str(bridge), "python3 -c " + shlex.quote(code)], capture_output=True, text=True, timeout=50)
    payload = next((line[len(MARKER):] for line in result.stdout.splitlines() if line.startswith(MARKER)), None)
    if result.returncode or payload is None:
        raise RuntimeError((result.stderr + "\n" + result.stdout)[-6000:] or "VM did not return an installation receipt")
    return json.loads(payload)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--prep", type=Path)
    parser.add_argument("--source", type=Path, default=Path.home() / ".local/src/ambxst")
    args = parser.parse_args()
    home = Path.home()
    bridge = home / ".local/bin/vmrun-cachy"
    data, manifest = bundle(args.source.expanduser())
    identity = digest(data)
    prep = find_prep(home, args.prep)
    retained = (prep / "crimson-repair" if prep else home / "Downloads/MULTI RICE DEVELOPMENT/crimson-repair") / identity[:20]
    retained.mkdir(parents=True, exist_ok=True)
    addon = retained / "addon.zip"
    if addon.exists() and addon.read_bytes() != data: raise RuntimeError("Different retained source archive was preserved")
    addon.write_bytes(data)
    (retained / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    patched = False
    if prep:
        assembler = prep / "assemble-candidate.py"
        original = assembler.read_text()
        updated = filter_patch(original)
        if updated != original:
            backup = retained / "assemble-candidate.py.before-crimson"
            if not backup.exists(): backup.write_text(original)
            temporary = assembler.with_name("assemble-candidate.crimson-new")
            if temporary.exists() or temporary.is_symlink(): raise RuntimeError("Assembler temporary file exists; it was retained")
            temporary.write_text(updated); temporary.chmod(assembler.stat().st_mode & 0o777); os.replace(temporary, assembler)
        patched = True
    print("PREPARED:", len(manifest["files"]), "Crimson UI sources;", round(sum(r["bytes"] for r in manifest["files"]) / 1024, 1), "KiB", flush=True)
    print("Retained build inputs:", retained, flush=True)
    archive = transfer(bridge, data)
    code = "ARCHIVE = " + repr(archive) + "\nEXPECTED = " + repr(identity) + "\nANCHORS = " + repr(ANCHORS) + "\n" + INSTALL
    print("VM: verify source version and add missing UI files", flush=True)
    receipt = run_bridge(bridge, code)
    print("ADDED:", receipt["added"], "missing UI files; existing files retained", flush=True)
    print("Repair receipt:", receipt["receipt"], flush=True)
    output = home / "Downloads/crimson-repair-report.zip"
    attempt = output.with_name("crimson-repair-attempt-" + str(time.time_ns()) + ".zip")
    checker = Path(__file__).resolve().with_name("crimson-launch-check.py")
    print("VM: start Crimson and capture load results", flush=True)
    result = subprocess.run([sys.executable, str(checker), "--start", "--output", str(attempt)], timeout=120)
    if attempt.is_file():
        with zipfile.ZipFile(attempt, "a", zipfile.ZIP_DEFLATED) as z:
            z.writestr("crimson-install-receipt.json", json.dumps(receipt, indent=2))
            z.writestr("crimson-addon-manifest.json", json.dumps(manifest, indent=2))
            z.writestr("build-retention.json", json.dumps({"directory": str(retained), "assembler_filter_patched": patched}))
        os.replace(attempt, output)
        print("REPORT:", output, flush=True)
    if result.returncode: raise RuntimeError("UI sources were retained, but startup collection stopped")
    with zipfile.ZipFile(output) as z:
        startup = json.loads(z.read("metadata.json")).get("startup", {})
    if startup.get("shell_pids") or startup.get("existing_shell_pids"):
        print("RUNNING: Crimson shell. Verify its panels and wallpaper picker inside the VM.")
    else:
        print("UI sources were added. Startup still failed; send the report for its next blocking error.")

if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired, zipfile.BadZipFile) as error:
        raise SystemExit("Crimson repair stopped: " + str(error))
