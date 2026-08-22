#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
MACHINE_DIR="$REPO_DIR/machine"
PKG_DIR="$MACHINE_DIR/packages"
REFIND_BACKUP_DIR="$MACHINE_DIR/refind"
SDDM_BACKUP_DIR="$MACHINE_DIR/sddm"

SWAP_DIR="${DOTFILES_SWAP_DIR:-/swap}"
SWAPFILE="${DOTFILES_SWAPFILE:-$SWAP_DIR/swapfile}"
SWAP_SIZE="${DOTFILES_SWAP_SIZE:-20G}"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
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

install_flexible() {
    local pkg="$1"
    if pacman -Q "$pkg" >/dev/null 2>&1; then
        return
    fi
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

machine_value() {
    local key="$1" file="$MACHINE_DIR/current-system.txt"
    [[ -f "$file" ]] || return 1
    sed -n "s/^${key}=//p" "$file" | head -1
}

current_vendor() {
    cat /sys/class/dmi/id/sys_vendor 2>/dev/null || true
}

current_product() {
    cat /sys/class/dmi/id/product_name 2>/dev/null || true
}

is_g16() {
    local product
    product="$(current_product)"
    [[ "$product" =~ GU60[35] || "$product" == *"Zephyrus G16"* ]]
}

machine_profile_matches() {
    local saved_vendor saved_product vendor product
    saved_vendor="$(machine_value dmi_vendor 2>/dev/null || true)"
    saved_product="$(machine_value dmi_product 2>/dev/null || true)"
    vendor="$(current_vendor)"
    product="$(current_product)"

    [[ -n "$saved_vendor" && -n "$saved_product" ]] || return 1
    [[ "$saved_vendor" == "$vendor" && "$saved_product" == "$product" ]]
}

allow_exact_machine_profile() {
    if machine_profile_matches; then
        return 0
    fi
    if [[ "${DOTFILES_FORCE_MACHINE_PROFILE:-0}" == "1" ]]; then
        warn "FORCING a captured machine profile onto a non-matching machine."
        return 0
    fi

    warn "Captured profile: $(machine_value dmi_vendor 2>/dev/null || echo unknown) / $(machine_value dmi_product 2>/dev/null || echo unknown)"
    warn "Current machine : $(current_vendor) / $(current_product)"
    return 1
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

is_vfat_mount() {
    local p="$1" fs
    mountpoint -q "$p" 2>/dev/null || return 1
    fs="$(findmnt -n -o FSTYPE --target "$p" 2>/dev/null || true)"
    [[ "$fs" == "vfat" || "$fs" == "fat" || "$fs" == "msdos" ]]
}

find_esp() {
    local p

    # Prefer the conventional dedicated ESP paths first. This avoids choosing
    # /boot when /boot/efi is the actual FAT ESP.
    for p in /boot/efi /efi /boot; do
        if is_vfat_mount "$p"; then
            printf '%s\n' "$p"
            return 0
        fi
    done

    # Fallback: any mounted FAT filesystem with an EFI directory.
    while IFS= read -r p; do
        [[ -d "$p/EFI" ]] || continue
        printf '%s\n' "$p"
        return 0
    done < <(findmnt -rn -t vfat,fat,msdos -o TARGET 2>/dev/null || true)

    return 1
}

find_refind_conf() {
    local esp="${1:-}" p

    if [[ -n "$esp" ]]; then
        for p in \
            "$esp/EFI/refind/refind.conf" \
            "$esp/EFI/REFIND/refind.conf"; do
            [[ -f "$p" ]] && { printf '%s\n' "$p"; return 0; }
        done
    fi

    for p in \
        /boot/efi/EFI/refind/refind.conf \
        /efi/EFI/refind/refind.conf \
        /boot/EFI/refind/refind.conf; do
        [[ -f "$p" ]] && { printf '%s\n' "$p"; return 0; }
    done

    # Last-resort search after refind-install. Keep it shallow and scoped.
    local root found
    for root in /boot/efi /efi /boot; do
        [[ -d "$root" ]] || continue
        found="$(sudo find "$root" -maxdepth 4 -type f -iname refind.conf -path '*/EFI/*' -print -quit 2>/dev/null || true)"
        if [[ -n "$found" ]]; then
            printf '%s\n' "$found"
            return 0
        fi
    done

    return 1
}

current_root_uuid() {
    findmnt -no UUID / 2>/dev/null || true
}

current_boot_order() {
    efibootmgr 2>/dev/null | sed -n 's/^BootOrder:[[:space:]]*//p' | tr -d ' ' | head -1
}

restore_boot_order() {
    local order="$1"
    [[ -n "$order" ]] || return 0
    log "Restoring previous UEFI BootOrder: $order"
    sudo efibootmgr -o "$order" >/dev/null
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

capture_widget_profile() {
    local src="$HOME/.config/caelestia/shell.json"
    local dst="$REPO_DIR/widgets/caelestia-widget-profile.json"

    [[ -f "$src" ]] || {
        warn "No Caelestia shell.json; skipping widget profile capture."
        return 0
    }

    mkdir -p "$REPO_DIR/widgets"

    jq '{
        formatVersion: 1,
        description: "Portable Caelestia desktop Lyrics + Audio Visualiser profile",
        background: (
            {}
            + (if (.background.desktopLyrics? | type) == "object"
               then {desktopLyrics: .background.desktopLyrics}
               else {desktopLyrics: {enabled: true}}
               end)
            + (if (.background.visualiser? | type) == "object"
               then {visualiser: .background.visualiser}
               else {visualiser: {enabled: true, blur: false, autoHide: true, rounding: 1, spacing: 1}}
               end)
        ),
        services: (
            {}
            + (if (.services? | type) == "object" and (.services | has("showLyrics"))
               then {showLyrics: .services.showLyrics}
               else {showLyrics: true}
               end)
            + (if (.services? | type) == "object" and (.services | has("lyricsBackend"))
               then {lyricsBackend: .services.lyricsBackend}
               else {}
               end)
            + (if (.services? | type) == "object" and (.services | has("visualiserBars"))
               then {visualiserBars: .services.visualiserBars}
               else {visualiserBars: 45}
               end)
        ),
        paths: (
            if (.paths? | type) == "object" and (.paths | has("lyricsDir"))
            then {lyricsDir: .paths.lyricsDir}
            else {}
            end
        )
    }' "$src" > "$dst"

    ok "Saved portable Lyrics/Visualiser widget profile"
}

capture_packages() {
    mkdir -p "$PKG_DIR"
    local excludes='(^|[-_])(nvidia|cuda|cudnn|nvtop)([-_]|$)|^(sbctl|sbsigntools|mokutil|shim)$'

    pacman -Qqen | grep -Evi "$excludes" | sort -u > "$PKG_DIR/pacman.txt"
    pacman -Qqem | grep -Evi "$excludes" | sort -u > "$PKG_DIR/aur.txt"

    ok "Saved package lists (GPU/NVIDIA/CUDA and Secure-Boot tooling excluded)"
}

capture_refind() {
    mkdir -p "$REFIND_BACKUP_DIR"

    local esp conf root_uuid
    esp="$(find_esp || true)"
    [[ -n "$esp" ]] || {
        warn "No mounted ESP found; skipping rEFInd capture."
        return 0
    }

    conf="$(find_refind_conf "$esp" || true)"
    [[ -n "$conf" ]] || {
        warn "No rEFInd config found; skipping rEFInd capture."
        return 0
    }

    root_uuid="$(current_root_uuid)"
    sudo cat "$conf" > "$REFIND_BACKUP_DIR/refind.conf"

    # Sanitize root identifiers. The snapshot remains a backup; the portable
    # installer does NOT deploy this complete config to another machine.
    sed -Ei \
        -e 's#root=UUID=[A-Fa-f0-9-]+#root=UUID=__ROOT_UUID__#g' \
        -e 's#root=/dev/[^ " ]+#root=UUID=__ROOT_UUID__#g' \
        "$REFIND_BACKUP_DIR/refind.conf"

    local linux_conf=""
    for linux_conf in "$esp/refind_linux.conf" /boot/refind_linux.conf; do
        [[ -f "$linux_conf" ]] || continue
        sudo cat "$linux_conf" > "$REFIND_BACKUP_DIR/refind_linux.conf"
        sed -Ei \
            -e 's#root=UUID=[A-Fa-f0-9-]+#root=UUID=__ROOT_UUID__#g' \
            -e 's#root=/dev/[^ " ]+#root=UUID=__ROOT_UUID__#g' \
            "$REFIND_BACKUP_DIR/refind_linux.conf"
        chmod 0644 "$REFIND_BACKUP_DIR/refind_linux.conf"
        break
    done

    local theme_src
    theme_src="$(dirname "$conf")/themes/rEFInd-minimal"
    if sudo test -d "$theme_src"; then
        rm -rf "$REFIND_BACKUP_DIR/themes/rEFInd-minimal"
        mkdir -p "$REFIND_BACKUP_DIR/themes"
        sudo cp -a "$theme_src" "$REFIND_BACKUP_DIR/themes/rEFInd-minimal"
        sudo chown -R "$USER":"$(id -gn)" "$REFIND_BACKUP_DIR/themes"
    fi

    {
        printf 'captured_at=%s\n' "$(date --iso-8601=seconds)"
        printf 'esp=%s\n' "$esp"
        printf 'config=%s\n' "$conf"
        printf 'root_uuid=%s\n' "$root_uuid"
    } > "$REFIND_BACKUP_DIR/manifest.txt"

    chmod 0644 "$REFIND_BACKUP_DIR/refind.conf"
    ok "Saved sanitized rEFInd backup and theme assets"
}

capture_system_info() {
    mkdir -p "$MACHINE_DIR"
    {
        printf 'captured_at=%s\n' "$(date --iso-8601=seconds)"
        printf 'hostname=%s\n' "$(hostname)"
        printf 'kernel=%s\n' "$(uname -r)"
        printf 'root_fs=%s\n' "$(findmnt -no FSTYPE /)"
        printf 'root_uuid=%s\n' "$(current_root_uuid)"
        printf 'dmi_vendor=%s\n' "$(current_vendor)"
        printf 'dmi_product=%s\n' "$(current_product)"
        printf 'swap=%s\n' "$(swapon --show --noheadings --raw 2>/dev/null | tr '\n' ';' || true)"
    } > "$MACHINE_DIR/current-system.txt"
}

capture_sddm() {
    local dst="$SDDM_BACKUP_DIR"
    local theme_src="/usr/share/sddm/themes/sddm-frieren-theme"

    log "Capturing exact SDDM/Frieren theme and configuration"
    rm -rf "$dst"
    mkdir -p "$dst/themes" "$dst/etc"

    if sudo test -d "$theme_src"; then
        sudo cp -a "$theme_src" "$dst/themes/sddm-frieren-theme"
        sudo chown -R "$USER":"$(id -gn)" "$dst/themes/sddm-frieren-theme"
    else
        warn "Frieren theme not found at $theme_src"
    fi

    if sudo test -f /etc/sddm.conf; then
        sudo cp -a /etc/sddm.conf "$dst/etc/sddm.conf"
        sudo chown "$USER":"$(id -gn)" "$dst/etc/sddm.conf"
    fi

    if sudo test -d /etc/sddm.conf.d; then
        mkdir -p "$dst/etc/sddm.conf.d"
        sudo cp -a /etc/sddm.conf.d/. "$dst/etc/sddm.conf.d/"
        sudo chown -R "$USER":"$(id -gn)" "$dst/etc/sddm.conf.d"
    fi

    {
        printf 'captured_at=%s\n' "$(date --iso-8601=seconds)"
        printf 'theme_path=%s\n' "$theme_src"
        printf 'dmi_vendor=%s\n' "$(current_vendor)"
        printf 'dmi_product=%s\n' "$(current_product)"
        printf 'sddm_version=%s\n' "$(sddm --version 2>/dev/null | head -1 || true)"
    } > "$dst/manifest.txt"

    ok "Exact SDDM snapshot saved under machine/sddm/"
}

capture() {
    require_arch
    sudo -v
    capture_dotfiles
    capture_widget_profile
    capture_packages
    capture_refind
    capture_sddm
    capture_system_info
    log "Capture complete. Review with:"
    printf '  git -C %q status\n' "$REPO_DIR"
    printf '  git -C %q diff\n' "$REPO_DIR"
}

restore_packages() {
    require_arch

    local -a pkgs=()
    if [[ -f "$PKG_DIR/pacman.txt" ]]; then
        mapfile -t pkgs < <(grep -Ev '^[[:space:]]*(#|$)' "$PKG_DIR/pacman.txt")
        ((${#pkgs[@]})) && sudo pacman -S --needed "${pkgs[@]}"
    fi

    pkgs=()
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
    vendor="$(current_vendor)"
    product="$(current_product)"

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

    ok "ASUS setup complete"
    printf '\nNo GPU mode was changed automatically.\n'
}

setup_g16() {
    require_arch

    local product
    product="$(current_product)"

    if ! is_g16; then
        warn "DMI product '$product' was not recognized as a GU603/GU605/Zephyrus G16."
        prompt_yes_no "Install G16 packages anyway?" n || return 0
    fi

    setup_asus

    log "Zephyrus G16 extras"
    printf 'No NVIDIA/CUDA driver, GPU mode, display timing, bootloader, or hibernation setting will be changed here.\n'

    if prompt_yes_no "Install optional supergfxctl GPU-switching tools (without switching modes)?" n; then
        install_flexible supergfxctl
        if systemctl list-unit-files supergfxd.service >/dev/null 2>&1; then
            sudo systemctl enable --now supergfxd.service
        fi
    fi

    ok "G16 safe extras complete"
    printf 'Refresh-rate automation remains opt-in: ./install.sh --refresh\n'
}

install_sddm_theme_only() {
    require_arch

    local theme_src="$SDDM_BACKUP_DIR/themes/sddm-frieren-theme"
    local theme_dst="/usr/share/sddm/themes/sddm-frieren-theme"
    [[ -d "$theme_src" ]] || die "Captured Frieren theme is missing: $theme_src"

    sudo pacman -S --needed sddm rsync
    sudo -v

    local stamp backup
    stamp="$(date +%Y%m%d-%H%M%S)"
    backup="/var/backups/huzaifah-dotfiles/sddm-theme/$stamp"
    sudo mkdir -p "$backup"

    if sudo test -d "$theme_dst"; then
        sudo cp -a "$theme_dst" "$backup/sddm-frieren-theme"
    fi

    sudo rm -rf "$theme_dst"
    sudo cp -a "$theme_src" "$theme_dst"
    sudo chown -R root:root "$theme_dst"

    # Theme-only drop-in. No autologin settings and no display-manager enable.
    sudo mkdir -p /etc/sddm.conf.d
    if sudo test -f /etc/sddm.conf.d/90-huzaifah-theme.conf; then
        sudo cp -a /etc/sddm.conf.d/90-huzaifah-theme.conf "$backup/90-huzaifah-theme.conf"
    fi
    printf '[Theme]\nCurrent=sddm-frieren-theme\n' |
        sudo tee /etc/sddm.conf.d/90-huzaifah-theme.conf >/dev/null

    ok "Frieren SDDM theme installed"
    printf 'SDDM was NOT enabled, autologin was NOT configured, and another display manager was NOT replaced.\n'
    printf 'Backup: %s\n' "$backup"
}

restore_sddm_exact() {
    require_arch

    allow_exact_machine_profile || die "Refusing exact SDDM restore on a different machine. Use --force-machine-profile only if you understand the risk."

    local src="$SDDM_BACKUP_DIR"
    local theme_src="$src/themes/sddm-frieren-theme"
    local theme_dst="/usr/share/sddm/themes/sddm-frieren-theme"

    if [[ ! -d "$theme_src" && ! -f "$src/etc/sddm.conf" && ! -d "$src/etc/sddm.conf.d" ]]; then
        die "No captured SDDM snapshot exists in machine/sddm."
    fi

    warn "EXACT SDDM restore can overwrite /etc/sddm.conf and /etc/sddm.conf.d."
    prompt_yes_no "Continue with exact captured SDDM configuration?" n || {
        log "Exact SDDM restore cancelled."
        return 0
    }

    sudo pacman -S --needed sddm rsync
    sudo -v

    local stamp backup dm_target
    stamp="$(date +%Y%m%d-%H%M%S)"
    backup="/var/backups/huzaifah-dotfiles/sddm-exact/$stamp"
    sudo mkdir -p "$backup"

    sudo test -d "$theme_dst" && sudo cp -a "$theme_dst" "$backup/sddm-frieren-theme"
    sudo test -f /etc/sddm.conf && sudo cp -a /etc/sddm.conf "$backup/sddm.conf"
    sudo test -d /etc/sddm.conf.d && sudo cp -a /etc/sddm.conf.d "$backup/sddm.conf.d"

    if [[ -d "$theme_src" ]]; then
        sudo rm -rf "$theme_dst"
        sudo cp -a "$theme_src" "$theme_dst"
        sudo chown -R root:root "$theme_dst"
    fi

    if [[ -f "$src/etc/sddm.conf" ]]; then
        sudo install -o root -g root -m 0644 "$src/etc/sddm.conf" /etc/sddm.conf
    fi

    if [[ -d "$src/etc/sddm.conf.d" ]]; then
        sudo mkdir -p /etc/sddm.conf.d
        sudo rsync -a --delete "$src/etc/sddm.conf.d/" /etc/sddm.conf.d/
        sudo chown -R root:root /etc/sddm.conf.d
    fi

    dm_target="$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null || true)"
    if [[ "$dm_target" == *"/sddm.service" ]]; then
        ok "SDDM is already the configured display manager"
    elif [[ -n "$dm_target" ]]; then
        warn "Another display manager is configured: $dm_target"
        warn "It was NOT replaced."
    elif prompt_yes_no "No display manager is enabled. Enable SDDM?" n; then
        sudo systemctl enable sddm.service
    fi

    ok "Exact captured SDDM files restored"
    printf 'Backup: %s\n' "$backup"
}

generate_refind_linux_conf() {
    local esp="$1"

    if command -v mkrlconf >/dev/null 2>&1 && compgen -G '/boot/vmlinuz-*' >/dev/null; then
        log "Generating machine-specific refind_linux.conf with mkrlconf"
        sudo mkrlconf || warn "mkrlconf failed; rEFInd can still auto-detect kernels/UKIs."
    else
        warn "mkrlconf or a conventional /boot/vmlinuz-* kernel was not found; leaving kernel options to the installed boot setup."
    fi

    # Apply the known G16 Intel backlight parameter only on a detected G16.
    # Never copy a hard-coded root device from the captured machine.
    local linux_conf=""
    for linux_conf in /boot/refind_linux.conf "$esp/refind_linux.conf"; do
        [[ -f "$linux_conf" ]] || continue
        if is_g16 && ! sudo grep -q 'i915.enable_dpcd_backlight=3' "$linux_conf"; then
            local tmp
            tmp="$(mktemp)"
            sudo cat "$linux_conf" > "$tmp"
            sed -E 's/"[[:space:]]*$/ i915.enable_dpcd_backlight=3"/' "$tmp" > "$tmp.new"
            sudo install -m 0644 "$tmp.new" "$linux_conf"
            rm -f "$tmp" "$tmp.new"
            log "Added G16 Intel backlight kernel parameter to $linux_conf"
        fi
        return 0
    done

    return 0
}

apply_refind_theme() {
    local conf="$1" refind_dir
    refind_dir="$(dirname "$conf")"

    local theme_src="$REFIND_BACKUP_DIR/themes/rEFInd-minimal"
    local theme_dst="$refind_dir/themes/rEFInd-minimal"
    [[ -f "$theme_src/theme.conf" ]] || {
        warn "Saved rEFInd-minimal theme not found; keeping the default rEFInd appearance."
        return 0
    }

    sudo mkdir -p "$refind_dir/themes"
    sudo rm -rf "$theme_dst"
    sudo cp -a "$theme_src" "$theme_dst"
    sudo chown -R root:root "$theme_dst" 2>/dev/null || true

    if ! sudo grep -Eq '^[[:space:]]*include[[:space:]]+themes/rEFInd-minimal/theme\.conf([[:space:]]|$)' "$conf"; then
        printf '\n# Huzaifah portable theme (no machine-specific boot entries)\ninclude themes/rEFInd-minimal/theme.conf\n' |
            sudo tee -a "$conf" >/dev/null
    fi

    ok "Applied rEFInd-minimal theme without replacing the machine's boot entries"
}

setup_refind() {
    require_arch

    [[ -d /sys/firmware/efi ]] || die "This system was not booted in UEFI mode."
    secure_boot_enabled && die "Secure Boot is enabled. Signing rEFInd is intentionally outside this installer."

    sudo pacman -S --needed refind efibootmgr
    sudo -v

    local esp conf old_order installed_now=0
    old_order="$(current_boot_order || true)"
    esp="$(find_esp || true)"
    [[ -n "$esp" ]] || die "Could not detect a mounted FAT ESP at /boot/efi, /efi, or /boot."

    conf="$(find_refind_conf "$esp" || true)"
    if [[ -z "$conf" ]]; then
        prompt_yes_no "rEFInd is not installed. Run refind-install on the detected ESP ($esp)?" y || return 0

        log "Installing rEFInd"
        if ! sudo refind-install; then
            restore_boot_order "$old_order" || true
            die "refind-install failed."
        fi
        installed_now=1

        # refind-install may have selected a more specific mount such as
        # /boot/efi. Re-detect instead of trusting the pre-install guess.
        esp="$(find_esp || true)"
        conf="$(find_refind_conf "$esp" || true)"

        if [[ -z "$conf" ]]; then
            restore_boot_order "$old_order" || true
            die "rEFInd reported success, but refind.conf still could not be located. Previous BootOrder was restored."
        fi
    fi

    local stamp
    stamp="$(date +%Y%m%d-%H%M%S)"
    sudo cp -a "$conf" "$conf.pre-huzaifah-$stamp"

    apply_refind_theme "$conf"
    generate_refind_linux_conf "$esp"

    if (( installed_now )); then
        if prompt_yes_no "Make rEFInd the default/first UEFI boot manager?" n; then
            log "Keeping the BootOrder created by refind-install."
        else
            restore_boot_order "$old_order"
            ok "Previous default boot order preserved"
        fi
    fi

    ok "rEFInd configured safely"
    printf 'Config: %s\n' "$conf"
    printf 'ESP:    %s\n' "$esp"
    printf 'Backup: %s.pre-huzaifah-%s\n' "$conf" "$stamp"
    printf '\nThe captured full refind.conf and captured root-device lines were NOT copied to this machine.\n'
}

refresh_compatible() {
    is_g16 || {
        warn "The saved refresh script is G16-specific."
        return 1
    }

    command -v hyprctl >/dev/null 2>&1 || {
        warn "hyprctl is not available."
        return 1
    }
    command -v jq >/dev/null 2>&1 || {
        warn "jq is not available."
        return 1
    }

    local monitors
    monitors="$(hyprctl -j monitors 2>/dev/null || true)"
    [[ -n "$monitors" ]] || {
        warn "No active Hyprland IPC session was found. Log into Hyprland first, then run --refresh."
        return 1
    }

    jq -e '
        any(.[ ];
            .name == "eDP-1"
            and .width == 2560
            and .height == 1600
        )
    ' <<< "$monitors" >/dev/null || {
        warn "Expected G16 internal panel eDP-1 at 2560x1600 was not detected."
        return 1
    }

    return 0
}

enable_refresh() {
    require_arch

    local unit="$HOME/.config/systemd/user/auto-refresh-rate.service"
    local script="$HOME/.local/bin/auto-refresh-rate"

    [[ -f "$unit" ]] || die "auto-refresh-rate.service is missing. Install the portable dotfiles first."
    [[ -x "$script" || -f "$script" ]] || die "auto-refresh-rate script is missing."

    if ! refresh_compatible; then
        if [[ "${DOTFILES_FORCE_MACHINE_PROFILE:-0}" != "1" ]]; then
            die "Refresh automation was NOT enabled because compatibility checks failed."
        fi
        warn "Forcing refresh automation despite failed compatibility checks."
    fi

    systemctl --user daemon-reload
    systemctl --user enable --now auto-refresh-rate.service
    ok "Enabled G16 120/240 Hz AC/battery refresh automation"
}

bytes_for_size() {
    local size="$1"
    numfmt --from=iec "$size" 2>/dev/null || return 1
}

setup_hibernate() {
    require_arch

    [[ "$(findmnt -no FSTYPE /)" == "btrfs" ]] || die "Hibernate setup expects a Btrfs root."
    sudo -v
    sudo pacman -S --needed btrfs-progs

    local required free_bytes
    required="$(bytes_for_size "$SWAP_SIZE" 2>/dev/null || echo 0)"
    free_bytes="$(df -B1 --output=avail / | tail -1 | tr -d ' ')"

    if [[ ! -f "$SWAPFILE" && "$required" -gt 0 && "$free_bytes" -lt "$required" ]]; then
        die "Not enough free space for a $SWAP_SIZE swapfile."
    fi

    local ram_bytes
    ram_bytes="$(awk '/MemTotal:/ {print $2 * 1024}' /proc/meminfo)"
    if [[ "$required" -gt 0 ]] && awk -v swap="$required" -v ram="$ram_bytes" 'BEGIN { exit !(swap < ram) }'; then
        warn "Requested swap size ($SWAP_SIZE) is smaller than installed RAM. Hibernation may fail for large memory images."
    fi

    warn "This creates/edits swap storage and /etc/fstab. It does NOT change your bootloader kernel resume parameters."
    prompt_yes_no "Continue with Btrfs hibernation storage setup?" n || return 0

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

    printf '%s\n' 'w /sys/power/image_size - - - - 0' |
        sudo tee /etc/tmpfiles.d/hibernation-image-size.conf >/dev/null
    printf '0' | sudo tee /sys/power/image_size >/dev/null

    local offset
    offset="$(sudo btrfs inspect-internal map-swapfile -r "$SWAPFILE")"

    ok "Btrfs hibernation storage configured"
    printf 'Swapfile:      %s\n' "$SWAPFILE"
    printf 'Resume offset: %s\n' "$offset"
    warn "Verify your initramfs and kernel resume configuration before relying on hibernation."
}

status_report() {
    printf 'OS:               '
    grep '^PRETTY_NAME=' /etc/os-release 2>/dev/null | cut -d= -f2- | tr -d '"'
    printf 'Kernel:           %s\n' "$(uname -r)"
    printf 'Root FS:          %s\n' "$(findmnt -no FSTYPE / 2>/dev/null || true)"
    printf 'DMI vendor:       %s\n' "$(current_vendor)"
    printf 'DMI product:      %s\n' "$(current_product)"
    printf 'Captured profile: %s\n' "$(machine_value dmi_product 2>/dev/null || echo none)"
    if machine_profile_matches; then
        printf 'Profile match:    yes\n'
    else
        printf 'Profile match:    no\n'
    fi

    printf 'Display manager:  %s\n' "$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null || echo not-configured)"
    printf 'rEFInd config:    %s\n' "$(find_refind_conf "$(find_esp 2>/dev/null || true)" 2>/dev/null || echo not-detected)"
    printf 'UEFI BootOrder:   %s\n' "$(current_boot_order 2>/dev/null || echo unavailable)"

    printf 'Swap:\n'
    swapon --show 2>/dev/null || true

    printf 'ASUS tools:       '
    asusctl --version 2>/dev/null | head -1 || printf 'not installed\n'

    printf 'Refresh service:  '
    if systemctl --user is-enabled auto-refresh-rate.service >/dev/null 2>&1; then
        systemctl --user is-active auto-refresh-rate.service 2>/dev/null || true
    else
        printf 'disabled\n'
    fi

    printf '\nSafety model: portable base never auto-restores exact SDDM, rEFInd boot entries, refresh timings, GPU mode, or hibernation.\n'
}

usage() {
    cat <<'EOF'
Usage: ./system-setup.sh COMMAND

Commands:
  capture       Capture current dotfiles + sanitized machine backups
  packages      Restore saved pacman/AUR package lists
  asus          Install generic ASUS laptop support
  g16           Install safe Zephyrus G16 extras
  sddm-theme    Install Frieren SDDM theme only; no DM switch/autologin
  sddm          Exact captured SDDM restore (guarded and explicit)
  refind        Safe rEFInd install + portable theme + machine-generated options
  refresh       Enable G16 refresh service only after panel/session checks
  hibernate     Configure Btrfs hibernation swap storage (explicit)
  status        Show current setup status

Environment overrides:
  DOTFILES_FORCE_MACHINE_PROFILE=1   bypass machine-profile guards
  DOTFILES_SWAP_SIZE=20G             hibernation swap size
EOF
}

main() {
    case "${1:-}" in
        capture) capture ;;
        packages) restore_packages ;;
        asus) setup_asus ;;
        g16) setup_g16 ;;
        sddm-theme) install_sddm_theme_only ;;
        sddm) restore_sddm_exact ;;
        refind) setup_refind ;;
        refresh) enable_refresh ;;
        hibernate) setup_hibernate ;;
        status) status_report ;;
        -h|--help|help|"") usage ;;
        *) die "Unknown command: $1" ;;
    esac
}

main "$@"
