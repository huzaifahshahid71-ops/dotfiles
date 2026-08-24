#!/usr/bin/env python3
import os
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RESTORE = ROOT / "scripts/restore-dual-rice.sh"
HOME = Path.home()

EXCLUDED_DIRS = {".git", "dist", "build", "__pycache__"}


def human_size(value: int) -> str:
    n = float(value)
    for unit in ("B", "KiB", "MiB", "GiB", "TiB"):
        if n < 1024.0 or unit == "TiB":
            return f"{n:.2f} {unit}"
        n /= 1024.0
    return f"{value} B"


def run(args):
    return subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)


def extract_restore_targets() -> list[str]:
    if not RESTORE.exists():
        raise RuntimeError(f"Restore script not found: {RESTORE}")

    lines = RESTORE.read_text(errors="replace").splitlines()
    targets = []
    collecting = False

    for line in lines:
        if not collecting:
            if "paru -S --needed" not in line:
                continue
            collecting = True
            text = line.split("--needed", 1)[1].strip()
        else:
            text = line.strip()

        continued = text.endswith("\\")
        if continued:
            text = text[:-1].strip()
        if text:
            targets.extend(shlex.split(text))
        if collecting and not continued:
            break

    if not targets:
        raise RuntimeError("Could not extract the paru dependency list from restore-dual-rice.sh")
    return sorted(set(targets))


def normalize_pactree_line(line: str) -> str | None:
    line = line.strip()
    if not line:
        return None
    # pactree -l normally returns one package per line. This fallback also
    # tolerates decorated/tree output.
    match = re.search(r"([A-Za-z0-9@._+:-]+)(?:[<>=].*)?$", line)
    return match.group(1) if match else None


def dependency_closure(targets: list[str]) -> tuple[set[str], list[str]]:
    closure = set()
    missing = []

    for pkg in targets:
        if run(["pacman", "-Qq", pkg]).returncode != 0:
            missing.append(pkg)
            continue
        result = run(["pactree", "-u", "-l", pkg])
        if result.returncode != 0:
            closure.add(pkg)
            continue
        for line in result.stdout.splitlines():
            name = normalize_pactree_line(line)
            if name:
                closure.add(name)

    return closure, missing


def local_installed_sizes() -> dict[str, int]:
    result = {}
    local_db = Path("/var/lib/pacman/local")
    for desc in local_db.glob("*/desc"):
        try:
            lines = desc.read_text(errors="replace").splitlines()
        except OSError:
            continue

        fields = {}
        i = 0
        while i < len(lines):
            line = lines[i]
            if line.startswith("%") and line.endswith("%"):
                key = line.strip("%")
                if i + 1 < len(lines) and lines[i + 1] and not lines[i + 1].startswith("%"):
                    fields[key] = lines[i + 1]
            i += 1

        name = fields.get("NAME")
        size = fields.get("ISIZE")
        if name and size:
            try:
                result[name] = int(size)
            except ValueError:
                pass
    return result


def parse_size_text(text: str) -> int | None:
    match = re.match(r"\s*([0-9.]+)\s*([KMGT]?i?B|B)\s*$", text)
    if not match:
        return None
    number = float(match.group(1))
    unit = match.group(2)
    multipliers = {
        "B": 1,
        "KiB": 1024,
        "MiB": 1024 ** 2,
        "GiB": 1024 ** 3,
        "TiB": 1024 ** 4,
        "KB": 1000,
        "MB": 1000 ** 2,
        "GB": 1000 ** 3,
        "TB": 1000 ** 4,
    }
    mult = multipliers.get(unit)
    return int(number * mult) if mult else None


def repo_download_size(pkg: str) -> int | None:
    result = run(["pacman", "-Si", pkg])
    if result.returncode != 0:
        return None
    match = re.search(r"^Download Size\s*:\s*(.+)$", result.stdout, flags=re.MULTILINE)
    return parse_size_text(match.group(1)) if match else None


def index_cached_packages() -> dict[str, tuple[int, float, str]]:
    roots = [
        Path("/var/cache/pacman/pkg"),
        HOME / ".cache/paru/clone",
        HOME / ".cache/paru/pkg",
    ]
    archives = []
    for root in roots:
        if not root.exists():
            continue
        try:
            archives.extend(p for p in root.rglob("*.pkg.tar.*") if not p.name.endswith(".sig"))
        except PermissionError:
            pass

    indexed = {}
    for archive in archives:
        info = run(["pacman", "-Qp", str(archive)])
        if info.returncode != 0 or not info.stdout.strip():
            continue
        name = info.stdout.split()[0]
        try:
            stat = archive.stat()
        except OSError:
            continue
        current = indexed.get(name)
        if current is None or stat.st_mtime > current[1]:
            indexed[name] = (stat.st_size, stat.st_mtime, str(archive))
    return indexed


