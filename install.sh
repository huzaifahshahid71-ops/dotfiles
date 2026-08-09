#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

echo
echo "======================================"
echo "   Huzaifah's CachyOS Dotfiles Setup"
echo "======================================"
echo

# ---------------------------------------------------------
# Basic checks
# ---------------------------------------------------------

if ! command -v pacman >/dev/null 2>&1; then
    echo "This installer is intended for Arch Linux / CachyOS."
    exit 1
fi

echo "Repository: $REPO_DIR"
echo "Backup:     $BACKUP_DIR"
echo

# ---------------------------------------------------------
# Install normal repository packages
# ---------------------------------------------------------

echo "Installing required packages..."

sudo pacman -S --needed \
    git \
    stow \
    fish \
    mpv \
    jq \
    hyprsunset

echo

# ---------------------------------------------------------
# DIM Caelestia
# ---------------------------------------------------------

if command -v paru >/dev/null 2>&1; then
    echo "Installing DIM Caelestia Shell..."
    paru -S --needed dim-caelestia-shell-git
else
    echo
    echo "paru was not found."
    echo "DIM Caelestia will NOT be installed automatically."
    echo
    echo "Install an AUR helper, then run:"
    echo "  paru -S dim-caelestia-shell-git"
    echo
fi

# ---------------------------------------------------------
# Back up files that would conflict with Stow
# ---------------------------------------------------------

mkdir -p "$BACKUP_DIR"

backup_conflicts() {
    local package="$1"

    echo "Checking $package..."

    while IFS= read -r -d '' source; do
        local relative="${source#"$REPO_DIR/$package/"}"
        local target="$HOME/$relative"

        if [[ -e "$target" || -L "$target" ]]; then

            # Don't back up a symlink that already points into this repo.
            if [[ -L "$target" ]]; then
                resolved="$(readlink -f "$target" 2>/dev/null || true)"

                case "$resolved" in
                    "$REPO_DIR"/*)
                        continue
                        ;;
                esac
            fi

            backup="$BACKUP_DIR/$relative"

            mkdir -p "$(dirname "$backup")"

            echo "  backing up $target"
            mv "$target" "$backup"
        fi
    done < <(
        find "$REPO_DIR/$package" \
            \( -type f -o -type l \) \
            -print0
    )
}

PACKAGES=(
    caelestia
    fish
    hypr
    mpv
    scripts
    systemd
)

echo
echo "Backing up conflicting files..."

for package in "${PACKAGES[@]}"; do
    if [[ -d "$REPO_DIR/$package" ]]; then
        backup_conflicts "$package"
    fi
done

# ---------------------------------------------------------
# Apply dotfiles with GNU Stow
# ---------------------------------------------------------

echo
echo "Applying dotfiles..."

cd "$REPO_DIR"

for package in "${PACKAGES[@]}"; do
    if [[ -d "$package" ]]; then
        echo "Stowing $package..."
        stow \
            --restow \
            --target="$HOME" \
            "$package"
    fi
done

# ---------------------------------------------------------
# systemd services
# ---------------------------------------------------------

echo
echo "Reloading user systemd..."

systemctl --user daemon-reload

# Night Light
if systemctl --user list-unit-files \
    | grep -q '^hyprsunset.service'; then

    systemctl --user enable --now hyprsunset.service || true
fi

# Background music
if [[ -f "$HOME/Music/Favorites.m3u8" ]]; then

    echo "Favorites.m3u8 found."

    if systemctl --user list-unit-files \
        | grep -q '^background-music.service'; then

        systemctl --user enable --now background-music.service
    fi

else
    echo
    echo "Background music was NOT enabled."
    echo
    echo "Create:"
    echo "  ~/Music/Favorites.m3u8"
    echo
    echo "Then run:"
    echo "  systemctl --user enable --now background-music.service"
fi

# ---------------------------------------------------------
# Hardware-specific refresh-rate service
# ---------------------------------------------------------

echo
echo "IMPORTANT:"
echo "The automatic refresh-rate script in these dotfiles"
echo "contains a custom modeline made for Huzaifah's"
echo "2560x1600 / 240 Hz laptop panel."
echo
echo "Do NOT enable it on a different panel without editing it."
echo

read -r -p \
"Enable the custom 120/240 Hz service? [y/N]: " answer

case "$answer" in
    y|Y|yes|YES)
        if systemctl --user list-unit-files \
            | grep -q '^auto-refresh-rate.service'; then

            systemctl --user enable --now auto-refresh-rate.service

            echo "Automatic refresh switching enabled."
        else
            echo "auto-refresh-rate.service was not found."
        fi
        ;;

    *)
        systemctl --user disable --now \
            auto-refresh-rate.service \
            2>/dev/null || true

        echo "Automatic refresh switching left disabled."
        ;;
esac

# ---------------------------------------------------------
# Wallpapers
# ---------------------------------------------------------

mkdir -p "$HOME/Pictures/Wallpapers"

# ---------------------------------------------------------
# Finished
# ---------------------------------------------------------

echo
echo "======================================"
echo "        Installation complete"
echo "======================================"
echo
echo "Backup of previous files:"
echo "  $BACKUP_DIR"
echo
echo "Recommended next steps:"
echo
echo "  1. Check your display:"
echo "     hyprctl monitors"
echo
echo "  2. Review:"
echo "     ~/.local/bin/auto-refresh-rate"
echo
echo "  3. Put wallpapers in:"
echo "     ~/Pictures/Wallpapers"
echo
echo "  4. Create your own:"
echo "     ~/Music/Favorites.m3u8"
echo
echo "  5. Log out and back in."
echo
