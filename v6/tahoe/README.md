# Project Tahoe — Alpha 0.2 (preview only)

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

- Compact macOS-style translucent menu bar with live active-app label and clock.
- A functional top-left preview menu with app launching and preview-only exit.
- More generously sized centered translucent Dock, unboxed app icons, hover magnification and labels.
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

## First visual feedback (September 30, 2026)

Alpha 0.1 **launched and loaded on the G16**, but the user correctly rejected
its tiny generic Dock and decorative, cramped bar as insufficiently macOS.
Quickshell printed nonfatal GTK CSS parser warnings (`transform`,
`filter`, `-gtk-icon-size`) from the currently loaded GTK theme and an
app-ID portal association warning; **there was no demonstrated QML startup
failure**. Alpha 0.2 changes visual proportions and makes menu actions real.
Do not modify host GTK files to suppress those warnings as part of alpha.

This remains a translucent preview rather than refractive Liquid Glass.
A separate, isolated Hyprliquid proof is the next milestone, before a
complete Tahoe profile or claims of genuine material parity.

## Glass build preflight (September 30, 2026)

Host read-only results: Hyprland exactly
`efb50993780079460b0cbed1363e2166a2de1d9f`, no loaded plugins,
no packaged hyprliquid; Intel Mesa OpenGL 4.6 is the active renderer, and
`qsb` exists at `/usr/lib/qt6/bin/qsb`. **Do not upgrade or switch GPU
modes for this work.**

The upstream `hyprpm.toml` on September 30 explicitly pins that
Hyprland commit to hyprliquid commit
`c5442379542dc5e5c91cc385e3168172dd9d5ff9` (including a
plugin-unload crash fix from that date). The pin does not guarantee a
crash-free plugin; exact build headers and runtime interactions still
need verification.

Build **without loading any native plugin**:

```fish
curl -fsSLo /tmp/z6-build-glass.sh https://raw.githubusercontent.com/huzaifahshahid71-ops/dotfiles/v6.0-tahoe-dev/v6/tahoe/build-glass.sh
bash /tmp/z6-build-glass.sh --check
# Only after preflight passes:
bash /tmp/z6-build-glass.sh --build
```

The helper verifies the exact binary commit and hyprland pkg-config
version, checks build tools and `stb_image.h`, pins the source revision,
compiles with limited parallelism and copies the result **only** to
`~/.local/share/zephyrus-v6/plugins/hyprliquid-v0562/libhyprliquid.so`.

It does NOT run sudo, package transactions, hyprpm, hyprctl plugin load,
Hyprland reload, alter `~/.config`, or change existing rices.
A successful build is **not** permission to load it into the current
desktop: next step is a tested independent Tahoe session with a rescue
login and guaranteed fallback.
