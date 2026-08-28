#!/usr/bin/env bash
set -euo pipefail

OUTPUT="${REFRESH_OUTPUT:-eDP-1}"
BIN_DIR="$HOME/.local/bin"
PROFILE_ROOT="$HOME/.local/share/desktop-profiles"
FUZZEL_CFG="$HOME/.config/desktop-switcher/fuzzel.ini"
AUTO_SCRIPT="$BIN_DIR/auto-refresh-rate"
SWITCH_SCRIPT="$BIN_DIR/refresh-switch"
STAMP="$(date +%Y%m%d-%H%M%S)"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARNING:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

command -v hyprctl >/dev/null 2>&1 || die "hyprctl is required"
command -v fuzzel >/dev/null 2>&1 || die "fuzzel is required"
command -v jq >/dev/null 2>&1 || die "jq is required"
[[ -f "$FUZZEL_CFG" ]] || die "Missing $FUZZEL_CFG (the Multi-Rice switcher theme)"

mkdir -p "$BIN_DIR"

if [[ -f "$AUTO_SCRIPT" ]]; then
    cp -a "$AUTO_SCRIPT" "$AUTO_SCRIPT.before-refresh-switcher-$STAMP"
    ok "Backed up auto-refresh-rate"
fi

log "Installing refresh-switch"
cat > "$SWITCH_SCRIPT" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

OUTPUT="${REFRESH_OUTPUT:-eDP-1}"
FUZZEL_CFG="$HOME/.config/desktop-switcher/fuzzel.ini"
OVERRIDE_FILE="${XDG_RUNTIME_DIR:-/run/user/$UID}/refresh-rate-override"
SCALE_FALLBACK="1.25"
CONFIRM_SECONDS="10"

# These use the same proven 2560x1600 timing family as the captured 120 Hz
# modeline, with pixel clock scaled for each requested refresh rate.
mode_for_rate() {
    case "$1" in
        52.03) echo 'modeline 487.900 2560 2568 2600 2640 1600 3534 3542 3552 -hsync -vsync' ;;
        60)    echo 'modeline 562.637 2560 2568 2600 2640 1600 3534 3542 3552 -hsync -vsync' ;;
        90)    echo 'modeline 843.955 2560 2568 2600 2640 1600 3534 3542 3552 -hsync -vsync' ;;
        120)   echo 'modeline 1125.275 2560 2568 2600 2640 1600 3534 3542 3552 -hsync -vsync' ;;
        144)   echo 'modeline 1350.328 2560 2568 2600 2640 1600 3534 3542 3552 -hsync -vsync' ;;
        165)   echo 'modeline 1547.251 2560 2568 2600 2640 1600 3534 3542 3552 -hsync -vsync' ;;
        180)   echo 'modeline 1687.910 2560 2568 2600 2640 1600 3534 3542 3552 -hsync -vsync' ;;
        240)   echo 'preferred' ;;
        *) return 1 ;;
    esac
}

monitor_json() {
    hyprctl monitors -j 2>/dev/null | jq -c --arg output "$OUTPUT" '.[] | select(.name == $output)'
}

current_rate() {
    monitor_json | jq -r '.refreshRate // 0'
}

current_position() {
    monitor_json | jq -r '(.x|tostring) + "x" + (.y|tostring)'
}

current_scale() {
    monitor_json | jq -r '.scale // 1.25'
}

power_state() {
    local r
    r="$(busctl --system get-property org.freedesktop.UPower /org/freedesktop/UPower org.freedesktop.UPower OnBattery 2>/dev/null || true)"
    [[ "$r" == 'b true' ]] && echo battery || echo ac
}

apply_mode() {
    local mode="$1" pos scale result
    pos="$(current_position)"
    scale="$(current_scale)"
    [[ -n "$pos" && "$pos" != "nullxnull" ]] || pos="0x0"
    [[ -n "$scale" && "$scale" != "null" ]] || scale="$SCALE_FALLBACK"

    result="$(hyprctl eval "hl.monitor({
        output = \"$OUTPUT\",
        mode = \"$mode\",
        position = \"$pos\",
        scale = $scale
    })" 2>&1)"
    [[ "$result" == "ok" ]] || {
        notify-send "Refresh Rate" "Failed: $result" 2>/dev/null || true
        return 1
    }
}

