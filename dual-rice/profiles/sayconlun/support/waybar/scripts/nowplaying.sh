#!/usr/bin/env bash
# The song, for the music drawer on the bar (group/music): hovering the note
# slides this out. Prints empty text - so the drawer has nothing to reveal -
# unless some player is playing or paused.
#
# Every write is `|| exit`: when waybar reloads (SIGUSR2) it stops reading, and
# without that this loop and its playerctl lived on as orphans.
playerctl --follow metadata --format '{{status}}|{{title}}|{{artist}}' 2>/dev/null |
while IFS='|' read -r status title artist; do
    case "$status" in
        Playing|Paused) ;;
        *) echo '{"text":""}' || exit 0; continue ;;
    esac
    label="$title${artist:+ · $artist}"
    (( ${#label} > 44 )) && label="${label:0:43}…"
    jq -cn --arg t "$label" --arg tip "${artist:+$artist · }$title · ${status,,}" --arg c "${status,,}" \
        '{text: $t, tooltip: $tip, class: $c}' || exit 0
done
