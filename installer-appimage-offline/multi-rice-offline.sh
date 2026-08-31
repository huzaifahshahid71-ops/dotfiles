#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PAYLOAD="$HERE/payload"
REPO="$PAYLOAD/repo"
PKG_DIR="$PAYLOAD/packages"
SOURCE_DIR="$PAYLOAD/sources"
BIN_DIR="$PAYLOAD/bin"
TARGETS_FILE="$PAYLOAD/targets.txt"
PROFILE_ROOT="$HOME/.local/share/desktop-profiles"
BACKUP_ROOT="$HOME/.local/share/desktop-profile-backups"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$BACKUP_ROOT/offline-restore-$STAMP"

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
        [[ "$default" == y ]]
        return
    fi
    if [[ "$default" == y ]]; then
        read -r -p "$prompt [Y/n] " ans < /dev/tty || true
        ans="${ans:-y}"
    else
        read -r -p "$prompt [y/N] " ans < /dev/tty || true
        ans="${ans:-n}"
    fi
    [[ "$ans" =~ ^[Yy]$ ]]
}

current_vendor() { cat /sys/class/dmi/id/sys_vendor 2>/dev/null || echo unknown; }
current_product() { cat /sys/class/dmi/id/product_name 2>/dev/null || echo unknown; }

is_g16() {
    local v p
    v="$(current_vendor)"; p="$(current_product)"
    [[ "$v" == *ASUS* || "$v" == *ASUSTeK* ]] || return 1
    [[ "$p" =~ GU60[35] || "$p" == *"Zephyrus G16"* || "$p" == *"ROG Zephyrus G16"* ]]
}

secure_boot_enabled() {
    [[ -d /sys/firmware/efi/efivars ]] || return 1
    local var
    var="$(find /sys/firmware/efi/efivars -maxdepth 1 -name 'SecureBoot-*' -print -quit 2>/dev/null || true)"
    [[ -n "$var" ]] || return 1
    od -An -t u1 -j 4 -N 1 "$var" 2>/dev/null | grep -Eq '[[:space:]]1[[:space:]]*$'
}

setup_mode_enabled() {
    [[ -d /sys/firmware/efi/efivars ]] || return 1
    local var
    var="$(find /sys/firmware/efi/efivars -maxdepth 1 -name 'SetupMode-*' -print -quit 2>/dev/null || true)"
    [[ -n "$var" ]] || return 1
    od -An -t u1 -j 4 -N 1 "$var" 2>/dev/null | grep -Eq '[[:space:]]1[[:space:]]*$'
}

backup_path() {
    local path="$1" name="$2"
    [[ -e "$path" || -L "$path" ]] || return 0
    mkdir -p "$BACKUP"
    cp -aL "$path" "$BACKUP/$name" 2>/dev/null || cp -a "$path" "$BACKUP/$name"
}

rewrite_home_paths_json() {
    local file="$1" tmp
    [[ -f "$file" ]] || return 0
    jq empty "$file" >/dev/null 2>&1 || return 0
    tmp="$(mktemp)"
    jq --arg home "$HOME" 'walk(if type == "string" then sub("^/home/[^/]+/"; ($home + "/")) else . end)' "$file" > "$tmp"
    mv "$tmp" "$file"
}

