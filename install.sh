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

    # A curl-piped copy cannot see the rest of the repository. Hand execution
    # to the checked-out copy before doing anything to the machine.
    local self_real repo_real
    self_real="$(readlink -f "$0" 2>/dev/null || true)"
    repo_real="$(readlink -f "$DOTFILES_DIR/install.sh" 2>/dev/null || true)"
    if [[ -n "$repo_real" && "$self_real" != "$repo_real" ]]; then
        exec "$DOTFILES_DIR/install.sh" "$@"
    fi
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

        # fish_variables contains host/user-specific universal variables and is
        # intentionally not deployed as a portable dotfile.
        if [[ "$pkg" == "fish" && "$rel" == ".config/fish/fish_variables" ]]; then
            continue
        fi

        dst="$HOME/$rel"
        if [[ -e "$dst" && ! -L "$dst" ]]; then
            mkdir -p "$backup/$(dirname "$rel")"
            mv "$dst" "$backup/$rel"
            log "Backed up $dst"
        fi
    done < <(find "$src" -type f -print0)
}

stow_portable_package() {
    local pkg="$1"
    [[ -d "$DOTFILES_DIR/$pkg" ]] || return 0
    backup_stow_conflicts "$pkg"

    if [[ "$pkg" == "fish" ]]; then
        stow -d "$DOTFILES_DIR" -t "$HOME" --ignore='(^|/)fish_variables$' --restow "$pkg"
    else
        stow -d "$DOTFILES_DIR" -t "$HOME" --restow "$pkg"
    fi
}

