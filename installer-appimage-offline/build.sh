#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/installer-appimage-offline"
ONLINE_SRC="$ROOT/installer-appimage"
RESTORE="$ROOT/scripts/restore-dual-rice.sh"
RESOLVER="$ROOT/scripts/resolve-offline-closure.py"
BUILD="$SRC/.build"
APPDIR="$BUILD/AppDir"
PAYLOAD="$APPDIR/payload"
PKG_DIR="$PAYLOAD/packages"
DIST="$ROOT/dist"
TOOL="$BUILD/appimagetool-modern-x86_64.AppImage"
OUT="$DIST/Huzaifah-Triple-Rice-Offline-x86_64.AppImage"
OUT_SHA="$DIST/Huzaifah-Triple-Rice-Offline-x86_64.sha256"
TARGETS_FILE="$BUILD/targets.txt"
CLOSURE_FILE="$BUILD/closure.txt"

END4_DOTS_SOURCE="${END4_DOTS_SOURCE:-$HOME/.local/src/end4-dots}"
END4_PC_SOURCE="${END4_PC_SOURCE:-$HOME/.config/quickshell/end4-pC}"
AMBXST_SOURCE="${AMBXST_SOURCE:-$HOME/.local/src/ambxst}"
AXCTL_SOURCE="${AXCTL_SOURCE:-$(command -v axctl 2>/dev/null || true)}"
SKIP_SYSTEM_UPDATE=0

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARNING:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
    cat <<'EOF'
Build the complete no-internet Huzaifah Triple-Rice AppImage.

Usage:
  bash installer-appimage-offline/build.sh [--skip-system-update]

Default builder behaviour:
  1. Fully updates the Arch/CachyOS build machine.
  2. Installs any direct triple-rice packages missing from the build machine.
  3. Resolves the exact installed dependency closure, including virtual providers.
  4. Preserves exact cached AUR archives when available and rebuilds only missing
     AUR archives, one package at a time to avoid virtual-provider conflicts.
  5. Ensures every foreign/AUR package has a real package archive.
  6. Downloads every official package archive into an embedded local pacman repo.
  7. Bundles current local end4-dots, end4-pC, Ambxst and axctl.
  8. Bundles the current dotfiles working tree and Frieren SDDM assets.
  9. Validates that every package in the dependency closure is present.
 10. Builds one x86_64 AppImage in ./dist.

The build step needs internet. The resulting AppImage does not.
Expect several GB of temporary disk usage while building even though the final
file is expected to be around the ~1-1.5 GiB range on the current setup.
EOF
}

while (($#)); do
    case "$1" in
        --skip-system-update) SKIP_SYSTEM_UPDATE=1 ;;
        --help|-h) usage; exit 0 ;;
        *) die "Unknown option: $1" ;;
    esac
    shift
done

is_arch_family() {
    [[ -r /etc/os-release ]] || return 1
    . /etc/os-release
    [[ "${ID:-}" == "arch" || "${ID:-}" == "cachyos" || "${ID_LIKE:-}" == *arch* ]]
}

ensure_paru() {
    if command -v paru >/dev/null 2>&1; then
        return
    fi
    log "Installing paru for AUR package preparation"
    local tmp
    tmp="$(mktemp -d)"
    git clone https://aur.archlinux.org/paru.git "$tmp/paru"
    (
        cd "$tmp/paru"
        makepkg -si --needed --noconfirm
    )
    rm -rf "$tmp"
}

extract_targets() {
    python3 - "$RESTORE" <<'PY'
import shlex
import sys
from pathlib import Path

path = Path(sys.argv[1])
lines = path.read_text(errors="replace").splitlines()
targets = []
collecting = False
for line in lines:
    if not collecting:
        if "paru -S --needed" not in line:
            continue
        collecting = True
        text = line.split("--needed", 1)[1].strip()
    else:
        text = line.strip()
    continued = text.endswith("\\")
    if continued:
        text = text[:-1].strip()
    if text:
        targets.extend(shlex.split(text))
    if collecting and not continued:
        break
for target in sorted(set(targets + ["sddm"])):
    print(target)
PY
}

package_version() {
    pacman -Q "$1" | awk '{print $2}'
}

