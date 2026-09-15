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
OUT="$DIST/Huzaifah-Multi-Rice-OFFLINE-v5.0.0-x86_64.AppImage"
OUT_SHA="$DIST/Huzaifah-Multi-Rice-OFFLINE-v5.0.0-x86_64.sha256"
TARGETS_FILE="$BUILD/targets.txt"
CLOSURE_FILE="$BUILD/closure.txt"

END4_DOTS_SOURCE="${END4_DOTS_SOURCE:-$HOME/.local/src/end4-dots}"
END4_PC_REPO_URL="${END4_PC_REPO_URL:-https://github.com/pctrade/end4-pC.git}"
END4_PC_SOURCE="${END4_PC_SOURCE:-$BUILD/end4-pC-upstream}"
END4_PC_EXPECTED_COMMIT="51a1347612a9b92971ee6845bb583067a1ce5eb7"
END4_PC_PATCH_FILE="$ROOT/dual-rice/versions/end4-pC-local.patch"
END4_PC_STAGE="$BUILD/end4-pC-source"
MPV_MPRIS_REPO_URL="${MPV_MPRIS_REPO_URL:-https://github.com/hoyon/mpv-mpris.git}"
MPV_MPRIS_SOURCE="${MPV_MPRIS_SOURCE:-$BUILD/mpv-mpris-upstream}"
MPV_MPRIS_COMMIT_FILE="$ROOT/dual-rice/versions/mpv-mpris-upstream-commit.txt"
MPV_MPRIS_PATCH_FILE="$ROOT/dual-rice/versions/mpv-mpris-embedded-art-file-url.patch"
MPV_MPRIS_STAGE="$BUILD/mpv-mpris-source"
AMBXST_SOURCE="${AMBXST_SOURCE:-$HOME/.local/src/ambxst}"
SERPANTINUM_REPO_URL="${SERPANTINUM_REPO_URL:-https://github.com/ilyamiro/serpantinum.git}"
SERPANTINUM_SOURCE="${SERPANTINUM_SOURCE:-$BUILD/serpantinum-upstream}"
SERPANTINUM_COMMIT_FILE="$ROOT/dual-rice/versions/serpantinum.commit"
SERPANTINUM_TARGETS_FILE="$SRC/serpantinum-targets.txt"
SERPANTINUM_PATCH_FILE="$ROOT/dual-rice/versions/serpantinum-local.patch"
SERPANTINUM_STAGE="$BUILD/serpantinum-source"
EVANGELION_REPO_URL="${EVANGELION_REPO_URL:-https://github.com/Aleph1-9012/Evangelion.git}"
EVANGELION_SOURCE="${EVANGELION_SOURCE:-$BUILD/evangelion-upstream}"
EVANGELION_COMMIT_FILE="$ROOT/dual-rice/versions/evangelion.commit"
EVANGELION_PATCH_FILE="$ROOT/dual-rice/patches/evangelion-silent.patch"
EVANGELION_STAGE="$BUILD/evangelion-source"

AXCTL_SOURCE="${AXCTL_SOURCE:-$(command -v axctl 2>/dev/null || true)}"
SKIP_SYSTEM_UPDATE=0

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARNING:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
    cat <<'EOF'
Build the complete no-internet Huzaifah Multi-Rice v5.0.0 AppImage.

Usage:
  bash installer-appimage-offline/build.sh [--skip-system-update]

Default builder behaviour:
  1. Fully updates the Arch/CachyOS build machine.
  2. Installs any direct Multi-Rice packages missing from the build machine.
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

    # Fast path: prefer an exact package/version archive by filename.
    # This is important for locally-built/foreign packages that are installed
    # correctly but are temporarily unavailable through paru/AUR metadata.
    for root in "${roots[@]}"; do
        [[ -d "$root" ]] || continue
        while IFS= read -r -d "" file; do
            [[ "$file" == *.sig ]] && continue
            meta="$(archive_meta "$file")"
            [[ -n "$meta" ]] || continue
            name="${meta%% *}"
            version="${meta#* }"
            if [[ "$name" == "$pkg" && "$version" == "$ver" ]]; then
                printf "%s
