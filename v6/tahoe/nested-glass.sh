#!/usr/bin/env bash
# Tahoe stage 2: load pinned Hyprliquid in a SEPARATE nested Hyprland only.
# No sudo, no hyprctl plugin commands, no systemd session mutations, no
# edits to ~/.config or active rice. This is a native GPU-plugin test;
# crashes of the nested compositor or GPU driver are still possible.
set -euo pipefail

PLUGIN="$HOME/.local/share/zephyrus-v6/plugins/hyprliquid-v0562/libhyprliquid.so"
HYPR_SHA="efb50993780079460b0cbed1363e2166a2de1d9f"
SOURCE_SHA="c5442379542dc5e5c91cc385e3168172dd9d5ff9"

log() { printf '\n==> %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ $# -eq 1 && ( "$1" == "--check" || "$1" == "--run" ) ]] ||
    die "Usage: bash $0 --check|--run"
[[ "${EUID:-$(id -u)}" -ne 0 ]] || die "Run as your ordinary user, not root."

for cmd in Hyprland hyprctl foot; do
    command -v "$cmd" >/dev/null 2>&1 || die "Required command absent: $cmd"
done

[[ -n "${WAYLAND_DISPLAY:-}" && -n "${XDG_RUNTIME_DIR:-}" &&
   -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] ||
    die "Run from a terminal inside your existing Hyprland desktop."
[[ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]] ||
    die "Parent Wayland socket is inaccessible."
Hyprland --version 2>&1 | grep -Fq "$HYPR_SHA" ||
    die "Live host Hyprland build has changed; stop and rebuild compatibility plan."
hyprctl -j monitors >/dev/null 2>&1 ||
    die "Parent compositor is not responding. Stop the test."
[[ -s "$PLUGIN" ]] || die "Compiled plugin missing: $PLUGIN"

log "Checking staged library (not loading it)"
printf 'Library: %s\n' "$PLUGIN"
if command -v file >/dev/null 2>&1; then file "$PLUGIN"; fi
sha256sum "$PLUGIN"
printf 'Expected upstream source pin: %s\n' "$SOURCE_SHA"
if command -v readelf >/dev/null 2>&1; then
    readelf -h "$PLUGIN" | grep -E 'Class:|Machine:|Type:' || true
fi

log "Preparing temporary configuration for validation"
sandbox="$(mktemp -d "${TMPDIR:-/tmp}/zephyrus-glass.XXXXXXXX")"
cleanup() { rm -rf -- "$sandbox"; }
trap cleanup EXIT

cat > "$sandbox/foot.ini" <<'INI'
[main]
font=monospace:size=12

[colors-dark]
background=223049
foreground=e9f2ff
alpha=0.50
INI

# Parse Foot's configuration BEFORE attempting a nested plugin load.
# Modern Foot uses [colors-dark]/[colors-light], not legacy [colors].
# A non-zero exit halts the test without touching either compositor.
foot --check-config --config="$sandbox/foot.ini" ||
    die "Foot rejected the temporary config. Nested compositor not launched."

if [[ "$1" == "--check" ]]; then
    log "PASS: host, plugin file, and Foot config validated. No plugin loaded."
    exit 0
fi

# This file belongs to a temporary nested compositor only. Never feed it
# to hyprctl reload on the parent. The GL plugin is *loaded only here*.
cat > "$sandbox/hyprland.lua" <<LUA
hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = 1.0,
})

-- Nested debug only. The ordinary desktop keeps its existing log settings.
hl.config({
    debug = {
        disable_logs = false,
        enable_stdout_logs = true,
        colored_stdout_logs = false
    }
})

-- Load the locally-built ABI-pinned plugin in this NEW compositor process.
hl.plugin.load([[$PLUGIN]])

hl.config({
    general = {
        gaps_in = 9,
        gaps_out = 16,
        border_size = 1,
        layout = "dwindle",
    },
    decoration = {
        rounding = 26,
        blur = { enabled = true, size = 6, passes = 2 },
    },
    animations = { enabled = true },
    misc = {
        force_default_wallpaper = 1,
        disable_hyprland_logo = false,
    }
})

hl.window_rule({
    name = "tahoe-glass-demo",
    match = { class = "foot" },
    float = true,
    no_blur = true,
    no_shadow = true,
    ["hyprliquid:effect"] = "liquid_glass",
    ["hyprliquid:rounding_lua"] = 28,
    ["hyprliquid:highlight_style"] = 3,
    ["hyprliquid:glass_dispersion"] = true,
    ["hyprliquid:tint_color"] = "rgba(0x1a, 0x1b, 0x26, 0.35)",
})

hl.bind("SUPER + RETURN", hl.dsp.exec_cmd([[foot --config=$sandbox/foot.ini]]))
hl.bind("SUPER + SHIFT + Q", hl.dsp.exit())
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })

hl.on("hyprland.start", function()
    hl.exec_cmd([[foot --config=$sandbox/foot.ini]])
end)
LUA

log "Preparing for FIRST actual shader test"
printf '%s\n' "This may crash the *nested* Hyprland process if the plugin fails."
printf '%s\n' "Move the transparent Foot window over the default triangles and watch for bending/edge highlights."
printf '%s\n' "Inside nested window: Super+Enter new Foot; Super+Shift+Q exits."
printf '%s\n' "Outside: Ctrl+C in this parent terminal stops the test."
printf '%s\n' "If nested crashes, do NOT run a plugin load on your ordinary Hyprland session."

# Stop config and environment cross-talk: no host session-wide dbus/systemd
# updates; no direct DRM preference copied from the parent.
env -u HYPRLAND_INSTANCE_SIGNATURE -u AQ_DRM_DEVICES \
    HYPRLAND_NO_SD_VARS=1 \
    HYPRLAND_NO_SD_NOTIFY=1 \
    HYPRLAND_NO_SD_TARGET=1 \
    HYPRLAND_NO_RT=1 \
    Hyprland --config "$sandbox/hyprland.lua" 2>&1 | tee "$sandbox/nested-hyprland.log"
result=${PIPESTATUS[0]}

printf '\n=== NESTED GLASS TEST DIAGNOSTICS ===\n'
printf 'Nested Hyprland exit status: %s\n' "$result"
grep -Ein 'hyprliquid|plugin|shader|failed|error|Wayland Backend|loading lua|window_rule|Config' "$sandbox/nested-hyprland.log" | tail -n 85 || true
printf '%s\n' "DRM/libseat failures alone are expected during nesting; look for plugin or Wayland failures."
exit "$result"
