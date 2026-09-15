#!/usr/bin/env bash
# Toggle a distraction-free writing mode: no bar, wide gaps, no borders.
#
# The gaps/border/rounding half is rice.focus() in conf/lib.lua, run inside
# Hyprland with `hyprctl eval`: entering saves the LIVE values and leaving puts
# exactly those back, so whatever rice-settings set survives the round trip.
# Hardcoding the "off" values silently undid it.
STATE="${XDG_RUNTIME_DIR:-/tmp}/hypr-focus.on"

if [[ -f "$STATE" ]]; then
    hyprctl eval 'rice.focus(false)' >/dev/null
    pkill -USR1 -x waybar             # SIGUSR1 toggles waybar's visibility
    rm -f "$STATE"; notify-send -t 1500 "Focus mode off" 2>/dev/null
else
    hyprctl eval 'rice.focus(true)' >/dev/null
    pkill -USR1 -x waybar
    : > "$STATE"
    notify-send -t 1500 "Focus mode" "Bar hidden, wide margins" 2>/dev/null
fi