" "$file"
                return 0
            fi
        done < <(find "$root" -type f -name "${pkg}-${ver}-*.pkg.tar.*" -print0 2>/dev/null)
    done

    # Fallback for unusual archive filenames.
    for root in "${roots[@]}"; do
        [[ -d "$root" ]] || continue
        while IFS= read -r -d "" file; do
            [[ "$file" == *.sig ]] && continue
            meta="$(archive_meta "$file")"
            [[ -n "$meta" ]] || continue
            name="${meta%% *}"
            version="${meta#* }"
            if [[ "$name" == "$pkg" && "$version" == "$ver" ]]; then
                printf "%s
" "$file"
                return 0
            fi
        done < <(find "$root" -type f -name "*.pkg.tar.*" -print0 2>/dev/null)
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
[[ -f "$END4_PC_PATCH_FILE" ]] || die "end4-pC local patch not found at $END4_PC_PATCH_FILE"

mkdir -p "$BUILD"

if [[ ! -d "$END4_PC_SOURCE/.git" ]]; then
    log "Cloning upstream end4-pC source for reproducible build"
    rm -rf "$END4_PC_SOURCE"
    git clone "$END4_PC_REPO_URL" "$END4_PC_SOURCE" ||
        die "Failed to clone upstream end4-pC source"
else
    git -C "$END4_PC_SOURCE" remote set-url origin "$END4_PC_REPO_URL"
fi

if ! git -C "$END4_PC_SOURCE" cat-file -e "${END4_PC_EXPECTED_COMMIT}^{commit}" 2>/dev/null; then
    log "Fetching pinned end4-pC commit"
    git -C "$END4_PC_SOURCE" fetch origin "$END4_PC_EXPECTED_COMMIT" ||
        die "Failed to fetch pinned end4-pC commit"
fi

git -C "$END4_PC_SOURCE" cat-file -e "${END4_PC_EXPECTED_COMMIT}^{commit}" ||
    die "Pinned end4-pC commit is unavailable"

[[ -f "$MPV_MPRIS_COMMIT_FILE" ]] || die "mpv-mpris upstream commit file is missing"
[[ -f "$MPV_MPRIS_PATCH_FILE" ]] || die "mpv-mpris artwork patch is missing"
MPV_MPRIS_EXPECTED_COMMIT="$(tr -d "[:space:]" < "$MPV_MPRIS_COMMIT_FILE")"
[[ "$MPV_MPRIS_EXPECTED_COMMIT" =~ ^[0-9a-f]{40}$ ]] || die "Invalid mpv-mpris pinned commit: $MPV_MPRIS_EXPECTED_COMMIT"

if [[ ! -d "$MPV_MPRIS_SOURCE/.git" ]]; then
    log "Cloning upstream mpv-mpris source for reproducible build"
    rm -rf "$MPV_MPRIS_SOURCE"
    git clone "$MPV_MPRIS_REPO_URL" "$MPV_MPRIS_SOURCE" || die "Failed to clone upstream mpv-mpris source"
else
    git -C "$MPV_MPRIS_SOURCE" remote set-url origin "$MPV_MPRIS_REPO_URL"
fi

if ! git -C "$MPV_MPRIS_SOURCE" cat-file -e "${MPV_MPRIS_EXPECTED_COMMIT}^{commit}" 2>/dev/null; then
    log "Fetching pinned mpv-mpris commit"
    git -C "$MPV_MPRIS_SOURCE" fetch origin "$MPV_MPRIS_EXPECTED_COMMIT" || die "Failed to fetch pinned mpv-mpris commit"
fi

git -C "$MPV_MPRIS_SOURCE" cat-file -e "${MPV_MPRIS_EXPECTED_COMMIT}^{commit}" || die "Pinned mpv-mpris commit is unavailable"
[[ -d "$AMBXST_SOURCE" ]] || die "Ambxst source not found at $AMBXST_SOURCE"
[[ -f "$SERPANTINUM_COMMIT_FILE" ]] || die "Serpantinum upstream commit file is missing"
[[ -f "$SERPANTINUM_TARGETS_FILE" ]] || die "Serpantinum target list not found at $SERPANTINUM_TARGETS_FILE"
[[ -f "$SERPANTINUM_PATCH_FILE" ]] || die "Serpantinum local patch not found at $SERPANTINUM_PATCH_FILE"

