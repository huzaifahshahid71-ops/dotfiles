#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${DOTFILES_REPO_URL:-https://github.com/huzaifahshahid71-ops/dotfiles.git}"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
SCRIPT_NAME="$(basename "$0")"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARNING:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

is_arch_family() {
    [[ -r /etc/os-release ]] || return 1
    . /etc/os-release
    [[ "${ID:-}" == "arch" || "${ID:-}" == "cachyos" || "${ID_LIKE:-}" == *arch* ]]
}

prompt_yes_no() {
    local prompt="$1" default="${2:-n}" ans
    if [[ ! -r /dev/tty ]]; then
        [[ "$default" == "y" ]]
        return
    fi
    if [[ "$default" == "y" ]]; then
        read -r -p "$prompt [Y/n] " ans < /dev/tty || true
        ans="${ans:-y}"
    else
        read -r -p "$prompt [y/N] " ans < /dev/tty || true
        ans="${ans:-n}"
    fi
    [[ "$ans" =~ ^[Yy]$ ]]
}

ensure_repo() {
    if [[ -d "$DOTFILES_DIR/.git" ]]; then
        log "Updating $DOTFILES_DIR"
        git -C "$DOTFILES_DIR" pull --ff-only
    else
        command -v git >/dev/null 2>&1 || {
            is_arch_family || die "Git is required. Install it first."
            sudo pacman -S --needed git
        }
        log "Cloning dotfiles"
        git clone "$REPO_URL" "$DOTFILES_DIR"
    fi

    # If this is the curl-piped copy, hand off to the repository copy so all
    # hardware/profile files are available.
    local self_real repo_real
    self_real="$(readlink -f "$0" 2>/dev/null || true)"
    repo_real="$(readlink -f "$DOTFILES_DIR/install.sh" 2>/dev/null || true)"
    if [[ -n "$repo_real" && "$self_real" != "$repo_real" ]]; then
        exec "$DOTFILES_DIR/install.sh" "$@"
    fi
}

install_repo_pkg() {
    local pkg
    for pkg in "$@"; do
        if pacman -Q "$pkg" >/dev/null 2>&1; then
            continue
        fi
        if pacman -Si "$pkg" >/dev/null 2>&1; then
            sudo pacman -S --needed "$pkg"
        else
            return 1
        fi
    done
}

ensure_aur_helper() {
    if command -v paru >/dev/null 2>&1; then
        printf '%s\n' "paru"
        return
    fi
    if command -v yay >/dev/null 2>&1; then
        printf '%s\n' "yay"
        return
    fi

    log "Installing paru for AUR packages"
    sudo pacman -S --needed base-devel git
    local tmp
    tmp="$(mktemp -d)"
    git clone https://aur.archlinux.org/paru.git "$tmp/paru"
    (
        cd "$tmp/paru"
        makepkg -si --needed --noconfirm
    )
    rm -rf "$tmp"
    printf '%s\n' "paru"
}

install_flexible_pkg() {
    local pkg="$1"
    if pacman -Q "$pkg" >/dev/null 2>&1; then
        return
    fi
    if pacman -Si "$pkg" >/dev/null 2>&1; then
        sudo pacman -S --needed "$pkg"
        return
    fi
    local aur
    aur="$(ensure_aur_helper)"
    "$aur" -S --needed "$pkg"
}

backup_stow_conflicts() {
    local pkg="$1" src="$DOTFILES_DIR/$pkg" stamp backup rel dst
    [[ -d "$src" ]] || return 0

    stamp="${DOTFILES_BACKUP_STAMP:-$(date +%Y%m%d-%H%M%S)}"
    DOTFILES_BACKUP_STAMP="$stamp"
    export DOTFILES_BACKUP_STAMP
    backup="$HOME/dotfiles-backup/$stamp"

    while IFS= read -r -d '' file; do
        rel="${file#"$src/"}"
        dst="$HOME/$rel"
        if [[ -e "$dst" && ! -L "$dst" ]]; then
            mkdir -p "$backup/$(dirname "$rel")"
            mv "$dst" "$backup/$rel"
            log "Backed up $dst"
        fi
    done < <(find "$src" -type f -print0)
}

