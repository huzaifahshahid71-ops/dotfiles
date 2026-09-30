# ZEPHYRUS G16 — v6.0 Project TAHOE (design stage)

Status: **proposal / no host configuration changes made yet**.

## Why this branch exists

Build **one** new, high-fidelity macOS Tahoe-inspired desktop on **Niri**,
instead of shipping the experimental full Revo shell collection.
Begin from v5.0 `main`, not the draft `v5.1.0-revo-dev` branch.

## Release scope

- Preserve exactly the **8 existing Hyprland profiles on the real G16**.
  The Git repository's current baseline contains 7; discover the 8th from
  the host. Do not invent its name or include an unverified directory.
- Preserve the 3 existing Niri rices: Solstice/jaqc, Cipher/clavis,
  Astra/nixri. Add **Tahoe** as the fourth Niri rice.
- Target release: **12 desktop rices: 8 Hyprland + 4 Niri**, contingent on
  actual host inventory and successful smoke tests.
- Preserve Lumina's current music player, media integrations, and existing
  user systemd backend services; audit actual filenames/units before shipping.
- Keep the original graphical rice switcher and its backend, with an optional
  **Revo-inspired** switcher visual skin under **Themes**. Implement the UI
  independently; do not vendor Revo's DotsBrowser source without permission
  or verified licensing. Make Super+B configurable, preserving other binds
  and Super+Shift+D.
- Do **not** merge draft v5.1 PR #3 or transplant its full Revo source tree.

## Mac-like Tahoe shell

One Quickshell application for Niri; never stack multiple independent shell
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

### Liquid Glass approach

- **Niri 26.04+** supports `background-effect` on windows/layer surfaces:
  native blur, noise, saturation and xray.
- Start with fast **xray wallpaper blur** for bar, dock, and popovers.
- Evaluate **non-xray blur** selectively. It is more expensive and niri
  currently documents animation/drag limitations.
- Implement *custom visual* glass highlights, specular borders, and
  restrained pseudo-refraction via QML/Qt shader effects. The compositor
  protocol does not itself reproduce Apple's proprietary Liquid Glass
  material; test capabilities before promising live scene refraction.
- Use shaped blur via `ext-background-effect` only where supported;
  niri layer rules alone do not guarantee correct arbitrary silhouettes.
- Require verified Niri, Qt/Quickshell, GPU and driver versions, with
  non-glass fallback. Test 60/240 Hz, display scaling, NVIDIA path,
  motion and performance.

Reference rule (not installed automatically):
```kdl
layer-rule {
    match namespace="^tahoe-dock$"

    background-effect {
        blur true
        xray true
    }
}
```
The actual app namespace/surface shape and transparency need to match.

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
