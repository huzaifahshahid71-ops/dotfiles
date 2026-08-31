#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
WORK="$TMP/dotfiles"
DIST="$ROOT/dist"
OLD_OUT="$WORK/dist/Huzaifah-Triple-Rice-Offline-x86_64.AppImage"
NEW_OUT="$DIST/Huzaifah-Multi-Rice-OFFLINE-x86_64.AppImage"
NEW_SHA="$DIST/Huzaifah-Multi-Rice-OFFLINE-x86_64.sha256"

cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARNING:\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

[[ "$(uname -m)" == x86_64 ]] || die "This builder currently targets x86_64 only"
[[ -f "$ROOT/installer-appimage-offline/build.sh" ]] || die "Historical offline builder is missing"
[[ -f "$ROOT/installer-appimage-offline/multi-rice-offline.sh" ]] || die "Multi-Rice offline engine is missing"

for cmd in rsync python3 bash; do
    command -v "$cmd" >/dev/null 2>&1 || die "$cmd is required"
done

log "Preparing isolated Multi-Rice offline build tree"
mkdir -p "$WORK" "$DIST"
rsync -a \
    --exclude '.git/' \
    --exclude 'dist/' \
    --exclude 'installer-appimage-offline/.build/' \
    "$ROOT/" "$WORK/"

cp "$ROOT/installer-appimage-offline/AppRun" "$WORK/installer-appimage-offline/AppRun"
cp "$ROOT/installer-appimage-offline/multi-rice-offline.sh" "$WORK/installer-appimage-offline/install-offline.sh"
chmod +x "$WORK/installer-appimage-offline/AppRun" "$WORK/installer-appimage-offline/install-offline.sh"

python3 - "$WORK/scripts/restore-dual-rice.sh" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
needle = "    adw-gtk-theme inter-font ttf-fira-code\n"
addition = "    adw-gtk-theme inter-font ttf-fira-code \\" + "\n" + \
           "    sbctl refind efibootmgr asusctl rog-control-center supergfxctl btrfs-progs\n"
if needle not in s:
    raise SystemExit("Could not locate the final Multi-Rice package line in restore-dual-rice.sh")
p.write_text(s.replace(needle, addition, 1))
PY

python3 - "$WORK/installer-appimage-offline/build.sh" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
old = '''mapfile -t TARGETS < "$TARGETS_FILE"
log "Installing any missing direct triple-rice targets on the build machine"
paru -S --needed --noconfirm --skipreview --sudoloop "${TARGETS[@]}"
'''
new = '''mapfile -t TARGETS < "$TARGETS_FILE"

log "Preparing Quickshell-sensitive packages"
for pkg in quickshell-git dim-caelestia-shell-git caelestia-cli dms-shell dms-shell-hyprland; do
    if pacman -Q "$pkg" >/dev/null 2>&1; then
        printf '  %s already installed; keeping current working package\n' "$pkg"
        continue
    fi
    if [[ "$pkg" == quickshell-git ]] && pacman -Q noctalia-qs >/dev/null 2>&1; then
        die "quickshell-git is missing while noctalia-qs is installed; resolve that provider choice before building"
    fi
    if [[ "$pkg" == dms-shell || "$pkg" == dms-shell-hyprland ]]; then
        sudo pacman -S --needed --noconfirm "$pkg"
    else
        paru -S --needed --noconfirm --skipreview --sudoloop "$pkg"
    fi
done

FILTERED_TARGETS=()
for pkg in "${TARGETS[@]}"; do
    case "$pkg" in
        quickshell-git|dim-caelestia-shell-git|caelestia-cli|dms-shell|dms-shell-hyprland) ;;
        *) FILTERED_TARGETS+=("$pkg") ;;
    esac
done

log "Installing any remaining direct Multi-Rice targets on the build machine"
if ((${#FILTERED_TARGETS[@]})); then
    paru -S --needed --noconfirm --skipreview --sudoloop "${FILTERED_TARGETS[@]}"
fi
'''
if old not in s:
    raise SystemExit("Could not locate the direct-target installation block in build.sh")
s = s.replace(old, new, 1)

