"""Turn privately collected host sources into a clean, portable payload layer.

No source archive is copied wholesale into the release. Caches, runtime state,
old receipts, logs and private Eclipse preferences are deliberately omitted.
"""
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import stat
import zipfile

from core import PROFILES, SetupError, relative_path, sha256
from eclipse_defaults import apply_defaults as eclipse_defaults
from runtime_sources import special_source

PREFIX = ".local/share/desktop-profiles/"
HOME_TOKEN = "@MULTI_RICE_HOME@"
USER_TOKEN = "@MULTI_RICE_USER@"
SKIP_NAMES = {".git", ".cache", "cache", ".state", "state", "logs", "log", "__pycache__",
              "node_modules", "venv", ".venv", "backups", "backup", "failed-profile"}
SKIP_FILES = re.compile(r"(^|/)(installed|receipt|last-boot)\.json$|\.lock$|\.log$|"
                        r"before-|backup-|\.(bak|old|orig|backup)(?:$|[-.])|current_wallpaper\.txt$|wallpaper_path\.txt$", re.I)
SCRIPT_FILES = {".local/bin/lumina-music-ctl", ".local/bin/huzaifah-lumina-music",
                ".local/bin/lumina-player-overlay", ".local/bin/desktop-switch",
                ".local/bin/multi-rice-control", ".local/bin/multi-rice-session",
                ".local/bin/refresh-rate-auto", ".local/bin/refresh-rate-ctl"}


def included(relative):
    path = relative_path(relative)
    ignored = SKIP_NAMES - {'state', '.state'} if special_source(relative) else SKIP_NAMES
    if any(x in ignored for x in path.parts) or SKIP_FILES.search(relative):
        return False
    if relative in SCRIPT_FILES:
        return True
    if relative.startswith((".local/share/desktop-switcher/", ".local/share/multi-rice-music/",
                            ".config/quickshell/multi-rice-switcher/")):
        return True
    if relative.startswith(".config/systemd/user/"):
        name = path.name
        return name.startswith(("huzaifah-cipher-native", "huzaifah-inir")) and name.endswith(".service")
    if relative.startswith(PREFIX):
        remainder = relative[len(PREFIX):].split("/")
        if len(remainder) < 2 or remainder[0] not in PROFILES:
            return False
        # Eclipse's private HOME contains application/session data, not source.
        if remainder[1] in ("home", "source", "pending-units", "test", "tests"):
            return False
        # A private XDG tree can acquire browser/application data when programs
        # inherit its environment. Only the rice's actual UI/theme folders are
        # runtime sources; never export arbitrary applications from that tree.
        if remainder[:3] == ['tsugumori','support','config']:
            if len(remainder) < 5 or remainder[3] not in {
                'quickshell','waybar','foot','kitty','fish','fastfetch','btop',
                'fontconfig','gtk-3.0','gtk-4.0'}:
                return False
        return True
    return False


def portable(data, old_home):
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError:
        return data, False
    if "\x00" in text:
        return data, False
    old_user = Path(old_home).name
    result = text.replace(old_home, HOME_TOKEN).replace("/AccountsService/icons/" + old_user,
                                                      "/AccountsService/icons/" + USER_TOKEN)
    return result.encode(), result != text


