#!/usr/bin/env python3
"""Exercise selection, stale environments, migration, restoration and failures."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("profile_fix", ROOT / "install.py")
fix = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fix)
CODE = (ROOT / "install.py").read_bytes()


class Runner:
    def __init__(self, home):
        self.home = home
        self.calls = []
        self.live = True
        self.env = "HYPRLAND_INSTANCE_SIGNATURE=live\nWAYLAND_DISPLAY=wayland-1\nSECRET_VALUE=not-printed\n"
        self.monitors = '[{"name":"eDP-1"}]'
        self.fail_reload = False

    def __call__(self, args, env=None, check=True):
        self.calls.append(args)
        result = subprocess.CompletedProcess(args, 0, "", "")
        if args[0].endswith("hyprctl"):
            result.stdout = self.monitors
        elif "show-environment" in args:
            result.stdout = self.env
        elif "show" in args:
            unit = args[3]
            prop = args[args.index("-p") + 1]
            if prop == "FragmentPath":
                result.stdout = str(self.home / ".config/systemd/user" / unit)
            elif prop == "DropInPaths":
                own = self.home / ".config/systemd/user" / (unit + ".d") / fix.DROP
                result.stdout = str(own) if own.exists() else ""
            elif prop == "LoadState":
                result.stdout = "loaded"
        elif "is-active" in args:
            result.returncode = 0 if self.live else 3
        elif "daemon-reload" in args and self.fail_reload:
            self.fail_reload = False
            result.returncode = 1
            result.stderr = "injected reload failure"
        if check and result.returncode:
            raise RuntimeError(result.stderr or "injected failure")
        return result


def fixture(home):
    user = home / ".config/systemd/user"
    user.mkdir(parents=True)
    state = home / ".config/desktop-profile/active"
    state.parent.mkdir(parents=True)
    state.write_text("sayconlun\n")
    for service in fix.SERVICES:
        (user / service).write_text(fix.expected_unit(service, home))
        link = user / "default.target.wants" / service
        link.parent.mkdir(exist_ok=True)
        link.symlink_to("../" + service)
    for rel in (".local/bin/refresh-rate-auto", ".local/bin/refresh-rate-ctl",
                ".local/share/desktop-profiles/sayconlun/support/bin/rice-wallpaper-auto"):
        p = home / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text("#!/usr/bin/true\n")
        p.chmod(0o755)
    return Runner(home)


with tempfile.TemporaryDirectory() as tmp:
    home = Path(tmp)
    runner = fixture(home)
    state = home / ".config/desktop-profile/active"
    env = {"HYPRLAND_INSTANCE_SIGNATURE": "live", "WAYLAND_DISPLAY": "wayland-1"}
    for profile in (*fix.HYPRLAND, "jaqc", "clavis", "nixri", "inir", "unknown"):
        state.write_text(profile + "\n")
        runner.calls.clear()
        assert fix.allowed("refresh", home, env, runner) == (profile in fix.HYPRLAND)
        assert fix.allowed("wallpaper", home, env, runner) == (profile == "sayconlun")
        if profile not in fix.HYPRLAND:
            assert not runner.calls, "Wrong profiles must not even probe Hyprland"
    state.write_text("sayconlun\n")
    assert not fix.allowed("refresh", home, {}, runner)
    runner.live = False
    runner.calls.clear()
    assert not fix.allowed("wallpaper", home, env, runner)
    assert not any(c[0].endswith("hyprctl") for c in runner.calls)
    runner.live = True
    runner.monitors = "not JSON"
    assert not fix.allowed("refresh", home, env, runner)
    runner.monitors = "[]"
    assert not fix.allowed("refresh", home, env, runner)
    runner.monitors = '[{"name":"eDP-1"}]'
    print("PASS: all 12 profiles, stale/missing environment and dead compositor gates")

    units_before = {s: (home / ".config/systemd/user" / s).read_bytes() for s in fix.SERVICES}
    before = {str(p): fix.snapshot(p) for p in fix.paths(home)}
    fix.install(home, CODE, False, runner)
    assert before == {str(p): fix.snapshot(p) for p in fix.paths(home)}
    assert not any("stop" in c or "restart" in c for c in runner.calls)
    fix.install(home, CODE, True, runner)
    assert units_before == {s: (home / ".config/systemd/user" / s).read_bytes() for s in fix.SERVICES}
    for service in fix.SERVICES:
        assert not (home / ".config/systemd/user/default.target.wants" / service).is_symlink()
        assert (home / ".config/systemd/user" / (fix.START_TARGET + ".wants") / service).resolve() == home / ".config/systemd/user" / service
    assert [c[-1] for c in runner.calls if "restart" in c] == list(fix.SERVICES)
    after = {str(p): fix.snapshot(p) for p in fix.paths(home)}
    count = len(runner.calls)
    fix.install(home, CODE, True, runner)
    assert not any("stop" in c or "restart" in c for c in runner.calls[count:])
    backup = next((home / ".local/share/desktop-profiles").glob("profile-services-backup-*"))
    fix.restore(home, backup, runner)
    assert before == {str(p): fix.snapshot(p) for p in fix.paths(home)}
    print("PASS: check-only, migration, original units preserved, repeat and restoration")

    runner.fail_reload = True
    try:
        fix.install(home, CODE, True, runner)
        raise AssertionError("Expected reload failure")
    except RuntimeError as error:
        assert "reload failure" in str(error)
    assert before == {str(p): fix.snapshot(p) for p in fix.paths(home)}
    print("PASS: publication failure restores files and activation links")

    own = home / ".config/systemd/user/refresh-rate-auto.service.d" / fix.DROP
    own.write_text("custom override\n")
    runner.calls.clear()
    try:
        fix.install(home, CODE, True, runner)
        raise AssertionError("Expected unknown configuration rejection")
    except RuntimeError:
        pass
    assert own.read_text() == "custom override\n"
    assert not any("stop" in c or "restart" in c for c in runner.calls)
    print("PASS: unexpected override rejected before stopping any worker")

with tempfile.TemporaryDirectory() as tmp:
    home = Path(tmp)
    runner = fixture(home)
    before = {str(p): fix.snapshot(p) for p in fix.paths(home)}
    def cyclic_runner(args, env=None, check=True):
        if args[0].endswith("systemd-analyze"):
            return subprocess.CompletedProcess(args, 0, "", "Found ordering cycle; optional job deleted\n")
        return runner(args, env=env, check=check)
    try:
        fix.install(home, CODE, True, cyclic_runner)
        raise AssertionError("Expected cycle diagnostic rejection")
    except RuntimeError as error:
        assert "ordering cycle" in str(error)
    assert before == {str(p): fix.snapshot(p) for p in fix.paths(home)}
    assert not any("stop" in c or "restart" in c for c in runner.calls)
    print("PASS: cycle diagnostics reject zero-exit verification before mutation")

with tempfile.TemporaryDirectory() as tmp:
    home = Path(tmp)
    runner = fixture(home)
    (home / ".config/desktop-profile/active").write_text("inir\n")
    fix.install(home, CODE, True, runner)
    assert not any("restart" in c or "start" in c for c in runner.calls)
    assert not any(c[0].endswith("hyprctl") for c in runner.calls)
    print("PASS: application from Eclipse starts neither worker nor compositor")

# Actual drop-in parser/order verification, with UWSM topology fixtures and
# dummy backend executables. No user manager or desktop is started by this test.
with tempfile.TemporaryDirectory() as tmp:
    p = Path(tmp)
    (p / "graphical-session-pre.target").write_text("[Unit]\nDescription=Pre\n")
    (p / "graphical-session.target").write_text("[Unit]\nDescription=Graphical\n")
    (p / fix.TARGET).write_text(f"[Unit]\nDescription=Hyprland session\nRequires={fix.WM}\nWants={fix.WAITENV} {fix.START_TARGET}\nBindsTo=graphical-session.target\nBefore=graphical-session.target\n")
    (p / fix.WM).write_text(f"[Unit]\nBefore={fix.TARGET} graphical-session.target\n[Service]\nExecStart=/usr/bin/true\n")
    (p / fix.WAITENV).write_text("[Unit]\nBefore=graphical-session.target\nAfter=graphical-session-pre.target\n[Service]\nType=oneshot\nExecStart=/usr/bin/true\n")
    (p / fix.START_TARGET).write_text(f"[Unit]\nDescription=Hyprland autostart\nPartOf=graphical-session.target\nAfter={fix.TARGET} graphical-session.target\n")
    targets = []
    for service, kind in fix.SERVICES.items():
        unit = p / service
        original = fix.expected_unit(service, p)
        lines = ["ExecStart=/usr/bin/true" if line.startswith("ExecStart=") else line for line in original.splitlines()]
        unit.write_text("\n".join(lines) + "\n")
        own = p / (service + ".d") / fix.DROP
        own.parent.mkdir()
        own.write_bytes(fix.legacy_dropin(kind))
        link = p / (fix.TARGET + ".wants") / service
        link.parent.mkdir(exist_ok=True)
        link.symlink_to("../" + service)
        targets.append(str(unit))
    env = dict(os.environ, XDG_RUNTIME_DIR=str(p), SYSTEMD_UNIT_PATH=str(p) + ":")
    result = subprocess.run(["systemd-analyze", "--user", "verify", *targets, fix.TARGET], env=env, capture_output=True, text=True)
    assert "cycle" in result.stderr.lower() or "cyclic" in result.stderr.lower(), result.stderr
    print("PASS: real v1 drop-ins reproduce the reported ordering cycle")
    for service, kind in fix.SERVICES.items():
        (p / (service + ".d") / fix.DROP).write_bytes(fix.dropin(kind))
        (p / (fix.TARGET + ".wants") / service).unlink()
        link = p / (fix.START_TARGET + ".wants") / service
        link.parent.mkdir(exist_ok=True)
        link.symlink_to("../" + service)
    result = subprocess.run(["systemd-analyze", "--user", "verify", *targets, fix.TARGET, fix.START_TARGET], env=env, capture_output=True, text=True)
    assert result.returncode == 0, result.stderr
    assert "cycle" not in result.stderr.lower() and "cyclic" not in result.stderr.lower(), result.stderr
    print("PASS: real v2 drop-ins and autostart links have no ordering cycle")

    # Exercise installer preparation over a still-installed v1 layout. Its
    # removed enable links must be masked in staging, and stderr cycles must
    # fail even if systemd-analyze deletes optional jobs and returns zero.
    for service, kind in fix.SERVICES.items():
        (p / (service + ".d") / fix.DROP).write_bytes(fix.legacy_dropin(kind))
        (p / (fix.START_TARGET + ".wants") / service).unlink()
        (p / (fix.TARGET + ".wants") / service).symlink_to("../" + service)
    with tempfile.TemporaryDirectory() as home_tmp:
        home = Path(home_tmp)
        fake = fixture(home)
        before = {str(path): fix.snapshot(path) for path in fix.paths(home)}
        def verify_runner(args, env=None, check=True):
            if args[0].endswith("systemd-analyze"):
                env = dict(env, XDG_RUNTIME_DIR=str(p), SYSTEMD_UNIT_PATH=env["SYSTEMD_UNIT_PATH"] + str(p) + ":")
                # Temporary base-unit paths contain host commands that the
                # fixture replaces with harmless, existing executables.
                for service in fix.SERVICES:
                    unit = Path(args[3]).parent / service
                    unit.write_text("\n".join("ExecStart=/usr/bin/true" if line.startswith("ExecStart=") else line for line in unit.read_text().splitlines()) + "\n")
                return fix.run(args, env=env, check=check)
            return fake(args, env=env, check=check)
        fix.install(home, CODE, False, verify_runner)
        assert before == {str(path): fix.snapshot(path) for path in fix.paths(home)}
        print("PASS: real staged verification shadows installed v1 activation links")

with tempfile.TemporaryDirectory() as tmp:
    home = Path(tmp)
    runner = fixture(home)
    legacy_code = b"known legacy fixture\n"
    old_hash = fix.V1_GUARD_SHA256
    fix.V1_GUARD_SHA256 = fix.hashlib.sha256(legacy_code).hexdigest()
    try:
        before = {str(p): fix.snapshot(p) for p in fix.paths(home)}
        legacy = fix.desired(home, legacy_code, before)
        for service, kind in fix.SERVICES.items():
            legacy[str(home / ".config/systemd/user" / (service + ".d") / fix.DROP)]["data"] = fix.legacy_dropin(kind).decode()
            legacy[str(home / ".config/systemd/user" / (fix.START_TARGET + ".wants") / service)] = {"type":"absent"}
            legacy[str(home / ".config/systemd/user" / (fix.TARGET + ".wants") / service)] = {"type":"link", "target":"../" + service}
        for path, entry in legacy.items():
            fix.publish(Path(path), entry)
        fix.install(home, CODE, True, runner)
        for service in fix.SERVICES:
            assert not (home / ".config/systemd/user" / (fix.TARGET + ".wants") / service).is_symlink()
            assert (home / ".config/systemd/user" / (fix.START_TARGET + ".wants") / service).is_symlink()
        print("PASS: known v1 installation migrates directly to v2")
    finally:
        fix.V1_GUARD_SHA256 = old_hash

print("PASS: profile service integration checks")
