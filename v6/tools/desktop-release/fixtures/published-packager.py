#!/usr/bin/env python3
"""Build local v6 release candidates from the verified AppDir; no installation."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import tarfile
import time
import zipfile

from core import PROFILES, SetupError, load_manifest, no_symlink_parents, relative_path, sha256
from maintenance import write_json
from payload_backend import validate_plan

ROOT = Path(__file__).resolve().parent
PINS = ["PySide6-Essentials==6.11.2", "shiboken6==6.11.2", "PyInstaller==6.22.3"]
BASE = "https://github.com/huzaifahshahid71-ops/dotfiles/releases/download/v6.0.0/"
IMAGE = "multi-rice-v6.0.0-rc1-x86_64.AppImage"
GUI_FILES = ("app.py", "core.py", "maintenance.py", "recovery.py", "runner.py", "grub_setup.py", "wallpapers.json", "release.json")
BACKEND_FILES = ("payload_backend.py", "system_transaction.py", "package_policy.py", "core.py", "maintenance.py", "recovery.py", "staging.py", "runtime_sources.py")
APPRUN = '''#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "$0")" && pwd)"
case "${1:-}" in
 --multi-rice-protocol) printf '{"protocol":1,"version":"6.0.0","status":"vm-candidate"}\\n' ;;
 --multi-rice-backend) [[ $# == 2 ]] || exit 2; exec /usr/bin/python3 "$ROOT/backend/payload_backend.py" "$2" --payload "$ROOT/payload" ;;
 *)
    manifest="${SUMI_SETUP_MANIFEST:-}"
    if [[ -z "$manifest" && -n "${APPIMAGE:-}" ]]; then
        manifest="$(dirname -- "$APPIMAGE")/release.json"
    fi
    if [[ -z "$manifest" || ! -f "$manifest" ]]; then manifest="$ROOT/gui/release.json"; fi
    exec "$ROOT/gui/SumiSetup" --offline --manifest "$manifest" "$@"
    ;;
esac
'''


def progress(message):
    print(message, flush=True)


def run(arguments, output, label, timeout=900, env=None, cwd=None):
    """Bound each build stage, retain output, and show a heartbeat every 15s."""
    progress(label)
    with (output / "packaging.log").open("a") as log:
        log.write("\n" + label + "\n")
        log.flush()
        process = subprocess.Popen([str(x) for x in arguments], stdin=subprocess.DEVNULL,
                                   stdout=log, stderr=subprocess.STDOUT, cwd=cwd, env=env,
                                   start_new_session=True)
        started = time.monotonic()
        try:
            while True:
                try:
                    code = process.wait(timeout=15)
                    break
                except subprocess.TimeoutExpired:
                    elapsed = int(time.monotonic() - started)
                    progress(f"  {label}: {elapsed}s; log: {output / 'packaging.log'}")
                    if elapsed >= timeout:
                        raise SetupError(f"{label} exceeded {timeout}s. Rerun with --resume after checking packaging.log.")
            if code:
                raise SetupError(f"{label} failed ({code}). Last output:\n" +
                                 "\n".join((output / "packaging.log").read_text(errors="replace").splitlines()[-18:]))
        finally:
            if process.poll() is None:
                import signal
                os.killpg(process.pid, signal.SIGTERM)
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait()


def verify_candidate(candidate, home):
    no_symlink_parents(candidate)
    payload = candidate / "payload"
    report = json.loads((candidate.parent / "assembly-report.json").read_text())
    if report.get("status") != "candidate-appdir" or report.get("plan_sha256") != sha256(payload / "plan.json"):
        raise SetupError("The candidate plan does not match its assembly report.")
    features = report.get("release_features", {})
    if features.get("login_cards") != 74 or features.get("grub_cards") != 8:
        raise SetupError("The candidate must include all 74 LOGIN cards and eight GRUB cards.")
    progress("Checking candidate configuration hashes")
    plan = validate_plan(payload, home)
    catalog = payload / "home/.local/share/multi-rice-shortcuts/catalog.py"
    if sha256(catalog) != sha256(ROOT / "build-support/shortcut-menu/catalog.py"):
        raise SetupError("Candidate shortcut labels are outdated. Run update-shortcut-candidate.py first.")
    expected = {"plan.json"}
    records = [*plan["user_files"], *plan["system_files"], *plan["packages"]]
    for index, record in enumerate(records, 1):
        source = payload / str(relative_path(record["source"]))
        no_symlink_parents(source)
        if not source.is_file() or sha256(source) != record["sha256"]:
            raise SetupError("Candidate source changed: " + record["source"])
        if "bytes" in record and source.stat().st_size != record["bytes"]:
            raise SetupError("Candidate source length changed: " + record["source"])
        expected.add(record["source"])
        if index % 250 == 0 or index == len(records):
            progress(f"Verified candidate files {index}/{len(records)}")
    actual = {p.relative_to(payload).as_posix() for p in payload.rglob("*") if p.is_file() or p.is_symlink()}
    if actual != expected:
        raise SetupError("Unregistered or missing candidate files: " + ", ".join(sorted(actual ^ expected)[:8]))
    return plan, report


def source_hash():
    files = [ROOT / name for name in set(GUI_FILES + BACKEND_FILES + ("package-release.py", "gui-build-requirements.txt"))]
    files += sorted((ROOT / "assets").glob("*.webp"))
    return hashlib.sha256(json.dumps(sorted((str(p.relative_to(ROOT)), sha256(p)) for p in files)).encode()).hexdigest()


def file_record(path):
    return {"asset": path.name, "bytes": path.stat().st_size, "sha256": sha256(path), "url": BASE + path.name}


def make_manifest(image, parts, plan):
    return {"schema": 1, "version": "6.0.0", "arch": "x86_64", "backend_protocol": 1,
            "status": "ready", "validation": "local-vm-candidate; publication pending",
            "profiles": PROFILES, "image": file_record(image), "parts": [file_record(p) for p in parts],
            "installed_bytes": sum(r["bytes"] for r in plan["user_files"]) +
                               4 * sum(r["bytes"] for r in plan["packages"])}


def split_image(image, output, part_bytes=512 * 1024**2):
    if part_bytes <= 0:
        raise SetupError("Part size must be positive.")
    parts = []
    with image.open("rb") as stream:
        index = 1
        while True:
            data = stream.read(min(1024**2, part_bytes))
            if not data:
                break
            part = output / f"{image.name}.part{index:03d}"
            temporary = part.with_suffix(part.suffix + ".partial")
            written = 0
            with temporary.open("wb") as target:
                while data:
                    target.write(data)
                    written += len(data)
                    if written == part_bytes:
                        break
                    data = stream.read(min(1024**2, part_bytes - written))
            os.replace(temporary, part)
            parts.append(part)
            progress(f"Created part {index}: {written / 1024**2:.1f} MiB")
            index += 1
    # The part hashes above alone cannot prove that ordering/reassembly works.
    digest = hashlib.sha256()
    for part in parts:
        with part.open("rb") as stream:
            while data := stream.read(1024**2):
                digest.update(data)
    if digest.hexdigest() != sha256(image):
        raise SetupError("Split/reassembly verification failed.")
    return parts


def gui_runtime(output, existing_build=None):
    runtime = output / "runtime/SumiSetup"
    stamp = output / "gui-complete.json"
    if stamp.is_file():
        saved = json.loads(stamp.read_text())
        actual = runtime_records(runtime)
        if saved != actual:
            raise SetupError("The retained GUI runtime changed; use a fresh output directory.")
        progress("Reusing checked GUI runtime")
        return runtime
    venv = (existing_build or output) / "build-venv"
    python = venv / "bin/python"
    if not python.is_file():
        run([sys.executable, "-m", "venv", str(venv)], output, "Create private build environment", 120)
    wheels = (existing_build or output) / "wheels"
    wheels.mkdir(exist_ok=True)
    # Downloads stay in this build environment; the desktop Python is untouched.
    if existing_build:
        # Recheck the exact wheel hashes offline; the existing environment avoids
        # another network download when only the installer window changes.
        wheel_args = ["--no-index", "--find-links", wheels]
    else:
        wheel_args = ["--index-url", "https://pypi.org/simple"]
    run([python, "-m", "pip", "--isolated", "download", *wheel_args,
         "--only-binary=:all:", "--timeout", "30", "--retries", "2", "--dest", wheels,
         "--require-hashes", "-r", ROOT / "gui-build-requirements.txt"],
        output, "Download pinned GUI build wheels", 600)
    lock = [{"asset": p.name, "bytes": p.stat().st_size, "sha256": sha256(p),
             "index": "https://pypi.org/simple"} for p in sorted(wheels.glob("*.whl"))]
    write_json(output / "gui-wheel-hashes.json", lock)
    run([python, "-m", "pip", "--isolated", "install", "--no-index", "--find-links", wheels,
         "--require-hashes", "-r", ROOT / "gui-build-requirements.txt"],
        output, "Install private GUI toolchain", 180)
    source = output / "gui-source"
    source.mkdir(exist_ok=True)
    for name in GUI_FILES:
        shutil.copy2(ROOT / name, source / name)
    shutil.copytree(ROOT / "assets", source / "assets", dirs_exist_ok=True)
    run([python, "-m", "PyInstaller", "--noconfirm", "--clean", "--onedir", "--name", "SumiSetup",
         "--distpath", output / "runtime", "--workpath", output / "freeze-work", "--specpath", output,
         "--add-data", str(source / "assets") + ":assets",
         "--add-data", str(source / "release.json") + ":.",
         "--add-data", str(source / "wallpapers.json") + ":.",
         "--hidden-import", "PySide6.QtCore", "--hidden-import", "PySide6.QtGui",
         "--hidden-import", "PySide6.QtWidgets", source / "app.py"], output, "Bundle Sumi Python and Qt runtime", 900)
    licenses = runtime / "licenses"
    licenses.mkdir(exist_ok=True)
    for wheel in wheels.glob("*.whl"):
        with zipfile.ZipFile(wheel) as archive:
            for member in archive.namelist():
                if not member.endswith("/") and any("license" in x.lower() or "copying" in x.lower()
                                                     for x in Path(member).parts):
                    relative = relative_path(member)
                    target = licenses / wheel.stem / str(relative)
                    target.parent.mkdir(parents=True, exist_ok=True)
                    target.write_bytes(archive.read(member))
    shutil.copytree(source, runtime / "source", dirs_exist_ok=True)
    # Python shared library licensing is not necessarily included by the freezer.
    import sysconfig
    python_license = next((p for p in (Path(sysconfig.get_path("stdlib")) / "LICENSE.txt",
                                      Path("/usr/share/licenses/python/LICENSE")) if p.is_file()), None)
    if python_license is None:
        raise SetupError("Python LICENSE.txt is missing; retain a complete Python license before distributing.")
    shutil.copy2(python_license, licenses / "Python-LICENSE.txt")
    shutil.copy2(output / "gui-wheel-hashes.json", runtime / "gui-wheel-hashes.json")
    shutil.copy2(ROOT / "gui-build-requirements.txt", runtime / "gui-build-requirements.txt")
    screenshot = output / "sumi-runtime.png"
    run([runtime / "SumiSetup", "--offline", "--screenshot", screenshot], output,
        "Render bundled Sumi window", 60, env=dict(os.environ, QT_QPA_PLATFORM="offscreen"))
    if not screenshot.is_file() or screenshot.stat().st_size < 1000:
        raise SetupError("The bundled GUI did not create its smoke-test screenshot.")
    write_json(stamp, runtime_records(runtime))
    return runtime


def runtime_records(runtime):
    if not (runtime / "SumiSetup").is_file():
        raise SetupError("Bundled Sumi executable missing.")
    records = []
    for p in sorted(runtime.rglob("*")):
        if p.is_symlink():
            if not p.resolve().is_relative_to(runtime.resolve()):
                raise SetupError("GUI bundle link leaves runtime: " + str(p))
            records.append({"path": str(p.relative_to(runtime)), "link": os.readlink(p)})
        elif p.is_file():
            records.append({"path": str(p.relative_to(runtime)), "sha256": sha256(p)})
    return records


def build_image(candidate, runtime, output, report):
    image = output / IMAGE
    stamp = output / "image-complete.json"
    if stamp.is_file():
        if json.loads(stamp.read_text()) != file_record(image):
            raise SetupError("The retained AppImage changed; use a fresh output directory.")
        progress("Reusing checked AppImage")
        return image
    packagers = report.get("appimage_packager_candidates", [])
    tool = next((Path(r["path"]) for r in packagers if Path(r["path"]).is_file()
                 and sha256(Path(r["path"])) == r["sha256"]), None)
    if tool is None:
        raise SetupError("The recorded appimagetool is missing or changed.")
    directory = output / "packed.AppDir"
    if directory.exists():
        shutil.rmtree(directory)
    directory.mkdir()
    # Hard links reduce disk usage. Payload bytes are never modified here.
    def link_or_copy(source, destination):
        try:
            os.link(source, destination)
        except OSError:
            shutil.copy2(source, destination)
        return destination
    shutil.copytree(candidate / "payload", directory / "payload", copy_function=link_or_copy)
    (directory / "backend").mkdir()
    for name in BACKEND_FILES:
        shutil.copy2(ROOT / name, directory / "backend" / name)
    shutil.copytree(runtime, directory / "gui", symlinks=True)
    (directory / "AppRun").write_text(APPRUN)
    (directory / "AppRun").chmod(0o755)
    shutil.copy2(candidate / "multi-rice.svg", directory / "multi-rice.svg")
    (directory / "multi-rice.desktop").write_text("[Desktop Entry]\nType=Application\nName=Sumi Setup\nExec=AppRun\nIcon=multi-rice\nCategories=Utility;\n")
    env = dict(os.environ, ARCH="x86_64", VERSION="6.0.0", APPIMAGE_EXTRACT_AND_RUN="1")
    arguments = [tool, "--no-appstream", "--comp", "zstd"]
    with tool.open("rb") as stream:
        is_elf = stream.read(4) == b"\x7fELF"
    if is_elf and tool.suffix == ".AppImage":
        # Reuse the verified tool's own type-2 runtime instead of downloading a
        # moving 'latest' runtime during packaging. Built-in commands need no FUSE.
        offset = int(subprocess.check_output([tool, "--appimage-offset"], timeout=30).strip())
        if not 4096 <= offset <= 16 * 1024**2:
            raise SetupError("Unexpected recorded AppImage runtime offset.")
        with tool.open("rb") as source:
            runtime_file = output / "appimage-runtime-x86_64"
            runtime_file.write_bytes(source.read(offset))
        arguments += ["--runtime-file", runtime_file]
    temporary = output / (IMAGE + ".partial")
    temporary.unlink(missing_ok=True)
    run([*arguments, directory, temporary], output, "Package offline AppImage", 1200, env=env)
    temporary.chmod(0o755)
    protocol = subprocess.check_output([temporary, "--multi-rice-protocol"], env=env, timeout=120)
    if json.loads(protocol) != {"protocol": 1, "version": "6.0.0", "status": "vm-candidate"}:
        raise SetupError("Packaged AppImage backend protocol failed.")
    os.replace(temporary, image)
    write_json(stamp, file_record(image))
    return image


def launcher(offline):
    flag = " --offline" if offline else ""
    return ('#!/bin/sh\nset -eu\nsetup_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)\n'
            'exec "$setup_dir/SumiSetup"' + flag + ' --manifest "$setup_dir/release.json" "$@"\n')


def build(candidate, output, home, resume=False):
    plan, assembly = verify_candidate(candidate, home)
    identity = {"schema": 1, "candidate": str(candidate), "plan_sha256": assembly["plan_sha256"],
                "source_sha256": source_hash(), "python": sys.version, "pins": PINS}
    marker = output / "build-identity.json"
    no_symlink_parents(output)
    if output.exists():
        if not resume or not marker.is_file() or json.loads(marker.read_text()) != identity:
            raise SetupError("Output exists. Resume requires --resume with the same candidate, code and Python.")
    else:
        # Archives, extraction, frozen runtime and configuration backups need room.
        required = 3 * sum(r["bytes"] for r in plan["packages"]) + 2 * sum(r["bytes"] for r in plan["user_files"]) + 2 * 1024**3
        if shutil.disk_usage(output.parent).free < required:
            raise SetupError(f"Packaging needs approximately {required / 1024**3:.1f} GiB free in {output.parent}.")
        output.mkdir(mode=0o700)
        write_json(marker, identity)
    runtime = gui_runtime(output)
    image = build_image(candidate, runtime, output, assembly)
    parts = split_image(image, output)
    manifest_path = output / "release.json"
    write_json(manifest_path, make_manifest(image, parts, plan))
    manifest = load_manifest(manifest_path)
    bundle = output / "sumi-setup-v6.0.0-rc1"
    if bundle.exists():
        shutil.rmtree(bundle)
    shutil.copytree(runtime, bundle, symlinks=True)
    shutil.copy2(manifest_path, bundle / "release.json")
    for offline in (True, False):
        path = bundle / ("launch-offline.sh" if offline else "launch-online.sh")
        path.write_text(launcher(offline))
        path.chmod(0o755)
    (bundle / "README.txt").write_text("Sumi Setup v6.0.0 RC1 — local VM candidate\n\n"
        "Python and Qt are included. Extract this archive with tar; symbolic links must be preserved.\n"
        "Place the AppImage or all .part files beside launch-offline.sh, then run it.\n"
        "The online launcher will be usable when matching assets are published.\n"
        "The AppImage also opens the offline GUI when release.json is beside it.\n"
        "Source and third-party licenses are included. VM install/upgrade/restore validation is pending.\n")
    archive = output / "sumi-setup-v6.0.0-rc1-x86_64.tar.xz"
    progress("Compressing small Sumi runtime archive")
    with tarfile.open(archive, "w:xz", dereference=False, preset=3) as tar:
        tar.add(bundle, arcname=bundle.name)
    artifacts = [image, *parts, manifest_path, archive]
    (output / "SHA256SUMS").write_text("".join(sha256(p) + "  " + p.name + "\n" for p in artifacts))
    return {"status": "packaged-vm-candidate", "version": "6.0.0", "published": False,
            "system_changes": False, "plan_sha256": identity["plan_sha256"],
            "image": manifest["image"], "parts": manifest["parts"],
            "gui_archive": file_record(archive), "gui_smoke_test": True,
            "release_features": assembly["release_features"],
            "package_architectures": assembly.get("package_architectures"),
            "private_python": plan.get("private_python"), "glibc": platform.libc_ver(),
            "remaining": ["VM fresh installation", "VM upgrade", "VM restore", "Desktop/login/GRUB acceptance", "Publication"]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidate", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--resume", action="store_true")
    args = parser.parse_args()
    import pwd
    home = Path(pwd.getpwuid(os.getuid()).pw_dir)
    if os.getuid() == 0 or platform.machine() != "x86_64":
        parser.error("Run as the desktop user on x86_64, without sudo.")
    candidate = args.candidate.expanduser().absolute()
    output = args.output.expanduser().absolute()
    no_symlink_parents(output)
    if output == candidate or output.is_relative_to(candidate) or candidate.is_relative_to(output):
        parser.error("Use an output directory separate from the assembled candidate.")
    result = {"status": "blocked", "published": False, "system_changes": False}
    code = 1
    try:
        result = build(candidate, output, home, args.resume)
        code = 0
        progress("PACKAGED: " + str(output / IMAGE))
        progress("Sumi GUI runtime and SHA-256 verified split parts are ready for VM testing.")
    except (OSError, ValueError, SetupError, subprocess.SubprocessError) as error:
        result["error"] = str(error)
        progress("Packaging stopped: " + str(error))
    finally:
        report_zip = home / "Downloads/multi-rice-v6-packaging-report.zip"
        report_zip.parent.mkdir(exist_ok=True)
        with zipfile.ZipFile(report_zip, "w", zipfile.ZIP_DEFLATED) as archive:
            archive.writestr("packaging-report.json", json.dumps(result, indent=2) + "\n")
            names = ("build-identity.json", "gui-wheel-hashes.json", "packaging.log", "sumi-runtime.png") if (output / "build-identity.json").is_file() else ()
            for name in names:
                path = output / name
                if path.is_file():
                    archive.write(path, name)
        progress("REPORT: " + str(report_zip))
    return code


if __name__ == "__main__":
    raise SystemExit(main())
