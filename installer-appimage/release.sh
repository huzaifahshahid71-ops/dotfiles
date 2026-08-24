#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TAG="triple-rice-installer-v1.0.0"
TITLE="Huzaifah Triple-Rice Installer v1.0.0"
DIST="$ROOT/dist"
NOTES="$DIST/RELEASE_NOTES.md"
SHOWCASE_SOURCE="${SHOWCASE_VIDEO:-$HOME/Downloads/recording_20260808_15-55-50_iPhone.mp4}"
SHOWCASE_ASSET="$DIST/Huzaifah-Triple-Rice-Showcase.mp4"
SHOWCASE_PREVIEW="$DIST/Huzaifah-Triple-Rice-Showcase-Preview.jpg"
MAX_RELEASE_ASSET_BYTES=$((2 * 1024 * 1024 * 1024))

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()  { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARNING:\033[0m %s\n' "$*" >&2; }
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

showcase_included=0
rm -f "$SHOWCASE_ASSET" "$SHOWCASE_PREVIEW"

if [[ -f "$SHOWCASE_SOURCE" ]]; then
    showcase_size="$(stat -c '%s' "$SHOWCASE_SOURCE")"
    if (( showcase_size >= MAX_RELEASE_ASSET_BYTES )); then
        die "Showcase video is too large for a GitHub Release asset (must be under 2 GiB): $SHOWCASE_SOURCE"
    fi

    log "Preparing showcase video"
    if command -v ffprobe >/dev/null 2>&1 && command -v ffmpeg >/dev/null 2>&1; then
        codec="$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$SHOWCASE_SOURCE" 2>/dev/null || true)"
        if [[ "$codec" == "h264" ]]; then
            cp -f "$SHOWCASE_SOURCE" "$SHOWCASE_ASSET"
        else
            log "Converting showcase to H.264 for browser compatibility"
            ffmpeg -y -i "$SHOWCASE_SOURCE" \
                -c:v libx264 -preset medium -crf 22 -pix_fmt yuv420p \
                -c:a aac -b:a 160k -movflags +faststart \
                "$SHOWCASE_ASSET"
        fi

        ffmpeg -y -ss 00:00:02 -i "$SHOWCASE_ASSET" \
            -frames:v 1 -vf 'scale=1280:-2' -q:v 2 \
            "$SHOWCASE_PREVIEW" >/dev/null 2>&1 || true
    else
        cp -f "$SHOWCASE_SOURCE" "$SHOWCASE_ASSET"
        warn "ffmpeg/ffprobe not found; uploading the original video without codec normalization or preview image"
    fi

    final_size="$(stat -c '%s' "$SHOWCASE_ASSET")"
    if (( final_size >= MAX_RELEASE_ASSET_BYTES )); then
        die "Prepared showcase is too large for a GitHub Release asset (must be under 2 GiB)"
    fi
    showcase_included=1
    ok "Showcase prepared: $SHOWCASE_ASSET"
else
    warn "Showcase video not found at $SHOWCASE_SOURCE; publishing installer without it"
fi

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

if (( showcase_included )); then
    cat >> "$NOTES" <<'EOF'

## 🎬 Showcase / Demo

`Huzaifah-Triple-Rice-Showcase.mp4` is a recorded walkthrough of the customized desktop so you can preview the setup before installing it.
EOF
fi

assets=(
    "$DIST/Huzaifah-Triple-Rice-Installer-x86_64.AppImage"
    "$DIST/Huzaifah-Triple-Rice-Installer-x86_64.tar.gz"
    "$DIST/SHA256SUMS.txt"
)

if (( showcase_included )); then
    assets+=("$SHOWCASE_ASSET")
    [[ -f "$SHOWCASE_PREVIEW" ]] && assets+=("$SHOWCASE_PREVIEW")
fi

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
if (( showcase_included )); then
    ok "Showcase video uploaded with the release"
fi
gh release view "$TAG" --web || true
