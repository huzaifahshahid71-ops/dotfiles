#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/installer-appimage"
BUILD="$SRC/.build"
APPDIR="$BUILD/AppDir"
DIST="$ROOT/dist"
TOOL="$BUILD/appimagetool-x86_64.AppImage"
OUT="$DIST/Huzaifah-Triple-Rice-Installer-x86_64.AppImage"
ARCHIVE="$DIST/Huzaifah-Triple-Rice-Installer-x86_64.tar.gz"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()  { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

[[ "$(uname -m)" == "x86_64" ]] || die "This builder currently targets x86_64 only"
command -v curl >/dev/null 2>&1 || die "curl is required"
command -v tar >/dev/null 2>&1 || die "tar is required"

rm -rf "$APPDIR"
mkdir -p "$APPDIR" "$DIST" "$BUILD"

log "Preparing AppDir"
cp "$SRC/AppRun" "$APPDIR/AppRun"
cp "$SRC/huzaifah-triple-rice-installer.desktop" "$APPDIR/"
cp "$SRC/huzaifah-triple-rice-installer.svg" "$APPDIR/"
ln -s huzaifah-triple-rice-installer.svg "$APPDIR/.DirIcon"
chmod +x "$APPDIR/AppRun"
bash -n "$APPDIR/AppRun"

if [[ ! -x "$TOOL" ]]; then
    log "Downloading appimagetool"
    curl -fL --retry 3 \
        https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage \
        -o "$TOOL"
    chmod +x "$TOOL"
fi

log "Building AppImage"
rm -f "$OUT" "$ARCHIVE" "$DIST/SHA256SUMS.txt"
ARCH=x86_64 APPIMAGE_EXTRACT_AND_RUN=1 "$TOOL" "$APPDIR" "$OUT"
chmod +x "$OUT"

log "Creating executable-preserving archive"
tar -C "$DIST" -czf "$ARCHIVE" "$(basename "$OUT")"

sha256sum "$OUT" "$ARCHIVE" > "$DIST/SHA256SUMS.txt"

APPIMAGE_EXTRACT_AND_RUN=1 "$OUT" --appimage-version >/dev/null

ok "Built $(basename "$OUT")"
ls -lh "$OUT" "$ARCHIVE" "$DIST/SHA256SUMS.txt"