SERPANTINUM_EXPECTED_COMMIT="$(tr -d "[:space:]" < "$SERPANTINUM_COMMIT_FILE")"
[[ "$SERPANTINUM_EXPECTED_COMMIT" =~ ^[0-9a-f]{40}$ ]] || die "Invalid Serpantinum pinned commit: $SERPANTINUM_EXPECTED_COMMIT"

if [[ ! -d "$SERPANTINUM_SOURCE/.git" ]]; then
    log "Cloning upstream Serpantinum source for reproducible build"
    rm -rf "$SERPANTINUM_SOURCE"
    git clone "$SERPANTINUM_REPO_URL" "$SERPANTINUM_SOURCE" || die "Failed to clone upstream Serpantinum source"
else
    git -C "$SERPANTINUM_SOURCE" remote set-url origin "$SERPANTINUM_REPO_URL"
fi

if ! git -C "$SERPANTINUM_SOURCE" cat-file -e "${SERPANTINUM_EXPECTED_COMMIT}^{commit}" 2>/dev/null; then
    log "Fetching pinned Serpantinum commit"
    git -C "$SERPANTINUM_SOURCE" fetch origin "$SERPANTINUM_EXPECTED_COMMIT" || die "Failed to fetch pinned Serpantinum commit"
fi

git -C "$SERPANTINUM_SOURCE" cat-file -e "${SERPANTINUM_EXPECTED_COMMIT}^{commit}" || die "Pinned Serpantinum commit is unavailable"
[[ -f "$EVANGELION_COMMIT_FILE" ]] || die "Evangelion commit pin is missing"
[[ -f "$EVANGELION_PATCH_FILE" ]] || die "Evangelion silent patch is missing"

EVANGELION_EXPECTED_COMMIT="$(tr -d "[:space:]" < "$EVANGELION_COMMIT_FILE")"
[[ "$EVANGELION_EXPECTED_COMMIT" =~ ^[0-9a-f]{40}$ ]] ||
    die "Invalid Evangelion commit pin: $EVANGELION_EXPECTED_COMMIT"

if [[ ! -d "$EVANGELION_SOURCE/.git" ]]; then
    log "Cloning pinned Evangelion source"
    rm -rf "$EVANGELION_SOURCE"
    git clone "$EVANGELION_REPO_URL" "$EVANGELION_SOURCE" ||
        die "Failed to clone Evangelion"
else
    git -C "$EVANGELION_SOURCE" remote set-url origin "$EVANGELION_REPO_URL"
fi

if ! git -C "$EVANGELION_SOURCE" cat-file -e "${EVANGELION_EXPECTED_COMMIT}^{commit}" 2>/dev/null; then
    log "Fetching pinned Evangelion commit"
    git -C "$EVANGELION_SOURCE" fetch origin "$EVANGELION_EXPECTED_COMMIT" ||
        die "Failed to fetch pinned Evangelion commit"
fi

git -C "$EVANGELION_SOURCE" cat-file -e "${EVANGELION_EXPECTED_COMMIT}^{commit}" ||
    die "Pinned Evangelion commit is unavailable"

rm -rf "$EVANGELION_STAGE"
mkdir -p "$EVANGELION_STAGE"

git -C "$EVANGELION_SOURCE" archive "$EVANGELION_EXPECTED_COMMIT" |
    tar -x -C "$EVANGELION_STAGE"

patch --dry-run --batch --forward --fuzz=0     -d "$EVANGELION_STAGE" -p1     < "$EVANGELION_PATCH_FILE" ||
    die "Evangelion silent patch does not apply cleanly"

patch --batch --forward --fuzz=0     -d "$EVANGELION_STAGE" -p1     < "$EVANGELION_PATCH_FILE" ||
    die "Failed to apply Evangelion silent patch"

