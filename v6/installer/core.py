"""Payload-independent Multi-Rice transport and host checks (protocol 1)."""
from __future__ import annotations

import contextlib
import fcntl
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import platform
import re
import shutil
import tempfile
import urllib.request
from urllib.parse import urlsplit

VERSION = "6.0.0"
PROFILES = {"caelestia": "Aether", "end4": "Obsidian", "ambxst": "Crimson",
            "dms": "Materia", "serpantinum": "Aurora", "noctalia": "Nocturne",
            "sayconlun": "Lumina", "tsugumori": "Tsugumori", "jaqc": "Solstice",
            "clavis": "Cipher", "nixri": "Astra", "inir": "Eclipse"}
CHUNK = 1024 * 1024


class SetupError(RuntimeError):
    pass


def emit(callback, stage, message, completed=0, total=0, **extra):
    callback({"protocol": 1, "stage": stage, "message": message,
              "completed": completed, "total": total, **extra})


def relative_path(value):
    if not isinstance(value, str) or not value or "\\" in value or "\x00" in value:
        raise SetupError("Invalid relative path.")
    path = PurePosixPath(value)
    if path.is_absolute() or any(x in ("", ".", "..") for x in value.split("/")):
        raise SetupError("Unsafe relative path: " + value)
    return path


def no_symlink_parents(path):
    for parent in (path, *path.parents):
        if parent.is_symlink():
            raise SetupError("A managed path is a symbolic link: " + str(parent))


def sha256(path, callback=None):
    digest = hashlib.sha256()
    done, total = 0, path.stat().st_size
    with path.open("rb") as stream:
        while data := stream.read(CHUNK):
            digest.update(data)
            done += len(data)
            if callback:
                emit(callback, "verify", "Checking " + path.name, done, total)
    return digest.hexdigest()


def spec_valid(record):
    if not isinstance(record, dict):
        raise SetupError("Invalid file record.")
    relative_path(record.get("asset"))
    if "/" in record["asset"] or record["asset"] in (".owned", ".lock") or record["asset"].endswith(".partial"):
        raise SetupError("Asset names must be unique, plain filenames.")
    if type(record.get("bytes")) is not int or record["bytes"] <= 0:
        raise SetupError("Invalid expected file length.")
    if not re.fullmatch(r"[0-9a-f]{64}", record.get("sha256", "")):
        raise SetupError("Invalid expected SHA-256.")
    url = urlsplit(record.get("url", ""))
    if url.scheme != "https" or url.hostname != "github.com" or url.username or url.password or url.port:
        raise SetupError("Release downloads must use pinned HTTPS GitHub URLs.")


def load_manifest(path):
    data = json.loads(path.read_text())
    if data.get("schema") != 1 or data.get("backend_protocol") != 1:
        raise SetupError("Unsupported release or backend protocol.")
    if data.get("version") != VERSION or data.get("arch") != "x86_64" or data.get("status") != "ready":
        raise SetupError("The verified v6.0.0 payload has not been published in this launcher yet.")
    if data.get("profiles") != PROFILES or not data.get("parts"):
        raise SetupError("The release must contain the twelve expected profiles.")
    for record in [data["image"], *data["parts"]]:
        spec_valid(record)
        prefix = "/huzaifahshahid71-ops/dotfiles/releases/download/v6.0.0/"
        if not urlsplit(record["url"]).path.startswith(prefix):
            raise SetupError("The file belongs to another release.")
    names = [x["asset"] for x in [data["image"], *data["parts"]]]
    if len(set(names)) != len(names) or sum(x["bytes"] for x in data["parts"]) != data["image"]["bytes"]:
        raise SetupError("Release parts have duplicate names or inconsistent lengths.")
    if type(data.get("installed_bytes")) is not int or data["installed_bytes"] <= 0:
        raise SetupError("The payload installation space estimate is missing.")
    return data


def verified(path, spec, callback=None):
    return (path.is_file() and not path.is_symlink() and path.stat().st_size == spec["bytes"]
            and sha256(path, callback) == spec["sha256"])


