#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
MACHINE_DIR="$REPO_DIR/machine"
PKG_DIR="$MACHINE_DIR/packages"
REFIND_BACKUP_DIR="$MACHINE_DIR/refind"
SWAP_DIR="/swap"
SWAPFILE="/swap/swapfile"
SWAP_SIZE="20G"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARNING:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

is_arch_family() {
    [[ -r /etc/os-release ]] || return 1
    . /etc/os-release
    [[ "${ID:-}" == "arch" || "${ID:-}" == "cachyos" || "${ID_LIKE:-}" == *arch* ]]
}

require_arch() {
    is_arch_family || die "This command currently supports Arch/CachyOS only."
}

prompt_yes_no() {
    local prompt="$1" default="${2:-n}" ans
    if [[ "$default" == "y" ]]; then
        read -r -p "$prompt [Y/n] " ans < /dev/tty || true
        ans="${ans:-y}"
    else
        read -r -p "$prompt [y/N] " ans < /dev/tty || true
        ans="${ans:-n}"
    fi
    [[ "$ans" =~ ^[Yy]$ ]]
}

install_flexible() {
    local pkg="$1"
    if pacman -Q "$pkg" >/dev/null 2>&1; then return; fi
    if pacman -Si "$pkg" >/dev/null 2>&1; then
        sudo pacman -S --needed "$pkg"
        return
    fi
    if command -v paru >/dev/null 2>&1; then
        paru -S --needed "$pkg"
    elif command -v yay >/dev/null 2>&1; then
        yay -S --needed "$pkg"
    else
        die "$pkg is not in enabled repositories and no AUR helper is installed."
    fi
}

secure_boot_enabled() {
    if command -v mokutil >/dev/null 2>&1; then
        mokutil --sb-state 2>/dev/null | grep -qi 'enabled'
        return
    fi
    [[ -d /sys/firmware/efi/efivars ]] || return 1
    local var
    var="$(find /sys/firmware/efi/efivars -maxdepth 1 -name 'SecureBoot-*' -print -quit 2>/dev/null || true)"
    [[ -n "$var" ]] || return 1
    od -An -t u1 -j 4 -N 1 "$var" 2>/dev/null | grep -Eq '[[:space:]]1[[:space:]]*$'
}

find_esp() {
    local p
    for p in /boot /boot/efi /efi; do
        if mountpoint -q "$p" 2>/dev/null && find "$p/EFI" -maxdepth 2 -iname 'refind_x64.efi' -print -quit 2>/dev/null | grep -q .; then
            printf '%s\n' "$p"
            return 0
        fi
    done
    for p in /boot /boot/efi /efi; do
        mountpoint -q "$p" 2>/dev/null && { printf '%s\n' "$p"; return 0; }
    done
    return 1
}

find_refind_conf() {
    local esp="${1:-}" p
    for p in \
        "$esp/EFI/refind/refind.conf" \
        /boot/EFI/refind/refind.conf \
        /boot/efi/EFI/refind/refind.conf \
        /efi/EFI/refind/refind.conf; do
        [[ -f "$p" ]] && { printf '%s\n' "$p"; return 0; }
    done
    return 1
}

current_root_uuid() {
    findmnt -no UUID /
}

sync_dir() {
    local src="$1" dst="$2"; shift 2
    [[ -d "$src" ]] || return 0
    mkdir -p "$dst"
    rsync -a --delete \
        --exclude '.git/' \
        --exclude 'build/' \
        --exclude 'cache/' \
        --exclude '.cache/' \
        --exclude '*.log' \
        --exclude '*.pid' \
        --exclude '*.lock' \
        --exclude '.env' \
        --exclude '.env.*' \
        --exclude '*token*' \
        --exclude '*secret*' \
        --exclude '*credential*' \
        "$@" \
        "$src/" "$dst/"
}

