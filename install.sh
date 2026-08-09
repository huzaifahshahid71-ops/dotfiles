#!/usr/bin/env bash

set -Eeuo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

# ---------------------------------------------------------
# Pretty output
# ---------------------------------------------------------

info() {
    printf "\n\033[1;36m==> %s\033[0m\n" "$*"
}

success() {
    printf "\033[1;32m✓ %s\033[0m\n" "$*"
}

warn() {
    printf "\033[1;33m! %s\033[0m\n" "$*"
}

die() {
    printf "\033[1;31mERROR: %s\033[0m\n" "$*" >&2
    exit 1
}

trap 'echo "Installer failed near line $LINENO."' ERR

echo
echo "=============================================="
echo "     Huzaifah's CachyOS / Hyprland Setup"
echo "=============================================="
echo

# ---------------------------------------------------------
# Checks
# ---------------------------------------------------------

[[ -f /etc/arch-release ]] || \
    die "This installer is intended for Arch Linux / CachyOS."

[[ "$EUID" -ne 0 ]] || \
    die "Run this script as your normal user, NOT with sudo."

command -v sudo >/dev/null || \
    die "sudo is required."

info "Requesting sudo access"
sudo -v

# ---------------------------------------------------------
# Update system + install main packages
# ---------------------------------------------------------

info "Updating system and installing desktop dependencies"

PACMAN_PACKAGES=(
    base-devel
    git
    stow

    hyprland
    hypridle
    hyprlock
    hyprpicker
    hyprsunset

    xdg-desktop-portal-hyprland
    xdg-desktop-portal-gtk
    xdg-user-dirs
    xdg-utils

    fish
    foot
    starship
    fastfetch
    btop
    eza
    jq

    mpv
    playerctl
    pavucontrol

    pipewire
    pipewire-alsa
    pipewire-pulse
    wireplumber

    brightnessctl
    upower

    networkmanager

    bluez
    bluez-utils

    wl-clipboard
    cliphist

    grim
    slurp
    swappy

    fuzzel

    libnotify
    dconf

    inotify-tools
    trash-cli

    lm_sensors

    noto-fonts
    noto-fonts-emoji
    ttf-jetbrains-mono-nerd
    ttf-cascadia-code-nerd
    ttf-nerd-fonts-symbols

    papirus-icon-theme
    adw-gtk-theme
)

sudo pacman -Syu \
    --needed \
    --noconfirm \
    "${PACMAN_PACKAGES[@]}"

success "Main packages installed"

# ---------------------------------------------------------
# Install paru
# ---------------------------------------------------------

if command -v paru >/dev/null 2>&1; then

    success "paru is already installed"

else

    info "Installing paru"

    # CachyOS ships paru in its repositories.
    if sudo pacman -S --needed --noconfirm paru; then

        success "paru installed from system repository"

    else

        warn "paru was not available from the system repository."
        info "Building paru from the AUR"

        sudo pacman -S --needed --noconfirm \
            base-devel \
            git \
            rust

        PARU_BUILD="$(mktemp -d)"

        git clone \
            https://aur.archlinux.org/paru.git \
            "$PARU_BUILD/paru"

        (
            cd "$PARU_BUILD/paru"
            makepkg -si --needed --noconfirm
        )

        rm -rf "$PARU_BUILD"

        success "paru built and installed"
    fi
fi

command -v paru >/dev/null 2>&1 || \
    die "paru installation failed."

# ---------------------------------------------------------
# DIM Caelestia
# ---------------------------------------------------------

info "Installing DIM Caelestia Shell"

paru -S \
    --needed \
    --noconfirm \
    dim-caelestia-shell-git

success "DIM Caelestia installed"

# ---------------------------------------------------------
# app2unit
# ---------------------------------------------------------

info "Installing Caelestia application helper"

paru -S \
    --needed \
    --noconfirm \
    app2unit

success "app2unit installed"

# ---------------------------------------------------------
# Create standard folders
# ---------------------------------------------------------

info "Creating user directories"

