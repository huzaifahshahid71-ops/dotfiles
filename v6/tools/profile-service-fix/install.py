#!/usr/bin/env python3
"""Scope the two inspected user services to their UWSM Hyprland session."""
import argparse
import configparser
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile

TARGET = "wayland-session@hyprland.desktop.target"
WM = "wayland-wm@hyprland.desktop.service"
WAITENV = "wayland-session-waitenv.service"
HYPRLAND = frozenset(("caelestia", "end4", "ambxst", "dms", "serpantinum",
                      "noctalia", "sayconlun", "tsugumori"))
SERVICES = {"refresh-rate-auto.service": "refresh", "rice-wallpaper-auto.service": "wallpaper"}
GUARD = ".local/libexec/multi-rice-service-guard.py"
DROP = "90-multi-rice-profile.conf"


def run(args, *, env=None, check=True):
    result = subprocess.run(args, env=env, text=True, capture_output=True, timeout=30)
    if check and result.returncode:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip() or f"Failed: {args[0]}")
    return result


def profile_allowed(kind, profile):
    return profile in HYPRLAND if kind == "refresh" else kind == "wallpaper" and profile == "sayconlun"


def allowed(kind, home, env, runner=run):
    try:
        profile = (home / ".config/desktop-profile/active").read_text().strip()
        if not profile_allowed(kind, profile):
            return False
        # Never start a compositor to satisfy a condition. Read the live unit.
        if runner(["/usr/bin/systemctl", "--user", "is-active", "--quiet", WM], check=False).returncode:
            return False
        if not env.get("HYPRLAND_INSTANCE_SIGNATURE") or not env.get("WAYLAND_DISPLAY"):
            return False
        # A stale signature must not be accepted merely because it is nonempty.
        result = runner(["/usr/bin/hyprctl", "-j", "monitors"], env=env, check=False)
        monitors = json.loads(result.stdout) if result.returncode == 0 else []
        return isinstance(monitors, list) and any(isinstance(m, dict) and m.get("name") for m in monitors)
    except (OSError, ValueError, subprocess.SubprocessError, RuntimeError):
        return False


def dropin(kind):
    # After= is reset: the old wallpaper unit orders itself AFTER the generic
    # graphical target, which would form a cycle when wanted by this session.
    # PartOf supplies stop propagation without pulling a compositor into a
    # manual start transaction (BindsTo/Requires on WM would do that).
    return f'''# Managed by Huzaifah Multi-Rice profile-service-fix v1
[Unit]
After=
After={WM} {WAITENV}
PartOf={TARGET} graphical-session.target

[Service]
ExecCondition=/usr/bin/python3 "%h/{GUARD}" --condition {kind}

[Install]
WantedBy=
WantedBy={TARGET}
'''.encode()


def expected_unit(service, home):
    if service == "refresh-rate-auto.service":
        return '''[Unit]
Description=Automatic AC/Battery refresh-rate switching
After=default.target
[Service]
Type=simple
ExecStart=%h/.local/bin/refresh-rate-auto
Restart=always
RestartSec=2
[Install]
WantedBy=default.target
'''
    return f'''[Unit]
Description=Lumina automatic wallpaper rotation
After=graphical-session.target
[Service]
Type=simple
ExecStart={home}/.local/share/desktop-profiles/sayconlun/support/bin/rice-wallpaper-auto
Restart=on-failure
RestartSec=5
[Install]
WantedBy=default.target
'''


def parsed(text):
    cfg = configparser.ConfigParser(interpolation=None, strict=True)
    cfg.optionxform = str
    cfg.read_string(text)
    return {section: dict(cfg[section]) for section in cfg.sections()}


def safe_parent(path, home):
    path.relative_to(home)
    current = path.parent
    while current != home:
        if current.is_symlink():
            raise RuntimeError(f"Refusing a symlink directory: {current}")
        current = current.parent


def snapshot(path):
    if path.is_symlink():
        return {"type": "link", "target": os.readlink(path)}
    if not path.exists():
        return {"type": "absent"}
    if not path.is_file():
        raise RuntimeError(f"Expected a regular file: {path}")
    return {"type": "file", "data": path.read_text(), "mode": stat.S_IMODE(path.stat().st_mode)}


