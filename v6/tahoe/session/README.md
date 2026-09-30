# Tahoe — standby standalone Hyprland session (NOT INSTALLED)

This directory stages **a plugin-free, isolated Hyprland 0.56.2 Lua
configuration**. It must not affect a running Hyprland or Niri rice.

## Why

On September 30 the G16 reported Aquamarine **0.15.0-2.1**. An upstream
nested-output stall in Aquamarine #348 was demonstrated on **0.14.0**;
we therefore cannot claim the issue is identical, and should not
downgrade, upgrade or patch Aquamarine based on that report.

The nested Hyprliquid v0.2.1 plugin was loaded and its shaders initialized,
but the nested GUI froze on the triangle wallpaper and no visible
refraction has been established. No more nested-glass retries.

## First-boot design

* Standalone physical Hyprland, **no native plugins** initially.
* Self-contained `hyprland.lua`: no `require()`, profile links,
  previous rice autostart, compositor plugin, shell, daemon or services.
* Uses preferred display mode at 1.25 scale, Foot autolaunch, and
  `Super+Enter` recovery terminal.
* `Super+Shift+E` exits ONLY this Tahoe compositor and returns to the
  login manager. Verify other sessions can still log in beforehand.
* Floating-first rules, Tahoe QML panels, auto-loaded hyprliquid,
  icon/GTK assets and minimized-window plumbing follow as independently
  testable milestones; nothing is silently enabled in the first boot.

## Before authorizing installation

Determine the real display manager/session launcher and the appropriate
user-vs-root session registration path; verify a functioning older
Hyprland/Niri/KDE login; inspect login session and relevant hooks for
conflicts. Review an exact list of target files, their backups and
rollback commands. Avoid overwriting a system-wide existing session
desktop file or `~/.config/hypr` symlink.

This branch contains **staging source only**. No installer or start
command should be executed yet. The standalone Lua config can undergo
syntax verification via `Hyprland --verify-config --config ...` after
clone, without starting Hyprland; doing so is optional.

## Evidence / signoff criteria

1. Baseline physical Tahoe login launches Foot and can exit/logout
   without affecting another rice.
2. Input, outputs, monitor scaling, GPU display, 60/240 Hz switching
   and parent/child session environment behave as intended.
3. Save a tested fallback login and recovery route, then add a separate
   **opt-in** Hyprliquid config with ABI check for later real refraction.
4. A visible screenshot and interaction over a high-contrast background
   are required before calling Liquid Glass operational.

## SDDM discovery on the G16 (September 30, 20:14 KSA)

The user ran the following read-only commands:

```text
readlink -f /etc/systemd/system/display-manager.service
/usr/lib/systemd/system/sddm.service

ls /usr/share/wayland-sessions/
huzaifah-multi-rice.desktop
hyprland-uwsm.desktop
hyprland.desktop
niri.desktop
```

Therefore this machine's display manager is **SDDM**. An opt-in fifth
session can be registered under a **unique** name and file, retaining all
four originals. It must **NOT** overwrite `huzaifah-multi-rice.desktop`
or modify `/var/lib/sddm/state.conf`.

Two **staged source templates, not installed**:

* `zephyrus-tahoe.desktop`: uniquely named SDDM desktop-entry;
  potential target `/usr/share/wayland-sessions/zephyrus-tahoe.desktop`.
* `zephyrus-tahoe-session`: watchdog launcher using
  `start-hyprland -- --config "$config"`; potential target
  `/usr/local/bin/zephyrus-tahoe-session`, executable permissions.
  At runtime it expects the separately installed, plugin-free Lua
  config in `${XDG_DATA_HOME:-$HOME/.local/share}/zephyrus-v6/tahoe-session/hyprland.lua`.

Hyprland v0.56.2 `start-hyprland` documentation explicitly states that
arguments after `--` are forwarded to Hyprland. The existing
`hyprland.desktop` in upstream uses the watchdog for primary logins.

**Next preflight, read-only in fish, BEFORE creating an installer:**

```fish
for f in /usr/share/wayland-sessions/huzaifah-multi-rice.desktop /usr/share/wayland-sessions/hyprland.desktop /usr/share/wayland-sessions/hyprland-uwsm.desktop
    echo "--- $f"
    grep -E '^(Name|Exec|TryExec|DesktopNames|Type)=' "$f"
end
command -v start-hyprland
command -v foot
```

After confirming existing launch conventions and the availability of both
programs, draft a user-reviewed installer with an explicit opt-in, exact
file list, backups/rollback and a no-write `--check` mode. No one should
register an entry without permission. All other sessions remain selectable
in SDDM for recovery.


## Physical plugin-free Tahoe baseline — PASS after live runtime inspection

Initial visual interpretation was wrong: the default Hyprland welcome /
triangle surface looked like a frozen session because the minimal Tahoe
baseline intentionally has no shell, dock, bar or wallpaper daemon.

Live inspection from the running Tahoe session proved it is healthy:

- `hyprctl configerrors`: empty.
- Physical output: `eDP-1`, 2560x1600, 240 Hz, scale 1.25, focused.
- `Super+T` launches Foot successfully; multiple Foot clients are mapped.
- Google Chrome launched and mapped on workspace 1.
- Input/keybind dispatch therefore works.
- Instance signature is valid and the compositor owns `wayland-1`.

**Status: standalone baseline PASS.** The default welcome surface is simply
the bare compositor background. Do not rollback the session solely because
that screen is visible.

Next milestone: launch the existing Tahoe Quickshell alpha live in this same
physical standalone session, still with Hyprliquid disabled. Validate bar,
Dock, launchers, focus and clean exit before enabling any native plugin.
