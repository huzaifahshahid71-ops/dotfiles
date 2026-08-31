#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
WORK="$TMP/dotfiles"
DIST="$ROOT/dist"
PREFLIGHT_ONLY=0
CACHE_AUDIT_ONLY=0
DOWNLOAD_PREFLIGHT_ONLY=0
FORWARD_ARGS=()

cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

for arg in "$@"; do
    case "$arg" in
        --preflight-only) PREFLIGHT_ONLY=1 ;;
        --cache-audit-only) CACHE_AUDIT_ONLY=1 ;;
        --download-preflight-only) DOWNLOAD_PREFLIGHT_ONLY=1 ;;
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

# Fix three historical builder problems before launching it:
#   1. package archive metadata was queried with an invalid pacman option mix;
#   2. exact archive lookup parsed every file in the whole pacman cache;
#   3. pacman was told to download into a private mktemp tree. Modern pacman can
#      drop download privileges to its sandbox user, which cannot traverse that
#      0700 parent directory and therefore fails with "Permission denied".
#
# The corrected builder downloads official packages into pacman's normal system
# cache, then copies the exact installed-version archives into the AppImage
# payload as the regular build user. This also makes those ~1 GiB downloads
# reusable after a late build failure instead of throwing them away with /tmp.
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

    # Compatibility fallback for unusual paru cache layouts. pacman -Qp is run
    # only on files whose basenames begin with the requested package name.
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

# The historical final validation used the same broken --print-format mixture.
old_validate = '''        name="$(pacman -Qp --print-format '%n' "$file" 2>/dev/null || true)"\n'''
new_validate = '''        name="$(LC_ALL=C pacman -Qp "$file" 2>/dev/null | awk '{print $1}' || true)"\n'''
if old_validate in s:
    s = s.replace(old_validate, new_validate, 1)
elif new_validate not in s:
    raise SystemExit("Could not locate staged-package validation metadata command")

old_download = '''mapfile -t OFFICIAL < "$BUILD/official.txt"
if ((${#OFFICIAL[@]})); then
    log "Downloading ${#OFFICIAL[@]} official package archives into the offline repository"
    sudo pacman -Sw --noconfirm --cachedir "$PKG_DIR" "${OFFICIAL[@]}"
fi
sudo chown -R "$USER":"$(id -gn)" "$PKG_DIR"
find "$PKG_DIR" -maxdepth 1 -type f -name '*.sig' -delete
'''
new_download = '''mapfile -t OFFICIAL < "$BUILD/official.txt"
if ((${#OFFICIAL[@]})); then
    log "Downloading ${#OFFICIAL[@]} official package archives into pacman's persistent system cache"
    # Do not point pacman's downloader at the private mktemp/AppDir path. On
    # modern Arch/CachyOS pacman may download as a sandbox user that cannot
    # traverse mktemp's 0700 parent directory. The normal system cache is the
    # supported location and survives retries.
    sudo pacman -Sw --noconfirm "${OFFICIAL[@]}"

    log "Copying exact installed-version official archives into the offline repository"
    while IFS= read -r pkg; do
        [[ -n "$pkg" ]] || continue
        ver="$(package_version "$pkg")"
        archive="$(find_exact_archive "$pkg" "$ver")" || \
            die "Exact official archive missing after download: $pkg $ver"
        cp -f "$archive" "$PKG_DIR/"
    done < "$BUILD/official.txt"
fi
find "$PKG_DIR" -maxdepth 1 -type f -name '*.sig' -delete
'''
if old_download not in s:
    raise SystemExit("Could not locate official package download block in build.sh")
s = s.replace(old_download, new_download, 1)

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

# Prove the corrected official-download route independently of the full build.
# This downloads/caches one tiny official package at most; it does not install it.
if (( DOWNLOAD_PREFLIGHT_ONLY )); then
    test_pkg="xorg-xprop"
    installed="$(pacman -Q "$test_pkg" 2>/dev/null)" || die "$test_pkg is not installed"
    test_ver="${installed#* }"
    log "Testing pacman's persistent-cache download path with $test_pkg $test_ver"
    sudo pacman -Sw --noconfirm "$test_pkg"
    found=0
    while IFS= read -r -d '' file; do
        file_meta="$(LC_ALL=C pacman -Qp "$file" 2>/dev/null || true)"
        if [[ "$file_meta" == "$test_pkg $test_ver" ]]; then
            found=1
            break
        fi
    done < <(find /var/cache/pacman/pkg -maxdepth 1 -type f \
        -name "${test_pkg}-*.pkg.tar.*" ! -name '*.sig' -print0 2>/dev/null)
    (( found )) || die "Download preflight completed but exact cached archive was not found for $test_pkg $test_ver"
    log "Download preflight passed; no AppImage build was started"
    exit 0
fi

# Read-only cache audit for the exact AUR/foreign set that previously looped.
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