return_to_auto() {
    rm -f "$OVERRIDE_FILE"
    if systemctl --user is-enabled auto-refresh-rate.service >/dev/null 2>&1; then
        systemctl --user restart auto-refresh-rate.service
    else
        local state
        state="$(power_state)"
        if [[ "$state" == battery ]]; then
            apply_mode "$(mode_for_rate 120)"
        else
            apply_mode "$(mode_for_rate 240)"
        fi
    fi
    notify-send "Refresh Rate" "Auto restored — 120 Hz battery / 240 Hz AC" 2>/dev/null || true
}

rate_is_current() {
    local target="$1" now="$2"
    awk -v a="$target" -v b="$now" 'BEGIN { d=a-b; if (d<0) d=-d; exit !(d < 0.35) }'
}

choose_rate() {
    local now auto_state choice line rate
    local -a rates=(52.03 60 90 120 144 165 180 240)
    local -a labels=()

    now="$(current_rate)"
    if [[ -f "$OVERRIDE_FILE" ]]; then
        auto_state="MANUAL"
    else
        auto_state="AUTO"
    fi

    if [[ "$auto_state" == AUTO ]]; then
        labels+=("✓  ⚙  Auto        120 Hz battery • 240 Hz AC")
    else
        labels+=("   ⚙  Auto        120 Hz battery • 240 Hz AC")
    fi

    for rate in "${rates[@]}"; do
        if rate_is_current "$rate" "$now"; then
            labels+=("✓  ◉  ${rate} Hz        ACTIVE")
        else
            labels+=("   ◉  ${rate} Hz")
        fi
    done

    choice="$(printf '%s\n' "${labels[@]}" | fuzzel \
        --config="$FUZZEL_CFG" \
        --dmenu \
        --lines="${#labels[@]}" \
        --prompt='  Refresh  ❯  ' \
        --mesg="Current: $(printf '%.2f' "$now") Hz   •   Auto policy: 120 battery / 240 AC")" || exit 0

    [[ "$choice" == *"Auto"* ]] && { echo auto; return; }
    for rate in "${rates[@]}"; do
        [[ "$choice" == *"${rate} Hz"* ]] && { echo "$rate"; return; }
    done
    exit 0
}

confirm_keep() {
    local rate="$1" choice
    choice="$(printf '%s\n' "✓  Keep ${rate} Hz" "↩  Revert to Auto" | timeout "${CONFIRM_SECONDS}s" fuzzel \
        --config="$FUZZEL_CFG" \
        --dmenu \
        --lines=2 \
        --prompt='  Confirm  ❯  ' \
        --mesg="Display test • auto-reverts in ${CONFIRM_SECONDS}s if you cannot see this")" || true
    [[ "$choice" == *"Keep"* ]]
}

main() {
    local selected mode
    selected="${1:-}"
    [[ -n "$selected" ]] || selected="$(choose_rate)"

    if [[ "$selected" == auto ]]; then
        return_to_auto
        exit 0
    fi

    mode="$(mode_for_rate "$selected")" || {
        echo "Usage: refresh-switch [auto|52.03|60|90|120|144|165|180|240]" >&2
        exit 2
    }

    apply_mode "$mode" || exit 1

    if confirm_keep "$selected"; then
        printf '%s\n' "$selected" > "$OVERRIDE_FILE"
        notify-send "Refresh Rate" "${selected} Hz manual override active" 2>/dev/null || true
    else
        return_to_auto
    fi
}

main "$@"
SCRIPT
chmod +x "$SWITCH_SCRIPT"

log "Updating auto-refresh-rate so manual selections survive its 30-second check"
cat > "$AUTO_SCRIPT" <<'SCRIPT'
#!/usr/bin/env bash
set -u

