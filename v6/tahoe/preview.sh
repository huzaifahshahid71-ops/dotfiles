#!/usr/bin/env bash
# Isolated Tahoe Quickshell preview, intentionally makes NO persistent changes.
# Only supported when called inside an existing Hyprland session.
set -euo pipefail

remote="https://raw.githubusercontent.com/huzaifahshahid71-ops/dotfiles/v6.0-tahoe-dev/v6/tahoe/shell.qml"
here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

check() {
    if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
        printf '%s\n' "Do not run Tahoe preview as root." >&2
        return 1
    fi
    if ! command -v qs >/dev/null 2>&1; then
        printf '%s\n' "Quickshell 'qs' not found; refusing to change system packages." >&2
        return 1
    fi
    if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" && "${XDG_CURRENT_DESKTOP,,}" != *hyprland* ]]; then
        printf '%s\n' "Please run from your existing Hyprland rice (not a Niri session)." >&2
        return 1
    fi
}

check
if [[ "${1:-}" == "--check" ]]; then
    printf '%s\n' "Ready: existing Hyprland session + Quickshell are available."
    exit 0
fi
if [[ $# -gt 0 ]]; then
    printf 'Usage: %s [--check]\n' "$0" >&2
    exit 2
fi

preview_dir="$(mktemp -d "${TMPDIR:-/tmp}/zephyrus-tahoe-preview.XXXXXXXX")"
cleanup() { rm -rf -- "$preview_dir"; }
trap cleanup EXIT

if [[ -f "$here/shell.qml" ]]; then
    cp -- "$here/shell.qml" "$preview_dir/shell.qml"
else
    command -v curl >/dev/null 2>&1 || {
        echo "curl is required for the downloaded preview script." >&2
        exit 1
    }
    curl --fail --location --silent --show-error --retry 2 \
        "$remote" -o "$preview_dir/shell.qml"
fi

printf '\n%s\n' "ZEPHYRUS TAHOE • Alpha 0.1"
printf '%s\n' "- Preview ONLY: menu bar, dock, running app focus, pinned launcher."
printf '%s\n' "- Glass here is VISUAL tint, not Hyprliquid refraction yet."
printf '%s\n' "- No profile switch, no system installs, no keybind or config changes."
printf '%s\n' "- Existing bars/docks may overlap while you inspect it."
printf '%s\n' "- Press Ctrl+C here (or click × on the preview bar) to exit."
printf '\n%s\n' "Launching isolated Quickshell path: $preview_dir/shell.qml"

# Stay in foreground: Ctrl+C closes THIS preview. Never pkill system Quickshell.
QS_NO_RELOAD_POPUP=1 qs -p "$preview_dir/shell.qml"
