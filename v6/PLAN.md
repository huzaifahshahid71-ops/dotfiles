# ZEPHYRUS G16 — v6.0 Project TAHOE (design stage)

Status: **Tahoe-on-Hyprland selected; implementation not yet installed on host**.

## Why this branch exists

Build **one** new, high-fidelity macOS Tahoe-inspired desktop on **Niri**,
instead of shipping the experimental full Revo shell collection.
Begin from v5.0 `main`, not the draft `v5.1.0-revo-dev` branch.

## Release scope

- Preserve exactly the **8 existing Hyprland profiles on the real G16**.
  The Git repository's current baseline contains 7; discover the 8th from
  the host. Do not invent its name or include an unverified directory.
- Preserve the 3 existing Niri rices: Solstice/jaqc, Cipher/clavis,
  Astra/nixri. Add **Tahoe** as the **ninth Hyprland rice**.
- Target release: **12 desktop rices: 9 Hyprland + 3 Niri**, contingent on
  successful native plugin and host validation.
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
  │   ├── Hyprland: 8 installed (host verified)
  │   └── Niri: 4 installed (includes Tahoe)
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