archive_meta() {
    pacman -Qp --print-format '%n %v' "$1" 2>/dev/null || true
}

find_exact_archive() {
    local pkg="$1" ver="$2" root file meta name version
    local roots=(/var/cache/pacman/pkg "$HOME/.cache/paru")
    for root in "${roots[@]}"; do
        [[ -d "$root" ]] || continue
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
        done < <(find "$root" -type f -name '*.pkg.tar.*' -print0 2>/dev/null)
    done
    return 1
}

resolve_closure() {
    python3 "$RESOLVER" --targets-file "$TARGETS_FILE" > "$CLOSURE_FILE"
}

split_closure() {
    local foreign_list="$BUILD/foreign-installed.txt"
    pacman -Qmq | sort -u > "$foreign_list"
    : > "$BUILD/official.txt"
    : > "$BUILD/foreign.txt"
    while IFS= read -r pkg; do
        [[ -n "$pkg" ]] || continue
        if grep -Fxq "$pkg" "$foreign_list"; then
            printf '%s\n' "$pkg" >> "$BUILD/foreign.txt"
        else
            printf '%s\n' "$pkg" >> "$BUILD/official.txt"
        fi
    done < "$CLOSURE_FILE"
}

rebuild_one_aur_package() {
    local pkg="$1"
    log "Rebuilding AUR package: $pkg"
    paru -S --rebuild=all --noconfirm --skipreview --nocheck --sudoloop "$pkg"
}

