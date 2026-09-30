#!/usr/bin/env bash
# Read-only, intentionally minimal inventory. No sudo; writes no files.
set -u

title() { printf '\n=== %s ===\n' "$1"; }
checkbin() {
    local name="$1"
    if command -v "$name" >/dev/null 2>&1; then
        printf '%s: %s\n' "$name" "$(command -v "$name")"
    else
        printf '%s: unavailable\n' "$name"
    fi
}

printf '%s\n' 'ZEPHYRUS v6.0 host inventory (read-only)'
title "COMPOSITORS / QUICKSHELL"
if command -v niri >/dev/null 2>&1; then niri --version 2>&1 | head -n 2; fi
if command -v Hyprland >/dev/null 2>&1; then Hyprland --version 2>&1 | head -n 2; fi
if command -v qs >/dev/null 2>&1; then qs --version 2>&1 | head -n 3; fi
if command -v quickshell >/dev/null 2>&1; then quickshell --version 2>&1 | head -n 3; fi
for cmd in niri Hyprland qs quickshell qsb swww awww; do checkbin "$cmd"; done

title "PROFILE DIRECTORIES"
root="$HOME/.local/share/desktop-profiles"
if [[ -d "$root" ]]; then
    found=0
    while IFS= read -r -d '' dir; do
        name="${dir##*/}"
        comp="-"
        [[ -f "$dir/hypr/hyprland.lua" ]] && comp="hyprland"
        [[ -f "$dir/niri/config.kdl" ]] && comp="niri"
        [[ "$comp" == "-" ]] && continue
        printf '%s | %s\n' "$name" "$comp"
        found=1
    done < <(find "$root" -mindepth 1 -maxdepth 1 -type d -print0)
    if [[ "$found" == 0 ]]; then
        printf 'No recognized profile structures. Actual paths need checking.\n'
    fi
else
    printf 'Profile root not found.\n'
fi

title "ACTIVE CONFIG LINKS"
for config in hypr niri; do
    path="$HOME/.config/$config"
    if [[ -L "$path" ]]; then
        target="$(readlink "$path")"
        # Print only the basename, not private home paths.
        printf '%s -> %s\n' "$config" "${target##*/}"
    elif [[ -d "$path" ]]; then
        printf '%s is a directory\n' "$config"
    else
        printf '%s not found\n' "$config"
    fi
done

title "SELECTED PACKAGES (INSTALLED VERSION)"
if command -v pacman >/dev/null 2>&1; then
    for pkg in niri hyprland quickshell quickshell-git qt6-base qt6-declarative qt6-shadertools; do
        pacman -Q "$pkg" 2>/dev/null || true
    done
fi

title "SWITCHER AND MEDIA ENTRY POINTS"
for cmd in multi-rice-control multi-rice-switcher background-music end4-media-backend; do
    checkbin "$cmd"
done
if command -v systemctl >/dev/null 2>&1; then
    systemctl --user list-unit-files --no-legend --no-pager 2>/dev/null |
        grep -Ei '(^|[-_])(music|media|lumina)([-_.[:space:]]|$)' |
        head -n 20 || true
fi

title "NIRI BLUR FEATURE CAPABILITY"
if command -v niri >/dev/null 2>&1; then
    printf '%s\n' 'Blur support requires Niri 26.04+; version shown above.'
fi

printf '\n%s\n' 'END OF READ-ONLY REPORT. Review before sharing.'
