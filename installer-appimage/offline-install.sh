#!/usr/bin/env bash
set -euo pipefail

PAYLOAD_ROOT="${1:-}"
[[ -n "$PAYLOAD_ROOT" ]] || { echo "ERROR: payload root not supplied" >&2; exit 2; }
PKGDIR="$PAYLOAD_ROOT/packages"
REPO="$PAYLOAD_ROOT/repo"
SOURCES="$PAYLOAD_ROOT/sources"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARNING:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

is_arch_family() {
    [[ -r /etc/os-release ]] || return 1
    . /etc/os-release
    [[ "${ID:-}" == "arch" || "${ID:-}" == "cachyos" || "${ID_LIKE:-}" == *arch* ]]
}

is_arch_family || die "This offline installer supports Arch/CachyOS-family systems only"
[[ "$(uname -m)" == "x86_64" ]] || die "This offline build targets x86_64 only"
command -v pacman >/dev/null 2>&1 || die "pacman is required"
[[ -d "$PKGDIR" ]] || die "Bundled package repository is missing"
[[ -x "$REPO/scripts/restore-triple-rice-offline.sh" || -f "$REPO/scripts/restore-triple-rice-offline.sh" ]] || die "Bundled offline restore script is missing"

mapfile -t packages < <(find "$PKGDIR" -maxdepth 1 -type f -name '*.pkg.tar.*' ! -name '*.sig' -print | sort)
((${#packages[@]})) || die "No bundled Arch package archives were found"

printf '\nHuzaifah Triple-Rice OFFLINE Installer\n'
printf '======================================\n'
printf 'Package archives: %d\n' "${#packages[@]}"
printf 'Network required: NO\n\n'

log "Validating bundled package archives"
for pkg in "${packages[@]}"; do
    pacman -Qp "$pkg" >/dev/null || die "Invalid package archive: $(basename "$pkg")"
done

log "Installing the complete bundled dependency snapshot"
printf 'This may install or downgrade packages to the versions bundled with this offline snapshot.\n'
printf 'That keeps Qt/Quickshell/Hyprland dependencies mutually compatible.\n\n'
sudo -v
sudo pacman -U --needed --noconfirm "${packages[@]}"

log "Restoring the three desktop profiles from bundled sources"
OFFLINE_REPO_ROOT="$REPO" OFFLINE_SOURCE_ROOT="$SOURCES" bash "$REPO/scripts/restore-triple-rice-offline.sh"

log "Installing bundled Frieren SDDM login theme"
theme_src="$REPO/machine/sddm/themes/sddm-frieren-theme"
theme_dst="/usr/share/sddm/themes/sddm-frieren-theme"
if [[ -d "$theme_src" ]]; then
    stamp="$(date +%Y%m%d-%H%M%S)"
    backup="/var/backups/huzaifah-dotfiles/sddm-theme/$stamp"
    sudo mkdir -p "$backup"
    sudo test -d "$theme_dst" && sudo cp -a "$theme_dst" "$backup/sddm-frieren-theme" || true
    sudo rm -rf "$theme_dst"
    sudo cp -a "$theme_src" "$theme_dst"
    sudo chown -R root:root "$theme_dst"
    sudo mkdir -p /etc/sddm.conf.d
    sudo test -f /etc/sddm.conf.d/90-huzaifah-theme.conf && sudo cp -a /etc/sddm.conf.d/90-huzaifah-theme.conf "$backup/90-huzaifah-theme.conf" || true
    printf '[Theme]\nCurrent=sddm-frieren-theme\n' | sudo tee /etc/sddm.conf.d/90-huzaifah-theme.conf >/dev/null
    ok "Frieren SDDM theme installed (display manager/autologin unchanged)"
else
    warn "Frieren SDDM theme snapshot was not present; skipping theme copy"
fi

ok "FULL OFFLINE installation complete"
printf '\nInstalled:\n'
printf '  ✦ Caelestia\n  ◈ end4-pC\n  ◆ Ambxst + axctl\n  🌙 Frieren SDDM theme\n  ⇄ SUPER + SHIFT + D switcher\n'
printf '\nNo files were fetched from the internet during this installation.\n'
printf 'Desktop wallpaper was left unchanged.\n'
printf 'Log out and back into Hyprland when ready.\n'
