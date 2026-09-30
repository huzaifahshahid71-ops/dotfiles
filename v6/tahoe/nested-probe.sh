#!/usr/bin/env bash
# ZEPHYRUS v6 Tahoe — stage 1: verify a nested Hyprland (no plugins).
# Nothing in the active ~/.config/hypr, desktop profile links, or services
# is modified. Stage 2 (genuine glass) is deliberately a separate step.
set -euo pipefail

log() { printf '\n==> %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

[[ "$#" == 1 ]] || die "Usage: bash $0 --check|--baseline"
case "$1" in --check|--baseline) ;; *) die "Usage: bash $0 --check|--baseline" ;; esac
[[ "${EUID:-$(id -u)}" -ne 0 ]] || die "Do not run as root."
command -v Hyprland >/dev/null || die "Hyprland unavailable."
command -v hyprctl >/dev/null || die "hyprctl unavailable."

[[ -n "${WAYLAND_DISPLAY:-}" && -n "${XDG_RUNTIME_DIR:-}" ]] ||
    die "Run inside an existing graphical Wayland session."
[[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] ||
    die "Please run from an existing Hyprland rice, not from a tty or Niri."
[[ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]] ||
    die "The parent Wayland display socket is inaccessible."

# A second compositor is permitted to use the parent Wayland display, but
# it must NEVER modify the host's systemd/dbus session environment.
log "Checking the existing compositor; it will remain untouched"
parent="${HYPRLAND_INSTANCE_SIGNATURE}"
parent_version="$(Hyprland --version 2>&1 || true)"
printf '%s\n' "$parent_version" | head -n2
printf '%s\n' "$parent_version" | grep -Fq     'efb50993780079460b0cbed1363e2166a2de1d9f' ||
    die "This probe is validated only against the current G16 Hyprland 0.56.2 build."
hyprctl -j monitors >/dev/null ||
    die "Cannot communicate with parent Hyprland."

sandbox="$(mktemp -d "${TMPDIR:-/tmp}/zephyrus-tahoe-nested.XXXXXXXX")"
cleanup() { rm -rf -- "$sandbox"; }
trap cleanup EXIT

cat > "$sandbox/hyprland.lua" <<'LUA'
-- Standalone nested window. Do NOT load Hyprliquid in stage 1.
hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = 1.0,
})

hl.config({
    general = {
        gaps_in = 8,
        gaps_out = 12,
        border_size = 2,
        layout = "dwindle",
    },
    decoration = {
        rounding = 16,
        blur = { enabled = true, size = 4, passes = 1 },
    },
    misc = {
        disable_hyprland_logo = false,
        force_default_wallpaper = 1,
    },
    animations = { enabled = true },
})

hl.bind("SUPER + RETURN", hl.dsp.exec_cmd("foot"))
hl.bind("SUPER + SHIFT + Q", hl.dsp.exit())
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
LUA

log "Verifying isolated config syntax; NOT loading any plugins"
# Hyprland --verify-config never starts a compositor.
Hyprland --verify-config --config "$sandbox/hyprland.lua" ||
    die "Nested config verification failed. The parent session is unchanged."

if [[ "$1" == "--check" ]]; then
    log "PASS — isolated configuration verified. No process launched."
    exit 0
fi

log "Launching plugin-free Hyprland as a nested window"
printf '%s\n' "Within the new nested window: Super+Enter opens foot; Super+Shift+Q exits."
printf '%s\n' "Alternatively press Ctrl+C in this original terminal."
printf '%s\n' "If no nested window appears, copy the terminal error and stop."
printf '%s\n' "No Hyprliquid load takes place in this step."

# Preserve the parent WAYLAND_DISPLAY so Aquamarine can fall back to its
# Wayland backend, not to an X11 session. Remove DRM preference overrides.
# Explicitly disable changes to the global dbus/systemd desktop environment.
# A nested child should not have a logind DRM seat. If it fails to nest,
# STOP here: do not re-run from a tty as an alternative.
env -u HYPRLAND_INSTANCE_SIGNATURE -u AQ_DRM_DEVICES \
    HYPRLAND_NO_SD_VARS=1 \
    HYPRLAND_NO_SD_NOTIFY=1 \
    HYPRLAND_NO_SD_TARGET=1 \
    HYPRLAND_NO_RT=1 \
    Hyprland --config "$sandbox/hyprland.lua"
code=$?
printf 'Nested compositor exited with status %s\n' "$code"
exit "$code"