class Cache:
    def __init__(self, root):
        self.root = Path(root).absolute()
        no_symlink_parents(self.root)
        self.root.mkdir(parents=True, exist_ok=True, mode=0o700)
        marker = self.root / ".owned"
        if not marker.exists():
            if any(self.root.iterdir()):
                raise SetupError("Refusing to use an unrecognized cache directory.")
            marker.write_text("multi-rice-cache-v1\n")
        if marker.is_symlink() or marker.read_text() != "multi-rice-cache-v1\n":
            raise SetupError("Unrecognized cache ownership marker.")

    @contextlib.contextmanager
    def locked(self):
        path = self.root / ".lock"
        no_symlink_parents(path)
        with path.open("a") as stream:
            try:
                fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError as error:
                raise SetupError("Another setup operation is already using the cache.") from error
            yield

    def path(self, name):
        relative_path(name)
        path = self.root / name
        no_symlink_parents(path)
        return path

    def cleanup_size(self):
        return sum(x.stat().st_size for x in self.root.rglob("*") if x.is_file() and not x.is_symlink())

    def cleanup(self):
        # Only this class's marked cache. Never sources, backups or wallpapers.
        with self.locked():
            for path in self.root.iterdir():
                if path.name in (".owned", ".lock"):
                    continue
                if path.is_symlink():
                    path.unlink()
                elif path.is_dir():
                    shutil.rmtree(path)
                else:
                    path.unlink()


def download(spec, target, callback, opener=urllib.request.urlopen):
    spec_valid(spec)
    no_symlink_parents(target)
    if verified(target, spec, callback):
        emit(callback, "download", "Reusing verified " + target.name, spec["bytes"], spec["bytes"])
        return target
    partial = target.with_name(target.name + ".partial")
    no_symlink_parents(partial)
    offset = partial.stat().st_size if partial.exists() else 0
    if offset == spec["bytes"]:
        if verified(partial, spec, callback):
            os.replace(partial, target)
            return target
        partial.unlink()
        offset = 0
    if offset > spec["bytes"]:
        partial.unlink()
        offset = 0
    headers = {"User-Agent": "Huzaifah-Multi-Rice/6.0.0", "Accept-Encoding": "identity"}
    if offset:
        headers["Range"] = f"bytes={offset}-"
    request = urllib.request.Request(spec["url"], headers=headers)
    with opener(request, timeout=30) as response:
        status = response.status
        if status == 200:
            offset = 0
        elif status == 206 and offset:
            expected = f"bytes {offset}-{spec['bytes'] - 1}/{spec['bytes']}"
            if response.headers.get("Content-Range") != expected:
                raise SetupError("Invalid resume response; the partial file was retained.")
        else:
            raise SetupError("Unexpected download response.")
        if response.headers.get("Content-Encoding", "identity") != "identity":
            raise SetupError("Unexpected compressed download response.")
        declared = response.headers.get("Content-Length")
        if declared is not None and int(declared) != spec["bytes"] - offset:
            raise SetupError("The server returned an unexpected file length.")
        with partial.open("ab" if offset else "wb") as stream:
            done = offset
            while data := response.read(CHUNK):
                if done + len(data) > spec["bytes"]:
                    raise SetupError("Download exceeds the pinned file length.")
                stream.write(data)
                done += len(data)
                emit(callback, "download", target.name, done, spec["bytes"])
            stream.flush()
            os.fsync(stream.fileno())
    if not verified(partial, spec, callback):
        partial.unlink()
        raise SetupError("SHA-256 verification failed: " + target.name)
    os.replace(partial, target)
    return target


def prepare_image(manifest, cache, callback, source_folders=(), offline=False):
    image = cache.path(manifest["image"]["asset"])
    with cache.locked():
        if verified(image, manifest["image"], callback):
            image.chmod(0o700)
            return image
        for folder in source_folders:
            candidate = Path(folder) / image.name
            if verified(candidate, manifest["image"], callback):
                temporary = cache.path(image.name + ".partial")
                shutil.copyfile(candidate, temporary)
                if not verified(temporary, manifest["image"], callback):
                    raise SetupError("The offline AppImage changed while being copied.")
                os.replace(temporary, image)
                image.chmod(0o700)
                return image
        parts = []
        for spec in manifest["parts"]:
            part = cache.path(spec["asset"])
            if not verified(part, spec, callback):
                local = next((Path(f) / part.name for f in source_folders
                              if verified(Path(f) / part.name, spec, callback)), None)
                if local:
                    temporary = cache.path(part.name + ".partial")
                    shutil.copyfile(local, temporary)
                    if not verified(temporary, spec, callback):
                        raise SetupError("Source changed while copying " + part.name)
                    os.replace(temporary, part)
                elif offline:
                    raise SetupError("Missing or invalid offline file: " + part.name)
                else:
                    download(spec, part, callback)
            parts.append(part)
        joined = cache.path(image.name + ".partial")
        done = 0
        with joined.open("wb") as stream:
            for part in parts:
                with part.open("rb") as source:
                    while block := source.read(CHUNK):
                        stream.write(block)
                        done += len(block)
                        emit(callback, "assemble", "Joining verified parts", done, manifest["image"]["bytes"])
            stream.flush()
            os.fsync(stream.fileno())
        if not verified(joined, manifest["image"], callback):
            joined.unlink()
            raise SetupError("The assembled AppImage failed its final checksum.")
        os.replace(joined, image)
        image.chmod(0o700)
        return image


