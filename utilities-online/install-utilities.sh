#!/usr/bin/env bash
set -Eeuo pipefail

TITLE="Huzaifah Utilities"
AUR_HELPER=""
FAILURES=0

log() { printf '\n[%s] %s\n' "$TITLE" "$*"; }
warn() { printf '\n[%s] WARNING: %s\n' "$TITLE" "$*" >&2; }

is_installed() { pacman -Q "$1" >/dev/null 2>&1; }

pac_install() {
    local pkgs=() p
    for p in "$@"; do
        is_installed "$p" || pkgs+=("$p")
    done
    ((${#pkgs[@]} == 0)) && return 0
    log "Installing official packages: ${pkgs[*]}"
    sudo pacman -S --needed --noconfirm "${pkgs[@]}"
}

ensure_aur_helper() {
    if command -v paru >/dev/null 2>&1; then AUR_HELPER=paru; return 0; fi
    if command -v yay >/dev/null 2>&1; then AUR_HELPER=yay; return 0; fi

    log "No AUR helper found. Bootstrapping paru-bin..."
    pac_install base-devel git
    local tmp
    tmp="$(mktemp -d)"
    trap 'rm -rf "${tmp:-}"' RETURN
    git clone https://aur.archlinux.org/paru-bin.git "$tmp/paru-bin"
    (
        cd "$tmp/paru-bin"
        makepkg -si --noconfirm
    )
    AUR_HELPER=paru
    rm -rf "$tmp"
    trap - RETURN
}

aur_install() {
    ensure_aur_helper
    local pkgs=() p
    for p in "$@"; do
        is_installed "$p" || pkgs+=("$p")
    done
    ((${#pkgs[@]} == 0)) && return 0
    log "Installing AUR packages: ${pkgs[*]}"
    if [[ "$AUR_HELPER" == paru ]]; then
        paru -S --needed --noconfirm --skipreview "${pkgs[@]}"
    else
        yay -S --needed --noconfirm "${pkgs[@]}"
    fi
}

install_chrome() {
    aur_install google-chrome
}

install_onlyoffice() {
    aur_install onlyoffice-bin
}

install_waydroid() {
    pac_install waydroid

    if [[ ! -d /var/lib/waydroid/images || -z "$(find /var/lib/waydroid/images -maxdepth 1 -type f 2>/dev/null | head -n1)" ]]; then
        log "Initializing Waydroid (downloads the current Android image)..."
        if ! sudo waydroid init; then
            warn "Waydroid package installed, but initialization failed. You can retry later with: sudo waydroid init"
            FAILURES=$((FAILURES + 1))
        fi
    else
        log "Waydroid already initialized; skipping image download."
    fi

    if systemctl list-unit-files waydroid-container.service >/dev/null 2>&1; then
        sudo systemctl enable --now waydroid-container.service || true
    fi
}

install_vm() {
    if ! grep -Eq '(vmx|svm)' /proc/cpuinfo; then
        warn "CPU virtualization flags are not visible. Check that Intel VT-x/AMD-V is enabled in firmware."
    fi

    pac_install qemu-full virt-manager virt-viewer libvirt dnsmasq edk2-ovmf swtpm iptables-nft

    if getent group libvirt >/dev/null 2>&1; then
        sudo usermod -aG libvirt "$USER"
    fi
    if getent group kvm >/dev/null 2>&1; then
        sudo usermod -aG kvm "$USER"
    fi

    if systemctl list-unit-files libvirtd.service 2>/dev/null | grep -q '^libvirtd.service'; then
        sudo systemctl enable --now libvirtd.service
    else
        sudo systemctl enable --now virtqemud.socket 2>/dev/null || true
        sudo systemctl enable --now virtnetworkd.socket 2>/dev/null || true
    fi

    if [[ -f /usr/share/libvirt/networks/default.xml ]]; then
        if ! sudo virsh net-info default >/dev/null 2>&1; then
            sudo virsh net-define /usr/share/libvirt/networks/default.xml >/dev/null
        fi
        sudo virsh net-autostart default >/dev/null 2>&1 || true
        sudo virsh net-start default >/dev/null 2>&1 || true
    fi

    log "VM stack ready. Log out and back in once so libvirt/kvm group membership applies."
}

install_btop() {
    pac_install btop
}

install_dolphin() {
    pac_install dolphin
}

pkg_state() {
    local pkg="$1" label="$2"
    if is_installed "$pkg"; then
        printf '  ✓ %-24s %s\n' "$label" "$(pacman -Q "$pkg" | awk '{print $2}')"
    else
        printf '  · %-24s not installed\n' "$label"
    fi
}

show_status() {
    printf '\nInstalled status\n================\n'
    pkg_state google-chrome "Google Chrome"
    pkg_state onlyoffice-bin "ONLYOFFICE"
    pkg_state waydroid "Waydroid"
    pkg_state virt-manager "virt-manager"
    pkg_state qemu-full "QEMU full"
    pkg_state libvirt "libvirt"
    pkg_state btop "btop"
    pkg_state dolphin "Dolphin"
    printf '\n'
    if command -v waydroid >/dev/null 2>&1; then
        systemctl is-enabled waydroid-container.service >/dev/null 2>&1 && printf '  ✓ Waydroid container service enabled\n' || printf '  · Waydroid container service not enabled\n'
    fi
    if command -v virsh >/dev/null 2>&1; then
        if sudo -n virsh net-info default >/dev/null 2>&1; then
            printf '  ✓ libvirt default network available\n'
        else
            printf '  · libvirt default network status requires sudo or is not configured\n'
        fi
    fi
}

install_selected() {
    (($# > 0)) || { warn "No utilities selected."; return 1; }
    local item
    for item in "$@"; do
        case "$item" in
            chrome) install_chrome || FAILURES=$((FAILURES + 1)) ;;
            onlyoffice) install_onlyoffice || FAILURES=$((FAILURES + 1)) ;;
            waydroid) install_waydroid || FAILURES=$((FAILURES + 1)) ;;
            vm) install_vm || FAILURES=$((FAILURES + 1)) ;;
            btop) install_btop || FAILURES=$((FAILURES + 1)) ;;
            dolphin) install_dolphin || FAILURES=$((FAILURES + 1)) ;;
            *) warn "Unknown utility id: $item"; FAILURES=$((FAILURES + 1)) ;;
        esac
    done

    printf '\n'
    if ((FAILURES == 0)); then
        log "All selected utilities completed successfully."
        return 0
    fi
    warn "$FAILURES selected step(s) reported an error. Review the log above."
    return 1
}

main() {
    ((EUID != 0)) || { warn "Run Utilities as your normal user, not as root. It will request sudo only when required."; exit 1; }
    [[ -r /etc/os-release ]] || { warn "/etc/os-release is missing."; exit 1; }
    . /etc/os-release
    [[ "${ID:-}" == arch || "${ID:-}" == cachyos || "${ID_LIKE:-}" == *arch* ]] || {
        warn "This installer supports Arch/CachyOS-family systems only."
        exit 1
    }
    [[ "$(uname -m)" == x86_64 ]] || { warn "x86_64 is required."; exit 1; }
    command -v pacman >/dev/null 2>&1 || { warn "pacman was not found."; exit 1; }

    local action="${1:-status}"
    shift || true
    case "$action" in
        install) install_selected "$@" ;;
        status) show_status ;;
        *) warn "Unknown action: $action"; exit 1 ;;
    esac
}

main "$@"