capture_dotfiles() {
    log "Synchronizing current user configuration into Stow packages"
    sync_dir "$HOME/.config/caelestia" "$REPO_DIR/caelestia/.config/caelestia"
    sync_dir "$HOME/.config/fish" "$REPO_DIR/fish/.config/fish" --exclude 'fish_variables'
    sync_dir "$HOME/.config/hypr" "$REPO_DIR/hypr/.config/hypr"
    sync_dir "$HOME/.config/mpv" "$REPO_DIR/mpv/.config/mpv"
    sync_dir "$HOME/.config/systemd/user" "$REPO_DIR/systemd/.config/systemd/user"
    sync_dir "$HOME/.local/bin" "$REPO_DIR/scripts/.local/bin"

    # Preserve the archived custom-shell development state as a manifest, not
    # as a nested Git repository inside dotfiles.
    local shell_repo="$HOME/.config/quickshell/huzaifah-shell-dev"
    if [[ -d "$shell_repo/.git" ]]; then
        {
            printf 'path=%s\n' "$shell_repo"
            printf 'branch=%s\n' "$(git -C "$shell_repo" branch --show-current 2>/dev/null || true)"
            printf 'commit=%s\n' "$(git -C "$shell_repo" rev-parse HEAD 2>/dev/null || true)"
            printf 'origin=%s\n' "$(git -C "$shell_repo" remote get-url origin 2>/dev/null || true)"
        } > "$MACHINE_DIR/custom-shell.txt"
    fi
}

capture_packages() {
    mkdir -p "$PKG_DIR"
    local excludes='(^|[-_])(nvidia|cuda|cudnn|nvtop)([-_]|$)|^(sbctl|sbsigntools|mokutil|shim)$'

    pacman -Qqen | grep -Evi "$excludes" | sort -u > "$PKG_DIR/pacman.txt"
    pacman -Qqem | grep -Evi "$excludes" | sort -u > "$PKG_DIR/aur.txt"

    log "Saved package lists (GPU/NVIDIA/CUDA and Secure-Boot tooling intentionally excluded)."
}

capture_refind() {
    mkdir -p "$REFIND_BACKUP_DIR"
    local esp conf root_uuid
    esp="$(find_esp || true)"
    [[ -n "$esp" ]] || { warn "No mounted ESP found; skipping rEFInd capture."; return 0; }

    conf="$(find_refind_conf "$esp" || true)"
    [[ -n "$conf" ]] || { warn "No rEFInd config found; skipping rEFInd capture."; return 0; }

    root_uuid="$(current_root_uuid)"
    sudo cat "$conf" > "$REFIND_BACKUP_DIR/refind.conf"
    if [[ -n "$root_uuid" ]]; then
        sed -Ei "s#root=UUID=[A-Fa-f0-9-]+#root=UUID=__ROOT_UUID__#g" "$REFIND_BACKUP_DIR/refind.conf"
    fi

    local theme_src
    theme_src="$(dirname "$conf")/themes/rEFInd-minimal"
    if sudo test -d "$theme_src"; then
        rm -rf "$REFIND_BACKUP_DIR/themes/rEFInd-minimal"
        mkdir -p "$REFIND_BACKUP_DIR/themes"
        sudo cp -a "$theme_src" "$REFIND_BACKUP_DIR/themes/rEFInd-minimal"
        sudo chown -R "$USER":"$(id -gn)" "$REFIND_BACKUP_DIR/themes"
    fi
    chmod 0644 "$REFIND_BACKUP_DIR/refind.conf"
    log "Saved sanitized rEFInd config and theme assets."
}

capture_system_info() {
    mkdir -p "$MACHINE_DIR"
    {
        printf 'captured_at=%s\n' "$(date --iso-8601=seconds)"
        printf 'hostname=%s\n' "$(hostname)"
        printf 'kernel=%s\n' "$(uname -r)"
        printf 'root_fs=%s\n' "$(findmnt -no FSTYPE /)"
        printf 'root_uuid=%s\n' "$(current_root_uuid)"
        printf 'dmi_vendor=%s\n' "$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || true)"
        printf 'dmi_product=%s\n' "$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)"
        printf 'swap=%s\n' "$(swapon --show --noheadings --raw 2>/dev/null | tr '\n' ';' || true)"
    } > "$MACHINE_DIR/current-system.txt"
}