preflight_payload() {
    [[ -d "$REPO/dual-rice" ]] || die "Offline payload is missing the dotfiles snapshot"
    [[ -d "$PKG_DIR" ]] || die "Offline payload is missing package archives"
    [[ -f "$PKG_DIR/huzaifah-offline.db" || -f "$PKG_DIR/huzaifah-offline.db.tar.gz" ]] || die "Offline pacman repository database is missing"
    [[ -s "$TARGETS_FILE" ]] || die "Offline target package list is missing"
    for profile in caelestia end4 ambxst dms; do
        [[ -f "$REPO/dual-rice/profiles/$profile/hypr/hyprland.lua" ]] || die "Missing $profile profile in offline payload"
    done
    [[ -d "$SOURCE_DIR/end4-dots" ]] || die "Bundled end4-dots source is missing"
    [[ -d "$SOURCE_DIR/end4-pC" ]] || die "Bundled end4-pC source is missing"
    [[ -d "$SOURCE_DIR/ambxst" ]] || die "Bundled Ambxst source is missing"
    [[ -x "$BIN_DIR/axctl" ]] || die "Bundled axctl binary is missing"
    [[ -x "$REPO/scripts/install-refresh-switcher.sh" ]] || die "Bundled refresh switcher installer is missing"
    [[ -d "$REPO/machine/sddm/themes/sddm-frieren-theme" ]] || die "Bundled Frieren SDDM theme is missing"
}

verify_payload() {
    preflight_payload
    if [[ -f "$PAYLOAD/SHA256SUMS" ]]; then
        log "Verifying bundled payload checksums"
        (cd "$PAYLOAD" && sha256sum -c SHA256SUMS)
    else
        warn "Payload checksum manifest is missing"
    fi
}

make_pacman_conf() {
    local conf="$1"
    cat > "$conf" <<EOF
[options]
Architecture = auto
CheckSpace
SigLevel = Never
LocalFileSigLevel = Never

[huzaifah-offline]
SigLevel = Never
Server = file://$PKG_DIR
EOF
}

local_repo_has() {
    local pkg="$1" conf
    conf="$(mktemp --suffix=.conf)"
    make_pacman_conf "$conf"
    pacman --config "$conf" -Sl huzaifah-offline 2>/dev/null | awk '{print $2}' | grep -Fxq "$pkg"
    local rc=$?
    rm -f "$conf"
    return "$rc"
}

install_named_local() {
    local conf
    conf="$(mktemp --suffix=.conf)"
    make_pacman_conf "$conf"
    sudo pacman --config "$conf" -Syy --noconfirm >/dev/null
    sudo pacman --config "$conf" -S --needed --noconfirm "$@"
    rm -f "$conf"
}

handle_noctalia_provider_transition() {
    pacman -Q noctalia-qs >/dev/null 2>&1 || return 0
    local_repo_has quickshell-git || die "noctalia-qs is installed, but bundled quickshell-git is missing"

    warn "Existing noctalia-qs conflicts with the bundled Caelestia/Quickshell stack."
    warn "The installer can replace its Quickshell provider with bundled quickshell-git before continuing."
    prompt_yes_no "Replace noctalia-qs with quickshell-git?" y || die "Cannot install Multi-Rice while noctalia-qs owns the conflicting Quickshell provider"

    sudo pacman -Rdd --noconfirm noctalia-qs
    install_named_local quickshell-git
    ok "Provider transition complete: noctalia-qs -> quickshell-git"
}

