#!/usr/bin/env bash

# Huzaifah Multi-Rice v5.1 profile metadata
# 10 Huzaifah desktop profiles + 21 Revo shell profiles.

profile_kind() {
    case "$1" in
        caelestia|end4|ambxst|dms|serpantinum|noctalia|sayconlun|jaqc|clavis|nixri)
            echo "desktop"
            ;;
        revo-*)
            echo "revo-shell"
            ;;
        *)
            return 1
            ;;
    esac
}

profile_origin() {
    case "$(profile_kind "$1" 2>/dev/null || true)" in
        desktop)    echo "huzaifah" ;;
        revo-shell) echo "revo" ;;
        *)          return 1 ;;
    esac
}

profile_compositor() {
    case "$1" in
        caelestia|end4|ambxst|dms|serpantinum|noctalia|sayconlun|revo-*)
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
        caelestia)           echo "Aether" ;;
        end4)                echo "Obsidian" ;;
        ambxst)              echo "Crimson" ;;
        dms)                 echo "Materia" ;;
        serpantinum)         echo "Aurora" ;;
        noctalia)            echo "Nocturne" ;;
        sayconlun)           echo "Lumina" ;;
        jaqc)                echo "Solstice" ;;
        clavis)              echo "Cipher" ;;
        nixri)               echo "Astra" ;;

        revo-11)             echo "Revo 11" ;;
        revo-q1)             echo "Revo Q1" ;;
        revo-brain-shell)    echo "Revo Brain Shell" ;;
        revo-cartoon-shell)  echo "Revo Cartoon" ;;
        revo-end4-pc)        echo "Revo end4-pC" ;;
        revo-eqsh)           echo "Revo EQSH" ;;
        revo-ii)             echo "Revo ii" ;;
        revo-clavis)         echo "Revo Clavis" ;;
        revo-k4)             echo "Revo K4" ;;
        revo-lotus)          echo "Revo Lotus" ;;
        revo-lucid)          echo "Revo Lucid" ;;
        revo-macduo)         echo "Revo MacDuo" ;;
        revo-macos)          echo "Revo macOS" ;;
        revo-nibrasshell)    echo "Revo Nibras" ;;
        revo-persona)        echo "Revo Persona" ;;
        revo-editorial)      echo "Revo Editorial" ;;
        revo-ryoku)          echo "Revo Ryoku" ;;
        revo-caelestia)      echo "Revo Caelestia" ;;
        revo-synoptik)       echo "Revo Synoptik" ;;
        revo-vast)           echo "Revo Vast" ;;
        revo-zesis)          echo "Revo Zesis" ;;
        *)                    echo "$1" ;;
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

        revo-lucid)      echo "◌" ;;
        revo-macos|revo-macduo) echo "⌘" ;;
        revo-end4-pc)    echo "◈" ;;
        revo-clavis)     echo "❖" ;;
        revo-caelestia)  echo "✦" ;;
        revo-ryoku)      echo "龍" ;;
        revo-*)          echo "R" ;;
        *)               echo "○" ;;
    esac
}

profile_shell() {
    case "$1" in
        revo-11)             echo "11" ;;
        revo-q1)             echo "Q1" ;;
        revo-brain-shell)    echo "brain_shell" ;;
        revo-cartoon-shell)  echo "cartoon-shell" ;;
        revo-end4-pc)        echo "end4-pc" ;;
        revo-eqsh)           echo "eqsh" ;;
        revo-ii)             echo "ii" ;;
        revo-clavis)         echo "imported-1789667132" ;;
        revo-k4)             echo "k4" ;;
        revo-lotus)          echo "lotus-dotfiles" ;;
        revo-lucid)          echo "lucid" ;;
        revo-macduo)         echo "macduo" ;;
        revo-macos)          echo "macos" ;;
        revo-nibrasshell)    echo "nibrasshell" ;;
        revo-persona)        echo "persona-quickshell" ;;
        revo-editorial)      echo "revo-editorial" ;;
        revo-ryoku)          echo "ryoku" ;;
        revo-caelestia)      echo "shell" ;;
        revo-synoptik)       echo "synoptik" ;;
        revo-vast)           echo "vast-shell" ;;
        revo-zesis)          echo "zesis" ;;
        *)                   return 1 ;;
    esac
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
        *)                   return 1 ;;
    esac
}

profile_config_path() {
    local root="$1"
    local profile="$2"
    local compositor kind

    compositor="$(profile_compositor "$profile")" || return 1
    kind="$(profile_kind "$profile")" || return 1

    if [[ "$kind" == "revo-shell" ]]; then
        if [[ -f "$root/revo/hypr/hyprland.lua" || -f "$root/revo/hypr/hyprland.conf" ]]; then
            printf "%s\n" "$root/revo/hypr"
            return 0
        fi
        return 1
    fi

    case "$compositor" in
        hyprland)
            [[ -f "$root/$profile/hypr/hyprland.lua" ]] || return 1
            printf "%s\n" "$root/$profile/hypr"
            ;;
        niri)
            [[ -f "$root/$profile/niri/config.kdl" ]] || return 1
            printf "%s\n" "$root/$profile/niri"
            ;;
        *)
            return 1
            ;;
    esac
}

profile_ids() {
    printf "%s\n" \
        caelestia \
        end4 \
        ambxst \
        dms \
        serpantinum \
        noctalia \
        sayconlun \
        jaqc \
        clavis \
        nixri \
        revo-11 \
        revo-q1 \
        revo-brain-shell \
        revo-cartoon-shell \
        revo-end4-pc \
        revo-eqsh \
        revo-ii \
        revo-clavis \
        revo-k4 \
        revo-lotus \
        revo-lucid \
        revo-macduo \
        revo-macos \
        revo-nibrasshell \
        revo-persona \
        revo-editorial \
        revo-ryoku \
        revo-caelestia \
        revo-synoptik \
        revo-vast \
        revo-zesis
}

profile_ids_for_compositor() {
    local wanted="$1"
    local profile

    while IFS= read -r profile; do
        [[ "$(profile_compositor "$profile" 2>/dev/null || true)" == "$wanted" ]] &&
            printf "%s\n" "$profile"
    done < <(profile_ids)
}
