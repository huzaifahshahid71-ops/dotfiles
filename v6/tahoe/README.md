# Project Tahoe — Alpha 0.1 (preview only)

This is the first **running UI prototype**, not a whole Hyprland profile and
**not yet actual refractive Liquid Glass**. It is designed for the *existing*
Hyprland 0.56.2 + Quickshell 0.3.1 G16 host.

## Run without installing or changing any active profile

Open a terminal **inside any existing Hyprland rice** (not Niri):

```fish
curl -fsSLo /tmp/zephyrus-tahoe-preview.sh https://raw.githubusercontent.com/huzaifahshahid71-ops/dotfiles/v6.0-tahoe-dev/v6/tahoe/preview.sh
bash /tmp/zephyrus-tahoe-preview.sh
```

Download the script first if you want to inspect it before running.
You can also run `bash v6/tahoe/preview.sh` from a local branch checkout.

- No `sudo`, `pacman`, systemd changes, changes to `~/.config`,
  session restart or modification of your current Quickshell instance.
- A disposable QML config is copied to a unique `/tmp` directory;
  `qs -p` runs it in the foreground.
- **Exit with Ctrl+C or the × button in the preview menu bar**.
  No `pkill quickshell` or `hyprctl reload` is required.
- Existing bars or docks might overlap: this stage is just a visual proof.
- Currently a **single-display preview**, avoiding a reported Qt 6.11.2
  `Variants` / `PanelWindow` crash while we verify the local combination.

## What currently works in source (requires testing on the real host)

- Light translucent/gradient menu bar with live active-app label and clock.
- Centered glass-styled Dock with hover magnification.
- Files, Terminal, Browser, and Apps launchers with desktop-entry lookup
  where available and safe fallback commands.
- Direct tracking of Hyprland's real toplevel list, active indicators, and
  focus requests for running windows.

## What is NOT implemented

- Genuine Liquid Glass: NO compositor-backed refraction is loaded yet.
  This alpha uses translucent QtQuick rectangles for geometry/color only.
- Floating-first Tahoe profile, macOS traffic-light controls, minimize or
  restore, per-app window grouping, Genie mesh deformation, hyprliquid,
  Mission Control, native global app menus, MacTahoe GTK/icon/cursors,
  audio player controls, or installer. These are separate milestones.
- UI is intentionally not yet a complete desktop replacement.

## Alpha smoke test

1. Run preview inside **one** existing Hyprland rice.
2. Do you see a pale top bar and centered translucent dock? Any QML errors?
3. Hover pinned icons: do they magnify smoothly?
4. Click Files and Terminal: do they launch?
5. Open two apps: do their live icons appear? Click each; does focus change?
6. Press Ctrl+C in the launching terminal: do both Tahoe surfaces disappear?
7. Verify your original rice still works unchanged.

Send screenshot + terminal error output if anything fails. This is the gate
before enabling any actual Hyprliquid or window-management experiments.

## References

- [Quickshell PanelWindow 0.3.1](https://quickshell.org/docs/v0.3.1/types/Quickshell/PanelWindow/)
- [Quickshell Hyprland 0.3.1](https://quickshell.org/docs/v0.3.1/types/Quickshell.Hyprland/Hyprland/)
- [Quickshell DesktopEntries](https://quickshell.org/docs/v0.3.1/types/Quickshell/DesktopEntries/)
- [Quickshell upstream Qt6.11.2 Variants regression](https://github.com/quickshell-mirror/quickshell/issues/983)

Phase 2 after alpha: standalone Tahoe Hyprland profile with reliable
minimize/restore. Phase 3: sandboxed hyprliquid exact-ABI proof and GPU
stability. Phase 4: experimental real Genie shape deformation.
