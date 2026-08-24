# Huzaifah Triple-Rice Installer AppImage

A lightweight graphical launcher for the repository's existing online installer.

The AppImage does **not** bundle Caelestia, end4-pC, Ambxst, Arch packages, or other upstream project files. Those remain online and are downloaded by the same `install.sh` used by the one-command installation method.

## What it installs

- ✦ Caelestia
- ◈ end4-pC
- ◆ Ambxst + axctl integration
- ⇄ `SUPER + SHIFT + D` triple-rice switcher
- 🌙 Frieren SDDM login theme
- saved local end4/Ambxst fixes and configuration from this repository

The desktop wallpaper is not replaced by the installer.

## Requirements

- x86_64 Arch Linux / CachyOS-family system
- internet access
- sudo privileges
- a graphical desktop session

The launcher uses Zenity, KDialog, or Yad when one is already installed. On Arch-family systems it can install Zenity through `pkexec` if no supported dialog helper is present. Installation itself opens in a terminal so normal `sudo`, pacman, and AUR prompts remain visible.

## Building

GitHub Actions builds the release AppImage with `appimagetool`. The generated release contains both the raw `.AppImage` and a `.tar.gz` copy that preserves the executable bit when extracted.

Published release tag: `triple-rice-installer-v1.0.0`.

If a browser strips the executable permission from the raw AppImage, enable **Allow executing file as program** in your file manager or run:

```bash
chmod +x Huzaifah-Triple-Rice-Installer-x86_64.AppImage
```