install_widgets() {
    local spec="${1:-}"
    [[ -n "$spec" ]] || die "--widgets requires: lyrics, visualiser, or lyrics,visualiser"
    is_arch_family || die "The widget installer currently supports Arch/CachyOS only."

    local want_lyrics=0 want_visualiser=0 item
    local -a raw
    IFS=',' read -ra raw <<< "$spec"
    for item in "${raw[@]}"; do
        item="${item,,}"
        item="${item// /}"
        case "$item" in
            lyrics|desktoplyrics|desktop-lyrics) want_lyrics=1 ;;
            visualiser|visualizer|audio-visualiser|audio-visualizer|desktop-visualiser|desktop-visualizer) want_visualiser=1 ;;
            "") ;;
            *) die "Unknown widget '$item'. Supported: lyrics, visualiser" ;;
        esac
    done
    (( want_lyrics || want_visualiser )) || die "No supported widgets were selected."

    log "Installing minimal Caelestia widget dependencies"
    sudo pacman -S --needed jq
    install_flexible_pkg dim-caelestia-shell-git || die "Could not install dim-caelestia-shell-git"
    install_flexible_pkg caelestia-cli || die "Could not install caelestia-cli"

    if (( want_visualiser )) && pacman -Si cava >/dev/null 2>&1; then
        sudo pacman -S --needed cava
    fi

    local profile="$DOTFILES_DIR/widgets/caelestia-widget-profile.json"
    [[ -f "$profile" ]] || die "Widget profile is missing: $profile"

    local config_dir="$HOME/.config/caelestia" config="$config_dir/shell.json"
    mkdir -p "$config_dir"
    [[ -f "$config" ]] || printf '{}\n' > "$config"
    jq empty "$config" >/dev/null || die "$config is not valid JSON"
    jq empty "$profile" >/dev/null || die "$profile is not valid JSON"

    local backup="$config.pre-widget-$(date +%Y%m%d-%H%M%S)"
    cp -a "$config" "$backup"

    local patch merged
    patch="$(mktemp)"
    merged="$(mktemp)"

    jq \
        --argjson lyrics "$want_lyrics" \
        --argjson visualiser "$want_visualiser" '
        (.background // {}) as $bg |
        (.services // {}) as $svc |
        (.paths // {}) as $paths |
        {
          background:
            ({enabled: true}
             + (if $lyrics == 1 then {desktopLyrics: (($bg.desktopLyrics // {}) + {enabled: true})} else {} end)
             + (if $visualiser == 1 then {visualiser: (($bg.visualiser // {}) + {enabled: true})} else {} end)),
          services:
            ((if $lyrics == 1
              then ({showLyrics: true}
                    + (if ($svc | has("lyricsBackend")) then {lyricsBackend: $svc.lyricsBackend} else {} end))
              else {} end)
             + (if $visualiser == 1
                then (if ($svc | has("visualiserBars")) then {visualiserBars: $svc.visualiserBars} else {} end)
                else {} end)),
          paths:
            (if $lyrics == 1 and ($paths | has("lyricsDir"))
             then {lyricsDir: $paths.lyricsDir}
             else {} end)
        }' "$profile" > "$patch"

    jq -s '.[0] * .[1]' "$config" "$patch" > "$merged"
    mv "$merged" "$config"
    rm -f "$patch"

    ok "Widget configuration installed"
    printf 'Backup of previous config: %s\n' "$backup"

    if pgrep -f 'qs -c caelestia' >/dev/null 2>&1; then
        printf '\nCaelestia is already running. Restart if needed:\n'
        printf 'pkill -f "qs -c caelestia"; caelestia shell -d\n'
    else
        caelestia shell -d || true
    fi
}

base_install() {
    is_arch_family || die "This installer currently supports Arch/CachyOS only."

    log "Installing portable base packages"
    local p
    for p in git stow rsync curl jq fish hyprland mpv playerctl brightnessctl hyprsunset; do
        if pacman -Si "$p" >/dev/null 2>&1; then
            sudo pacman -S --needed "$p"
        else
            warn "Package '$p' is not in enabled pacman repositories; skipping."
        fi
    done

    install_flexible_pkg dim-caelestia-shell-git || warn "Could not install dim-caelestia-shell-git."
    install_flexible_pkg caelestia-cli || warn "Could not install caelestia-cli."

    log "Applying PORTABLE Stow packages"
    local pkg
    for pkg in caelestia fish hypr mpv scripts systemd; do
        stow_portable_package "$pkg"
    done
    systemctl --user daemon-reload 2>/dev/null || true

    ok "Portable dotfiles installed"
    printf '\nNo display manager, bootloader, GPU mode, hibernation, or refresh-rate service was changed.\n'
}

show_detected_machine() {
    local vendor product
    vendor="$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || true)"
    product="$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)"
    printf '\nDetected machine\n'
    printf '  Vendor : %s\n' "${vendor:-unknown}"
    printf '  Product: %s\n\n' "${product:-unknown}"
}

interactive_install() {
    local do_base=0 do_asus=0 do_g16=0 do_sddm_theme=0
    local do_refind=0 do_refresh=0 do_hibernate=0
    local vendor product

    vendor="$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || true)"
    product="$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)"

    show_detected_machine

    prompt_yes_no "Install portable Hyprland/Caelestia/Fish dotfiles?" y && do_base=1

    if [[ "$vendor" == *ASUS* || "$vendor" == *ASUSTeK* ]]; then
        prompt_yes_no "ASUS laptop detected. Install generic ASUS support?" y && do_asus=1
    fi
    if [[ "$product" =~ GU60[35] || "$product" == *"Zephyrus G16"* ]]; then
        prompt_yes_no "Zephyrus G16 detected. Install safe G16 extras?" y && { do_g16=1; do_asus=1; }
    fi

    prompt_yes_no "Install the Frieren SDDM THEME only (no autologin/DM switch)?" n && do_sddm_theme=1

    printf '\nAdvanced / machine-changing options (all default to NO):\n'
    prompt_yes_no "Configure rEFInd safely for THIS machine?" n && do_refind=1
    prompt_yes_no "Enable the captured 120/240 Hz refresh automation if this panel is compatible?" n && do_refresh=1
    prompt_yes_no "Configure Btrfs hibernation swap?" n && do_hibernate=1

    (( do_base )) && base_install
    (( do_asus && ! do_g16 )) && "$DOTFILES_DIR/system-setup.sh" asus
    (( do_g16 )) && "$DOTFILES_DIR/system-setup.sh" g16
    (( do_sddm_theme )) && "$DOTFILES_DIR/system-setup.sh" sddm-theme
    (( do_refind )) && "$DOTFILES_DIR/system-setup.sh" refind
    (( do_refresh )) && "$DOTFILES_DIR/system-setup.sh" refresh
    (( do_hibernate )) && "$DOTFILES_DIR/system-setup.sh" hibernate

    "$DOTFILES_DIR/system-setup.sh" status || true
}

usage() {
    cat <<'EOF'
Huzaifah dotfiles — safe installer

Usage: ./install.sh [options]

No options:
  Interactive installer. Nothing machine-specific is applied silently.

Portable / safe:
  --base             Install portable Hyprland/Caelestia/Fish dotfiles
  --widgets LIST     Install selected Caelestia widgets only
  --asus             Generic ASUS packages; never switches GPU mode
  --g16              Safe G16 extras; implies --asus
  --sddm-theme       Install Frieren SDDM theme only; no autologin or DM switch
  --all              Portable base + auto-detected safe ASUS/G16 extras

Explicit machine-changing actions:
  --refind           Safely install/configure rEFInd for the current machine
  --refresh          Enable captured refresh automation only after compatibility checks
  --hibernate        Configure Btrfs hibernation swap
  --sddm             Restore the exact captured SDDM config (guarded + confirmation)
  --force-machine-profile
                     Allow exact captured machine profile on a non-matching model
                     (only with an explicit machine-specific action)

Other:
  --status           Print setup/hardware status
  --help             Show this help

Important:
  --base and --all never touch SDDM configuration, boot order, rEFInd,
  GPU mode, refresh-rate activation, or hibernation.
EOF
}

main() {
    ensure_repo "$@"
    is_arch_family || die "This installer currently supports Arch/CachyOS only."

    if (($# == 0)); then
        interactive_install
        return
    fi

    local do_base=0 do_asus=0 do_g16=0 do_sddm_theme=0 do_sddm_exact=0
    local do_refind=0 do_refresh=0 do_hibernate=0 do_status=0 do_all=0
    local widget_spec=""

    while (($#)); do
        case "$1" in
            --base) do_base=1 ;;
            --widgets)
                [[ $# -ge 2 ]] || die "--widgets requires a value"
                widget_spec="$2"
                shift
                ;;
            --widgets=*) widget_spec="${1#*=}" ;;
            --asus) do_asus=1 ;;
            --g16) do_g16=1; do_asus=1 ;;
            --sddm-theme) do_sddm_theme=1 ;;
            --sddm) do_sddm_exact=1 ;;
            --refind) do_refind=1 ;;
            --refresh) do_refresh=1 ;;
            --hibernate) do_hibernate=1 ;;
            --status) do_status=1 ;;
            --all) do_all=1 ;;
            --force-machine-profile)
                export DOTFILES_FORCE_MACHINE_PROFILE=1
                ;;
            --help|-h) usage; return ;;
            *) die "Unknown option: $1" ;;
        esac
        shift
    done

    if [[ -n "$widget_spec" ]]; then
        install_widgets "$widget_spec"
    fi

    if (( do_all )); then
        do_base=1
        local vendor product
        vendor="$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || true)"
        product="$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)"
        if [[ "$vendor" == *ASUS* || "$vendor" == *ASUSTeK* ]]; then
            do_asus=1
        fi
        if [[ "$product" =~ GU60[35] || "$product" == *"Zephyrus G16"* ]]; then
            do_g16=1
            do_asus=1
        fi
        warn "--all is intentionally SAFE: rEFInd, exact SDDM, refresh activation, and hibernation are skipped unless separately requested."
    fi

    (( do_base )) && base_install
    (( do_asus && ! do_g16 )) && "$DOTFILES_DIR/system-setup.sh" asus
    (( do_g16 )) && "$DOTFILES_DIR/system-setup.sh" g16
    (( do_sddm_theme )) && "$DOTFILES_DIR/system-setup.sh" sddm-theme
    (( do_sddm_exact )) && "$DOTFILES_DIR/system-setup.sh" sddm
    (( do_refind )) && "$DOTFILES_DIR/system-setup.sh" refind
    (( do_refresh )) && "$DOTFILES_DIR/system-setup.sh" refresh
    (( do_hibernate )) && "$DOTFILES_DIR/system-setup.sh" hibernate
    (( do_status )) && "$DOTFILES_DIR/system-setup.sh" status

    ok "Done"
}

main "$@"