def stage_collection(archive_path, destination, repository):
    destination, repository = Path(destination), Path(repository)
    if destination.exists() and any(destination.iterdir()):
        raise SetupError("Source staging must start in an empty directory.")
    destination.mkdir(parents=True, exist_ok=True)
    layer = destination / "home"
    layer.mkdir()
    records, omitted, seen = [], [], set()
    with zipfile.ZipFile(archive_path) as archive:
        report = json.loads(archive.read("report.json"))
        if report.get("schema") != 1 or set(report.get("profiles", {})) != set(PROFILES) or not all(report["profiles"].values()):
            raise SetupError("The collection does not cover all twelve profiles.")
        expected = {"home/" + x["path"]: x for x in report["files"]}
        if len(expected) != len(report["files"]):
            raise SetupError("Duplicate source records.")
        for info in archive.infolist():
            relative_path(info.filename)
            if info.filename in seen or stat.S_ISLNK(info.external_attr >> 16):
                raise SetupError("Duplicate or symbolic ZIP member.")
            seen.add(info.filename)
            if info.filename == "report.json":
                continue
            record = expected.get(info.filename)
            if not record or info.file_size != record["bytes"]:
                raise SetupError("Unexpected collection member: " + info.filename)
            if not included(record["path"]):
                omitted.append(record["path"])
                continue
            data = archive.read(info)
            if hashlib.sha256(data).hexdigest() != record["sha256"]:
                raise SetupError("Collected source hash differs: " + record["path"])
            data, template = portable(data, "/home/gamer")
            output = layer / record["path"]
            output.parent.mkdir(parents=True, exist_ok=True)
            output.write_bytes(data)
            output.chmod(record["mode"] & 0o777)
            records.append({"path": record["path"], "sha256": sha256(output), "bytes": len(data),
                            "mode": record["mode"] & 0o777, "template": template})
    if not set(expected).issubset(seen):
        raise SetupError("The source ZIP is incomplete.")

    def generated(relative, data, mode=0o644, init=False):
        data = data.encode() if isinstance(data, str) else data
        output = layer / relative
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_bytes(data)
        output.chmod(mode)
        records[:] = [x for x in records if x["path"] != relative]
        records.append({"path": relative, "sha256": sha256(output), "bytes": len(data), "mode": mode,
                        "template": HOME_TOKEN.encode() in data or USER_TOKEN.encode() in data, "init": init})

    # Generate clean Eclipse settings from its pinned upstream defaults. Only a
    # small visual preset is selected; account, AI, history, clipboard, network
    # and location preferences from the private home are never imported.
    inir = PREFIX + "inir/"
    defaults = json.loads((layer / (inir + "runtime/defaults/config.json")).read_text())
    defaults["panelFamily"] = "waffle"
    defaults["appearance"]["fakeScreenRounding"] = 0
    defaults = eclipse_defaults(defaults)
    generated(inir + "home/.config/inir/config.json", json.dumps(defaults, indent=2) + "\n", init=True)
    generated(inir + "READY", "6.0.0\n")

    # Use the corrected v2 guard/drop-ins, not the old base units collected
    # without their effective configuration. No services are started here.
    guard_path = repository / "v6/tools/profile-service-fix/install.py"
    spec = importlib.util.spec_from_file_location("release_service_guard", guard_path)
    guard = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(guard)
    generated(guard.GUARD, guard_path.read_bytes(), 0o755)
    for kind, name in (("refresh", "refresh-rate-auto.service"), ("wallpaper", "rice-wallpaper-auto.service")):
        generated(".config/systemd/user/" + name, guard.expected_unit(name, Path(HOME_TOKEN)))
        generated(".config/systemd/user/" + name + ".d/90-multi-rice-profile.conf", guard.dropin(kind))

    manifest = {"schema": 1, "version": "6.0.0", "profiles": PROFILES, "files": sorted(records, key=lambda x: x["path"]),
                "collection_sha256": sha256(Path(archive_path)),
                "source_context": "Reviewed host source layer; no caches, private Eclipse home or old receipts",
                "cipher_source": {"repository": "https://github.com/StatIndet/niri-edge.git",
                                  "commit": "c1a5a2f0a45dba69b07d2dcbba071fcc9e17e1d0"},
                "omitted_count": len(omitted)}
    (destination / "source-layer.json").write_text(json.dumps(manifest, indent=2) + "\n")
    # This private diagnostic never becomes part of the public payload.
    (destination / "omitted-private-paths.json").write_text(json.dumps(omitted, indent=2) + "\n")
    return manifest
