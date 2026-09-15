#!/usr/bin/env bash

# Huzaifah Multi-Rice v5 profile metadata

profile_compositor() {
    case "$1" in
        caelestia|end4|ambxst|dms|serpantinum|noctalia|sayconlun)
            echo "hyprland"
            ;;
        jaqc|clavis|nixri)
            echo "niri"
            ;;
        *)
            return 1
            ;;
    esac
}

profile_name() {
    case "$1" in
        caelestia)   echo "Aether" ;;
        end4)        echo "Obsidian" ;;
        ambxst)      echo "Crimson" ;;
        dms)         echo "Materia" ;;
        serpantinum) echo "Aurora" ;;
        noctalia)    echo "Nocturne" ;;
        sayconlun)   echo "Lumina" ;;
        jaqc)        echo "Solstice" ;;
        clavis)      echo "Cipher" ;;
        nixri)       echo "Astra" ;;
        *)           echo "$1" ;;
    esac
}

profile_icon() {
    case "$1" in
        caelestia)   echo "✦" ;;
        end4)        echo "◈" ;;
        ambxst)      echo "◆" ;;
        dms)         echo "●" ;;
        serpantinum) echo "◇" ;;
        noctalia)    echo "◉" ;;
        sayconlun)   echo "⬡" ;;
        jaqc)        echo "☀" ;;
        clavis)      echo "❖" ;;
        nixri)       echo "✧" ;;
        *)           echo "○" ;;
    esac
}

profile_config_path() {
    local root="$1"
    local profile="$2"
    local compositor

    compositor="$(profile_compositor "$profile")" || return 1

    case "$compositor" in
        hyprland)
            [ -f "$root/$profile/hypr/hyprland.lua" ] || return 1
            printf "%s\n" "$root/$profile/hypr"
            ;;
        niri)
            [ -f "$root/$profile/niri/config.kdl" ] || return 1
            printf "%s\n" "$root/$profile/niri"
            ;;
        *)
            return 1
            ;;
    esac
}


profile_ids() {
    printf "%s
"         caelestia         end4         ambxst         dms         serpantinum         noctalia         sayconlun         jaqc         clavis         nixri
}

profile_ids_for_compositor() {
    local wanted="$1"
    local profile

    while IFS= read -r profile; do
        [ "$(profile_compositor "$profile" 2>/dev/null || true)" = "$wanted" ] &&
            printf "%s
" "$profile"
    done < <(profile_ids)
}
