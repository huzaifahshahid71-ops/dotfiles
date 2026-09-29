#!/usr/bin/env bash
# Revo v5.1 compatibility front-end.
# All Revo shell changes go through multi-rice-control so DotsBrowser, Rofi,
# cycle actions, and the Huzaifah GUI share one source of truth.

set -euo pipefail

CONTROL="${MULTI_RICE_CONTROL:-$HOME/.local/bin/multi-rice-control}"

[[ -x "$CONTROL" ]] || {
    echo "toggle_qs_dots.sh: unified Multi-Rice backend not found: $CONTROL" >&2
    exit 1
}

profile_for_shell() {
    case "$1" in
        11)                  echo "revo-11" ;;
        Q1)                  echo "revo-q1" ;;
        brain_shell)         echo "revo-brain-shell" ;;
        cartoon-shell)       echo "revo-cartoon-shell" ;;
        end4-pc)             echo "revo-end4-pc" ;;
        eqsh)                echo "revo-eqsh" ;;
        ii)                  echo "revo-ii" ;;
        imported-1789667132) echo "revo-clavis" ;;
        k4)                  echo "revo-k4" ;;
        lotus-dotfiles)      echo "revo-lotus" ;;
        lucid)               echo "revo-lucid" ;;
        macduo)              echo "revo-macduo" ;;
        macos)               echo "revo-macos" ;;
        nibrasshell)         echo "revo-nibrasshell" ;;
        persona-quickshell)  echo "revo-persona" ;;
        revo-editorial)      echo "revo-editorial" ;;
        ryoku)               echo "revo-ryoku" ;;
        shell)               echo "revo-caelestia" ;;
        synoptik)            echo "revo-synoptik" ;;
        vast-shell)          echo "revo-vast" ;;
        zesis)               echo "revo-zesis" ;;
        default)             echo "revo-lucid" ;;
        revo-*)              echo "$1" ;;
        *)                   return 1 ;;
    esac
}

cycle_next() {
    local current id kind installed active
    local -a revo_profiles=()
    local active_index=-1

    current="$("$CONTROL" profile 2>/dev/null || true)"

    while IFS='|' read -r id _ _ _ installed active kind _; do
        [[ "$installed" == "true" && "$kind" == "revo-shell" ]] || continue
        [[ "$id" == "$current" || "$active" == "true" ]] && active_index="${#revo_profiles[@]}"
        revo_profiles+=("$id")
    done < <("$CONTROL" list)

    (( ${#revo_profiles[@]} > 0 )) || {
        echo "No installed Revo shells found" >&2
        exit 4
    }

    local next=$(( (active_index + 1) % ${#revo_profiles[@]} ))
    exec "$CONTROL" switch "${revo_profiles[$next]}"
}

show_menu() {
    if command -v foot >/dev/null 2>&1; then
        exec foot -e "$HOME/.local/bin/qs-list"
    elif command -v kitty >/dev/null 2>&1; then
        exec kitty "$HOME/.local/bin/qs-list"
    else
        exec "$HOME/.local/bin/qs-list"
    fi
}

case "${1:-menu}" in
    --next|-n)
        cycle_next
        ;;
    --menu|-m|menu)
        show_menu
        ;;
    stop)
        pkill -x quickshell >/dev/null 2>&1 || true
        ;;
    *)
        profile="$(profile_for_shell "$1")" || {
            echo "Unknown Revo shell/profile: $1" >&2
            exit 2
        }
        exec "$CONTROL" switch "$profile"
        ;;
esac