capture() {
    require_arch
    sudo -v
    capture_dotfiles
    capture_packages
    capture_refind
    capture_system_info
    log "Capture complete. Review with:"
    printf '  git -C %q status\n' "$REPO_DIR"
    printf '  git -C %q diff\n' "$REPO_DIR"
}

restore_packages() {
    require_arch
    local f
    if [[ -f "$PKG_DIR/pacman.txt" ]]; then
        mapfile -t pkgs < <(grep -Ev '^[[:space:]]*(#|$)' "$PKG_DIR/pacman.txt")
        ((${#pkgs[@]})) && sudo pacman -S --needed "${pkgs[@]}"
    fi

    if [[ -f "$PKG_DIR/aur.txt" ]]; then
        command -v paru >/dev/null 2>&1 || die "paru is required to restore AUR packages."
        mapfile -t pkgs < <(grep -Ev '^[[:space:]]*(#|$)' "$PKG_DIR/aur.txt")
        ((${#pkgs[@]})) && paru -S --needed "${pkgs[@]}"
    fi

    warn "GPU/NVIDIA/CUDA and Secure-Boot packages were intentionally excluded."
}

setup_asus() {
    require_arch
    local vendor product
    vendor="$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || true)"
    product="$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)"

    if [[ "$vendor" != *ASUS* && "$vendor" != *ASUSTeK* ]]; then
        warn "This does not appear to be an ASUS laptop ($vendor / $product)."
        prompt_yes_no "Continue with ASUS package installation anyway?" n || return 0
    fi

    log "Installing ASUS laptop support"
    install_flexible asusctl
    install_flexible rog-control-center

    if pacman -Si power-profiles-daemon >/dev/null 2>&1; then
        sudo pacman -S --needed power-profiles-daemon
    fi

    if systemctl is-active --quiet tlp.service 2>/dev/null || systemctl is-active --quiet tuned.service 2>/dev/null; then
        warn "TLP or tuned is active. Not enabling power-profiles-daemon automatically."
    elif systemctl list-unit-files power-profiles-daemon.service >/dev/null 2>&1; then
        sudo systemctl enable --now power-profiles-daemon.service || true
    fi

    sudo udevadm trigger 2>/dev/null || true

    log "ASUS setup complete."
    asusctl --version 2>/dev/null || true
    printf '\nUseful commands:\n'
    printf '  asusctl --help\n'
    printf '  asusctl profile -n        # cycle supported performance profiles\n'
    printf '  rog-control-center        # GUI\n'
    printf '\nNo GPU mode was changed automatically.\n'
}

setup_g16() {
    require_arch
    local product
    product="$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)"

    if [[ ! "$product" =~ GU60[35] && "$product" != *"Zephyrus G16"* ]]; then
        warn "DMI product '$product' was not recognized as a GU603/GU605/Zephyrus G16."
        prompt_yes_no "Apply the G16 profile anyway?" n || return 0
    fi

    setup_asus

    log "Zephyrus G16 extras"
    printf 'This profile keeps your existing Hyprland 1.25 scale and 120/240 Hz automation.\n'
    printf 'It does NOT install or modify NVIDIA/CUDA drivers.\n\n'

    if prompt_yes_no "Install optional supergfxctl GPU-switching tools?" n; then
        install_flexible supergfxctl
        if systemctl list-unit-files supergfxd.service >/dev/null 2>&1; then
            sudo systemctl enable --now supergfxd.service
        fi
        printf '\nGPU commands (run manually only after checking current state):\n'
        printf '  supergfxctl --help\n'
        printf '  supergfxctl --mode Hybrid\n'
        printf '  supergfxctl --mode Integrated\n'
        printf '\nThe installer will never switch GPU mode automatically.\n'
    fi

    if [[ -f "$HOME/.config/systemd/user/auto-refresh-rate.service" ]]; then
        if prompt_yes_no "Enable the existing 120/240 Hz AC/battery refresh service?" y; then
            enable_refresh
        fi
    fi
}

setup_hibernate() {
    require_arch
    [[ "$(findmnt -no FSTYPE /)" == "btrfs" ]] || die "Hibernate setup expects a Btrfs root."
    sudo -v
    sudo pacman -S --needed btrfs-progs

    if [[ ! -d "$SWAP_DIR" ]]; then
        sudo btrfs subvolume create "$SWAP_DIR"
    fi

    if [[ ! -f "$SWAPFILE" ]]; then
        sudo btrfs filesystem mkswapfile --size "$SWAP_SIZE" --uuid clear "$SWAPFILE"
        sudo chmod 600 "$SWAPFILE"
    fi

    swapon --show=NAME --noheadings | grep -qx "$SWAPFILE" || sudo swapon -p 10 "$SWAPFILE"

    local fstab_line="$SWAPFILE none swap defaults,pri=10 0 0"
    grep -Fqx "$fstab_line" /etc/fstab || printf '%s\n' "$fstab_line" | sudo tee -a /etc/fstab >/dev/null

    printf '%s\n' 'w /sys/power/image_size - - - - 0' | sudo tee /etc/tmpfiles.d/hibernation-image-size.conf >/dev/null
    printf '0' | sudo tee /sys/power/image_size >/dev/null

    log "Btrfs swapfile resume offset:"
    sudo btrfs inspect-internal map-swapfile -r "$SWAPFILE"

    if grep -Eq '^HOOKS=.*\bsystemd\b' /etc/mkinitcpio.conf 2>/dev/null; then
        log "mkinitcpio systemd hook detected."
    else
        warn "mkinitcpio 'systemd' hook was not detected; verify your hibernation initramfs configuration."
    fi

    log "Hibernate storage configured. The script will not hibernate the machine automatically."
}

setup_refind() {
    require_arch
    secure_boot_enabled && die "Secure Boot is enabled. Secure-Boot signing is intentionally outside this installer."

    sudo pacman -S --needed refind efibootmgr

    local esp conf refind_dir root_uuid saved
    esp="$(find_esp || true)"
    [[ -n "$esp" ]] || die "Could not detect a mounted ESP at /boot, /boot/efi, or /efi."

    conf="$(find_refind_conf "$esp" || true)"
    if [[ -z "$conf" ]]; then
        prompt_yes_no "rEFInd is not installed on the detected ESP. Run refind-install?" y || return 0
        sudo refind-install
        conf="$(find_refind_conf "$esp" || true)"
        [[ -n "$conf" ]] || die "rEFInd installed but refind.conf could not be found."
    fi

    refind_dir="$(dirname "$conf")"
    sudo cp -a "$conf" "$conf.fresh-backup-$(date +%Y%m%d-%H%M%S)"

    saved="$REFIND_BACKUP_DIR/refind.conf"
    root_uuid="$(current_root_uuid)"

    if [[ -f "$saved" ]]; then
        local tmp
        tmp="$(mktemp)"
        sed "s/__ROOT_UUID__/$root_uuid/g" "$saved" > "$tmp"
        # Compatibility with an older captured config that still had a UUID.
        sed -Ei "s#root=UUID=[A-Fa-f0-9-]+#root=UUID=$root_uuid#g" "$tmp"
        sudo install -m 0644 "$tmp" "$conf"
        rm -f "$tmp"
    fi

    if [[ -d "$REFIND_BACKUP_DIR/themes/rEFInd-minimal" ]]; then
        sudo mkdir -p "$refind_dir/themes"
        sudo rm -rf "$refind_dir/themes/rEFInd-minimal"
        sudo cp -a "$REFIND_BACKUP_DIR/themes/rEFInd-minimal" "$refind_dir/themes/rEFInd-minimal"
    fi

    # Ensure Linux is launched in graphics mode without duplicating active lines.
    if sudo grep -Eq '^[[:space:]]*use_graphics_for\b.*\blinux\b' "$conf"; then
        :
    else
        printf '\nuse_graphics_for + linux\n' | sudo tee -a "$conf" >/dev/null
    fi

    if command -v mkrlconf >/dev/null 2>&1 && [[ ! -f "$esp/refind_linux.conf" && ! -f /boot/refind_linux.conf ]]; then
        if prompt_yes_no "Generate a machine-specific refind_linux.conf with mkrlconf?" n; then
            sudo mkrlconf
        fi
    fi

    log "rEFInd profile restored."
    printf 'Config: %s\n' "$conf"
    printf 'ESP:    %s\n' "$esp"
}

enable_refresh() {
    local unit="$HOME/.config/systemd/user/auto-refresh-rate.service"
    [[ -f "$unit" ]] || die "auto-refresh-rate.service is missing. Run ./install.sh first."
    systemctl --user daemon-reload
    systemctl --user enable --now auto-refresh-rate.service
    log "Enabled 120/240 Hz AC/battery refresh automation."
}

status_report() {
    printf 'OS:             '
    grep '^PRETTY_NAME=' /etc/os-release 2>/dev/null | cut -d= -f2- | tr -d '"'
    printf 'Kernel:         %s\n' "$(uname -r)"
    printf 'Root FS:        %s\n' "$(findmnt -no FSTYPE / 2>/dev/null || true)"
    printf 'DMI vendor:     %s\n' "$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || true)"
    printf 'DMI product:    %s\n' "$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)"
    printf 'Swap:\n'
    swapon --show 2>/dev/null || true
    printf 'CanHibernate:   '
    busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager CanHibernate 2>/dev/null || true
    printf 'image_size:     %s\n' "$(cat /sys/power/image_size 2>/dev/null || true)"
    printf 'ASUS:           '
    asusctl --version 2>/dev/null | head -1 || printf 'not installed\n'
    printf 'rEFInd ESP:     %s\n' "$(find_esp 2>/dev/null || printf 'not detected')"
    printf 'Refresh service:\n'
    systemctl --user --no-pager --full status auto-refresh-rate.service 2>/dev/null | sed -n '1,5p' || true
    printf 'Saved packages: pacman=%s aur=%s\n' \
        "$([[ -f "$PKG_DIR/pacman.txt" ]] && echo yes || echo no)" \
        "$([[ -f "$PKG_DIR/aur.txt" ]] && echo yes || echo no)"
    printf '\nGPU/NVIDIA/CUDA drivers and Secure-Boot signing remain outside this installer.\n'
}

usage() {
    cat <<'EOF'
Usage: ./system-setup.sh COMMAND

Commands:
  capture      Sync dotfiles + package lists + sanitized rEFInd + machine info
  packages     Restore saved pacman/AUR package lists
  asus         Install generic ASUS laptop support
  g16          ASUS ROG Zephyrus G16 extras
  refind       Install/restore rEFInd and rEFInd-minimal theme
  refresh      Enable 120/240 Hz AC/battery refresh service
  hibernate    Configure the 20G Btrfs hibernation swap setup
  status       Show current setup status
  all          packages + ASUS + hibernate + optional rEFInd + refresh + status
EOF
}

main() {
    case "${1:-}" in
        capture) capture ;;
        packages) restore_packages ;;
        asus) setup_asus ;;
        g16) setup_g16 ;;
        refind) setup_refind ;;
        refresh) enable_refresh ;;
        hibernate) setup_hibernate ;;
        status) status_report ;;
        all)
            restore_packages
            setup_asus
            setup_hibernate
            if ! secure_boot_enabled; then
                prompt_yes_no "Set up rEFInd?" n && setup_refind
            else
                warn "Secure Boot enabled; skipping rEFInd customization."
            fi
            prompt_yes_no "Enable 120/240 Hz refresh automation?" y && enable_refresh
            status_report
            ;;
        -h|--help|help|"") usage ;;
        *) die "Unknown command: $1" ;;
    esac
}

main "$@"
