#!/bin/bash
# gamemoded hook: silence notifications (Quickshell DND) while a game runs.
#
# Records the DND state from before the FIRST game, so gamemode-end.sh puts
# back what you had instead of clearing a DND you switched on yourself.
# `qs ipc` finds the shell through its socket under XDG_RUNTIME_DIR, so it
# needs no WAYLAND_DISPLAY from gamemoded's environment.
set -uo pipefail
: "${XDG_RUNTIME_DIR:=/run/user/$(id -u)}"
STATE="$XDG_RUNTIME_DIR/gamemode-dnd-previous"

if [ ! -e "$STATE" ]; then
    prev="$(qs -c lumina ipc call notifications dnd 2>/dev/null | tr -d '[:space:]')"
    case "$prev" in true|false) ;; *) prev=false ;; esac
    printf '%s\n' "$prev" > "$STATE"
fi

qs -c lumina ipc call notifications setDnd true >/dev/null 2>&1

# Always succeed: gamemoded logs a non-zero hook as a failure, and an
# unreachable shell is no reason to make starting a game look broken.
exit 0
