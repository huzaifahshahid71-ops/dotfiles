#!/bin/bash
# gamemoded hook: the last game exited - restore the DND state from before it.
set -uo pipefail
: "${XDG_RUNTIME_DIR:=/run/user/$(id -u)}"
STATE="$XDG_RUNTIME_DIR/gamemode-dnd-previous"

prev=false
[ -r "$STATE" ] && prev="$(tr -d '[:space:]' < "$STATE")"
rm -f "$STATE"

if [ "$prev" = true ]; then
    qs -c lumina ipc call notifications setDnd true >/dev/null 2>&1
else
    qs -c lumina ipc call notifications setDnd false >/dev/null 2>&1
    # only worth a toast once notifications are visible again
    notify-send -a "GameMode" -i input-gaming -t 3000 \
        "GameMode off" "Back to normal · notifications restored"
fi
exit 0