def tree_size(path: Path) -> int:
    if not path.exists() and not path.is_symlink():
        return 0
    if path.is_file() or path.is_symlink():
        try:
            return path.lstat().st_size
        except OSError:
            return 0

    total = 0
    for root, dirs, files in os.walk(path, followlinks=False):
        dirs[:] = [d for d in dirs if d not in EXCLUDED_DIRS]
        for filename in files:
            p = Path(root) / filename
            try:
                total += p.lstat().st_size
            except OSError:
                pass
    return total


def compress_local_payload(paths: list[Path]) -> tuple[int, str | None]:
    existing = [p for p in paths if p.exists() or p.is_symlink()]
    if not existing:
        return 0, None

    fd, archive_name = tempfile.mkstemp(prefix="triple-rice-local-payload-", suffix=".tar.zst")
    os.close(fd)
    archive = Path(archive_name)

    cmd = [
        "tar", "--zstd", "-cf", str(archive),
        "--exclude=.git", "--exclude=dist", "--exclude=build", "--exclude=__pycache__",
    ] + [str(p) for p in existing]

    result = run(cmd)
    if result.returncode != 0:
        try:
            archive.unlink()
        except OSError:
            pass
        return 0, result.stderr.strip() or "tar failed"

    size = archive.stat().st_size
    try:
        archive.unlink()
    except OSError:
        pass
    return size, None


def main() -> int:
    print("Huzaifah Triple-Rice Offline Size Calculator")
    print("==============================================")
    print("This is read-only. It uses your current local package database, caches and rice files.\n")

    if shutil.which("pacman") is None:
        print("ERROR: pacman was not found.")
        return 1
    if shutil.which("pactree") is None:
        print("ERROR: pactree is required for an exact dependency closure.")
        print("Install it once with: sudo pacman -S --needed pacman-contrib")
        return 2
    if shutil.which("tar") is None or shutil.which("zstd") is None:
        print("ERROR: tar and zstd are required for the local payload compression test.")
        return 2

    targets = extract_restore_targets()
    closure, missing_targets = dependency_closure(targets)
    installed_sizes = local_installed_sizes()

    installed_footprint = sum(installed_sizes.get(pkg, 0) for pkg in closure)

    cache = index_cached_packages()
    compressed_packages = 0
    foreign_missing = []
    official_count = 0
    cached_foreign_count = 0

    for pkg in sorted(closure):
        download_size = repo_download_size(pkg)
        if download_size is not None:
            compressed_packages += download_size
            official_count += 1
            continue

        cached = cache.get(pkg)
        if cached is not None:
            compressed_packages += cached[0]
            cached_foreign_count += 1
        else:
            foreign_missing.append(pkg)

    local_payload_paths = [
        ROOT,
        HOME / ".local/src/end4-dots",
        HOME / ".config/quickshell/end4-pC",
        HOME / ".local/src/ambxst",
        Path("/usr/local/bin/axctl"),
    ]

    raw_local_payload = sum(tree_size(p) for p in local_payload_paths)
    compressed_local_payload, compression_error = compress_local_payload(local_payload_paths)

    # A Type-2 AppImage wrapper itself is tiny compared with the package payload.
    appimage_overhead = 8 * 1024 * 1024
    known_offline_payload = compressed_packages + compressed_local_payload + appimage_overhead

    print(f"Direct packages in restore script : {len(targets)}")
    print(f"Installed dependency closure      : {len(closure)} packages")
    if missing_targets:
        print(f"Direct targets not installed      : {len(missing_targets)}")
    print()
    print(f"Installed package footprint       : {human_size(installed_footprint)}")
    print(f"Rice/source payload, raw          : {human_size(raw_local_payload)}")
    if compression_error:
        print(f"Rice/source compression test      : FAILED ({compression_error})")
    else:
        print(f"Rice/source payload, compressed   : {human_size(compressed_local_payload)}")
    print()
    print(f"Official repo package archives    : {official_count} packages")
    print(f"Cached foreign/AUR archives       : {cached_foreign_count} packages")
    print(f"Known compressed package payload  : {human_size(compressed_packages)}")
    print(f"Estimated AppImage wrapper        : {human_size(appimage_overhead)}")
    print("----------------------------------------------")
    qualifier = ">=" if foreign_missing else "≈"
    print(f"Projected offline AppImage size   : {qualifier} {human_size(known_offline_payload)}")

    if foreign_missing:
        print("\nThe result above is a LOWER BOUND because these foreign/AUR package archives")
        print("are installed but are not present in your current package caches:")
        for pkg in foreign_missing:
            print(f"  - {pkg}")
        print("\nOnce those archives are available locally, rerun this script and the")
        print("projected compressed size becomes near-exact for the offline design.")
    else:
        print("\nAll package payload sizes were resolved locally/from the current pacman sync DB.")
        print("This should be very close to the real single-file offline AppImage size.")

    if missing_targets:
        print("\nRestore-script targets currently missing from this machine:")
        for pkg in missing_targets:
            print(f"  - {pkg}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