grep -Fq "result = source" "$EVANGELION_STAGE/bin/boot-console.awk" ||
    die "Silent-boot Evangelion patch verification failed"

[[ -x "$EVANGELION_STAGE/install.sh" ]] ||
    die "Evangelion installer is missing"

[[ -x "$EVANGELION_STAGE/bin/eva" ]] ||
    die "Evangelion manager is missing"

ok "Pinned silent Evangelion source prepared"

[[ -n "$AXCTL_SOURCE" && -x "$AXCTL_SOURCE" ]] || die "axctl binary not found; set AXCTL_SOURCE if necessary"

for cmd in python3 git curl rsync jq sha256sum find tar zstd repo-add patch; do
    command -v "$cmd" >/dev/null 2>&1 || die "$cmd is required"
done

mkdir -p "$BUILD" "$DIST"
extract_targets > "$TARGETS_FILE"
cat "$SERPANTINUM_TARGETS_FILE" >> "$TARGETS_FILE"
sort -u -o "$TARGETS_FILE" "$TARGETS_FILE"
TARGET_COUNT="$(wc -l < "$TARGETS_FILE")"

printf '\nHuzaifah Multi-Rice v5.0.0 OFFLINE Builder\n'
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
' "${TARGETS[@]}" | grep -Fx quickshell-git >/dev/null; then
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

# HUZ_V4_VALIDATE_LITERAL_QUICKSHELL
# A provider such as noctalia-qs is NOT sufficient here. Rollback-safe
# offline migration requires an actual package named quickshell-git.
log "Validating literal quickshell-git in the offline repository"

QUICKSHELL_ARCHIVE=""
for archive in "${PACKAGE_ARCHIVES[@]}"; do
    pkg_name="$(LC_ALL=C pacman -Qp "$archive" 2>/dev/null | awk '{print $1}' || true)"
    if [[ "$pkg_name" == "quickshell-git" ]]; then
        QUICKSHELL_ARCHIVE="$archive"
        break
    fi
done

[[ -n "$QUICKSHELL_ARCHIVE" ]]     || die "Offline payload has no literal quickshell-git package archive"

tar -xOzf "$PKG_DIR/huzaifah-offline.db.tar.gz" --wildcards "*/desc" 2>/dev/null     | awk '$0 == "%NAME%" { getline; print }'     | grep -Fx quickshell-git >/dev/null     || die "Embedded pacman repository database has no literal quickshell-git entry"

ok "Literal quickshell-git archive and repository entry verified"

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


log "Preparing reproducible end4-pC source"
rm -rf "$END4_PC_STAGE"
mkdir -p "$END4_PC_STAGE"

git -C "$END4_PC_SOURCE" archive "$END4_PC_EXPECTED_COMMIT" | tar -x -C "$END4_PC_STAGE"

patch --dry-run --batch --forward --fuzz=0     -d "$END4_PC_STAGE" -p1     < "$END4_PC_PATCH_FILE"     || die "end4-pC local patch does not apply cleanly to pinned source"

patch --batch --forward --fuzz=0     -d "$END4_PC_STAGE" -p1     < "$END4_PC_PATCH_FILE"     || die "Failed to apply end4-pC local patch to pinned source"

log "Building reproducible patched mpv-mpris artwork module"
rm -rf "$MPV_MPRIS_STAGE"
mkdir -p "$MPV_MPRIS_STAGE"

git -C "$MPV_MPRIS_SOURCE" archive "$MPV_MPRIS_EXPECTED_COMMIT" | tar -x -C "$MPV_MPRIS_STAGE"

patch --dry-run --batch --forward --fuzz=0     -d "$MPV_MPRIS_STAGE" -p1     < "$MPV_MPRIS_PATCH_FILE"     || die "mpv-mpris artwork patch does not apply cleanly to pinned source"

patch --batch --forward --fuzz=0     -d "$MPV_MPRIS_STAGE" -p1     < "$MPV_MPRIS_PATCH_FILE"     || die "Failed to apply mpv-mpris artwork patch"

