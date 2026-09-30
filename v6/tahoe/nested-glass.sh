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
report_file=""
cleanup() {
    local code=$?
    trap - EXIT
    if [[ -n "$report_file" && -f "$report_file" ]]; then
        printf '\n=== NESTED GLASS TEST SUMMARY ===\n'
        printf 'Nested Hyprland exit status: %s\n' "$code"
        printf 'Persistent diagnostic log: %s\n' "$report_file"
        grep -Ei 'Plugin hyprliquid loaded|Loading plugin .*hyprliquid|Hyprland is ready|Running on WAYLAND_DISPLAY|Shaders initialized successfully|Window .*set class to foot|Map request dispatched|Plugin .*error|shader.*(error|failed)|FATAL|CRIT' "$report_file" | tail -n 30 || true
        printf '%s\n' 'Loading and mapping do not prove visible refraction; inspect the nested window.'
    fi
    rm -rf -- "$sandbox"
}
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

log "Starting visual Liquid Glass check in the nested compositor"
printf '%s\n' "Expect a separate Hyprland window containing a transparent Foot terminal."
printf '%s\n' "Drag Foot over the blue triangles with Super + left mouse drag."
printf '%s\n' "Observe whether the wallpaper BENDS at the glass edges, not just whether it blurs."
printf '%s\n' "Exit with Super+Shift+Q inside the nested window (or Ctrl+C outside)."
printf '%s\n' "The diagnostic log is saved separately; no debug spam will flood this terminal."
printf '%s\n' "Do not load the plugin into your ordinary Hyprland session."

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/zephyrus-v6"
mkdir -p -- "$state_dir"
report_file="$state_dir/nested-glass-$(date +%Y%m%d-%H%M%S)-$.log"

# Capture verbose compositor diagnostics to a persistent user-only file.
# This does not alter the parent compositor or any graphical session profile.
if env -u HYPRLAND_INSTANCE_SIGNATURE -u AQ_DRM_DEVICES \
    HYPRLAND_NO_SD_VARS=1 \
    HYPRLAND_NO_SD_NOTIFY=1 \
    HYPRLAND_NO_SD_TARGET=1 \
    HYPRLAND_NO_RT=1 \
    Hyprland --config "$sandbox/hyprland.lua" >"$report_file" 2>&1; then
    exit 0
else
    exit "$?"
fi
