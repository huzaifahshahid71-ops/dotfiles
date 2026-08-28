#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE_ROOT="$HOME/.local/share/desktop-profiles"
BIN_DIR="$HOME/.local/bin"
CFG_DIR="$HOME/.config/refresh-switcher"
PROFILE_FILE="$CFG_DIR/profile"
SWITCH_SRC="$REPO_ROOT/dual-rice/bin/refresh-switch"
SWITCH_DST="$BIN_DIR/refresh-switch"
AUTO_SRC="$REPO_ROOT/scripts/.local/bin/auto-refresh-rate"
START_SRC="$REPO_ROOT/scripts/.local/bin/start-auto-refresh-rate"
SERVICE_SRC="$REPO_ROOT/systemd/.config/systemd/user/auto-refresh-rate.service"
SERVICE_DST="$HOME/.config/systemd/user/auto-refresh-rate.service"
STAMP="$(date +%Y%m%d-%H%M%S)"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARNING:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

current_vendor() {
    cat /sys/class/dmi/id/sys_vendor 2>/dev/null || echo unknown
}

current_product() {
    cat /sys/class/dmi/id/product_name 2>/dev/null || echo unknown
}

is_g16() {
    local vendor product
    vendor="$(current_vendor)"
    product="$(current_product)"
    [[ "$vendor" == *ASUS* || "$vendor" == *ASUSTeK* ]] || return 1
    [[ "$product" =~ GU60[35] || "$product" == *"Zephyrus G16"* || "$product" == *"ROG Zephyrus G16"* ]]
}

usage() {
    cat <<'EOF'
Usage: scripts/install-refresh-switcher.sh [--auto|--generic|--g16]

  --auto     Detect the machine model. Zephyrus G16 gets the tested custom
             profile + 120/240 AC/battery automation; everything else gets
             an OEM-only switcher populated from Hyprland availableModes.
  --generic  Force OEM-only modes. No custom modelines are offered.
  --g16      Install the tested Zephyrus G16 profile. Refuses non-G16 DMI
             unless DOTFILES_FORCE_MACHINE_PROFILE=1 is set.
EOF
}

requested="auto"
case "${1:-}" in
    ""|--auto) requested="auto" ;;
    --generic) requested="generic" ;;
    --g16) requested="g16" ;;
    --help|-h) usage; exit 0 ;;
    *) die "Unknown option: $1" ;;
esac

[[ -f "$SWITCH_SRC" ]] || die "Missing $SWITCH_SRC"
command -v jq >/dev/null 2>&1 || die "jq is required"
command -v fuzzel >/dev/null 2>&1 || die "fuzzel is required"

printf '\n'
log "Detected machine: $(current_vendor) / $(current_product)"

profile="$requested"
if [[ "$requested" == auto ]]; then
    if is_g16; then
        profile="g16"
        ok "Zephyrus G16 detected — enabling tested G16 refresh profile"
    else
        profile="generic"
        ok "Using portable OEM-only refresh profile"
    fi
elif [[ "$requested" == g16 ]] && ! is_g16; then
    if [[ "${DOTFILES_FORCE_MACHINE_PROFILE:-0}" != 1 ]]; then
        die "G16 refresh profile refused: DMI does not identify this machine as a Zephyrus G16"
    fi
    warn "Forcing G16 refresh profile onto a non-matching machine"
fi

mkdir -p "$BIN_DIR" "$CFG_DIR"

if [[ -f "$SWITCH_DST" ]]; then
    cp -a "$SWITCH_DST" "$SWITCH_DST.before-portable-$STAMP"
fi
install -m 0755 "$SWITCH_SRC" "$SWITCH_DST"

previous_profile=""
[[ -f "$PROFILE_FILE" ]] && previous_profile="$(tr -d '[:space:]' < "$PROFILE_FILE")"
printf '%s\n' "$profile" > "$PROFILE_FILE"

# Ensure existing local Multi-Rice profiles get the hotkey immediately. New
# installs already carry this bind in the backed-up profile source files.
for rice in caelestia end4 ambxst dms; do
    root="$PROFILE_ROOT/$rice/hypr"
    file="$root/hyprland.lua"
    [[ -f "$file" ]] || continue
    if ! grep -Rqs 'HUZAIFAH-REFRESH-SWITCHER' "$root"; then
        cat >> "$file" <<'LUA'

-- HUZAIFAH-REFRESH-SWITCHER
hl.bind(
    "SUPER + SHIFT + R",
    hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/refresh-switch"),
    { description = "Display: Switch refresh rate" }
)
LUA
    fi
done

if [[ "$profile" == g16 ]]; then
    [[ -f "$AUTO_SRC" && -f "$START_SRC" && -f "$SERVICE_SRC" ]] || die "G16 refresh automation files are incomplete"
    mkdir -p "$HOME/.config/systemd/user"
    install -m 0755 "$AUTO_SRC" "$BIN_DIR/auto-refresh-rate"
    install -m 0755 "$START_SRC" "$BIN_DIR/start-auto-refresh-rate"
    install -m 0644 "$SERVICE_SRC" "$SERVICE_DST"
    rm -f "${XDG_RUNTIME_DIR:-/run/user/$UID}/refresh-rate-override"
    systemctl --user daemon-reload
    systemctl --user enable --now auto-refresh-rate.service
    ok "G16 auto policy enabled: 120 Hz battery / 240 Hz AC"
else
    # If this installation was previously configured as our G16 profile,
    # remove its machine-specific automation when returning to generic mode.
    if [[ "$previous_profile" == g16 ]]; then
        systemctl --user disable --now auto-refresh-rate.service >/dev/null 2>&1 || true
        rm -f "${XDG_RUNTIME_DIR:-/run/user/$UID}/refresh-rate-override"
        ok "Disabled previous G16-only automatic refresh service"
    fi
fi

hyprctl reload >/dev/null 2>&1 || true

printf '\n'
ok "Refresh-rate switcher installed"
printf 'Hotkey : SUPER + SHIFT + R\n'
printf 'Profile: %s\n' "$profile"
if [[ "$profile" == g16 ]]; then
    printf 'Rates  : 60, 90, 120, 144, 165, 180, 240 Hz\n'
    printf 'Auto   : 120 Hz battery / 240 Hz AC\n'
else
    printf 'Rates  : detected live from each focused monitor\x27s OEM/EDID modes\n'
    printf 'Custom : disabled\n'
fi
printf 'Safety : Revert is selected by default; unconfirmed changes revert in 10 seconds\n\n'
