#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
UNIT=huzaifah-inir.service
if [[ "${1:-}" == --compositor ]]; then
    [[ "$(tr -d '[:space:]' < "$HOME/.config/desktop-profile/active")" == inir ]] || exit 1
    export PATH="$ROOT/bin:$HOME/.local/bin:$PATH"
    export NIRI_CONFIG="$ROOT/niri/config.kdl"
    export XDG_CURRENT_DESKTOP=niri XDG_SESSION_TYPE=wayland
    unset NIRI_DISABLE_SYSTEM_MANAGER_NOTIFY
    exec /usr/bin/niri --session --config "$NIRI_CONFIG"
fi
[[ -f "$ROOT/READY" ]] || { echo 'iNiR preparation is incomplete.' >&2; exit 1; }
[[ -z "${WAYLAND_DISPLAY:-}" && -z "${DISPLAY:-}" ]] || { echo 'Select iNiR, then log out and log in through Huzaifah Multi-Rice.' >&2; exit 1; }
for unit in niri.service huzaifah-cipher-genie.service huzaifah-cipher-native.service "$UNIT"; do
    ! systemctl --user --quiet is-active "$unit" || { echo 'A compositor session is already active.' >&2; exit 1; }
done
umask 077
mkdir -p "$ROOT/logs"
exec >>"$ROOT/logs/login-startup.log" 2>&1
snapshot="$(systemctl --user show-environment)"
had_path=false; had_config=false; old_path=''; old_config=''
while IFS= read -r entry; do
    case "$entry" in
        PATH=*) had_path=true; old_path="${entry#PATH=}" ;;
        NIRI_CONFIG=*) had_config=true; old_config="${entry#NIRI_CONFIG=}" ;;
    esac
done <<< "$snapshot"
cleanup() {
    systemctl --user stop huzaifah-inir-shell.service inir-wlsunset.service huzaifah-inir-wallpaper.service inir-xembedsniproxy.service "$UNIT" || true
    systemctl --user start --job-mode=replace-irreversibly niri-shutdown.target || true
    systemctl --user unset-environment WAYLAND_DISPLAY DISPLAY NIRI_SOCKET XDG_CURRENT_DESKTOP XDG_SESSION_TYPE || true
    if $had_path; then systemctl --user set-environment "PATH=$old_path"; else systemctl --user unset-environment PATH; fi
    if $had_config; then systemctl --user set-environment "NIRI_CONFIG=$old_config"; else systemctl --user unset-environment NIRI_CONFIG; fi
}
trap cleanup EXIT
trap 'exit 143' TERM HUP
trap 'exit 130' INT
imports=()
for name in XDG_SESSION_ID XDG_SEAT XDG_VTNR XDG_RUNTIME_DIR XDG_SESSION_TYPE XDG_CURRENT_DESKTOP; do
    [[ -z "${!name+x}" ]] || imports+=("$name")
done
(( ${#imports[@]} == 0 )) || systemctl --user import-environment "${imports[@]}"
systemctl --user set-environment "PATH=$ROOT/bin:$HOME/.local/bin:$PATH" "NIRI_CONFIG=$ROOT/niri/config.kdl"
systemctl --user reset-failed "$UNIT" huzaifah-inir-shell.service || true
status=0
systemctl --user --wait start "$UNIT" || status=$?
exit "$status"
