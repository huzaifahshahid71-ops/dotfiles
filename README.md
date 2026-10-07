<div align="center">

# Huzaifah Multi-Rice v6.0.0 — Sumi

<!-- SUMI_BADGES_START -->
[![Stars](https://img.shields.io/github/stars/huzaifahshahid71-ops/dotfiles?style=for-the-badge&color=a6c9ff&labelColor=24292f)](https://github.com/huzaifahshahid71-ops/dotfiles/stargazers)
[![Forks](https://img.shields.io/github/forks/huzaifahshahid71-ops/dotfiles?style=for-the-badge&color=cbb8e8&labelColor=24292f)](https://github.com/huzaifahshahid71-ops/dotfiles/forks)
[![Release](https://img.shields.io/github/v/release/huzaifahshahid71-ops/dotfiles?style=for-the-badge&color=9de0cf&labelColor=24292f)](https://github.com/huzaifahshahid71-ops/dotfiles/releases/latest)
[![Last commit](https://img.shields.io/github/last-commit/huzaifahshahid71-ops/dotfiles/main?style=for-the-badge&color=a6c9ff&labelColor=24292f)](https://github.com/huzaifahshahid71-ops/dotfiles/commits/main)
[![License: not specified](https://img.shields.io/badge/license-not_specified-e8c58a?style=for-the-badge&labelColor=24292f)](#sources-and-credits)
<!-- SUMI_BADGES_END -->

**12 desktops. One Sumi Deck. One install command.**

**8 Hyprland · 4 Niri · 74 login themes · 8 GRUB themes · 631 wallpapers**

[Download v6](https://github.com/huzaifahshahid71-ops/dotfiles/releases/tag/v6.0.0) · [Installation guide](https://github.com/huzaifahshahid71-ops/dotfiles/releases/download/v6.0.0/CACHY.OS.%2B.V6.INSTALL.GUIDE.mp4) · [Wallpaper collection](https://github.com/huzaifahshahid71-ops/multi-rice-wallpapers)

</div>

Sumi brings twelve separate desktop profiles together with a shared desktop switcher, searchable shortcuts, music controls, login-theme previews and GRUB-theme selection. Install it on an existing **x86_64 CachyOS or compatible Arch Linux desktop**. Setup checks system and package compatibility before installation.

## Install with one command

Run in your graphical desktop terminal, as your normal user:

```bash
curl -fsSL https://github.com/huzaifahshahid71-ops/dotfiles/releases/download/v6.0.0/ONLINE-INSTALL-v6.sh | bash
```

This opens **Sumi Setup**. Run preflight, choose your options, and start the backup and installation in the window. Authenticate when setup requests system changes. The command installs desktop customization on your existing Linux installation; install CachyOS itself first if you are starting from an empty machine.

The public launcher currently selects **desktop-r3**, which includes the verified Crimson wallpaper-picker sources, Cipher search routing and Aether icon lookup fixes, alongside the earlier SDDM, quiet GRUB, MacTahoe icon and Lumina launcher/palette repairs. The initial launch may take several minutes while the payload is downloaded or extracted.

## All twelve rices

| Desktop in Sumi Deck | Profile | Compositor |
| --- | --- | --- |
| **Aether** | Caelestia (`caelestia`) | Hyprland |
| **Obsidian** | end4 (`end4`) | Hyprland |
| **Crimson** | Ambxst (`ambxst`) | Hyprland |
| **Materia** | DankMaterialShell (`dms`) | Hyprland |
| **Aurora** | Serpantinum (`serpantinum`) | Hyprland |
| **Nocturne** | Noctalia (`noctalia`) | Hyprland |
| **Lumina** | Sayconlun (`sayconlun`) | Hyprland |
| **Tsugumori** | Tsugumori (`tsugumori`) | Hyprland |
| **Solstice** | JAQC (`jaqc`) | Niri |
| **Cipher** | Clavis (`clavis`) | Niri |
| **Astra** | Nixri (`nixri`) | Niri |
| **Eclipse** | iNiR (`inir`) | Niri |

Each rice retains its own configuration and supporting files under `~/.local/share/desktop-profiles`. Use Sumi Deck to select and switch desktops.

## Shared controls

| Shortcut | Opens |
| --- | --- |
| **Super + Shift + D** | Sumi Deck: desktop, LOGIN and GRUB cards |
| **Super + /** | Searchable keyboard-shortcut menu, with readable action names |
| **Super + Shift + M** | Shared music controls |
| **Super + Shift + R** | Refresh-rate controls |

Native launchers, settings and other bindings vary by rice. Open **Super + /** to see the active profile's shortcuts.

## Login and boot themes

- **74 SDDM login cards**, including Frieren and four additional custom cards, with previews and authenticated selection in Sumi Deck → **LOGIN**.
- **Eight Evangelion GRUB cards** with previews and authenticated selection in Sumi Deck → **GRUB**. These require an existing GRUB installation.
- The fresh-machine fixes retain SDDM selection for the next boot and quiet GRUB configuration across theme changes.

SDDM cards customize the login screen. Desktop lock screens are provided by the active rice and its lock-screen tools.

## Wallpapers

Choose the optional full collection in setup to download **631 wallpapers**. The downloader fetches **three ZIP packs in parallel**, then verifies and extracts the images locally. Choose the destination folder in setup and select wallpapers through your rice's wallpaper picker.

[Browse the wallpaper repository](https://github.com/huzaifahshahid71-ops/multi-rice-wallpapers) · [Pinned 631-image collection](https://github.com/huzaifahshahid71-ops/multi-rice-wallpapers/releases/tag/wallpapers-0aa529a78a8430dc)

## Installation video

<!-- SUMI_V6_SHOWCASE_START -->
[Watch/download the FHD+ CachyOS + Sumi v6 installation and showcase](https://github.com/huzaifahshahid71-ops/dotfiles/releases/download/v6.0.0/CachyOS-Sumi-v6-FHDplus.mp4).

[Watch/download the original CachyOS + v6 installation guide](https://github.com/huzaifahshahid71-ops/dotfiles/releases/download/v6.0.0/CACHY.OS.%2B.V6.INSTALL.GUIDE.mp4).
<!-- SUMI_V6_SHOWCASE_END -->

## Offline installation

From the [v6.0.0 release](https://github.com/huzaifahshahid71-ops/dotfiles/releases/tag/v6.0.0), download **`assemble-v6-r3.py`** into an empty directory and run:

```bash
python3 assemble-v6-r3.py
APPIMAGE_EXTRACT_AND_RUN=1 ./multi-rice-v6.0.0-r3-x86_64.AppImage
```

The assembler downloads `release-r3.json` and missing `.partNNN` files, verifies their SHA-256 hashes, and assembles the AppImage. For an offline machine, download all five r3 parts, `release-r3.json` and the assembler beforehand, then run them from the same directory. Keep `release-r3.json` beside the AppImage. The wallpaper collection is a separate optional download.

Use **setup's preflight** to check free space, graphical authentication and package compatibility. The payload includes CachyOS-optimized packages; installation depends on the preflight and dependency checks passing on your system.

## Backups and restore

Setup verifies a configuration backup before installation and records its installation receipt under:

```text
~/.local/share/huzaifah-multi-rice/v6-installations/
```

Use the receipt with the installer's restore function to restore backed-up user configuration and managed system desktop routes. Restore retains installed packages. Guards preserve files edited after installation rather than silently replacing them.

## Validation

The original v6 payload's twelve desktops, shortcuts, login themes, GRUB themes, installation and configuration restore were tested in CachyOS VMs. Fresh-machine appearance repairs and the three desktop-r3 fixes were also accepted in a fresh VM. The combined r3 build passed payload hash checks, GUI rendering and packaged backend checks; a complete new installation of that combined r3 image has not yet been accepted.

## Earlier screenshots

These are screenshots from the earlier v3 setup, retained as examples of the upstream desktop designs. The twelve-profile v6 inventory is listed above.

<table>
<tr>
<td width="50%"><img src="screenshots/v3/03-caelestia-desktop.webp" alt="Earlier Caelestia desktop"><br><b>Aether / Caelestia</b></td>
<td width="50%"><img src="screenshots/v3/10-end4-pc-desktop.webp" alt="Earlier end4 desktop"><br><b>Obsidian / end4</b></td>
</tr>
<tr>
<td><img src="screenshots/v3/13-ambxst-dashboard.webp" alt="Earlier Ambxst dashboard"><br><b>Crimson / Ambxst</b></td>
<td><img src="screenshots/v3/16-dms-overview.webp" alt="Earlier DankMaterialShell overview"><br><b>Materia / DMS</b></td>
</tr>
<tr>
<td><img src="screenshots/v3/20-noctalia-system.webp" alt="Earlier Noctalia system panel"><br><b>Nocturne / Noctalia</b></td>
<td><img src="screenshots/v3/01-frieren-sddm-login.webp" alt="Frieren SDDM login theme"><br><b>Frieren login theme</b></td>
</tr>
</table>

## Sources and credits

Release sources are maintained on [`v6.0-tahoe-dev`](https://github.com/huzaifahshahid71-ops/dotfiles/tree/v6.0-tahoe-dev). The [v6 release](https://github.com/huzaifahshahid71-ops/dotfiles/releases/tag/v6.0.0) includes the matching **`sumi-installer-source-v6.0.0-r3.zip`**, split payload, setup runtime and checksums. Older release assets remain available for their corresponding revisions; use matching revision files together.

This setup builds on Caelestia, end4, Ambxst/axctl, DankMaterialShell, Serpantinum, Noctalia, Sayconlun, Tsugumori, JAQC, Clavis, Nixri, iNiR, Hyprland, Niri, Quickshell and the included SDDM/GRUB and icon themes. Third-party projects retain their respective licenses and credits.

**App developer: Huzaifah.**