rebuild_aur_closure() {
    resolve_closure
    split_closure

    local pkg ver archive
    local rebuild_needed=()
    local cached_exact=()
    local local_only=()

    while IFS= read -r pkg; do
        [[ -n "$pkg" ]] || continue
        ver="$(package_version "$pkg")"

        if paru -Si --aur "$pkg" >/dev/null 2>&1; then
            if archive="$(find_exact_archive "$pkg" "$ver")"; then
                cached_exact+=("$pkg")
            else
                rebuild_needed+=("$pkg")
            fi
        else
            if archive="$(find_exact_archive "$pkg" "$ver")"; then
                local_only+=("$pkg")
            else
                die "Foreign package '$pkg' is not available from the AUR and its exact local archive is missing"
            fi
        fi
    done < "$BUILD/foreign.txt"

    if ((${#cached_exact[@]})); then
        log "Keeping ${#cached_exact[@]} exact AUR archive(s) already matching the installed versions"
        printf '  %s\n' "${cached_exact[@]}"
    fi

    if ((${#local_only[@]})); then
        log "Keeping ${#local_only[@]} non-AUR foreign package archive(s) exactly as installed"
        printf '  %s\n' "${local_only[@]}"
    fi

    if ((${#rebuild_needed[@]})); then
        log "Rebuilding ${#rebuild_needed[@]} AUR package(s) whose exact installed archives are missing"
        printf '  %s\n' "${rebuild_needed[@]}"
        # Never ask paru to solve the entire foreign-package set in one
        # transaction. Packages such as DMS depend on the virtual `quickshell`
        # provider and can make paru select noctalia-qs while quickshell-git is
        # already installed. One-package transactions preserve the installed
        # provider and avoid that resolver ambiguity.
        for pkg in "${rebuild_needed[@]}"; do
            rebuild_one_aur_package "$pkg"
        done
    fi
}

ensure_foreign_archives() {
    local pass=1 pkg ver archive
    while (( pass <= 3 )); do
        resolve_closure
        split_closure
        local missing=()
        while IFS= read -r pkg; do
            [[ -n "$pkg" ]] || continue
            ver="$(package_version "$pkg")"
            if ! archive="$(find_exact_archive "$pkg" "$ver")"; then
                missing+=("$pkg")
            fi
        done < "$BUILD/foreign.txt"

        if ((${#missing[@]} == 0)); then
            return 0
        fi

        log "Rebuilding ${#missing[@]} foreign/AUR package(s) whose exact archives are still missing (pass $pass)"
        printf '  %s\n' "${missing[@]}"

        for pkg in "${missing[@]}"; do
            if paru -Si --aur "$pkg" >/dev/null 2>&1; then
                rebuild_one_aur_package "$pkg"
            else
                die "Foreign package '$pkg' has no cached archive and could not be resolved from the AUR. Preserve/provide its .pkg.tar.* archive before rebuilding the offline image."
            fi
        done
        ((pass++))
    done

    die "Foreign package closure kept changing after rebuilds; refusing to create an incomplete offline image"
}

copy_foreign_archives() {
    local pkg ver archive
    while IFS= read -r pkg; do
        [[ -n "$pkg" ]] || continue
        ver="$(package_version "$pkg")"
        archive="$(find_exact_archive "$pkg" "$ver")" || die "Exact archive still missing for $pkg $ver"
        cp -f "$archive" "$PKG_DIR/"
    done < "$BUILD/foreign.txt"
}

validate_staged_packages() {
    local index="$BUILD/staged-package-names.txt" file name
    : > "$index"
    while IFS= read -r -d '' file; do
        name="$(pacman -Qp --print-format '%n' "$file" 2>/dev/null || true)"
        [[ -n "$name" ]] && printf '%s\n' "$name" >> "$index"
    done < <(find "$PKG_DIR" -maxdepth 1 -type f -name '*.pkg.tar.*' ! -name '*.sig' -print0)
    sort -u -o "$index" "$index"

    local missing=()
    while IFS= read -r name; do
        grep -Fxq "$name" "$index" || missing+=("$name")
    done < "$CLOSURE_FILE"

    if ((${#missing[@]})); then
        printf 'Missing staged package archives:\n' >&2
        printf '  %s\n' "${missing[@]}" >&2
        die "Offline package payload validation failed"
    fi
}

copy_tree() {
    local src="$1" dst="$2"
    [[ -d "$src" ]] || die "Required source tree is missing: $src"
    mkdir -p "$dst"
    rsync -a --delete \
        --exclude '.git/' \
        --exclude '.build/' \
        --exclude 'build/' \
        --exclude 'dist/' \
        --exclude '*.before-*' \
        --exclude '__pycache__/' \
        --exclude '*.pyc' \
        "$src/" "$dst/"
}

build_payload_checksums() {
    local checksum="$PAYLOAD/SHA256SUMS"
    : > "$checksum"
    (
        cd "$PAYLOAD"
        find packages -maxdepth 1 -type f \( -name '*.pkg.tar.*' -o -name 'huzaifah-offline.db*' \) -print0 \
            | sort -z \
            | xargs -0 -r sha256sum
        sha256sum bin/axctl targets.txt manifest.txt
    ) > "$checksum"
}

[[ "$(uname -m)" == "x86_64" ]] || die "This builder currently targets x86_64 only"
is_arch_family || die "Build the offline image on an Arch/CachyOS-family x86_64 machine"
[[ -f "$RESTORE" ]] || die "Missing restore script: $RESTORE"
[[ -f "$RESOLVER" ]] || die "Missing dependency resolver: $RESOLVER"
[[ -f "$SRC/AppRun" && -f "$SRC/install-offline.sh" ]] || die "Offline AppImage source files are incomplete"
[[ -f "$ONLINE_SRC/huzaifah-triple-rice-installer.svg" ]] || die "Installer SVG icon is missing"
[[ -d "$ROOT/machine/sddm/themes/sddm-frieren-theme" ]] || die "Frieren SDDM theme assets are missing from the repository"
[[ -d "$END4_DOTS_SOURCE" ]] || die "end4-dots source not found at $END4_DOTS_SOURCE"
[[ -d "$END4_PC_SOURCE" ]] || die "end4-pC source not found at $END4_PC_SOURCE"
[[ -d "$AMBXST_SOURCE" ]] || die "Ambxst source not found at $AMBXST_SOURCE"
[[ -n "$AXCTL_SOURCE" && -x "$AXCTL_SOURCE" ]] || die "axctl binary not found; set AXCTL_SOURCE if necessary"

for cmd in python3 git curl rsync jq sha256sum find tar zstd repo-add; do
    command -v "$cmd" >/dev/null 2>&1 || die "$cmd is required"
done

mkdir -p "$BUILD" "$DIST"
extract_targets > "$TARGETS_FILE"
TARGET_COUNT="$(wc -l < "$TARGETS_FILE")"

printf '\nHuzaifah Triple-Rice OFFLINE Builder\n'
printf '=====================================\n'
printf 'Direct package targets (including SDDM): %s\n' "$TARGET_COUNT"
printf 'Output: %s\n\n' "$OUT"
printf 'This builder intentionally prepares the current machine first so the final\n'
printf 'AppImage cannot silently omit the packages that were missing in the size test.\n\n'

if (( ! SKIP_SYSTEM_UPDATE )); then
    log "Fully updating the build machine to avoid an Arch partial-upgrade package set"
    sudo pacman -Syu --needed --noconfirm base-devel git curl rsync jq zstd
else
    warn "System update skipped by request; the final package set is only as coherent as the current host"
    sudo pacman -S --needed --noconfirm base-devel git curl rsync jq zstd
fi

ensure_paru

mapfile -t TARGETS < "$TARGETS_FILE"
log "Installing any missing direct Multi-Rice targets on the build machine"

# HUZ_FIX_QUICKSHELL_PROVIDER:
# Never ask paru to resolve quickshell-git by package name here. Some repositories
# expose legacy noctalia-qs as a Quickshell provider, which can make paru choose it
# and conflict with the exact quickshell-git package already used by this setup.
if printf '%s
' "${TARGETS[@]}" | grep -Fxq quickshell-git; then
if pacman -Q quickshell-git >/dev/null 2>&1; then
log "Keeping installed quickshell-git as the exact Quickshell provider"
elif pacman -Q noctalia-qs >/dev/null 2>&1; then
die "Legacy noctalia-qs is installed instead of quickshell-git; refusing to alter the build host provider automatically"
else
die "quickshell-git is required but is not installed on the build host"
fi
fi

for target in "${TARGETS[@]}"; do
    [[ "$target" == "quickshell-git" ]] && continue
    if pacman -Q "$target" >/dev/null 2>&1; then
        continue
    fi
    log "Preparing direct target: $target"
    paru -S --needed --noconfirm --skipreview --sudoloop "$target"
done

log "Resolving exact installed dependency closure"
resolve_closure
split_closure
printf '  Initial closure: %s packages (%s official, %s foreign/AUR)\n' \
    "$(wc -l < "$CLOSURE_FILE")" "$(wc -l < "$BUILD/official.txt")" "$(wc -l < "$BUILD/foreign.txt")"

rebuild_aur_closure
ensure_foreign_archives
resolve_closure
split_closure
printf '  Final closure:   %s packages (%s official, %s foreign/AUR)\n' \
    "$(wc -l < "$CLOSURE_FILE")" "$(wc -l < "$BUILD/official.txt")" "$(wc -l < "$BUILD/foreign.txt")"

log "Preparing clean AppDir and package payload"
rm -rf "$APPDIR"
mkdir -p "$APPDIR" "$PAYLOAD" "$PKG_DIR" "$PAYLOAD/sources" "$PAYLOAD/bin"
chmod 0777 "$PKG_DIR"

mapfile -t OFFICIAL < "$BUILD/official.txt"
if ((${#OFFICIAL[@]})); then
    log "Downloading ${#OFFICIAL[@]} official package archives into the offline repository"
    sudo pacman -Sw --noconfirm --cachedir "$PKG_DIR" "${OFFICIAL[@]}"
fi
sudo chown -R "$USER":"$(id -gn)" "$PKG_DIR"
find "$PKG_DIR" -maxdepth 1 -type f -name '*.sig' -delete

log "Copying exact foreign/AUR package archives"
copy_foreign_archives

log "Validating that every package in the dependency closure has an archive"
validate_staged_packages
ok "Every dependency in the closure has a bundled package archive"

log "Creating embedded local pacman repository database"
rm -f "$PKG_DIR"/huzaifah-offline.db* "$PKG_DIR"/huzaifah-offline.files*
mapfile -d '' PACKAGE_ARCHIVES < <(find "$PKG_DIR" -maxdepth 1 -type f -name '*.pkg.tar.*' ! -name '*.sig' -print0 | sort -z)
((${#PACKAGE_ARCHIVES[@]})) || die "No package archives were staged"
repo-add -q "$PKG_DIR/huzaifah-offline.db.tar.gz" "${PACKAGE_ARCHIVES[@]}"

log "Bundling the current dotfiles working tree"
copy_tree "$ROOT" "$PAYLOAD/repo"

# HUZ_FIX_PAYLOAD_EXEC_BITS: git/archive copies may lose executable metadata.
log "Normalizing executable permissions in the bundled repository payload"
find "$PAYLOAD/repo" -type f -name '*.sh' -exec chmod 0755 {} +
if [[ -d "$PAYLOAD/repo/dual-rice/bin" ]]; then
    find "$PAYLOAD/repo/dual-rice/bin" -maxdepth 1 -type f -exec chmod 0755 {} +
fi
[[ -x "$PAYLOAD/repo/scripts/install-refresh-switcher.sh" ]] \
    || die "Bundled refresh switcher installer is not executable after staging"


log "Bundling current local rice source trees (including local patches)"
copy_tree "$END4_DOTS_SOURCE" "$PAYLOAD/sources/end4-dots"
copy_tree "$END4_PC_SOURCE" "$PAYLOAD/sources/end4-pC"
copy_tree "$AMBXST_SOURCE" "$PAYLOAD/sources/ambxst"
install -m 0755 "$AXCTL_SOURCE" "$PAYLOAD/bin/axctl"
cp "$TARGETS_FILE" "$PAYLOAD/targets.txt"
cp "$CLOSURE_FILE" "$PAYLOAD/closure.txt"

{
    printf 'format=1\n'
    printf 'built_at=%s\n' "$(date --iso-8601=seconds)"
    printf 'builder_host=%s\n' "$(hostname)"
    printf 'architecture=%s\n' "$(uname -m)"
    printf 'dotfiles_commit=%s\n' "$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"
    if git -C "$ROOT" diff --quiet --ignore-submodules HEAD -- 2>/dev/null && git -C "$ROOT" diff --cached --quiet --ignore-submodules HEAD -- 2>/dev/null; then
        printf 'dotfiles_worktree=clean\n'
    else
        printf 'dotfiles_worktree=dirty-working-tree-bundled\n'
    fi
    printf 'direct_targets=%s\n' "$(wc -l < "$TARGETS_FILE")"
    printf 'dependency_closure=%s\n' "$(wc -l < "$CLOSURE_FILE")"
    printf 'package_archives=%s\n' "${#PACKAGE_ARCHIVES[@]}"
    printf 'axctl_version=%s\n' "$("$AXCTL_SOURCE" --version 2>/dev/null | head -1 || echo unknown)"
} > "$PAYLOAD/manifest.txt"

log "Generating payload checksum manifest"
build_payload_checksums

log "Preparing AppImage launcher"
cp "$SRC/AppRun" "$APPDIR/AppRun"
cp "$SRC/install-offline.sh" "$APPDIR/install-offline.sh"
cp "$SRC/huzaifah-triple-rice-offline.desktop" "$APPDIR/"
cp "$ONLINE_SRC/huzaifah-triple-rice-installer.svg" "$APPDIR/huzaifah-triple-rice-offline.svg"
ln -s huzaifah-triple-rice-offline.svg "$APPDIR/.DirIcon"
chmod +x "$APPDIR/AppRun" "$APPDIR/install-offline.sh"
bash -n "$APPDIR/AppRun"
bash -n "$APPDIR/install-offline.sh"
python3 -m py_compile "$RESOLVER"

if [[ ! -x "$TOOL" ]]; then
    log "Downloading appimagetool"
    curl -fL --retry 3 \
        https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage \
        -o "$TOOL"
    chmod +x "$TOOL"
fi

log "Building the single-file offline AppImage (this is the CPU/disk-heavy part)"
rm -f "$OUT" "$OUT_SHA"
ARCH=x86_64 APPIMAGE_EXTRACT_AND_RUN=1 "$TOOL" "$APPDIR" "$OUT"
chmod +x "$OUT"
sha256sum "$OUT" > "$OUT_SHA"
APPIMAGE_EXTRACT_AND_RUN=1 "$OUT" --appimage-version >/dev/null

ok "Built the fully offline installer"
printf '\n'
ls -lh "$OUT" "$OUT_SHA"
printf '\nPackage closure: %s packages\n' "$(wc -l < "$CLOSURE_FILE")"
printf 'Bundled package archives: %s\n' "${#PACKAGE_ARCHIVES[@]}"
printf 'The resulting AppImage can install with networking disabled.\n'