xdg-user-dirs-update || true

mkdir -p \
    "$HOME/.config" \
    "$HOME/.local/bin" \
    "$HOME/.config/systemd/user" \
    "$HOME/Pictures/Wallpapers" \
    "$HOME/Music"

# ---------------------------------------------------------
# Backup function
# ---------------------------------------------------------

backup_path() {

    local path="$1"

    [[ -e "$path" || -L "$path" ]] || return 0

    # Ignore links already pointing into this repository
    if [[ -L "$path" ]]; then

        local resolved
        resolved="$(readlink -f "$path" 2>/dev/null || true)"

        case "$resolved" in
            "$REPO_DIR"/*)
                return 0
                ;;
        esac
    fi

    local relative="${path#"$HOME"/}"
    local destination="$BACKUP_DIR/$relative"

    mkdir -p "$(dirname "$destination")"

    echo "Backing up:"
    echo "  $path"
    echo "  -> $destination"

    mv "$path" "$destination"
}

info "Backing up conflicting configuration"

mkdir -p "$BACKUP_DIR"

# Whole configuration directories
backup_path "$HOME/.config/hypr"
backup_path "$HOME/.config/caelestia"
backup_path "$HOME/.config/fish"
backup_path "$HOME/.config/mpv"

# Individual systemd services
if [[ -d "$REPO_DIR/systemd/.config/systemd/user" ]]; then

    for src in "$REPO_DIR/systemd/.config/systemd/user/"*; do

        [[ -e "$src" ]] || continue

        backup_path \
            "$HOME/.config/systemd/user/$(basename "$src")"

    done
fi

# Individual helper scripts
if [[ -d "$REPO_DIR/scripts/.local/bin" ]]; then

    for src in "$REPO_DIR/scripts/.local/bin/"*; do

        [[ -e "$src" ]] || continue

        backup_path \
            "$HOME/.local/bin/$(basename "$src")"

    done
fi

success "Existing conflicting configs backed up"

# ---------------------------------------------------------
# GNU Stow
# ---------------------------------------------------------

info "Applying dotfiles with GNU Stow"

cd "$REPO_DIR"

STOW_PACKAGES=(
    caelestia
    fish
    hypr
    mpv
    scripts
    systemd
)

for package in "${STOW_PACKAGES[@]}"; do

    if [[ -d "$package" ]]; then

        echo "Stowing $package..."

        stow \
            --restow \
            --target="$HOME" \
            "$package"

    fi
done

success "Dotfiles applied"

# ---------------------------------------------------------
# Fish shell
# ---------------------------------------------------------

info "Configuring Fish"

FISH_PATH="$(command -v fish)"

if ! grep -Fxq "$FISH_PATH" /etc/shells; then
    echo "$FISH_PATH" | sudo tee -a /etc/shells >/dev/null
fi

CURRENT_LOGIN_SHELL="$(getent passwd "$USER" | cut -d: -f7)"

if [[ "$CURRENT_LOGIN_SHELL" != "$FISH_PATH" ]]; then

    chsh -s "$FISH_PATH"

    success "Fish set as default shell"

else

    success "Fish is already the default shell"
fi

# ---------------------------------------------------------
# Audio
# ---------------------------------------------------------

info "Starting PipeWire audio"

systemctl --user enable --now pipewire.socket \
    2>/dev/null || true

systemctl --user enable --now pipewire-pulse.socket \
    2>/dev/null || true

systemctl --user enable --now wireplumber.service \
    2>/dev/null || true

# ---------------------------------------------------------
# Bluetooth
# ---------------------------------------------------------

info "Enabling Bluetooth"

sudo systemctl enable --now bluetooth.service \
    2>/dev/null || true

# ---------------------------------------------------------
# NetworkManager
# ---------------------------------------------------------

if systemctl is-active --quiet NetworkManager; then

    success "NetworkManager already running"

elif systemctl is-active --quiet systemd-networkd ||
     systemctl is-active --quiet iwd; then

    warn "Another network service is already active."
    warn "NetworkManager was installed but NOT automatically enabled."

else

    info "Enabling NetworkManager"

    sudo systemctl enable --now NetworkManager.service \
        2>/dev/null || true
fi

# ---------------------------------------------------------
# Hyprsunset / Night Light
# ---------------------------------------------------------

info "Enabling Hyprsunset"

systemctl --user enable --now hyprsunset.service \
    2>/dev/null || true

# ---------------------------------------------------------
# Background music playlist
# ---------------------------------------------------------

PLAYLIST="$HOME/Music/Favorites.m3u8"

if [[ ! -f "$PLAYLIST" ]]; then

    info "Looking for music in ~/Music"

    mapfile -d '' TRACKS < <(
        find "$HOME/Music" \
            -maxdepth 1 \
            -type f \
            \( \
                -iname '*.mp3' \
                -o -iname '*.flac' \
                -o -iname '*.m4a' \
                -o -iname '*.ogg' \
                -o -iname '*.opus' \
                -o -iname '*.wav' \
            \) \
            -print0 |
        sort -z
    )

    if (( ${#TRACKS[@]} > 0 )); then

        {
            echo "#EXTM3U"
            printf '%s\n' "${TRACKS[@]}"
        } > "$PLAYLIST"

        success "Generated Favorites.m3u8"

    else

        warn "No music found in ~/Music."
        warn "Background music will remain disabled."

    fi
fi

# ---------------------------------------------------------
# Reload systemd user units
# ---------------------------------------------------------

systemctl --user daemon-reload

# ---------------------------------------------------------
# Background music
# ---------------------------------------------------------

if [[ -f "$PLAYLIST" ]] &&
   grep -qvE '^[[:space:]]*(#|$)' "$PLAYLIST"; then

    if systemctl --user list-unit-files \
        | grep -q '^background-music.service'; then

        info "Enabling background music"

        systemctl --user enable \
            background-music.service || true

        systemctl --user restart \
            background-music.service || true

    fi
fi

# ---------------------------------------------------------
# IMPORTANT:
# Do not enable Huzaifah's custom display modeline automatically
# ---------------------------------------------------------

if systemctl --user list-unit-files \
    | grep -q '^auto-refresh-rate.service'; then

    systemctl --user disable --now \
        auto-refresh-rate.service \
        2>/dev/null || true
fi

warn "Custom 120/240 Hz automatic refresh switching was NOT enabled."
warn "It contains a modeline specific to Huzaifah's laptop panel."

# ---------------------------------------------------------
# Final sanity checks
# ---------------------------------------------------------

info "Checking installation"

command -v Hyprland >/dev/null &&
    success "Hyprland installed"

command -v fish >/dev/null &&
    success "Fish installed"

command -v mpv >/dev/null &&
    success "mpv installed"

command -v caelestia >/dev/null &&
    success "Caelestia CLI installed"

command -v paru >/dev/null &&
    success "paru installed"

command -v stow >/dev/null &&
    success "GNU Stow installed"

# ---------------------------------------------------------
# Done
# ---------------------------------------------------------

echo
echo "=================================================="
echo "              INSTALLATION COMPLETE"
echo "=================================================="
echo
echo "Previous configuration backup:"
echo
echo "  $BACKUP_DIR"
echo
echo "Wallpapers:"
echo
echo "  ~/Pictures/Wallpapers"
echo
echo "Music:"
echo
echo "  ~/Music"
echo
echo "Playlist:"
echo
echo "  ~/Music/Favorites.m3u8"
echo
echo "IMPORTANT:"
echo
echo "  Log out and log back in before using the setup."
echo
echo "  Select Hyprland from your login manager."
echo
echo "  The custom 120/240 Hz service is disabled by default"
echo "  because it is hardware-specific."
echo
echo "Useful checks:"
echo
echo "  hyprctl monitors"
echo "  caelestia shell -d"
echo
echo "  systemctl --user status background-music.service"
echo
echo "=================================================="
echo
