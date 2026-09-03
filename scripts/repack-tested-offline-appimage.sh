#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "${2:-.}" && pwd)"
DIST="$ROOT/dist"
SRC="$ROOT/installer-appimage-offline"
BUILD="$SRC/.build"
TOOL="$BUILD/appimagetool-modern-x86_64.AppImage"
WORK="$BUILD/repack-tested-fixed"
OUT="$DIST/Huzaifah-Multi-Rice-OFFLINE-FIXED-x86_64.AppImage"
OUT_SHA="$OUT.sha256"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()  { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

INPUT="${1:-}"
if [[ -z "$INPUT" ]]; then
    for candidate in \
        "$DIST/Huzaifah-Multi-Rice-OFFLINE-x86_64.AppImage" \
        "$DIST/Huzaifah-Triple-Rice-Offline-x86_64.AppImage"; do
        if [[ -f "$candidate" ]]; then
            INPUT="$candidate"
            break
        fi
    done
fi

[[ -n "$INPUT" && -f "$INPUT" ]] || die "Could not find the previously tested offline AppImage in $DIST"
INPUT="$(realpath "$INPUT")"
[[ -f "$SRC/AppRun" ]] || die "Missing fixed AppRun"
[[ -f "$SRC/install-offline.sh" ]] || die "Missing fixed install-offline.sh"
[[ -f "$ROOT/dual-rice/profiles/caelestia/hypr/hyprland.lua" ]] || die "Missing fixed Caelestia profile"

log "Repacking the already-tested offline payload; no package resolution or system changes"
rm -rf "$WORK"
mkdir -p "$WORK" "$BUILD" "$DIST"

log "Extracting tested AppImage"
(
    cd "$WORK"
    "$INPUT" --appimage-extract >/dev/null
)
APPDIR="$WORK/squashfs-root"
[[ -d "$APPDIR/payload/packages" ]] || die "Extracted AppImage does not contain the offline package payload"

log "Overlaying only the verified release fixes"
install -m 0755 "$SRC/AppRun" "$APPDIR/AppRun"
install -m 0755 "$SRC/install-offline.sh" "$APPDIR/install-offline.sh"
install -m 0644 \
    "$ROOT/dual-rice/profiles/caelestia/hypr/hyprland.lua" \
    "$APPDIR/payload/repo/dual-rice/profiles/caelestia/hypr/hyprland.lua"

# The original test exposed missing executable bits in staged repository scripts.
find "$APPDIR/payload/repo" -type f -name '*.sh' -exec chmod 0755 {} +
if [[ -d "$APPDIR/payload/repo/dual-rice/bin" ]]; then
    find "$APPDIR/payload/repo/dual-rice/bin" -maxdepth 1 -type f -exec chmod 0755 {} +
fi
chmod 0755 "$APPDIR/AppRun" "$APPDIR/install-offline.sh"

bash -n "$APPDIR/AppRun"
bash -n "$APPDIR/install-offline.sh"

if [[ ! -x "$TOOL" ]]; then
    log "Downloading modern appimagetool"
    curl -fL --retry 3 \
        https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage \
        -o "$TOOL"
    chmod +x "$TOOL"
fi

log "Building fixed single-file AppImage"
rm -f "$OUT" "$OUT_SHA"
ARCH=x86_64 APPIMAGE_EXTRACT_AND_RUN=1 "$TOOL" "$APPDIR" "$OUT"
chmod +x "$OUT"
sha256sum "$OUT" > "$OUT_SHA"

# Exercise the new runtime normally; this catches the old libfuse.so.2 problem.
"$OUT" --appimage-version >/dev/null

ok "Fixed AppImage built from the payload that already passed the VM install test"
ls -lh "$OUT" "$OUT_SHA"
printf '\nNo packages were installed, removed, upgraded, or re-resolved while repacking.\n'
