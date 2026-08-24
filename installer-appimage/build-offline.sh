#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/installer-appimage"
BUILD="$SRC/.build-offline"
APPDIR="$BUILD/AppDir"
PAYLOAD="$APPDIR/usr/lib/huzaifah-offline"
PKGDIR="$PAYLOAD/packages"
REPO_SNAPSHOT="$PAYLOAD/repo"
SOURCE_SNAPSHOT="$PAYLOAD/sources"
DIST="$ROOT/dist"
TOOL="$BUILD/appimagetool-x86_64.AppImage"
OUT="$DIST/Huzaifah-Triple-Rice-OFFLINE-x86_64.AppImage"
ARCHIVE="$DIST/Huzaifah-Triple-Rice-OFFLINE-x86_64.tar.gz"
DBPATH="$BUILD/pacman-db"
PACMAN_LOG="$BUILD/pacman-offline-builder.log"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARNING:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

[[ "$(uname -m)" == "x86_64" ]] || die "Offline builder currently targets x86_64 only"
for cmd in pacman pactree python3 rsync git curl tar zstd bsdtar sha256sum; do
    command -v "$cmd" >/dev/null 2>&1 || die "$cmd is required"
done
[[ -f "$ROOT/scripts/restore-dual-rice.sh" ]] || die "Missing restore script"
[[ -f "$ROOT/scripts/measure-offline-size.py" ]] || die "Missing size calculator"
[[ -f "$SRC/AppRun-offline" ]] || die "Missing AppRun-offline"
[[ -f "$SRC/offline-install.sh" ]] || die "Missing offline-install.sh"
[[ -f "$ROOT/scripts/restore-triple-rice-offline.sh" ]] || die "Missing offline restore script"

rm -rf "$APPDIR" "$DBPATH"
mkdir -p "$APPDIR" "$PAYLOAD" "$PKGDIR" "$REPO_SNAPSHOT" "$SOURCE_SNAPSHOT" "$DIST" "$BUILD" "$DBPATH/sync"

log "Reading the exact triple-rice package list"
mapfile -t direct_targets < <(python3 - "$ROOT" <<'PY'
import importlib.util, pathlib, sys
root = pathlib.Path(sys.argv[1])
p = root / "scripts" / "measure-offline-size.py"
spec = importlib.util.spec_from_file_location("measure", p)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
for x in m.extract_restore_targets():
    print(x)
PY
)
# The normal installer adds SDDM after the rice restore; include it in the offline snapshot too.
direct_targets+=(sddm)
mapfile -t direct_targets < <(printf '%s\n' "${direct_targets[@]}" | sort -u)

repo_targets=()
aur_targets=()
for pkg in "${direct_targets[@]}"; do
    if pacman -Si "$pkg" >/dev/null 2>&1; then
        repo_targets+=("$pkg")
    else
        aur_targets+=("$pkg")
    fi
done

printf 'Direct package targets: %d (%d repository, %d foreign/AUR)\n' \
    "${#direct_targets[@]}" "${#repo_targets[@]}" "${#aur_targets[@]}"