base_install() {
    is_arch_family || die "This installer currently supports Arch/CachyOS only."

    log "Installing base packages"
    local p
    for p in git stow rsync curl jq fish hyprland mpv playerctl brightnessctl hyprsunset; do
        if pacman -Si "$p" >/dev/null 2>&1; then
            sudo pacman -S --needed "$p"
        else
            warn "Package '$p' is not in enabled pacman repositories; skipping."
        fi
    done

    # DiM Caelestia remains the daily shell. Keep it separate from archived
    # development shell experiments.
    install_flexible_pkg dim-caelestia-shell-git || warn "Could not install dim-caelestia-shell-git."
    install_flexible_pkg caelestia-cli || warn "Could not install caelestia-cli."

    log "Applying GNU Stow packages"
    local pkg
    for pkg in caelestia fish hypr mpv scripts systemd; do
        [[ -d "$DOTFILES_DIR/$pkg" ]] || continue
        backup_stow_conflicts "$pkg"
        stow -d "$DOTFILES_DIR" -t "$HOME" --restow "$pkg"
    done

    systemctl --user daemon-reload 2>/dev/null || true
    log "Base dotfiles installed."
}

usage() {
    cat <<'EOF'
Usage: ./install.sh [options]

No options:
  Interactive installer. Base dotfiles are always installed first.

Options:
  --base          Base CachyOS/Arch + Hyprland + DiM Caelestia dotfiles
  --asus          ASUS laptop support (asusctl + ROG Control Center)
  --g16           Zephyrus G16 profile; implies --asus
  --refind        rEFInd install/restore/customization
  --refresh       Enable the existing 120/240 Hz AC/battery refresh service
  --hibernate     Configure the existing Btrfs 20G hibernation swap setup
  --all           Base + detected ASUS/G16 + rEFInd + refresh + hibernate
  --status        Print system/dotfiles hardware status
  --help          Show this help

Examples:
  ./install.sh --base
  ./install.sh --asus
  ./install.sh --g16 --refind
  ./install.sh --all
EOF
}

main() {
    ensure_repo "$@"
    is_arch_family || die "This installer currently supports Arch/CachyOS only."

    local do_asus=0 do_g16=0 do_refind=0 do_refresh=0 do_hibernate=0 do_status=0
    local explicit=0

    while (($#)); do
        case "$1" in
            --base) explicit=1 ;;
            --asus) do_asus=1; explicit=1 ;;
            --g16) do_g16=1; do_asus=1; explicit=1 ;;
            --refind) do_refind=1; explicit=1 ;;
            --refresh) do_refresh=1; explicit=1 ;;
            --hibernate) do_hibernate=1; explicit=1 ;;
            --status) do_status=1; explicit=1 ;;
            --all)
                do_asus=1; do_refind=1; do_refresh=1; do_hibernate=1; explicit=1
                if grep -Eqi 'GU60[35]|Zephyrus G16' /sys/class/dmi/id/product_name 2>/dev/null; then
                    do_g16=1
                fi
                ;;
            --help|-h) usage; exit 0 ;;
            *) die "Unknown option: $1" ;;
        esac
        shift
    done

    base_install

    if (( explicit == 0 )); then
        local vendor product
        vendor="$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || true)"
        product="$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)"

        if [[ "$vendor" == *ASUS* || "$vendor" == *ASUSTeK* ]]; then
            prompt_yes_no "ASUS laptop detected ($product). Install ASUS support?" y && do_asus=1
        fi
        if [[ "$product" =~ GU60[35] || "$product" == *"Zephyrus G16"* ]]; then
            prompt_yes_no "Zephyrus G16-like model detected. Enable G16 extras?" y && { do_g16=1; do_asus=1; }
        fi
        prompt_yes_no "Configure rEFInd from the saved profile?" n && do_refind=1
        prompt_yes_no "Enable 120/240 Hz AC/battery refresh automation?" n && do_refresh=1
        prompt_yes_no "Configure the 20G Btrfs hibernation swap setup?" n && do_hibernate=1
    fi

    (( do_asus )) && "$DOTFILES_DIR/system-setup.sh" asus
    (( do_g16 )) && "$DOTFILES_DIR/system-setup.sh" g16
    (( do_refind )) && "$DOTFILES_DIR/system-setup.sh" refind
    (( do_refresh )) && "$DOTFILES_DIR/system-setup.sh" refresh
    (( do_hibernate )) && "$DOTFILES_DIR/system-setup.sh" hibernate
    (( do_status )) && "$DOTFILES_DIR/system-setup.sh" status

    log "Done."
}

main "$@"
