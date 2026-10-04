#!/usr/bin/env python3
"""Read-only, allowlisted collection of the tested twelve-profile source inputs.

No uploads, configuration edits, package changes or desktop restarts. The ZIP
is for private source review, not direct redistribution as a release payload.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import pwd
import re
import subprocess
import tempfile
import zipfile

PROFILES = ("caelestia", "end4", "ambxst", "dms", "serpantinum", "noctalia",
            "sayconlun", "tsugumori", "jaqc", "clavis", "nixri", "inir")
EXTENSIONS = {".qml", ".js", ".mjs", ".lua", ".kdl", ".sh", ".py", ".css", ".scss",
              ".ini", ".conf", ".json", ".jsonc", ".toml", ".svg", ".png", ".webp", ".jpg",
              ".jpeg", ".desktop", ".service", ".target", ".xml", ".qrc", ".cpp", ".h",
              ".txt", ".cmake", ".ttf", ".otf", ".patch", ".md", ".rs", ".lock"}
SKIP_PARTS = re.compile(r"(^|/)(\.git|__pycache__|node_modules|venv|\.venv|cache|state|"
                        r"backups?|failed-profile|downloads?|wallpapers|generated)(/|$)|before-|\.log$", re.I)
SECRETS = re.compile(rb"(?:gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|"
                     rb"sk-[A-Za-z0-9_-]{20,}|-----BEGIN (?:RSA |OPENSSH |EC )?PRIVATE KEY-----|"
                     rb"(?:api[_-]?key|access[_-]?token|password)\s*[:=]\s*['\"][A-Za-z0-9_+/=-]{12,}['\"])", re.I)
MAX_FILE = 20 * 1024**2
MAX_TOTAL = 300 * 1024**2


def collect(home, output):
    home = Path(home).resolve()
    output = Path(output).absolute()
    files, skipped, missing, aliases = {}, [], [], {}
    total = 0

    def add(path, explicit=False):
        nonlocal total
        logical = path.relative_to(home).as_posix()
        if SKIP_PARTS.search(logical):
            return
        try:
            real = path.resolve(strict=True)
            real.relative_to(home)
            if not real.is_file():
                return
            if real != path:
                aliases[logical] = real.relative_to(home).as_posix()
            if not explicit and real.suffix.lower() not in EXTENSIONS and real.name not in ("qmldir", "CMakeLists.txt", "LICENSE", "COPYING", "ctrl.sh"):
                skipped.append({"path": logical, "reason": "not an allowlisted source type"})
                return
            if real.stat().st_size > MAX_FILE:
                skipped.append({"path": logical, "reason": "file size limit"})
                return
            data = real.read_bytes()
            if data.startswith(b"\x7fELF") or data[:2] == b"MZ":
                skipped.append({"path": logical, "reason": "binary inventoried, not collected"})
                return
            if b"\0" not in data and SECRETS.search(data):
                skipped.append({"path": logical, "reason": "possible credential; retained only on host"})
                return
            if logical in files:
                return
            total += len(data)
            if total > MAX_TOTAL:
                raise RuntimeError("Collection exceeds 300 MiB; no partial archive will be published.")
            files[logical] = {"data": data, "mode": real.stat().st_mode & 0o777,
                              "sha256": hashlib.sha256(data).hexdigest()}
        except (OSError, ValueError) as error:
            skipped.append({"path": logical, "reason": str(error)})

    def tree(path):
        if not path.exists():
            missing.append(path.relative_to(home).as_posix())
            return
        for current, directories, names in os.walk(path, followlinks=False):
            directories[:] = sorted(name for name in directories
                if not SKIP_PARTS.search((Path(current) / name).relative_to(home).as_posix()))
            for name in sorted(names):
                add(Path(current) / name)

    def explicit(relative):
        path = home / relative
        if path.exists():
            add(path, True)
        else:
            missing.append(relative)

    for profile in PROFILES:
        root = home / ".local/share/desktop-profiles" / profile
        tree(root)
        for entry in ("session.sh", "shell.sh", "bin/inir", "metadata.sh"):
            path = root / entry
            if path.exists():
                add(path, True)
    for relative in (".config/quickshell/multi-rice-switcher", ".local/share/desktop-switcher",
                     ".local/share/huzaifah-lumina-music", ".local/share/multi-rice-music",
                     ".local/share/desktop-profiles/clavis/native",
                     ".local/share/desktop-profiles/inir/niri"):
        tree(home / relative)
    # Script-based services/controllers sometimes live outside the UI tree.
    for relative in (".local/bin/lumina-music-ctl", ".local/bin/huzaifah-lumina-music",
                     ".local/bin/lumina-player-overlay", ".local/bin/desktop-switch",
                     ".local/bin/multi-rice-control", ".local/bin/multi-rice-session",
                     ".local/bin/refresh-rate-auto", ".local/share/desktop-switcher/profile-metadata.sh",
                     ".local/share/desktop-profiles/sayconlun/support/bin/rice-wallpaper-auto",
                     ".local/share/desktop-profiles/cipher-genie-session/session.sh"):
        explicit(relative)
    for path in sorted((home / ".config/systemd/user").glob("*")):
        if path.name.startswith(("huzaifah-", "refresh-rate-auto", "rice-wallpaper-auto")) and path.is_file():
            add(path, True)
    for path in sorted((home / ".local/share/desktop-profiles/inir").glob("*.json")):
        if path.name in ("manifest.json", "routes.json", "source-manifest.json"):
            add(path)
    def command(args):
        try:
            result = subprocess.run(args, capture_output=True, text=True, timeout=20)
            return {"status": result.returncode, "stdout": result.stdout[:2 * 1024**2], "stderr": result.stderr[:4000]}
        except (OSError, subprocess.TimeoutExpired) as error:
            return {"error": str(error)}
    build_sources = []
    source_root = home / ".local/share/desktop-profiles"
    for candidate in sorted(source_root.glob(".cipher-genie-build-*/source")):
        if not (candidate / ".git").exists():
            continue
        git = ["git", "-C", str(candidate)]
        remote = command(git + ["remote", "get-url", "origin"])
        if SECRETS.search(remote.get("stdout", "").encode()) or re.search(r"https?://[^/]*@", remote.get("stdout", "")):
            remote = {"error": "Authenticated remote URL withheld"}
        diff = command(git + ["diff", "--no-ext-diff", "--no-textconv", "HEAD", "--", "*.rs", "Cargo.toml", "Cargo.lock"])
        if SECRETS.search(diff.get("stdout", "").encode()):
            diff = {"error": "Possible credential in source diff; retained on host"}
        build_sources.append({"path": candidate.relative_to(home).as_posix(), "remote": remote,
            "revision": command(git + ["rev-parse", "HEAD"]), "local_diff": diff,
            "status": command(git + ["status", "--porcelain", "--untracked-files=all"])})
        for name in ("Cargo.toml", "Cargo.lock"):
            if (candidate / name).exists():
                add(candidate / name)
    binary_info = []
    native = source_root / "clavis/native"
    binary_paths = [native / "bin/niri", native / "buttons/foot/foot",
                    native / "buttons/probe-qt5", native / "buttons/probe-qt6"]
    binary_paths.extend(sorted((native / "buttons").glob("qt*/plugins/**/*.so")))
    for binary in binary_paths:
        if binary.is_file():
            with binary.open("rb") as stream:
                binary_hash = hashlib.file_digest(stream, "sha256").hexdigest()
            binary_info.append({"path": binary.relative_to(home).as_posix(), "bytes": binary.stat().st_size,
                "sha256": binary_hash,
                "dynamic_dependencies": command(["readelf", "--dynamic", str(binary)])})
    report = {"schema": 1, "purpose": "Private review of release sources; not a public payload",
              "profiles": {key: (home / ".local/share/desktop-profiles" / key).exists() for key in PROFILES},
              "files": [{"path": key, "bytes": len(value["data"]), "sha256": value["sha256"], "mode": value["mode"]}
                        for key, value in sorted(files.items())],
              "aliases": aliases, "missing": missing, "skipped": skipped,
              "cipher_build_sources": build_sources, "native_binary_inventory": binary_info,
              "commands": {"packages": command(["pacman", "-Q"]), "quickshell": command(["qs", "--version"]),
                           "niri": command(["niri", "--version"]),
                           "units": command(["systemctl", "--user", "show", "refresh-rate-auto.service",
                                      "rice-wallpaper-auto.service", "huzaifah-inir-shell.service", "--no-pager",
                                      "-p", "FragmentPath", "-p", "DropInPaths", "-p", "WantedBy", "-p", "PartOf"])}}
    output.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=".v6-release-inputs-", dir=output.parent)
    os.close(fd)
    try:
        with zipfile.ZipFile(temporary, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
            for key, value in sorted(files.items()):
                info = zipfile.ZipInfo("home/" + key)
                info.external_attr = (0o100000 | value["mode"]) << 16
                info.compress_type = zipfile.ZIP_DEFLATED
                archive.writestr(info, value["data"])
            archive.writestr("report.json", json.dumps(report, indent=2))
        os.replace(temporary, output)
        output.chmod(0o600)
    finally:
        Path(temporary).unlink(missing_ok=True)
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    home = Path(pwd.getpwuid(os.getuid()).pw_dir)
    if os.getuid() == 0:
        parser.error("Run as the desktop user, without sudo.")
    output = args.output or home / "Downloads/multi-rice-v6-release-inputs.zip"
    report = collect(home, output)
    print("COLLECTED:", output)
    print("Source files:", len(report["files"]))
    print("Missing paths:", len(report["missing"]), "| skipped:", len(report["skipped"]))
    print("No uploads, configuration edits, package changes or desktop restarts.")
    print("Review report.json before sharing. Credentials/playlists/state are not requested; possible secret matches are skipped.")


if __name__ == "__main__":
    main()