if ((${#aur_targets[@]})); then
    printf 'Foreign/AUR targets:'
    printf ' %s' "${aur_targets[@]}"
    printf '\n'
fi

log "Creating an empty temporary pacman database"
# Using an empty local DB makes pacman treat the full dependency closure as missing,
# so it downloads every required repository archive instead of only packages absent on this laptop.
pacman -Sy --dbpath "$DBPATH" --cachedir "$PKGDIR" --logfile "$PACMAN_LOG" --noconfirm >/dev/null

log "Downloading COMPLETE repository dependency closure"
pacman -Sw --dbpath "$DBPATH" --cachedir "$PKGDIR" --logfile "$PACMAN_LOG" --noconfirm "${repo_targets[@]}"

find_cached_archive() {
    local pkg="$1" best="" best_mtime=0 file mt
    while IFS= read -r -d '' file; do
        local info name
        info="$(pacman -Qp "$file" 2>/dev/null || true)"
        name="${info%% *}"
        [[ "$name" == "$pkg" ]] || continue
        mt="$(stat -c %Y "$file" 2>/dev/null || echo 0)"
        if (( mt > best_mtime )); then
            best="$file"; best_mtime="$mt"
        fi
    done < <(find /var/cache/pacman/pkg "$HOME/.cache/paru" -type f -name '*.pkg.tar.*' ! -name '*.sig' -print0 2>/dev/null || true)
    [[ -n "$best" ]] && printf '%s\n' "$best"
}

build_aur_archive() {
    local pkg="$1" tmp archive
    command -v paru >/dev/null 2>&1 || die "$pkg is not in repositories and no cached archive was found. Install paru or place the package archive in your pacman/paru cache."
    tmp="$BUILD/aur-build/$pkg"
    rm -rf "$tmp"
    mkdir -p "$tmp"
    log "Building missing AUR archive: $pkg"
    (
        cd "$tmp"
        paru -G "$pkg"
        cd "$pkg"
        makepkg -s --needed --noconfirm --nocheck
    )
    archive="$(find "$tmp/$pkg" -maxdepth 1 -type f -name '*.pkg.tar.*' ! -name '*.sig' -print -quit)"
    [[ -n "$archive" ]] || die "AUR build finished but no package archive was produced for $pkg"
    printf '%s\n' "$archive"
}

log "Collecting foreign/AUR package archives"
for pkg in "${aur_targets[@]}"; do
    archive="$(find_cached_archive "$pkg" || true)"
    if [[ -z "$archive" ]]; then
        archive="$(build_aur_archive "$pkg")"
    fi
    cp -f "$archive" "$PKGDIR/"
done

# Read AUR runtime dependencies from their built package metadata. Any dependency
# available in enabled repositories is resolved against the same empty pacman DB,
# ensuring its complete repository closure is also bundled.
aur_repo_deps=()
unresolved_aur_deps=()
for archive in "$PKGDIR"/*.pkg.tar.*; do
    [[ -f "$archive" ]] || continue
    name="$(pacman -Qp "$archive" 2>/dev/null | awk '{print $1}')"
    [[ " ${aur_targets[*]} " == *" $name "* ]] || continue
    while IFS= read -r dep; do
        dep="${dep%%[<>=]*}"
        dep="${dep%%:*}"
        [[ -n "$dep" ]] || continue
        if pacman -Si "$dep" >/dev/null 2>&1; then
            aur_repo_deps+=("$dep")
        elif [[ " ${aur_targets[*]} " != *" $dep "* ]]; then
            # Virtual dependency names are okay if a bundled package provides them.
            unresolved_aur_deps+=("$dep")
        fi
    done < <(bsdtar -xOf "$archive" .PKGINFO 2>/dev/null | sed -n 's/^depend = //p')
done
if ((${#aur_repo_deps[@]})); then
    mapfile -t aur_repo_deps < <(printf '%s\n' "${aur_repo_deps[@]}" | sort -u)
    log "Downloading repository dependencies declared by AUR packages"
    pacman -Sw --dbpath "$DBPATH" --cachedir "$PKGDIR" --logfile "$PACMAN_LOG" --noconfirm "${aur_repo_deps[@]}"
fi

log "Creating package manifest"
: > "$PAYLOAD/package-manifest.txt"
for archive in "$PKGDIR"/*.pkg.tar.*; do
    [[ "$archive" == *.sig ]] && continue
    pacman -Qp "$archive" >> "$PAYLOAD/package-manifest.txt"
done
sort -u -o "$PAYLOAD/package-manifest.txt" "$PAYLOAD/package-manifest.txt"
package_count="$(wc -l < "$PAYLOAD/package-manifest.txt")"

snapshot_tree() {
    local local_path="$1" url="$2" commit_file="$3" dest="$4"
    local tmp commit=""
    rm -rf "$dest"
    if [[ -d "$local_path" ]]; then
        log "Snapshotting local source: $local_path"
        mkdir -p "$dest"
        rsync -a --delete --exclude='.git/' --exclude='build/' --exclude='dist/' "$local_path/" "$dest/"
        return
    fi
    tmp="$(mktemp -d)"
    [[ -f "$commit_file" ]] && commit="$(tr -d '[:space:]' < "$commit_file")"
    log "Local source missing; cloning bundled fallback: $url"
    git clone "$url" "$tmp/src"
    [[ -n "$commit" ]] && git -C "$tmp/src" checkout --detach "$commit"
    mkdir -p "$dest"
    rsync -a --delete --exclude='.git/' "$tmp/src/" "$dest/"
    rm -rf "$tmp"
}

log "Snapshotting the dotfiles repository"
rsync -a --delete \
    --exclude='.git/' \
    --exclude='dist/' \
    --exclude='installer-appimage/.build/' \
    --exclude='installer-appimage/.build-offline/' \
    "$ROOT/" "$REPO_SNAPSHOT/"

log "Snapshotting end4 and Ambxst sources"
snapshot_tree "$HOME/.local/src/end4-dots" \
    "https://github.com/end-4/dots-hyprland.git" "$ROOT/dual-rice/versions/end4-dots.commit" "$SOURCE_SNAPSHOT/end4-dots"
snapshot_tree "$HOME/.config/quickshell/end4-pC" \
    "https://github.com/pctrade/end4-pC.git" "$ROOT/dual-rice/versions/end4-pC.commit" "$SOURCE_SNAPSHOT/end4-pC"
snapshot_tree "$HOME/.local/src/ambxst" \
    "https://github.com/Axenide/Ambxst.git" "$ROOT/dual-rice/versions/ambxst.commit" "$SOURCE_SNAPSHOT/ambxst"

if [[ -x /usr/local/bin/axctl ]]; then
    cp -a /usr/local/bin/axctl "$SOURCE_SNAPSHOT/axctl"
elif command -v axctl >/dev/null 2>&1; then
    cp -a "$(command -v axctl)" "$SOURCE_SNAPSHOT/axctl"
else
    desired="$(grep -Eo 'v?[0-9]+(\.[0-9]+)+' "$ROOT/dual-rice/versions/axctl.txt" | head -1 | sed 's/^v//')"
    [[ -n "$desired" ]] || die "Could not determine pinned axctl version"
    log "Downloading pinned axctl $desired for the payload"
    curl -fL --retry 3 "https://github.com/Axenide/axctl/releases/download/v${desired}/axctl_linux_amd64" -o "$SOURCE_SNAPSHOT/axctl"
fi
chmod +x "$SOURCE_SNAPSHOT/axctl"

log "Preparing offline AppDir"
cp "$SRC/AppRun-offline" "$APPDIR/AppRun"
cp "$SRC/huzaifah-triple-rice-installer.desktop" "$APPDIR/"
cp "$SRC/huzaifah-triple-rice-installer.svg" "$APPDIR/"
ln -s huzaifah-triple-rice-installer.svg "$APPDIR/.DirIcon"
cp "$SRC/offline-install.sh" "$PAYLOAD/offline-install.sh"
chmod +x "$APPDIR/AppRun" "$PAYLOAD/offline-install.sh" "$REPO_SNAPSHOT/scripts/restore-triple-rice-offline.sh"
bash -n "$APPDIR/AppRun"
bash -n "$PAYLOAD/offline-install.sh"
bash -n "$REPO_SNAPSHOT/scripts/restore-triple-rice-offline.sh"

cat > "$PAYLOAD/BUILD-INFO.txt" <<EOF
Huzaifah Triple-Rice Offline Snapshot
Built: $(date -Is)
Architecture: x86_64
Package archives: $package_count
Dotfiles commit: $(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)
Network required during installation: no
EOF

if [[ ! -x "$TOOL" ]]; then
    log "Downloading appimagetool (builder-only dependency)"
    curl -fL --retry 3 https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage -o "$TOOL"
    chmod +x "$TOOL"
fi

log "Building the giant offline AppImage — CPU usage will rise here 😈"
rm -f "$OUT" "$ARCHIVE" "$DIST/SHA256SUMS-OFFLINE.txt"
ARCH=x86_64 APPIMAGE_EXTRACT_AND_RUN=1 "$TOOL" "$APPDIR" "$OUT"
chmod +x "$OUT"

log "Creating executable-preserving release archive"
tar -C "$DIST" -czf "$ARCHIVE" "$(basename "$OUT")"
sha256sum "$OUT" "$ARCHIVE" > "$DIST/SHA256SUMS-OFFLINE.txt"

APPIMAGE_EXTRACT_AND_RUN=1 "$OUT" --appimage-version >/dev/null

ok "FULL OFFLINE AppImage built"
printf '\nPackage archives bundled: %s\n' "$package_count"
ls -lh "$OUT" "$ARCHIVE" "$DIST/SHA256SUMS-OFFLINE.txt"
if ((${#unresolved_aur_deps[@]})); then
    printf '\nNote: AUR metadata contained these non-repository/virtual dependency names:\n'
    printf '  %s\n' "${unresolved_aur_deps[@]}" | sort -u
    printf 'They are expected to be satisfied by providers in the bundled package set; the install transaction will verify this.\n'
fi
