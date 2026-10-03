# ZEPHYRUS G16 — v6.0 Project TAHOE (design stage)

Status: **Current release scope: preserve the eight host Hyprland rices and three existing Niri rices; add Eclipse (iNiR) as profile 12, the fourth Niri rice.** The selected-profile installer is in [`tools/inir-profile`](tools/inir-profile/README.md). Remote adaptation, environment, catalog/routing and recovery checks pass. The user confirmed successful host installation, live iNiR login and the modern switcher shortcut on 2026-10-03. Eclipse is the display name; `inir` remains the internal ID. Broader feature and cross-profile switching validation remains outstanding.

## Why this branch exists

Build **one** new, high-fidelity macOS Tahoe-inspired desktop on **Hyprland**,
instead of shipping the experimental full Revo shell collection.
Begin from v5.0 `main`, not the draft `v5.1.0-revo-dev` branch.

## Release scope

- Preserve exactly the **8 existing Hyprland profiles on the real G16**, including Tsugumori.
  The Git repository's baseline table contains 7; extend the installed host
  table additively so Tsugumori and any local profiles remain available.
- Preserve the 3 existing Niri rices: Solstice/jaqc, Cipher/clavis,
  Astra/nixri. Add **Eclipse/inir (upstream iNiR)** as the **fourth Niri rice**.
- Target release: **12 desktop rices: 8 Hyprland + 4 Niri**, contingent on
  successful iNiR host validation. The older Tahoe design sections below
  record the earlier exploration; Eclipse (iNiR) is the currently selected final rice.
- Preserve Lumina's current music player, media integrations, and existing
  user systemd backend services; audit actual filenames/units before shipping.
- Keep the original graphical rice switcher and its backend, with an optional
  **Revo-inspired** switcher visual skin under **Themes**. Implement the UI
  independently; do not vendor Revo's DotsBrowser source without permission
  or verified licensing. Make Super+B configurable, preserving other binds
  and Super+Shift+D.
- Do **not** merge draft v5.1 PR #3 or transplant its full Revo source tree.

## Mac-like Tahoe shell

One Quickshell application for Hyprland; never stack multiple independent shell
bars or watchers. Subsystems:

1. Full-width top menu bar with active app/title, clock, tray, status.
2. Bottom responsive dock with icons, magnification, launch/status indicators.
3. Spotlight-style searchable launcher, including keyboard accessibility.
4. Translucent Control Center (audio, brightness, network, Bluetooth,
   night light) and notification surface.
5. Finder-inspired file management **appearance** via an existing
   file manager plus a matching icon/GTK theme; do not promise to reproduce
   macOS Finder application features.
6. Wallpapers, light/dark mode, lock screen, animation/performance profiles.

### Liquid Glass + actual window behavior

- Use `hyprliquid` only within the isolated Tahoe Hyprland 0.56.2
  profile; require exact-build compatibility, snapshot and fallback.
- Native refraction and rim highlights are a different task from window
  animation deformation.
- Build a floating-first window manager with a **real minimize/restore
  backend** (selected-window move into hidden special workspace, restore to
  original placement); stable Dock entries and multiple windows per app.
- **True Genie** is a separate experimental Hyprland compositor-plugin
  milestone, *not* an advertised built-in feature. Begin with safe
  Dock-directed scaling fallback, then prototype a real window-texture
  funnel/mesh warp if compatibility and performance allow.
- Evaluate HyprExpo for macOS-style Mission Control; it advertises support
  for Hyprland 0.56.2 but must be tested alongside Hyprliquid.
- Preserve window-specific CSD differences; full cross-toolkit Apple
  menu integration is not guaranteed.
- See [TAHOE-WINDOW-MANAGEMENT.md](TAHOE-WINDOW-MANAGEMENT.md) for
  minimize state model, Genie geometry and acceptance gates.

## MacTahoe resources

- https://github.com/vinceliuice/MacTahoe-icon-theme — **icons**, not a
  desktop shell or compositor effect. Install into user's local icon
  directory and configure desktop/toolkit icon lookups.
- https://github.com/vinceliuice/MacTahoe-gtk-theme — optional GTK
  application styling; GTK4/libadwaita differences remain.
- Independently audit asset license obligations. Do not silently absorb
  upstream icons/fonts into the dotfiles repository or distributable.

## UI / switcher contract

```
Multi-Rice switcher
  ├── Rices
  │   ├── Hyprland: 9 planned (8 verified + Tahoe)
  │   └── Niri: 3 installed (unchanged)
  └── Themes
      ├── Original skin
      └── Revo-inspired visual skin (original implementation)
```

Theme preference changes the *appearance of the switcher*, not compositor
profile state. All themes call the same tested backend. Super+B is optional;
support safe revert for any keyboard conflict.

## Host-first packaging

1. Run the **read-only** `v6/tools/audit-host.sh` on the G16.
2. Build exact profile / unit / package manifests from **real host state**;
   redact secrets, keys, credentials, private browser data, and huge caches.
3. Btrfs snapshot or timestamped backup **before** modifying existing
   system files; prepare tested recovery path and fallback session.
4. Prototype Tahoe in a user-local isolated config on the host.
5. Validate boot/session switch, compositor differences, media backend,
   GPU, keyboard binds, wallpapers, refresh-rate handling, and sleep/wake.
6. Build installer with reproducible pinned sources. Keep system tweaks,
   custom kernel, bootloader, power management and swap/hibernation untouched.
7. VM validation when possible, then production-host smoke-test with
   rollback before a public v6.0 tag.
8. Offline installer/AppImage packaging **after** host integration succeeds,
   with checksums and optional split distribution.

No installer should issue `pacman -Syu` blindly on the G16.

## September 30, 2026: rendering evidence and safe session direction

- G16 host: Hyprland v0.56.2, commit `efb50993780079460b0cbed1363e2166a2de1d9f`, **Aquamarine 0.15.0-2.1** confirmed with `pacman -Q aquamarine`.
- Hyprliquid v0.2.1 built at pinned upstream commit `c5442379542dc5e5c91cc385e3168172dd9d5ff9`, loads in a nested Hyprland, and its shaders initialized.
- The nested Wayland *display* froze or dropped its real output even though Foot mapped internally. **Live visual refraction NOT yet demonstrated**.
- Open upstream [Aquamarine #348](https://github.com/hyprwm/aquamarine/issues/348) reports a similar nested presentation stall, but describes **Aquamarine 0.14.0**, not the host's **0.15.0**. A match is a hypothesis, not a verified root cause.
- Stop repeating nested-glass runs. Stage a clean **real login Tahoe profile**, disabled plugin initially. No host files, display-manager entries, package installs, service changes, compositor reloads or profile switch until the user reviews the recovery route and explicitly chooses to install.
- Keep a separate original rice or KDE login, physical tty fallback, existing config untouched. Test output/input/Foot reliability in standalone session **before** optionally enabling any native rendering plugin.
