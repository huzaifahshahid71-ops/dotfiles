#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
WORK="$TMP/dotfiles"
DIST="$ROOT/dist"
PREFLIGHT_ONLY=0
CACHE_AUDIT_ONLY=0
FORWARD_ARGS=()

cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

for arg in "$@"; do
    case "$arg" in
        --preflight-only) PREFLIGHT_ONLY=1 ;;
        --cache-audit-only) CACHE_AUDIT_ONLY=1 ;;
        *) FORWARD_ARGS+=("$arg") ;;
    esac
done

[[ -f "$ROOT/installer-appimage-offline/build-multi-rice.sh" ]] || die "build-multi-rice.sh is missing"
[[ -f "$ROOT/installer-appimage-offline/build.sh" ]] || die "build.sh is missing"

log "Preparing isolated safe build tree"
mkdir -p "$WORK" "$DIST"
rsync -a \
    --exclude '.git/' \
    --exclude 'dist/' \
    --exclude 'installer-appimage-offline/.build/' \
    "$ROOT/" "$WORK/"

# Root cause of the long rebuild loop:
# `pacman -Qp` uses -p as the query-file option, while --print-format implies
# pacman's global --print operation. Combining them caused archive_meta() to
# return no usable metadata, so every successfully built AUR archive looked
# "missing" forever. Use normal `pacman -Qp FILE`, whose output is exactly
# "pkgname pkgver" and is what find_exact_archive() expects.
python3 - "$WORK/installer-appimage-offline/build.sh" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
s = p.read_text()
old = "    pacman -Qp --print-format '%n %v' \"$1\" 2>/dev/null || true\n"
new = "    LC_ALL=C pacman -Qp \"$1\" 2>/dev/null || true\n"
if old not in s:
    raise SystemExit("Could not locate the broken archive_meta command in build.sh")
p.write_text(s.replace(old, new, 1))
PY

# Fast sanity-check the exact metadata path before allowing another long build.
sample="$(find "$HOME/.cache/paru" /var/cache/pacman/pkg -type f -name '*.pkg.tar.*' ! -name '*.sig' -print -quit 2>/dev/null || true)"
if [[ -n "$sample" ]]; then
    meta="$(LC_ALL=C pacman -Qp "$sample" 2>/dev/null || true)"
    [[ -n "$meta" ]] || die "pacman cannot read package archive metadata: $sample"
    log "Archive metadata preflight passed: $meta"
else
    log "No cached package archive found for preflight; continuing because the builder can create them"
fi

if (( PREFLIGHT_ONLY )); then
    log "Preflight-only mode passed; no packages were installed/rebuilt and no AppImage build was started"
    exit 0
fi

# The packages below were the exact foreign/AUR set repeatedly rebuilt by the
# failed runs. Audit them before another expensive build. This is read-only.
if (( CACHE_AUDIT_ONLY )); then
    audit_pkgs=(
        caelestia-cli
        dim-caelestia-shell-git
        libcava
        matugen-bin
        python-materialyoucolor
        python312
        quickshell-git
        ttf-league-gothic
        ttf-phosphor-icons
        ttf-readex-pro
        ttf-rubik-vf
    )

    log "Auditing exact cached archives for the 11 foreign/AUR packages"
    missing=0
    for pkg in "${audit_pkgs[@]}"; do
        if ! installed="$(pacman -Q "$pkg" 2>/dev/null)"; then
            printf '  MISSING INSTALLED PACKAGE: %s\n' "$pkg"
            missing=1
            continue
        fi
        ver="${installed#* }"
        found=0
        while IFS= read -r -d '' file; do
            file_meta="$(LC_ALL=C pacman -Qp "$file" 2>/dev/null || true)"
            [[ -n "$file_meta" ]] || continue
            name="${file_meta%% *}"
            file_ver="${file_meta#* }"
            if [[ "$name" == "$pkg" && "$file_ver" == "$ver" ]]; then
                printf '  OK  %-30s %s\n' "$pkg" "$ver"
                found=1
                break
            fi
        done < <(find "$HOME/.cache/paru" /var/cache/pacman/pkg -type f -name '*.pkg.tar.*' ! -name '*.sig' -print0 2>/dev/null)

        if (( ! found )); then
            printf '  NO EXACT ARCHIVE: %-24s %s\n' "$pkg" "$ver"
            missing=1
        fi
    done

    (( missing == 0 )) || die "Cache audit found missing exact archives; full build was NOT started"
    log "Cache audit passed for all 11 packages; full build was NOT started"
    exit 0
fi

log "Starting corrected Multi-Rice offline build"
(
    cd "$WORK"
    bash installer-appimage-offline/build-multi-rice.sh "${FORWARD_ARGS[@]}"
)

for name in Huzaifah-Multi-Rice-OFFLINE-x86_64.AppImage Huzaifah-Multi-Rice-OFFLINE-x86_64.sha256; do
    [[ -f "$WORK/dist/$name" ]] || die "Corrected builder finished without producing $name"
    cp -f "$WORK/dist/$name" "$DIST/$name"
done
chmod +x "$DIST/Huzaifah-Multi-Rice-OFFLINE-x86_64.AppImage"

printf '\nBuilt successfully:\n'
ls -lh "$DIST/Huzaifah-Multi-Rice-OFFLINE-x86_64.AppImage" "$DIST/Huzaifah-Multi-Rice-OFFLINE-x86_64.sha256"
