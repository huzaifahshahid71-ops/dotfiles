# ZEPHYRUS v6 — Tahoe Window Manager and Genie Effect
Decision: **Tahoe will be the ninth Hyprland rice** on the real G16 (8 existing
Hyprland rices + Tahoe + 3 existing Niri rices = 12). No new compositor.
This is a technical specification, not a claim that the effects are built.

## Minimum high-fidelity macOS behavior

- Tahoe-only floating-first windows by default. Retain manual tile/float
  toggle and sensible exception rules for fullscreen games, transient
  dialogs, Picture-in-Picture, accessibility/portal prompts, XWayland.
- Window control semantics: close requests an orderly app close; minimize
  hides without killing; maximize preserves menu bar and dock; fullscreen
  enters true fullscreen when requested. Always test the client-side
  decorations of GTK/Qt apps; traffic-light buttons are not automatically
  injected into every Wayland app.
- Dock: group by desktop-file/app ID; distinguish pinned vs running apps;
  show open and minimized windows; bounce/zoom feedback; middle-click and
  right-click semantics; focus/restore existing window rather than opening
  duplicates; multi-window chooser; move to preferred workspace.
- Mission Control: evaluate maintained HyprExpo only against *exact*
  Hyprland 0.56.2 ABI (and in combination with Hyprliquid).
- Spotlight-style launcher, Control Center, notifications, menu bar; active
  window title and app name. Full native macOS global menus are NOT
  universally provided by Wayland/GTK/Qt apps; use app integrations where
  exported and a truthful fallback otherwise.
- Multi-monitor, fractional scale, eDP-1, docking/undocking, suspend,
  touchpad gestures, physical Nvidia hardware, games and 60/240 Hz.

## Minimize state model (MVP before any fancy animation)

Hyprland's Lua dispatcher can send a selected window to a special
workspace while leaving its process alive. This is a *managed approximation*
of macOS minimize; Hyprland is not itself a full macOS Dock/window manager.

1. Identify the exact window by stable ID or address; never match only by
   app class (multiple windows may share it).
2. Store its original workspace, monitor, last focus order, floating state,
   original geometry/maximize state and desktop-file/app ID. Keep a bounded
   runtime state, not a persisted list of leaked client identifiers.
3. On user minimize request, move *that window* to
   `special:tahoe-minimized` with `follow=false`. Keep the special
   workspace hidden. Preserve a Dock entry with minimized status.
4. On click, move the specific window back to its original or currently
   chosen workspace, restore geometry/state, focus, and clear minimized
   status. Do not toggle the entire special workspace visible.
5. On close/process exit, clear stale entries. Reconcile session restarts,
   monitor unplug, fullscreen transitions, windows moved by another client,
   and application rules.
6. Must not interfere with other rices' `special:*` workspaces.

Reference: https://wiki.hypr.land/configuring/core/dispatchers/
(syntax is Lua for Hyprland 0.55+).

## Genie requirements and feasibility

**True Genie = spatially deform the rendered window surface toward the
position of its exact Dock icon**, dynamically using the whole window's
texture. It is NOT a built-in Hyprland animation style. Current built-in
styles include slide, popin and gnomed:
https://wiki.hypr.land/configuring/core/animations/

### Tier 1 — guaranteed fallback behavior

- Fast, Dock-directed scale/move/ease + opacity transition. This is an
  imitation of minimize, **not** a true Genie. A custom Quickshell overlay
  may use a controlled snapshot only if permitted and technically viable.
- Respect reduced motion, battery/performance toggles, fullscreen/game
  exceptions. Minimize/restore must work even if animation crashes.

### Tier 2 — prototype genuine deformation

- Explore a **pinned, independently switchable native Hyprland plugin**
  using compositor-level access to live window textures and per-frame
  transformations.
- Render a continuously deforming mesh/trapezoid strip field from window
  rectangle to Dock icon rectangle. Use 2-stage cubic Bézier funnel with
  an opening and restoring inverse, stable rounding and occlusion.
- Reverse/toggle animations during rapid minimize/restore. Correctly handle
  app closure mid-animation, scaling, opacity, multiple monitors,
  fractional scales, rotated monitors, 60 Hz and 240 Hz.
- Prototype with **one disposable test app**, test renderer and GPU paths,
  and disable the effect instantly if unstable. Do not install as mandatory
  until it survives actual hardware torture tests.
- The GNOME macos-genie extension and KWin Magic Lamp are conceptual
  references only; they cannot be loaded into Hyprland. Do not silently
  copy source/licenses into this repo.
- Hyprliquid (live refraction) and Genie (window texture deformation) are
  *different render passes*. Treat their compositing interaction as an
  explicit integration test. Do not assume plugins compose without issue.

References:
- https://github.com/SekiroKenjii/macos-genie
- https://github.com/end-4/dots-hyprland/issues/2991
- https://github.com/zaregototsukai/hyprliquid

## Acceptance gates (no promise of full parity before passing)

1. Tahoe launches as a separate profile; all 11 original profiles retain
   working login, switch, music service, and recovery.
2. Floating, stacking, focus, close, maximize, native fullscreen and moving
   windows between virtual desktops feel consistent.
3. Minimize/restore of 2 independent windows from the same application is
   lossless; no disappearing app, no duplicate process, no Dock orphan.
4. Precise icon target positions and scaling with auto-hidden Dock.
5. Distinct visual tests: blur, live refraction, minimized window mesh warp.
   Passing blur does NOT imply refraction; shrink does NOT imply Genie.
6. Plugins load with exact Hyprland 0.56.2 ABI; test separately and together,
   preserve a plugin-free fallback boot session.
7. No imposed host package upgrades, bootloader modifications, kernel
   modifications, custom power or refresh-rate overrides.