install_all_local_packages() {
    local conf
    mapfile -t targets < <(grep -Ev '^[[:space:]]*(#|$)' "$TARGETS_FILE" | sort -u)
    ((${#targets[@]})) || die "Offline target package list is empty"

    handle_noctalia_provider_transition

    conf="$(mktemp --suffix=.conf)"
    make_pacman_conf "$conf"
    log "Installing ${#targets[@]} targets from the embedded local pacman repository"
    sudo pacman --config "$conf" -Syy --noconfirm
    sudo pacman --config "$conf" -S --needed --noconfirm "${targets[@]}"
    rm -f "$conf"
}

preflight_report() {
    verify_payload
    printf '\nHuzaifah Multi-Rice OFFLINE Preflight\n'
    printf '====================================\n'
    printf 'OS:            '; grep '^PRETTY_NAME=' /etc/os-release 2>/dev/null | cut -d= -f2- | tr -d '"'
    printf 'Architecture:  %s\n' "$(uname -m)"
    printf 'Machine:       %s / %s\n' "$(current_vendor)" "$(current_product)"
    printf 'UEFI boot:     %s\n' "$([[ -d /sys/firmware/efi ]] && echo yes || echo no)"
    printf 'Secure Boot:   %s\n' "$(secure_boot_enabled && echo enabled || echo disabled)"
    printf 'Setup Mode:    %s\n' "$(setup_mode_enabled && echo enabled || echo disabled)"
    printf 'G16 profile:   %s\n' "$(is_g16 && echo yes || echo no)"
    printf 'Free space /:  %s\n' "$(df -h --output=avail / | tail -1 | xargs)"
    if pacman -Q noctalia-qs >/dev/null 2>&1; then
        printf 'Conflict:      noctalia-qs detected; automatic provider transition available\n'
    else
        printf 'Conflict:      no known Quickshell provider conflict detected\n'
    fi
    printf 'Network:       not required\n'
    printf '\nPRE-FLIGHT RESULT: payload is complete and ready for offline installation.\n'
}

restore_profiles_and_configs() {
    local src="$REPO/dual-rice"
    log "Creating safety backup before profile restore"
    mkdir -p "$BACKUP"
    backup_path "$HOME/.config/hypr" hypr
    backup_path "$HOME/.config/caelestia" caelestia
    backup_path "$HOME/.config/illogical-impulse" illogical-impulse
    backup_path "$HOME/.config/ambxst" ambxst-config
    backup_path "$HOME/.config/DankMaterialShell" dms-config
    backup_path "$HOME/.local/share/ambxst" ambxst-share
    backup_path "$HOME/.local/src/ambxst" ambxst-source
    backup_path "$HOME/.cache/ambxst/wallpapers.json" ambxst-wallpapers.json
    backup_path "$HOME/.config/desktop-switcher" desktop-switcher
    backup_path "$PROFILE_ROOT" desktop-profiles
    backup_path "$HOME/.local/bin/desktop-switch" desktop-switch
    backup_path "$HOME/.local/bin/recover-caelestia" recover-caelestia

    log "Restoring Caelestia, end4-pC, Ambxst and DMS profiles"
    for profile in caelestia end4 ambxst dms; do
        mkdir -p "$PROFILE_ROOT/$profile/hypr"
        rsync -a --delete "$src/profiles/$profile/hypr/" "$PROFILE_ROOT/$profile/hypr/"
    done

    if [[ -d "$src/caelestia" ]]; then
        mkdir -p "$HOME/.config/caelestia"
        rsync -a --delete "$src/caelestia/" "$HOME/.config/caelestia/"
        rewrite_home_paths_json "$HOME/.config/caelestia/shell.json"
    fi
    if [[ -f "$src/end4/config.json" ]]; then
        mkdir -p "$HOME/.config/illogical-impulse"
        cp -a "$src/end4/config.json" "$HOME/.config/illogical-impulse/config.json"
        rewrite_home_paths_json "$HOME/.config/illogical-impulse/config.json"
    fi
    if [[ -d "$src/ambxst/config" ]] && find "$src/ambxst/config" -mindepth 1 -print -quit | grep -q .; then
        mkdir -p "$HOME/.config/ambxst"
        rsync -a --delete "$src/ambxst/config/" "$HOME/.config/ambxst/"
    fi
    if [[ -f "$src/ambxst/wallpapers.json" ]]; then
        mkdir -p "$HOME/.cache/ambxst"
        cp -a "$src/ambxst/wallpapers.json" "$HOME/.cache/ambxst/wallpapers.json"
        rewrite_home_paths_json "$HOME/.cache/ambxst/wallpapers.json"
    fi
    if [[ -d "$src/dms/config" ]] && find "$src/dms/config" -mindepth 1 -print -quit | grep -q .; then
        mkdir -p "$HOME/.config/DankMaterialShell"
        rsync -a --delete "$src/dms/config/" "$HOME/.config/DankMaterialShell/"
        while IFS= read -r json; do rewrite_home_paths_json "$json"; done < <(find "$HOME/.config/DankMaterialShell" -type f -name '*.json' -print)
    fi
    if [[ -d "$src/desktop-switcher" ]]; then
        mkdir -p "$HOME/.config/desktop-switcher"
        rsync -a --delete "$src/desktop-switcher/" "$HOME/.config/desktop-switcher/"
    fi

    mkdir -p "$HOME/.local/bin"
    for bin in desktop-switch recover-caelestia; do
        [[ -f "$src/bin/$bin" ]] && install -m 0755 "$src/bin/$bin" "$HOME/.local/bin/$bin"
    done
}

restore_bundled_sources() {
    log "Installing bundled end4-pC, end4-dots and Ambxst source snapshots"
    mkdir -p "$HOME/.config/quickshell" "$HOME/.local/src" "$HOME/.local/bin"
    rm -rf "$HOME/.local/src/end4-dots" "$HOME/.config/quickshell/end4-pC" "$HOME/.local/src/ambxst" "$HOME/.config/quickshell/ii"
    cp -a "$SOURCE_DIR/end4-dots" "$HOME/.local/src/end4-dots"
    [[ -d "$HOME/.local/src/end4-dots/dots/.config/quickshell/ii" ]] || die "Bundled end4-dots source lacks quickshell/ii"
    cp -a "$HOME/.local/src/end4-dots/dots/.config/quickshell/ii" "$HOME/.config/quickshell/ii"
    cp -a "$SOURCE_DIR/end4-pC" "$HOME/.config/quickshell/end4-pC"
    cp -a "$SOURCE_DIR/ambxst" "$HOME/.local/src/ambxst"
    chmod +x "$HOME/.local/src/ambxst/cli.sh"
    sudo install -m 0755 "$BIN_DIR/axctl" /usr/local/bin/axctl

    cat > "$HOME/.local/bin/ambxst" <<'EOF'
#!/usr/bin/env bash
export PATH="$HOME/.local/bin:$PATH"
export QML2_IMPORT_PATH="$HOME/.local/lib/qml:${QML2_IMPORT_PATH:-}"
export QML_IMPORT_PATH="$QML2_IMPORT_PATH"
exec "$HOME/.local/src/ambxst/cli.sh" "$@"
EOF
    chmod +x "$HOME/.local/bin/ambxst"
    sudo tee /usr/local/bin/ambxst >/dev/null <<'EOF'
#!/usr/bin/env bash
exec "$HOME/.local/bin/ambxst" "$@"
EOF
    sudo chmod +x /usr/local/bin/ambxst
    command -v fish >/dev/null 2>&1 && fish -c 'fish_add_path ~/.local/bin' >/dev/null 2>&1 || true
}

configure_end4_search_only() {
    local config="$HOME/.config/illogical-impulse/config.json" tmp
    mkdir -p "$(dirname "$config")"
    [[ -f "$config" ]] || printf '{}\n' > "$config"
    jq empty "$config" >/dev/null 2>&1 || return 0
    tmp="$(mktemp)"
    jq '.overview = (.overview // {}) | .overview.enable = false' "$config" > "$tmp"
    mv "$tmp" "$config"
}

install_frieren_theme() {
    local theme_src="$REPO/machine/sddm/themes/sddm-frieren-theme"
    local theme_dst="/usr/share/sddm/themes/sddm-frieren-theme"
    local root_backup="/var/backups/huzaifah-multi-rice/sddm-$STAMP"
    sudo mkdir -p "$root_backup" /etc/sddm.conf.d /usr/share/sddm/themes
    sudo test -d "$theme_dst" && sudo cp -a "$theme_dst" "$root_backup/" || true
    sudo test -f /etc/sddm.conf.d/90-huzaifah-theme.conf && sudo cp -a /etc/sddm.conf.d/90-huzaifah-theme.conf "$root_backup/" || true
    sudo rm -rf "$theme_dst"
    sudo cp -a "$theme_src" "$theme_dst"
    printf '[Theme]\nCurrent=sddm-frieren-theme\n' | sudo tee /etc/sddm.conf.d/90-huzaifah-theme.conf >/dev/null
    ok "Frieren SDDM login theme installed; display-manager/autologin state unchanged"
}

activate_saved_profile() {
    local active=caelestia
    [[ -f "$REPO/dual-rice/state/active" ]] && active="$(tr -d '[:space:]' < "$REPO/dual-rice/state/active")"
    case "$active" in caelestia|end4|ambxst|dms) ;; *) active=caelestia ;; esac
    rm -rf "$HOME/.config/hypr"
    ln -s "$PROFILE_ROOT/$active/hypr" "$HOME/.config/hypr"
    mkdir -p "$HOME/.config/desktop-profile"
    printf '%s\n' "$active" > "$HOME/.config/desktop-profile/active"
}

install_refresh_switcher() {
    install_named_local jq fuzzel upower
    bash "$REPO/scripts/install-refresh-switcher.sh" --auto
}

install_multi_rice() {
    verify_payload
    install_all_local_packages
    systemctl --user disable --now dms.service >/dev/null 2>&1 || true
    restore_profiles_and_configs
    restore_bundled_sources
    configure_end4_search_only
    activate_saved_profile
    install_refresh_switcher
    install_frieren_theme
    ok "Fully offline Multi-Rice installation completed"
    printf 'Safety backup: %s\n' "$BACKUP"
    printf 'No internet connection was required.\n'
}

run_system_setup() {
    local cmd="$1"; shift || true
    [[ -x "$REPO/system-setup.sh" ]] || die "Bundled system-setup.sh is missing"
    bash "$REPO/system-setup.sh" "$cmd" "$@"
}

find_refind_binary() {
    local esp p
    for esp in /boot/efi /efi /boot; do
        for p in "$esp/EFI/refind/refind_x64.efi" "$esp/EFI/REFIND/refind_x64.efi"; do
            [[ -f "$p" ]] && { printf '%s\n' "$p"; return 0; }
        done
    done
    return 1
}

sign_known_secure_boot_files() {
    local refind kernel
    refind="$(find_refind_binary || true)"
    [[ -n "$refind" ]] || die "rEFInd EFI binary was not found. Configure rEFInd first, then rerun Secure Boot setup."

    log "Registering/signing rEFInd with sbctl"
    sudo sbctl sign -s "$refind"

    local found=0
    for kernel in /boot/vmlinuz-*; do
        [[ -f "$kernel" ]] || continue
        found=1
        log "Registering/signing $(basename "$kernel")"
        sudo sbctl sign -s "$kernel"
    done
    (( found )) || warn "No /boot/vmlinuz-* kernel images were found; verify your UKI/kernel signing separately."
}

secure_boot_setup() {
    [[ -d /sys/firmware/efi ]] || die "System was not booted in UEFI mode"
    verify_payload
    install_named_local sbctl

    printf '\nCurrent Secure Boot status:\n'
    sudo sbctl status || true

    if secure_boot_enabled; then
        ok "Secure Boot is already enabled in firmware"
        printf '\nVerification only; no firmware keys will be changed.\n'
        sudo sbctl verify || true
        return 0
    fi

    if ! setup_mode_enabled; then
        warn "Firmware is not in Secure Boot Setup Mode."
        printf '\nBefore key enrollment, reboot into firmware settings and:\n'
        printf '  1. Disable Secure Boot.\n'
        printf '  2. Clear/delete the existing Secure Boot keys or select Custom/Setup Mode.\n'
        printf '  3. Boot Linux again and rerun this Secure Boot option.\n'
        printf '\nNo firmware keys were changed.\n'
        return 2
    fi

    [[ -n "$(find_refind_binary || true)" ]] || die "Configure rEFInd first. Secure Boot setup will not enroll keys without a known rEFInd binary to sign."

    warn "SECURE BOOT KEY ENROLLMENT CHANGES UEFI FIRMWARE VARIABLES."
    warn "This guided flow enrolls your sbctl keys together with Microsoft's keys (-m), preserving normal Windows/Microsoft trust."
    warn "Firmware implementations vary; incorrect key enrollment can make some pre-boot devices unavailable."
    printf '\nType ENROLL to continue, or anything else to cancel: '
    local ans
    read -r ans < /dev/tty || true
    [[ "$ans" == ENROLL ]] || { log "Secure Boot enrollment cancelled"; return 0; }

    if ! sudo test -d /var/lib/sbctl/keys; then
        sudo sbctl create-keys
    else
        log "Existing sbctl key directory detected; keeping the existing keys"
    fi

    sudo sbctl enroll-keys -m
    sign_known_secure_boot_files

    printf '\nPost-enrollment verification:\n'
    sudo sbctl status || true
    sudo sbctl verify || true

    ok "Keys enrolled and known Linux/rEFInd boot files registered with sbctl"
    printf '\nNext step is MANUAL: reboot into firmware and enable Secure Boot.\n'
    printf 'Do not delete Microsoft keys; this flow intentionally enrolled them alongside your keys.\n'
}

status_report() {
    printf '\nHuzaifah Multi-Rice OFFLINE Status\n'
    printf '==================================\n'
    printf 'Machine:       %s / %s\n' "$(current_vendor)" "$(current_product)"
    printf 'G16 detected:  %s\n' "$(is_g16 && echo yes || echo no)"
    printf 'Secure Boot:   %s\n' "$(secure_boot_enabled && echo enabled || echo disabled)"
    printf 'Setup Mode:    %s\n' "$(setup_mode_enabled && echo enabled || echo disabled)"
    [[ -f "$PAYLOAD/manifest.txt" ]] && { printf '\nPayload manifest:\n'; cat "$PAYLOAD/manifest.txt"; }
    printf '\nSystem setup status:\n'
    run_system_setup status || true
}

usage() {
    cat <<'EOF'
Usage: install-offline.sh ACTION

Actions:
  preflight     Verify payload and target-machine readiness without changing it
  install       Install all four rices + switchers + Frieren SDDM theme
  refresh       Install/reconfigure SUPER+SHIFT+R refresh switcher
  sddm          Install Frieren SDDM theme only
  asus          Install generic ASUS support (asusctl/ROG Control Center)
  g16           Install guarded Zephyrus G16 extras
  refind        Configure rEFInd safely using the bundled theme
  secureboot    Guided sbctl Secure Boot setup with explicit enrollment gate
  hibernate     Configure guarded Btrfs hibernation storage
  status        Show machine/offline-payload status
EOF
}

main() {
    local action="${1:-install}"
    is_arch_family || die "This offline installer supports Arch/CachyOS-family systems only"
    [[ "$(uname -m)" == x86_64 ]] || die "This offline build targets x86_64 only"
    case "$action" in
        preflight) preflight_report ;;
        install) install_multi_rice ;;
        refresh) verify_payload; install_refresh_switcher ;;
        sddm) verify_payload; install_named_local sddm rsync; install_frieren_theme ;;
        asus) verify_payload; install_named_local asusctl rog-control-center power-profiles-daemon; run_system_setup asus ;;
        g16) verify_payload; install_named_local asusctl rog-control-center power-profiles-daemon supergfxctl; run_system_setup g16 ;;
        refind) verify_payload; install_named_local refind efibootmgr; run_system_setup refind ;;
        secureboot) secure_boot_setup ;;
        hibernate) verify_payload; install_named_local btrfs-progs; run_system_setup hibernate ;;
        status) status_report ;;
        help|-h|--help) usage ;;
        *) die "Unknown action: $action" ;;
    esac
}

main "$@"
