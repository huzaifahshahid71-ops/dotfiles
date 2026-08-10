#!/bin/bash
# SDDM Frieren Theme Installation Script
# Copyright (c) 2026 moau-prog
# Licensed under GPL-3.0-or-later
# https://github.com/moau-prog

set -e

THEME_NAME="sddm-frieren-theme"
THEME_DIR="/usr/share/sddm/themes/${THEME_NAME}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "  SDDM Frieren Theme Installer"
echo "  Copyright (c) 2026 moau-prog"
echo "=========================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Error: This script must be run as root (use sudo)"
    exit 1
fi

# Check if SDDM is installed
if ! command -v sddm &> /dev/null; then
    echo "Error: SDDM is not installed on your system"
    echo "Please install SDDM first: sudo pacman -S sddm (Arch) or sudo apt install sddm (Debian/Ubuntu)"
    exit 1
fi

# Backup existing theme if it exists
if [ -d "$THEME_DIR" ]; then
    echo "Backing up existing theme..."
    mv "$THEME_DIR" "${THEME_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
fi

# Create theme directory
echo "Installing theme to $THEME_DIR..."
mkdir -p "$THEME_DIR"

# Copy theme files
cp -r "$SCRIPT_DIR"/* "$THEME_DIR/"

# Create metadata.desktop file
cat > "$THEME_DIR/metadata.desktop" <<EOL
[SddmGreeterTheme]
Name=sddm-frieren-theme
Description=Frieren: Beyond Journey's End themed SDDM login screen
Author=moau-prog
Website=https://github.com/moau-prog
License=GPL-3.0-or-later
Type=sddm-theme
Version=1.0
ConfigFile=Themes/theme.conf
MainScript=Main.qml
Theme-Id=sddm-frieren-theme
Theme-API=2.0
QtVersion=6
EOL

# Set correct permissions
chown -R root:root "$THEME_DIR"
chmod -R 755 "$THEME_DIR"

# Update SDDM configuration
SDDM_CONF="/etc/sddm.conf.d/sddm.conf"
mkdir -p /etc/sddm.conf.d

if [ -f "$SDDM_CONF" ]; then
    # Backup existing config
    cp "$SDDM_CONF" "${SDDM_CONF}.backup.$(date +%Y%m%d_%H%M%S)"
    # Update or add Current theme
    if grep -q "^Current=" "$SDDM_CONF"; then
        sed -i "s|^Current=.*|Current=${THEME_NAME}|" "$SDDM_CONF"
    else
        if grep -q "^\[Theme\]" "$SDDM_CONF"; then
            sed -i "/^\[Theme\]/a Current=${THEME_NAME}" "$SDDM_CONF"
        else
            echo -e "\n[Theme]\nCurrent=${THEME_NAME}" >> "$SDDM_CONF"
        fi
    fi
else
    # Create new config file
    cat > "$SDDM_CONF" <<EOL
[Theme]
Current=${THEME_NAME}
EOL
fi

echo ""
echo "=========================================="
echo "  Installation Complete!"
echo "=========================================="
echo ""
echo "The Frieren theme has been installed successfully."
echo "The theme will be applied on next boot or when SDDM restarts."
echo ""
echo "To apply immediately, restart SDDM:"
echo "  sudo systemctl restart sddm"
echo ""
echo "WARNING: This will log you out of your current session!"
echo ""
echo "To customize the theme, edit:"
echo "  $THEME_DIR/Themes/theme.conf"
echo ""
echo "=========================================="
echo "  Copyright (c) 2026 moau-prog"
echo "  Licensed under GPL-3.0-or-later"
echo "=========================================="