OUTPUT="${REFRESH_OUTPUT:-eDP-1}"
BATTERY_MODE='modeline 1125.275 2560 2568 2600 2640 1600 3534 3542 3552 -hsync -vsync'
AC_MODE='preferred'
OVERRIDE_FILE="${XDG_RUNTIME_DIR:-/run/user/$UID}/refresh-rate-override"

exec 9>"${XDG_RUNTIME_DIR:-/run/user/$UID}/auto-refresh-rate.lock"
flock -n 9 || exit 0

last_state=""
last_verification=0

get_power_state() {
    local result
    result="$(busctl --system get-property org.freedesktop.UPower /org/freedesktop/UPower org.freedesktop.UPower OnBattery 2>/dev/null)" || return 1
    case "$result" in
        "b true")  printf 'battery\n' ;;
        "b false") printf 'ac\n' ;;
        *) return 1 ;;
    esac
}

get_refresh_rate() {
    hyprctl monitors -j 2>/dev/null | jq -r --arg output "$OUTPUT" '.[] | select(.name == $output) | .refreshRate'
}

apply_mode() {
    local state="$1" mode result
    [[ "$state" == battery ]] && mode="$BATTERY_MODE" || mode="$AC_MODE"
    result="$(hyprctl eval "hl.monitor({
        output = \"$OUTPUT\",
        mode = \"$mode\",
        position = \"0x0\",
        scale = 1.25
    })" 2>&1)"
    [[ "$result" == ok ]] || { echo "Failed to apply $state mode: $result" >&2; return 1; }
    echo "Power state: $state — default refresh-rate command applied"
}

echo "Automatic refresh-rate service started"

while true; do
    state="$(get_power_state)" || { sleep 2; continue; }
    now="$(date +%s)"
    should_apply=false

    # A charger transition always restores the default policy and ends a
    # temporary manual override.
    if [[ "$state" != "$last_state" ]]; then
        rm -f "$OVERRIDE_FILE"
        should_apply=true

    # While a manual selection is active, do not fight refresh-switch.
    elif [[ -f "$OVERRIDE_FILE" ]]; then
        last_verification="$now"

    elif (( now - last_verification >= 30 )); then
        refresh="$(get_refresh_rate)"
        if [[ "$state" == battery ]]; then
            awk -v hz="$refresh" 'BEGIN { exit !(hz > 180) }' && should_apply=true
        else
            awk -v hz="$refresh" 'BEGIN { exit !(hz < 200) }' && should_apply=true
        fi
        last_verification="$now"
    fi

    if [[ "$should_apply" == true ]]; then
        if apply_mode "$state"; then
            last_state="$state"
            last_verification="$now"
        fi
    else
        last_state="$state"
    fi

    sleep 1
done
SCRIPT
chmod +x "$AUTO_SCRIPT"

log "Adding SUPER + SHIFT + R to every installed Multi-Rice profile"
for profile in caelestia end4 ambxst dms; do
    file="$PROFILE_ROOT/$profile/hypr/hyprland.lua"
    [[ -f "$file" ]] || { warn "Skipping missing profile: $profile"; continue; }
    if ! grep -q 'HUZAIFAH-REFRESH-SWITCHER' "$file"; then
        cat >> "$file" <<'LUA'

-- HUZAIFAH-REFRESH-SWITCHER
hl.bind("SUPER + SHIFT + R", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/refresh-switch"))
LUA
    fi
done

if systemctl --user is-enabled auto-refresh-rate.service >/dev/null 2>&1; then
    systemctl --user daemon-reload
    systemctl --user restart auto-refresh-rate.service
fi

hyprctl reload >/dev/null 2>&1 || true

printf '\n'
ok "Refresh switcher installed"
printf 'Hotkey: SUPER + SHIFT + R\n'
printf 'Rates : 52.03, 60, 90, 120, 144, 165, 180, 240 Hz\n'
printf 'Auto  : 120 Hz on battery / 240 Hz on AC\n'
printf 'Safety: custom modes auto-revert after 10 seconds unless confirmed\n'
printf '\nBackup: %s.before-refresh-switcher-%s\n' "$AUTO_SCRIPT" "$STAMP"
