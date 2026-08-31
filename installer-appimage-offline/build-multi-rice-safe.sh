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

# Fix archive metadata parsing and, crucially, replace the old O(N) archive
# search. The old function walked every package in /var/cache/pacman/pkg and
# ran pacman -Qp on each file for every lookup. The corrected lookup narrows
# candidates by package-name prefix first, then validates the exact name/version
# from package metadata. Do not encode the installed version into the filename
# glob: Arch package epochs and some PKGBUILD filename details do not have to
# match pacman's displayed version string byte-for-byte.
python3 - "$WORK/installer-appimage-offline/build.sh" <<'PY'
from pathlib import Path
import re
import sys

p = Path(sys.argv[1])
s = p.read_text()

old_meta = "    pacman -Qp --print-format '%n %v' \"$1\" 2>/dev/null || true\n"
new_meta = "    LC_ALL=C pacman -Qp \"$1\" 2>/dev/null || true\n"
if old_meta in s:
    s = s.replace(old_meta, new_meta, 1)
elif new_meta not in s:
    raise SystemExit("Could not locate archive_meta command in build.sh")

new_find = r'''find_exact_archive() {
    local pkg="$1" ver="$2" file meta name version

    check_candidates() {
        local dir="$1" depth="$2"
        [[ -d "$dir" ]] || return 1
        while IFS= read -r -d '' file; do
            [[ "$file" == *.sig ]] && continue
            meta="$(archive_meta "$file")"
            [[ -n "$meta" ]] || continue
            name="${meta%% *}"
            version="${meta#* }"
            if [[ "$name" == "$pkg" && "$version" == "$ver" ]]; then
                printf '%s\n' "$file"
                return 0
            fi
        done < <(find "$dir" -maxdepth "$depth" -type f \
            -name "${pkg}-*.pkg.tar.*" ! -name '*.sig' -print0 2>/dev/null)
        return 1
    }

    # Official cache is flat. Paru normally stores built archives in the
    # package's own clone directory, so check those tiny locations first.
    check_candidates /var/cache/pacman/pkg 1 && return 0
    check_candidates "$HOME/.cache/paru/clone/$pkg" 2 && return 0
    check_candidates "$HOME/.cache/paru/$pkg" 2 && return 0

    # Compatibility fallback for unusual paru cache layouts. This may traverse
    # the directory tree, but pacman -Qp is run ONLY on files whose basenames
    # begin with the requested package name, never on the whole cache.
    [[ -d "$HOME/.cache/paru" ]] || return 1
    while IFS= read -r -d '' file; do
        [[ "$file" == *.sig ]] && continue
        meta="$(archive_meta "$file")"
        [[ -n "$meta" ]] || continue
        name="${meta%% *}"
        version="${meta#* }"
        if [[ "$name" == "$pkg" && "$version" == "$ver" ]]; then
            printf '%s\n' "$file"
            return 0
        fi
    done < <(find "$HOME/.cache/paru" -type f \
        -name "${pkg}-*.pkg.tar.*" ! -name '*.sig' -print0 2>/dev/null)
    return 1
}
'''
pattern = r'(?ms)^find_exact_archive\(\) \{.*?^\}\n\n(?=resolve_closure\(\))'
s, count = re.subn(pattern, lambda _m: new_find + "\n", s, count=1)
if count != 1:
    raise SystemExit("Could not locate find_exact_archive in build.sh")

p.write_text(s)
PY

# Fast sanity-check the metadata path before allowing another long build.
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

# Read-only cache audit. Use package-name-targeted lookups so this itself does
# not scan and parse the whole pacman cache repeatedly.
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

        candidate_dirs=(/var/cache/pacman/pkg "$HOME/.cache/paru/clone/$pkg" "$HOME/.cache/paru/$pkg")
        for dir in "${candidate_dirs[@]}"; do
            [[ -d "$dir" ]] || continue
            while IFS= read -r -d '' file; do
                file_meta="$(LC_ALL=C pacman -Qp "$file" 2>/dev/null || true)"
                [[ "$file_meta" == "$pkg $ver" ]] || continue
                printf '  OK  %-30s %s\n' "$pkg" "$ver"
                found=1
                break 2
            done < <(find "$dir" -maxdepth 2 -type f \
                -name "${pkg}-*.pkg.tar.*" ! -name '*.sig' -print0 2>/dev/null)
        done

        if (( ! found )); then
            while IFS= read -r -d '' file; do
                file_meta="$(LC_ALL=C pacman -Qp "$file" 2>/dev/null || true)"
                [[ "$file_meta" == "$pkg $ver" ]] || continue
                printf '  OK  %-30s %s\n' "$pkg" "$ver"
                found=1
                break
            done < <(find "$HOME/.cache/paru" -type f \
                -name "${pkg}-*.pkg.tar.*" ! -name '*.sig' -print0 2>/dev/null)
        fi

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
