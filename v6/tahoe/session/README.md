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
