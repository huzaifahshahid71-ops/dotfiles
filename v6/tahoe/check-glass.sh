#!/usr/bin/env bash
# Non-invasive Hyprliquid feasibility check for exact live G16 build.
# Does not install, load, unload, or restart compositor plugins.
set -u

echo "ZEPHYRUS Tahoe v6.0 — refractive material readiness (read-only)"
printf '\n%s\n' '=== SESSION / VERSIONS ==='
printf 'Compositor environment: %s\n' "${XDG_CURRENT_DESKTOP:-not-set}"
if command -v Hyprland >/dev/null 2>&1; then
    Hyprland --version 2>/dev/null | head -n 2 || true
fi
if command -v qs >/dev/null 2>&1; then
    qs --version 2>/dev/null | head -n 1 || true
fi

printf '\n%s\n' '=== HYPRLIQUID INSTALLATION ==='
if command -v pacman >/dev/null 2>&1; then
    pacman -Q hyprliquid 2>/dev/null || echo 'No hyprliquid pacman package recorded.'
fi
for path in \
    /usr/lib/libhyprliquid.so \
    "$HOME/.local/lib/hyprliquid.so" \
    "$HOME/.local/lib/libhyprliquid.so"
do
    if [[ -f "$path" ]]; then
        printf 'Found shared library: %s\n' "$path"
    fi
done

printf '\n%s\n' '=== CURRENTLY LOADED PLUGINS ==='
if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && command -v hyprctl >/dev/null 2>&1; then
    hyprctl plugin list 2>&1 || true
else
    echo 'No live Hyprland connection in this shell.'
fi

printf '\n%s\n' '=== SHADER TOOLS / RENDERER ==='
for path in /usr/lib/qt6/bin/qsb /usr/bin/qsb /opt/qt6/bin/qsb; do
    if [[ -x "$path" ]]; then
        printf 'QSB present: %s\n' "$path"
    fi
done
if command -v glxinfo >/dev/null 2>&1; then
    glxinfo -B 2>/dev/null | grep -E '(OpenGL vendor|OpenGL renderer|OpenGL version)' || true
else
    echo 'glxinfo not installed; no need to install it yet.'
fi

printf '\n%s\n' 'Read-only check complete. No Hyprland changes were made.'
