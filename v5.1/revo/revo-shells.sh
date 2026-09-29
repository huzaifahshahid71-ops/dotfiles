#!/usr/bin/env bash
# Revo shell registry pinned for Huzaifah Multi-Rice v5.1.
# Upstream snapshot: vzbc/revo-shell@a15d62c87aa992ab8e5d366575bb4074eada7d98

revo_shell_ids() {
    printf '%s\n' \
        11 \
        Q1 \
        brain_shell \
        cartoon-shell \
        end4-pc \
        eqsh \
        ii \
        imported-1789667132 \
        k4 \
        lotus-dotfiles \
        lucid \
        macduo \
        macos \
        nibrasshell \
        persona-quickshell \
        revo-editorial \
        ryoku \
        shell \
        synoptik \
        vast-shell \
        zesis
}

revo_selectable_shell_ids() {
    printf '%s\n' \
        Q1 \
        brain_shell \
        cartoon-shell \
        end4-pc \
        eqsh \
        ii \
        imported-1789667132 \
        k4 \
        lotus-dotfiles \
        lucid \
        macos \
        nibrasshell \
        persona-quickshell \
        revo-editorial \
        ryoku \
        shell \
        synoptik \
        vast-shell \
        zesis
}

revo_utility_shell_ids() {
    # Eleven is HyprQuickFrame (screenshot overlay), not a persistent desktop.
    # MacDuo is the macOS lid/suspend animation companion.
    printf '%s\n' 11 macduo
}

revo_profile_ids() {
    printf '%s\n' \
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

revo_shell_for_profile() {
    case "$1" in
        revo-11)            echo "11" ;;
        revo-q1)            echo "Q1" ;;
        revo-brain-shell)   echo "brain_shell" ;;
        revo-cartoon-shell) echo "cartoon-shell" ;;
        revo-end4-pc)       echo "end4-pc" ;;
        revo-eqsh)          echo "eqsh" ;;
        revo-ii)            echo "ii" ;;
        revo-clavis)        echo "imported-1789667132" ;;
        revo-k4)            echo "k4" ;;
        revo-lotus)         echo "lotus-dotfiles" ;;
        revo-lucid)         echo "lucid" ;;
        revo-macduo)        echo "macduo" ;;
        revo-macos)         echo "macos" ;;
        revo-nibrasshell)   echo "nibrasshell" ;;
        revo-persona)       echo "persona-quickshell" ;;
        revo-editorial)     echo "revo-editorial" ;;
        revo-ryoku)         echo "ryoku" ;;
        revo-caelestia)     echo "shell" ;;
        revo-synoptik)      echo "synoptik" ;;
        revo-vast)          echo "vast-shell" ;;
        revo-zesis)         echo "zesis" ;;
        *) return 1 ;;
    esac
}

revo_profile_for_shell() {
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
        *) return 1 ;;
    esac
}
