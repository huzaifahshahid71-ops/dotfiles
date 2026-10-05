"""Add missing packages without replacing installed versions or providers."""
from collections import defaultdict
from functools import lru_cache
from pathlib import Path
import re
import stat
import subprocess

from core import SetupError, no_symlink_parents

# These forks advertise the same Aether interfaces. Reuse only an explicitly
# known installed provider that actually declares the relevant capability.
ALIASES = {
    "midnight-cli-git": ("caelestia-cli", ("caelestia-cli", "caelestia-cli-git")),
    "midnight-shell-git": ("caelestia-shell", ("dim-caelestia-shell-git", "caelestia-shell", "caelestia-shell-git")),
}
M3SHAPES_FILES = ("usr/lib/qt6/qml/M3Shapes/libm3shapesplugin.so",
                  "usr/lib/qt6/qml/M3Shapes/m3shapes.qmltypes",
                  "usr/lib/qt6/qml/M3Shapes/qmldir")


def bundled_m3shapes(files_path, system_root=Path("/")):
    owned, section = set(), None
    for line in files_path.read_text().splitlines():
        if line.startswith("%") and line.endswith("%"):
            section = line.strip("%")
        elif not line:
            section = None
        elif section == "FILES":
            owned.add(line)
    if not set(M3SHAPES_FILES).issubset(owned):
        return False
    for relative in M3SHAPES_FILES:
        path = system_root / relative
        no_symlink_parents(path)
        if not path.is_file():
            raise SetupError("The installed Aether M3Shapes module is incomplete: " + relative)
        info = path.stat()
        if not stat.S_ISREG(info.st_mode) or info.st_uid != 0 or info.st_mode & 0o022:
            raise SetupError("The installed Aether M3Shapes module is not trusted: " + relative)
    qmldir = (system_root / M3SHAPES_FILES[-1]).read_text()
    if not re.search(r"(?m)^module\s+M3Shapes\s*$", qmldir) or not re.search(r"(?m)^(?:optional\s+)?plugin\s+m3shapesplugin(?:\s|$)", qmldir):
        raise SetupError("The installed Aether M3Shapes module descriptor differs.")
    try:
        result = subprocess.run([str(system_root / "usr/lib/ld-linux-x86-64.so.2"), "--list",
                                 str(system_root / M3SHAPES_FILES[0])], stdin=subprocess.DEVNULL,
                                capture_output=True, text=True, timeout=30)
    except subprocess.TimeoutExpired as error:
        raise SetupError("The installed Aether M3Shapes library check timed out.") from error
    if result.returncode:
        raise SetupError("The installed Aether M3Shapes library cannot load: " + result.stderr.strip()[-1500:])
    return True


def command(arguments):
    try:
        result = subprocess.run(arguments, stdin=subprocess.DEVNULL, capture_output=True,
                                text=True, timeout=60)
    except subprocess.TimeoutExpired as error:
        raise SetupError("Package metadata query timed out: " + str(arguments[0])) from error
    if result.returncode:
        raise SetupError(result.stderr.strip() or "Package metadata query failed.")
    return result.stdout


def read_database(root):
    packages = {}
    for path in sorted(root.glob("*/desc")):
        fields, key = defaultdict(list), None
        for line in path.read_text().splitlines():
            if line.startswith("%") and line.endswith("%"):
                key = line.strip("%")
            elif not line:
                key = None
            elif key:
                fields[key].append(line)
        if fields.get("NAME"):
            packages[fields["NAME"][0]] = {
                "name": fields["NAME"][0], "version": fields["VERSION"][0],
                "provides": fields.get("PROVIDES", []), "depends": fields.get("DEPENDS", []),
                "conflicts": fields.get("CONFLICTS", [])}
            if fields["NAME"][0] == "dim-caelestia-shell-git":
                files = path.with_name("files")
                if files.is_file():
                    packages[fields["NAME"][0]]["bundled_m3shapes"] = bundled_m3shapes(files, root.parents[3])
    if not packages:
        raise SetupError("The installed package metadata is empty or unreadable.")
    return packages


def archive_metadata(path):
    fields = defaultdict(list)
    for line in command(["/usr/bin/bsdtar", "-xOf", str(path), ".PKGINFO"]).splitlines():
        if " = " in line and not line.startswith("#"):
            key, value = line.split(" = ", 1)
            fields[key].append(value)
    if len(fields["pkgname"]) != 1 or len(fields["pkgver"]) != 1:
        raise SetupError("Ambiguous package metadata: " + path.name)
    return {"name": fields["pkgname"][0], "version": fields["pkgver"][0],
            "provides": fields["provides"], "depends": fields["depend"], "conflicts": fields["conflict"]}


def specification(value):
    match = re.fullmatch(r"([^<>=]+)(>=|<=|=|>|<)?(.*)", value)
    if not match:
        raise SetupError("Invalid package requirement: " + value)
    return match.groups()


@lru_cache(maxsize=None)
def vercmp(a, b):
    return int(command(["/usr/bin/vercmp", a, b]).strip())


def select(records, installed):
    names, retained, aliases, missing = set(), {}, {}, []
    for record in records:
        name = record["name"]
        if name in names:
            raise SetupError("Duplicate package target: " + name)
        names.add(name)
        if name in installed:
            retained[name] = installed[name]["version"]
            continue
        if (name == "qt6-m3shapes-git" and
            installed.get("dim-caelestia-shell-git", {}).get("bundled_m3shapes") is True):
            aliases[name] = "dim-caelestia-shell-git (bundled M3Shapes)"
            continue
        if name in ALIASES:
            capability, allowed = ALIASES[name]
            provider = next((p for p in allowed if p in installed and
                            (p == capability or any(specification(x)[0] == capability
                             for x in installed[p].get("provides", [])))), None)
            if provider:
                aliases[name] = provider
                continue
        missing.append(record)
    return missing, retained, aliases


def validate(proposed, installed, compare=vercmp):
    providers = defaultdict(list)
    for package in [*installed.values(), *proposed]:
        providers[package["name"]].append((package["name"], package["version"]))
        for item in package.get("provides", []):
            name, operator, version = specification(item)
            providers[name].append((package["name"], version if operator == "=" else None))

    def matching(spec):
        name, operator, expected = specification(spec)
        result = set()
        for owner, version in providers[name]:
            if not operator:
                result.add(owner)
            elif version is not None:
                value = compare(version, expected)
                if {"=": value == 0, ">=": value >= 0, "<=": value <= 0,
                    ">": value > 0, "<": value < 0}[operator]:
                    result.add(owner)
        return result

    new_names = {p["name"] for p in proposed}
    if new_names.intersection(installed):
        raise SetupError("Package proposal would replace an installed package.")
    failures = []
    for package in proposed:
        for dependency in package["depends"]:
            if not matching(dependency):
                failures.append(package["name"] + " requires " + dependency)
    for package in [*installed.values(), *proposed]:
        for conflict in package.get("conflicts", []):
            for other in sorted(matching(conflict)):
                if other != package["name"] and (other in new_names or package["name"] in new_names):
                    failures.append(package["name"] + " conflicts with " + other)
    if failures:
        raise SetupError("Missing-package compatibility check failed; no packages changed:\n" +
                         "\n".join(dict.fromkeys(failures)))


def unchanged(before, after):
    changed = [name for name, version in before.items() if after.get(name) != version]
    if changed:
        raise SetupError("Installed package inventory changed: " + ", ".join(changed[:20]))