def put_wallpaper(source, relative, destination, expected):
    path = destination / str(relative_path(relative))
    no_symlink_parents(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        if sha256(path) == expected:
            return path, "existing"
        path = path.with_name(path.stem + "-" + expected[:12] + path.suffix)
        no_symlink_parents(path)
        if path.exists():
            if sha256(path) == expected:
                return path, "existing"
            raise SetupError("Wallpaper collision: " + str(path))
    fd, name = tempfile.mkstemp(prefix=".multi-rice-", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as output, source.open("rb") as incoming:
            shutil.copyfileobj(incoming, output, CHUNK)
        if sha256(Path(name)) != expected:
            raise SetupError("Wallpaper changed while being copied.")
        # Do not replace a file created by another process while copying.
        os.link(name, path)
    finally:
        Path(name).unlink(missing_ok=True)
    return path, "copied"


def local_wallpapers(source, destination, callback):
    source, destination = Path(source).resolve(), Path(destination).absolute()
    no_symlink_parents(destination)
    if source == destination or source in destination.parents:
        raise SetupError("Choose a destination outside the source folder.")
    if not source.is_dir():
        raise SetupError("Choose a readable wallpaper folder or skip.")
    files = sorted(p for p in source.rglob("*") if not p.is_symlink() and p.is_file()
                   and p.suffix.lower() in (".png", ".jpg", ".jpeg", ".webp", ".avif", ".bmp", ".gif"))
    if not files:
        raise SetupError("No supported images found. Choose another folder or skip.")
    results = []
    for index, path in enumerate(files, 1):
        if any(x.is_symlink() for x in path.parents if x != source):
            continue
        result, status = put_wallpaper(path, path.relative_to(source).as_posix(), destination, sha256(path))
        results.append({"path": str(result), "status": status})
        emit(callback, "wallpapers", result.name, index, len(files), result=status)
    return results


def online_wallpapers(pin, collection, destination, cache, callback):
    with cache.locked():
        path = download(pin["manifest"], cache.path(pin["manifest"]["asset"]), callback)
        data = json.loads(path.read_text())
        if data.get("schema") != 1 or data.get("snapshot_sha256") != pin["snapshot_sha256"]:
            raise SetupError("Wallpaper snapshot identity differs from the pinned collection.")
        items = data["wallpapers"]
        if collection == "selection":
            selected = set(pin["selection_ids"])
            items = [x for x in items if x["id"] in selected]
            if len(items) != len(selected):
                raise SetupError("The selection is missing from the pinned wallpaper manifest.")
        elif collection != "full":
            raise SetupError("Unknown wallpaper collection.")
        results = []
        for index, item in enumerate(items, 1):
            original = download(item, cache.path(item["asset"]), callback)
            result, status = put_wallpaper(original, item["path"], destination, item["sha256"])
            results.append({"path": str(result), "status": status})
            emit(callback, "wallpapers", result.name, index, len(items), result=status)
        return results


def preflight(home, cache, manifest=None):
    checks = []
    def check(name, passed, detail):
        checks.append({"name": name, "passed": bool(passed), "detail": detail})
    os_release = Path("/etc/os-release").read_text() if Path("/etc/os-release").exists() else ""
    distro = dict(line.split("=", 1) for line in os_release.splitlines() if "=" in line)
    check("Supported system", any("arch" in distro.get(x, "").strip('"').split() or
          "cachyos" in distro.get(x, "").strip('"').split() for x in ("ID", "ID_LIKE")), "Arch Linux or CachyOS")
    check("Architecture", platform.machine() == "x86_64", platform.machine())
    check("Desktop user", os.getuid() != 0 and home.is_dir() and os.access(home, os.W_OK), str(home))
    check("Package manager", shutil.which("pacman"), "pacman is required; no packages are changed by preflight")
    check("Authentication", shutil.which("pkexec"), "A graphical Polkit agent is needed for system operations")
    required = 512 * 1024**2 if manifest is None else manifest["image"]["bytes"] * 3 + manifest["installed_bytes"]
    check("Preparation space", shutil.disk_usage(cache.root).free >= required, f"At least {required / 1024**3:.1f} GiB on {cache.root}")
    check("Home space", shutil.disk_usage(home).free >= (manifest["installed_bytes"] if manifest else 512 * 1024**2),
          "Installation and configuration backups also require free space in your home")
    return checks