(
    cd "$MPV_MPRIS_STAGE"
    make -j"$(nproc)" || die "Failed to build patched mpv-mpris module"
)

[[ -f "$MPV_MPRIS_STAGE/mpris.so" ]] || die "Patched mpv-mpris build did not produce mpris.so"
if ldd "$MPV_MPRIS_STAGE/mpris.so" | grep -q "not found"; then
    ldd "$MPV_MPRIS_STAGE/mpris.so" >&2
    die "Patched mpv-mpris module has unresolved libraries"
fi

install -m 0755 "$MPV_MPRIS_STAGE/mpris.so" "$PAYLOAD/bin/mpv-mpris-huzaifah.so"
ok "Patched mpv-mpris module built and bundled"

log "Preparing reproducible Serpantinum 2.1.6 source"
rm -rf "$SERPANTINUM_STAGE"
mkdir -p "$SERPANTINUM_STAGE"

git -C "$SERPANTINUM_SOURCE" archive "$SERPANTINUM_EXPECTED_COMMIT"     | tar -x -C "$SERPANTINUM_STAGE"

patch --dry-run --batch --forward --fuzz=0     -d "$SERPANTINUM_STAGE" -p1     < "$SERPANTINUM_PATCH_FILE"     || die "Serpantinum local patch does not apply cleanly to pinned source"

patch --batch --forward --fuzz=0     -d "$SERPANTINUM_STAGE" -p1     < "$SERPANTINUM_PATCH_FILE"     || die "Failed to apply Serpantinum local patch to pinned source"

[[ "$(cat "$SERPANTINUM_STAGE/version.txt")" == "2.1.6" ]]     || die "Staged Serpantinum source is not version 2.1.6"

log "Bundling current local rice source trees (including local patches)"
copy_tree "$END4_DOTS_SOURCE" "$PAYLOAD/sources/end4-dots"
copy_tree "$END4_PC_STAGE" "$PAYLOAD/sources/end4-pC"
copy_tree "$AMBXST_SOURCE" "$PAYLOAD/sources/ambxst"
copy_tree "$SERPANTINUM_STAGE" "$PAYLOAD/sources/serpantinum"
copy_tree "$EVANGELION_STAGE" "$PAYLOAD/sources/evangelion"
install -m 0755 "$AXCTL_SOURCE" "$PAYLOAD/bin/axctl"
cp "$TARGETS_FILE" "$PAYLOAD/targets.txt"
cp "$CLOSURE_FILE" "$PAYLOAD/closure.txt"

{
    printf 'format=1\n'
    printf 'built_at=%s\n' "$(date --iso-8601=seconds)"
    printf 'builder_host=%s\n' "$(hostname)"
    printf 'architecture=%s\n' "$(uname -m)"
    printf 'dotfiles_commit=%s\n' "$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"
    printf 'end4_pc_commit=%s\n' "$END4_PC_EXPECTED_COMMIT"
printf 'end4_pc_patch_sha256=%s\n' "$(sha256sum "$END4_PC_PATCH_FILE" | awk '{print $1}')"
printf "mpv_mpris_commit=%s\n" "$MPV_MPRIS_EXPECTED_COMMIT"
printf "mpv_mpris_patch_sha256=%s\n" "$(sha256sum "$MPV_MPRIS_PATCH_FILE" | cut -d" " -f1)"
printf "mpv_mpris_module_sha256=%s\n" "$(sha256sum "$PAYLOAD/bin/mpv-mpris-huzaifah.so" | cut -d" " -f1)"
printf 'serpantinum_commit=%s\n' "$SERPANTINUM_EXPECTED_COMMIT"
printf 'serpantinum_patch_sha256=%s\n' "$(sha256sum "$SERPANTINUM_PATCH_FILE" | awk '{print $1}')"
    printf 'evangelion_commit=%s\n' "$EVANGELION_EXPECTED_COMMIT"
    printf 'evangelion_patch_sha256=%s\n' "$(sha256sum "$EVANGELION_PATCH_FILE" | awk '{print $1}')"
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
