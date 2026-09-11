#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${1:-$ROOT/Huzaifah-Utilities-ONLINE-v1.0.0-x86_64.AppImage}"
WORK="$ROOT/build"
APPDIR="$WORK/Utilities.AppDir"
TOOL="$WORK/appimagetool-x86_64.AppImage"

rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin" "$APPDIR/usr/share/applications" "$APPDIR/usr/share/icons/hicolor/scalable/apps"

install -Dm755 "$ROOT/AppRun" "$APPDIR/AppRun"
install -Dm755 "$ROOT/install-utilities.sh" "$APPDIR/install-utilities.sh"
ln -s ../../AppRun "$APPDIR/usr/bin/huzaifah-utilities"
install -Dm644 "$ROOT/huzaifah-utilities.desktop" "$APPDIR/huzaifah-utilities.desktop"
install -Dm644 "$ROOT/huzaifah-utilities.desktop" "$APPDIR/usr/share/applications/huzaifah-utilities.desktop"
install -Dm644 "$ROOT/huzaifah-utilities.svg" "$APPDIR/huzaifah-utilities.svg"
install -Dm644 "$ROOT/huzaifah-utilities.svg" "$APPDIR/usr/share/icons/hicolor/scalable/apps/huzaifah-utilities.svg"

mkdir -p "$WORK"
if [[ ! -x "$TOOL" ]]; then
    printf 'Downloading appimagetool...\n'
    curl -fL --retry 3 \
        -o "$TOOL" \
        https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
    chmod +x "$TOOL"
fi

rm -f "$OUT"
ARCH=x86_64 APPIMAGE_EXTRACT_AND_RUN=1 "$TOOL" "$APPDIR" "$OUT"
chmod +x "$OUT"
printf '\nBuilt: %s\n' "$OUT"
sha256sum "$OUT" | tee "$OUT.sha256"
