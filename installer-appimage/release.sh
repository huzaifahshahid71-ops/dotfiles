#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TAG="triple-rice-installer-v1.0.0"
TITLE="Huzaifah Triple-Rice Installer v1.0.0"
DIST="$ROOT/dist"
NOTES="$DIST/RELEASE_NOTES.md"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()  { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

if ! command -v gh >/dev/null 2>&1; then
    if command -v pacman >/dev/null 2>&1; then
        log "Installing GitHub CLI"
        sudo pacman -S --needed github-cli
    else
        die "GitHub CLI (gh) is required"
    fi
fi

gh auth status >/dev/null 2>&1 || {
    printf '\nGitHub CLI is not authenticated. Run:\n\n  gh auth login\n\nThen run this script again.\n'
    exit 1
}

"$ROOT/installer-appimage/build.sh"

cat > "$NOTES" <<'EOF'
# Huzaifah Triple-Rice Installer v1.0.0

Double-click graphical installer for the Huzaifah Hyprland triple-rice setup.

**Installs:**
- ✦ Caelestia
- ◈ end4-pC
- ◆ Ambxst with axctl integration
- ⇄ `SUPER + SHIFT + D` profile switcher
- 🌙 Frieren SDDM login theme
- saved end4/Ambxst fixes and configuration from the dotfiles repository

This AppImage is intentionally lightweight. It does **not** bundle upstream packages or rice source trees; those remain online and are downloaded by the repository's normal `install.sh` during installation.

**Requirements:** x86_64 Arch/CachyOS-family Linux, internet access, sudo privileges, and a graphical desktop session.

The installer leaves your desktop wallpaper unchanged.

The `.tar.gz` asset contains the same AppImage while preserving its executable bit after extraction. If a browser strips the executable permission from the raw `.AppImage`, mark it executable in your file manager or run `chmod +x` on it once.
EOF

assets=(
    "$DIST/Huzaifah-Triple-Rice-Installer-x86_64.AppImage"
    "$DIST/Huzaifah-Triple-Rice-Installer-x86_64.tar.gz"
    "$DIST/SHA256SUMS.txt"
)

log "Publishing GitHub Release"
if gh release view "$TAG" >/dev/null 2>&1; then
    gh release edit "$TAG" --title "$TITLE" --notes-file "$NOTES"
    gh release upload "$TAG" "${assets[@]}" --clobber
else
    gh release create "$TAG" "${assets[@]}" \
        --target main \
        --title "$TITLE" \
        --notes-file "$NOTES"
fi

ok "Release published: $TAG"
gh release view "$TAG" --web || true