old_rebuild = '''rebuild_one_aur_package() {
    local pkg="$1"
    log "Rebuilding AUR package: $pkg"
    paru -S --rebuild=all --noconfirm --skipreview --nocheck --sudoloop "$pkg"
}
'''
new_rebuild = '''rebuild_one_aur_package() {
    local pkg="$1"
    log "Rebuilding AUR package: $pkg"

    # noctalia-qs is a repository package that provides `quickshell-git` and
    # conflicts with the real AUR quickshell-git package. Asking paru to install
    # quickshell-git can therefore make the resolver choose noctalia-qs instead.
    # For the offline image we only need a package archive, so build quickshell-git
    # from its PKGBUILD without installing/replacing the working provider.
    if [[ "$pkg" == "quickshell-git" ]]; then
        local tmp cache_dir built=0 file
        tmp="$(mktemp -d)"
        cache_dir="$HOME/.cache/paru/clone/quickshell-git"
        mkdir -p "$cache_dir"
        (
            cd "$tmp"
            paru -G quickshell-git
            cd quickshell-git
            makepkg -s --noconfirm --cleanbuild --clean --nocheck
        )
        while IFS= read -r -d '' file; do
            cp -f "$file" "$cache_dir/"
            built=1
        done < <(find "$tmp/quickshell-git" -maxdepth 1 -type f -name '*.pkg.tar.*' ! -name '*.sig' -print0)
        rm -rf "$tmp"
        (( built )) || die "quickshell-git PKGBUILD completed without producing a package archive"
        return 0
    fi

    paru -S --rebuild=all --noconfirm --skipreview --nocheck --sudoloop "$pkg"
}
'''
if old_rebuild not in s:
    raise SystemExit("Could not locate rebuild_one_aur_package in build.sh")
s = s.replace(old_rebuild, new_rebuild, 1)

old_ensure = '''ensure_foreign_archives() {
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
'''
new_ensure = '''ensure_foreign_archives() {
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

    # The old loop failed immediately after pass 3 without checking whether the
    # archives rebuilt during pass 3 now satisfy the closure. Perform one final
    # verification before declaring the closure unstable.
    resolve_closure
    split_closure
    local final_missing=()
    while IFS= read -r pkg; do
        [[ -n "$pkg" ]] || continue
        ver="$(package_version "$pkg")"
        if ! archive="$(find_exact_archive "$pkg" "$ver")"; then
            final_missing+=("$pkg")
        fi
    done < "$BUILD/foreign.txt"

    if ((${#final_missing[@]} == 0)); then
        return 0
    fi

    printf 'Foreign package archives still missing after final verification:\n' >&2
    printf '  %s\n' "${final_missing[@]}" >&2
    die "Foreign package closure is still incomplete after rebuild attempts"
}
'''
if old_ensure not in s:
    raise SystemExit("Could not locate ensure_foreign_archives in build.sh")
s = s.replace(old_ensure, new_ensure, 1)
p.write_text(s)
PY

cat > "$WORK/installer-appimage-offline/huzaifah-triple-rice-offline.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Huzaifah Multi-Rice OFFLINE
Comment=Offline Multi-Rice installer, ASUS/G16 tools, rEFInd and guided Secure Boot setup
Exec=AppRun
Icon=huzaifah-triple-rice-offline
Terminal=false
Categories=System;Settings;
StartupNotify=true
EOF

log "Syntax-checking the Multi-Rice launcher and engine"
bash -n "$WORK/installer-appimage-offline/AppRun"
bash -n "$WORK/installer-appimage-offline/install-offline.sh"
bash -n "$WORK/installer-appimage-offline/build.sh"

log "Running the proven dependency-closure offline builder"
(
    cd "$WORK"
    bash installer-appimage-offline/build.sh "$@"
)

[[ -f "$OLD_OUT" ]] || die "Underlying builder completed without producing the expected AppImage"

log "Publishing Multi-Rice offline artifact"
rm -f "$NEW_OUT" "$NEW_SHA"
mv "$OLD_OUT" "$NEW_OUT"
chmod +x "$NEW_OUT"
sha256sum "$NEW_OUT" > "$NEW_SHA"

printf '\nBuilt:\n'
ls -lh "$NEW_OUT" "$NEW_SHA"
printf '\nThis AppImage contains:\n'
printf '  ✦ Caelestia\n  ◈ end4-pC\n  ◆ Ambxst\n  ● DankMaterialShell\n'
printf '  ⇄ Multi-Rice switcher\n  ↻ hardware-aware refresh switcher\n'
printf '  🌙 Frieren SDDM theme\n  ◇ ASUS / Zephyrus G16 setup tools\n'
printf '  ◇ rEFInd configuration\n  ◇ guided sbctl Secure Boot setup\n'
printf '  ◇ guarded Btrfs hibernation storage setup\n'
printf '\nInstallation/runtime network requirement: none.\n'
