#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${DOTFILES_REPO_URL:-https://github.com/huzaifahshahid71-ops/dotfiles.git}"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARNING:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

is_arch_family() {
    [[ -r /etc/os-release ]] || return 1
    . /etc/os-release
    [[ "${ID:-}" == "arch" || "${ID:-}" == "cachyos" || "${ID_LIKE:-}" == *arch* ]]
}

ensure_repo() {
    if [[ -d "$DOTFILES_DIR/.git" ]]; then
        log "Updating $DOTFILES_DIR"
        git -C "$DOTFILES_DIR" pull --ff-only
    else
        if ! command -v git >/dev/null 2>&1; then
            is_arch_family || die "Git is required. Install it first."
            sudo pacman -S --needed git
        fi
        log "Cloning dotfiles"
        git clone "$REPO_URL" "$DOTFILES_DIR"
    fi

    # When install.sh is curl-piped, hand execution to the checked-out copy so
    # the rest of the repository is available locally.
    local self_real repo_real
    self_real="$(readlink -f "$0" 2>/dev/null || true)"
    repo_real="$(readlink -f "$DOTFILES_DIR/install.sh" 2>/dev/null || true)"
    if [[ -n "$repo_real" && "$self_real" != "$repo_real" ]]; then
        exec "$DOTFILES_DIR/install.sh" "$@"
    fi
}

install_dual_rice() {
    local restore="$DOTFILES_DIR/scripts/restore-dual-rice.sh"
    [[ -f "$restore" ]] || die "Missing dual-rice restore script: $restore"
    chmod +x "$restore"

    printf '\n'
    log "Installing Huzaifah dual-rice desktop"
    printf '  ✦ Caelestia\n'
    printf '  ◈ end4-pC\n'
    printf '  ⇄ SUPER + SHIFT + D profile switcher\n'
    printf '  🖼 Frieren desktop wallpaper\n\n'

    "$restore"
}

install_frieren_sddm_theme() {
    local setup="$DOTFILES_DIR/system-setup.sh"
    [[ -f "$setup" ]] || die "Missing system setup helper: $setup"
    chmod +x "$setup"

    log "Installing Frieren SDDM theme"
    "$setup" sddm-theme
}

full_customization() {
    install_dual_rice
    install_frieren_sddm_theme

    printf '\n'
    ok "Full desktop customization installed"
    printf '\nIncluded:\n'
    printf '  ✦ Caelestia configuration\n'
    printf '  ◈ end4-pC configuration and saved album-art fixes\n'
    printf '  🖼 Frieren desktop wallpaper\n'
    printf '  🌙 Frieren SDDM login theme\n'
    printf '  ⇄ SUPER + SHIFT + D desktop switcher\n'
    printf '\nLog out and back into Hyprland when the installer finishes.\n'
}

usage() {
    cat <<'EOF'
Huzaifah Hyprland customization installer

Usage: ./install.sh [options]

Default (no options):
  Install the complete customization automatically:
    - Caelestia rice
    - end4-pC rice
    - saved end4 widget/bar layout
    - Frieren desktop wallpaper
    - Frieren SDDM theme
    - SUPER + SHIFT + D rice switcher
    - saved local end4-pC album-art fixes

Customization options:
  --customization     Full customization (same as no options)
  --dual-rice         Full customization (alias)
  --dual-rice-only    Install Caelestia + end4-pC without touching SDDM
  --sddm-theme-only   Install only the Frieren SDDM theme
  --no-sddm-theme     Install dual-rice + wallpaper, but skip the SDDM theme

Optional machine-specific extras (never run automatically):
  --asus              Generic ASUS support
  --g16               Zephyrus G16-specific safe extras
  --refind            Configure rEFInd for this machine
  --refresh           Enable captured refresh-rate automation after checks
  --hibernate         Configure Btrfs hibernation swap
  --status            Show system-setup status

Other:
  --help, -h          Show this help

This repository customizes an existing Arch/CachyOS-family installation.
It does not install an operating system.
EOF
}

main() {
    ensure_repo "$@"
    is_arch_family || die "This customization currently supports Arch/CachyOS-family systems only."

    # The public one-command installer intentionally defaults to the complete
    # visual setup. Machine-specific changes remain explicit flags.
    if (($# == 0)); then
        full_customization
        return
    fi

    local do_dual=0
    local do_theme=0
    local do_asus=0
    local do_g16=0
    local do_refind=0
    local do_refresh=0
    local do_hibernate=0
    local do_status=0

    while (($#)); do
        case "$1" in
            --customization|--dual-rice|--base|--all)
                do_dual=1
                do_theme=1
                ;;
            --dual-rice-only|--no-sddm-theme)
                do_dual=1
                do_theme=0
                ;;
            --sddm-theme|--sddm-theme-only)
                do_theme=1
                ;;
            --asus)
                do_asus=1
                ;;
            --g16)
                do_g16=1
                do_asus=1
                ;;
            --refind)
                do_refind=1
                ;;
            --refresh)
                do_refresh=1
                ;;
            --hibernate)
                do_hibernate=1
                ;;
            --status)
                do_status=1
                ;;
            --help|-h)
                usage
                return
                ;;
            *)
                die "Unknown option: $1. Run ./install.sh --help"
                ;;
        esac
        shift
    done

    (( do_dual )) && install_dual_rice
    (( do_theme )) && install_frieren_sddm_theme

    if (( do_asus && ! do_g16 )); then
        "$DOTFILES_DIR/system-setup.sh" asus
    fi
    (( do_g16 )) && "$DOTFILES_DIR/system-setup.sh" g16
    (( do_refind )) && "$DOTFILES_DIR/system-setup.sh" refind
    (( do_refresh )) && "$DOTFILES_DIR/system-setup.sh" refresh
    (( do_hibernate )) && "$DOTFILES_DIR/system-setup.sh" hibernate
    (( do_status )) && "$DOTFILES_DIR/system-setup.sh" status

    ok "Done"
}

main "$@"
