# ZEPHYRUS v6 — Liquid Glass feasibility and host inventory
Research note: 2026-09-30. No host modifications made.

## Host state (reported from read-only audit)

- Niri 26.04 (8ed0da4), package 26.04-1.1.
- Hyprland 0.56.2 (efb50993780079460b0cbed1363e2166a2de1d9f), package 0.56.2-3.1.
- Quickshell 0.3.1 (2d3b3e9), qt6-base/qt6-declarative 6.11.2.
- Eight existing Hyprland rices: caelestia, end4, ambxst, dms, serpantinum, noctalia, sayconlun, **tsugumori**.
- Three existing Niri rices: jaqc, clavis, nixri.
- `lucid-niri.backup.*` are archived directories, NOT active profiles.
- `awww` available; `swww` unavailable. `qsb` is not on the PATH, but `qt6-shadertools` is installed. Check `/usr/lib/qt6/bin/qsb` before declaring shader compilation unavailable.
- `multi-rice-control` exists; **`multi-rice-switcher` command not present** on the host. Restore/test GUI before adding visual Themes choices.
- `background-music` present; `background-music.service` enabled. Preserve this and any Lumina player/bindings after an actual backup. `end4-media-backend.service` disabled.
- No blanket kernel/Hyprland/Niri/driver upgrade for prototyping.

## User's explicit visual goal

A high-fidelity macOS Tahoe-style shell with **genuine refractive Liquid Glass** (distortion of pixels *behind* the glass as objects move), not a static translucent imitation. Original icon, GTK, and cursor assets should be used from these separate upstream sources:

- https://github.com/vinceliuice/MacTahoe-gtk-theme
- https://github.com/vinceliuice/MacTahoe-icon-theme
- https://github.com/vinceliuice/MacTahoe-icon-theme/tree/main/cursors

Icons: GPL-3.0 COPYING. Cursors: GPL-3.0 LICENSE. GTK repo advertises MIT; verify upstream file notices and asset/subproject licensing before redistribution. Fetch/install pinned upstream sources rather than blindly bundling.

## Technical feasibility

### Niri path — supported baseline, not full live Liquid Glass

Official docs:
- https://niri-wm.github.io/niri/Window-Effects.html
- https://niri-wm.github.io/niri/Configuration%3A-Layer-Rules.html

Niri 26.04 implements compositor blur, xray, noise, and saturation for windows/layer-shell/popups. xray defaults to wallpaper-only blur; setting `xray false` blurs actual windows beneath but is computationally heavier and has documented animation/drag limitations.

Importantly, compositor-backed blur does **not** hand arbitrarily sampled background pixels into the Quickshell `ShaderEffect`. A client shader can paint gloss/highlights, and distort a controlled wallpaper texture, but not automatically distort live windows beneath it. Fully live refractive glass for arbitrary surfaces requires additional access/scene rendering work (e.g. Niri compositor modification or new supported protocol/client path) plus sustained maintenance.

### Hyprland path — existing compositor, direct genuine refraction option

- https://github.com/zaregototsukai/hyprliquid
- https://wiki.hypr.land/Plugins/Using-Plugins/

`hyprliquid` is a **Hyprland-specific native plugin** implementing refractive liquid glass, optional RGB dispersion, highlights, rounded corners, material presets, and optional `background-share` protocol for compatible clients. **It cannot be loaded as a Niri plugin**.

The real host already has Hyprland 0.56.2. If live scene refraction is mandatory, prototype on a **separate isolated Hyprland Tahoe profile**, not by modifying an existing daily-use rice. Check plugin build/API compatibility with exactly 0.56.2. Hyprland's plugin documentation warns that native plugins execute in compositor process and can crash it. Do not blindly load unsigned pre-built .so files. Snapshot/config backup and fallback login are prerequisites.

A third compositor adds operational complexity and is not needed for the initial proof.

## Release-layout decision **pending user's confirmation**

Goal remains **12 rices** preserving 8 currently installed Hyprland + 3 Niri:

- Option A — **9 Hyprland + 3 Niri**: Add Tahoe as a ninth Hyprland rice, using `hyprliquid`. Direct path toward live refractive materials.
- Option B — **8 Hyprland + 4 Niri**: Add Tahoe as fourth Niri rice, with built-in live background blur + custom visual shaders, but true arbitrary live refraction is a separately scoped compositor/protocol development effort. Do **not** claim parity until demonstrated.

Whichever option the user chooses, keep all 11 existing rices, the original switcher, the optional independent Revo-inspired switcher theme, Lumina music service, and host-first offline v6 packaging.

## Decision gate / proof sequence

1. **No changes on host:** choose A or B with accurate tradeoffs.
2. Safely back up active Niri/Hyprland and Quickshell configs; verify fallback login. Confirm user's custom kernel, Btrfs snapshot, power/refresh control remain untouched.
3. Render a stand-alone MacTahoe bar/dock glass proof: test with *moving app windows behind* to check whether content is truly distorted, not just blurred.
4. Benchmark 60 Hz and high-refresh mode on actual NVIDIA hardware, while dragging a window and during fullscreen/overview. Measure visible artifacts and frame pacing.
5. Only then implement Control Center, Spotlight, dock animation, icons/GTK/cursors, switcher Themes, and installer.