def publish(path, entry):
    path.parent.mkdir(parents=True, exist_ok=True)
    if entry["type"] == "absent":
        path.unlink(missing_ok=True)
        return
    if entry["type"] == "link":
        tmp = path.parent / (".profile-link-" + next(tempfile._get_candidate_names()))
        try:
            tmp.symlink_to(entry["target"])
            os.replace(tmp, path)
        finally:
            tmp.unlink(missing_ok=True)
        return
    fd, tmp = tempfile.mkstemp(prefix=".profile-service-", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            stream.write(entry["data"])
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(tmp, entry["mode"])
        os.replace(tmp, path)
    finally:
        Path(tmp).unlink(missing_ok=True)


def paths(home):
    user = home / ".config/systemd/user"
    result = [home / GUARD]
    for service in SERVICES:
        result.extend((user / (service + ".d") / DROP,
                       user / "default.target.wants" / service,
                       user / (TARGET + ".wants") / service))
    return result


def manager_env(runner):
    env = dict(os.environ)
    # Read without printing the manager environment (it may contain secrets).
    for key in ("HYPRLAND_INSTANCE_SIGNATURE", "WAYLAND_DISPLAY", "DISPLAY", "NIRI_SOCKET"):
        env.pop(key, None)
    for line in runner(["/usr/bin/systemctl", "--user", "show-environment"]).stdout.splitlines():
        key, sep, value = line.partition("=")
        if sep and key in ("HYPRLAND_INSTANCE_SIGNATURE", "WAYLAND_DISPLAY", "DISPLAY", "NIRI_SOCKET"):
            env[key] = value
    return env


def preflight(home, code, runner=run):
    user = home / ".config/systemd/user"
    for path in paths(home):
        safe_parent(path, home)
    guard = home / GUARD
    if guard.exists() or guard.is_symlink():
        if guard.is_symlink() or not guard.is_file() or guard.read_bytes() != code:
            raise RuntimeError("The guard destination contains another file; preserved")
    for service, kind in SERVICES.items():
        source = user / service
        safe_parent(source, home)
        if source.is_symlink() or not source.is_file() or parsed(source.read_text()) != parsed(expected_unit(service, home)):
            raise RuntimeError(f"Installed unit differs from the inspected source: {source}; preserved")
        own = user / (service + ".d") / DROP
        if own.exists() or own.is_symlink():
            if own.is_symlink() or not own.is_file() or own.read_bytes() != dropin(kind):
                raise RuntimeError(f"Another drop-in occupies {own}; preserved")
        fragment = runner(["/usr/bin/systemctl", "--user", "show", service, "-p", "FragmentPath", "--value"]).stdout.strip()
        drops = runner(["/usr/bin/systemctl", "--user", "show", service, "-p", "DropInPaths", "--value"]).stdout.strip()
        if fragment != str(source) or drops not in ("", str(own)):
            raise RuntimeError(f"Unexpected loaded configuration for {service}; preserved")
        allowed_links = {user / "default.target.wants" / service, user / (TARGET + ".wants") / service}
        for link in user.glob("*.*/*"):
            if link.name == service and (link.exists() or link.is_symlink()):
                if link not in allowed_links or not link.is_symlink() or link.resolve() != source.resolve():
                    raise RuntimeError(f"Unexpected activation link: {link}; preserved")
    for rel in (".local/bin/refresh-rate-auto", ".local/bin/refresh-rate-ctl",
                ".local/share/desktop-profiles/sayconlun/support/bin/rice-wallpaper-auto"):
        script = home / rel
        if not script.is_file() or not os.access(script, os.X_OK):
            raise RuntimeError(f"Installed backend is missing or not executable: {script}")
    for unit in (TARGET, WM, WAITENV):
        state = runner(["/usr/bin/systemctl", "--user", "show", unit, "-p", "LoadState", "--value"]).stdout.strip()
        if state != "loaded":
            raise RuntimeError(f"Required UWSM unit is unavailable: {unit}")


def desired(home, code, before):
    user = home / ".config/systemd/user"
    result = {str(home / GUARD): {"type": "file", "data": code.decode(), "mode": 0o755}}
    for service, kind in SERVICES.items():
        own = user / (service + ".d") / DROP
        old = user / "default.target.wants" / service
        new = user / (TARGET + ".wants") / service
        enabled = before[str(old)]["type"] == "link" or before[str(new)]["type"] == "link"
        result[str(own)] = {"type": "file", "data": dropin(kind).decode(), "mode": 0o644}
        result[str(old)] = {"type": "absent"}
        result[str(new)] = {"type": "link", "target": "../" + service} if enabled else {"type": "absent"}
    return result


def install(home, code, apply=False, runner=run):
    preflight(home, code, runner)
    before = {str(p): snapshot(p) for p in paths(home)}
    after = desired(home, code, before)
    if before == after:
        print("ALREADY APPLIED: services are owned by the Hyprland session")
        return
    # Verify staged merged units against the host's UWSM dependencies first.
    base = home / ".local/share/desktop-profiles"
    safe_parent(base / "stage", home)
    base.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".profile-services-stage-", dir=base) as staging:
        staged = []
        for service, kind in SERVICES.items():
            path = Path(staging) / service
            path.write_text(expected_unit(service, home) + "\n" + dropin(kind).decode())
            staged.append(str(path))
        runner(["/usr/bin/systemd-analyze", "--user", "verify", *staged])
    print("Refresh: all eight Hyprland profiles; wallpaper rotation: Lumina only")
    if not apply:
        print("CHECK PASSED: run with --apply to install")
        return
    active = [s for s in SERVICES if runner(["/usr/bin/systemctl", "--user", "is-active", "--quiet", s], check=False).returncode == 0]
    env = manager_env(runner)
    backup = Path(tempfile.mkdtemp(prefix="profile-services-backup-", dir=base))
    receipt = {"before": before, "after": after, "active": active}
    (backup / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print("Backup: " + str(backup), flush=True)
    mutated = False
    try:
        # Detect edits between inspection and publication before stopping anything.
        if any(snapshot(Path(p)) != entry for p, entry in before.items()):
            raise RuntimeError("A destination changed during preparation")
        mutated = True
        runner(["/usr/bin/systemctl", "--user", "stop", *SERVICES])
        for p, entry in after.items():
            publish(Path(p), entry)
        runner(["/usr/bin/systemctl", "--user", "daemon-reload"])
        # Only these two services are started, and only with a live allowed session.
        for service, kind in SERVICES.items():
            if allowed(kind, home, env, runner) and (service in active or after[str(home / '.config/systemd/user' / (TARGET + '.wants') / service)]["type"] == "link"):
                runner(["/usr/bin/systemctl", "--user", "restart", service])
        (backup / "APPLIED").write_text("Profile service ownership v1\n")
    except BaseException:
        if mutated:
            runner(["/usr/bin/systemctl", "--user", "stop", *SERVICES], check=False)
            for p, entry in before.items():
                publish(Path(p), entry)
            runner(["/usr/bin/systemctl", "--user", "daemon-reload"], check=False)
            if active:
                runner(["/usr/bin/systemctl", "--user", "start", *active], check=False)
        raise
    print("INSTALLED: profile-scoped services; current desktop remains running")
    status(runner)


def restore(home, backup, runner=run):
    base = home / ".local/share/desktop-profiles"
    if backup.is_symlink() or backup.parent != base or not backup.name.startswith("profile-services-backup-"):
        raise RuntimeError("Expected the backup directory printed by this installer")
    receipt = json.loads((backup / "receipt.json").read_text())
    allowed_paths = {str(p) for p in paths(home)}
    if set(receipt["before"]) != allowed_paths or set(receipt["after"]) != allowed_paths:
        raise RuntimeError("Backup path table is invalid")
    if any(service not in SERVICES for service in receipt["active"]):
        raise RuntimeError("Backup service table is invalid")
    for p in allowed_paths:
        safe_parent(Path(p), home)
        if snapshot(Path(p)) != receipt["after"][p]:
            raise RuntimeError(f"Installed file was edited since application: {p}; preserved")
    runner(["/usr/bin/systemctl", "--user", "stop", *SERVICES])
    for p, entry in receipt["before"].items():
        publish(Path(p), entry)
    runner(["/usr/bin/systemctl", "--user", "daemon-reload"])
    env = manager_env(runner)
    for service in receipt["active"]:
        if allowed(SERVICES[service], home, env, runner):
            runner(["/usr/bin/systemctl", "--user", "start", service])
    print("RESTORED: original activation links and prior guard files")


def status(runner=run):
    result = runner(["/usr/bin/systemctl", "--user", "show", *SERVICES,
                    "-p", "Id", "-p", "ActiveState", "-p", "SubState",
                    "-p", "PartOf", "-p", "WantedBy", "--no-pager"])
    print(result.stdout.rstrip())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--apply", action="store_true")
    group.add_argument("--restore", type=Path)
    group.add_argument("--status", action="store_true")
    group.add_argument("--condition", choices=("refresh", "wallpaper"))
    args = parser.parse_args()
    home = Path.home()
    if args.condition:
        return 0 if allowed(args.condition, home, dict(os.environ)) else 1
    try:
        if os.geteuid() == 0:
            raise RuntimeError("Run this as your desktop user, without sudo")
        if args.status:
            status()
        elif args.restore:
            restore(home, args.restore.absolute())
        else:
            install(home, Path(__file__).read_bytes(), args.apply)
        return 0
    except (Exception, KeyboardInterrupt) as error:
        print("Profile service fix stopped: " + str(error), file=sys.stderr)
        print("No desktop logout or restart was requested.", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
