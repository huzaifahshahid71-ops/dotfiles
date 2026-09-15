#!/usr/bin/env bash
# The bar's record button. Capture.qml writes the start time (epoch seconds)
# to ~/.local/share/desktop-profiles/sayconlun/support/state/cache/recording while recording and empties it afterwards; this
# shows a record icon when idle and a red timer while recording.
# Every write ends the loop if waybar has gone, or reloads would orphan it.
f="$HOME/.local/share/desktop-profiles/sayconlun/support/state/cache/recording"
last=""
while :; do
    start=""
    [[ -r "$f" ]] && read -r start < "$f"
    if [[ "$start" =~ ^[0-9]+$ ]]; then
        s=$(( $(printf '%(%s)T' -1) - start ))
        line=$(printf '{"text":"\u25cf %d:%02d","class":"recording","tooltip":"Recording \u00b7 click to stop"}' $((s / 60)) $((s % 60)))
    else
        line='{"text":"󰑊","class":"idle","tooltip":"Record the screen \u00b7 right-click for an area"}'
    fi
    if [[ "$line" != "$last" ]]; then
        printf '%s\n' "$line" || exit
        last="$line"
    fi
    sleep 1
done
