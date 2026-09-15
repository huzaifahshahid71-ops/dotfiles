#!/usr/bin/env bash
# The bar's bell. State comes from Quickshell's notification server:
# NotifService.qml writes ~/.local/share/desktop-profiles/sayconlun/support/state/cache/notifications-state.json and sends
# waybar SIGRTMIN+8 whenever the count or Do Not Disturb changes.
f="$HOME/.local/share/desktop-profiles/sayconlun/support/state/cache/notifications-state.json"
count=0
dnd=false
if [[ -r "$f" ]]; then
    count="$(jq -r '.count // 0' "$f" 2>/dev/null || echo 0)"
    dnd="$(jq -r '.dnd // false' "$f" 2>/dev/null || echo false)"
fi
if [[ "$dnd" == true ]]; then
    alt=dnd
elif (( count > 0 )); then
    alt=notification
else
    alt=none
fi
tip="$count notification$([[ "$count" == 1 ]] || echo s)"
[[ "$dnd" == true ]] && tip="$tip · do not disturb"
printf '{"text":"","alt":"%s","class":"%s","tooltip":"%s"}\n' "$alt" "$alt" "$tip"
