<div align="center">

# Huzaifah Multi-Rice v6.0.0 — Sumi

<!-- SUMI_BADGES_START -->
[![Stars](https://img.shields.io/github/stars/huzaifahshahid71-ops/dotfiles?style=for-the-badge&color=a6c9ff&labelColor=24292f)](https://github.com/huzaifahshahid71-ops/dotfiles/stargazers)
[![Forks](https://img.shields.io/github/forks/huzaifahshahid71-ops/dotfiles?style=for-the-badge&color=cbb8e8&labelColor=24292f)](https://github.com/huzaifahshahid71-ops/dotfiles/forks)
[![Release](https://img.shields.io/github/v/release/huzaifahshahid71-ops/dotfiles?style=for-the-badge&color=9de0cf&labelColor=24292f)](https://github.com/huzaifahshahid71-ops/dotfiles/releases/latest)
[![Last commit](https://img.shields.io/github/last-commit/huzaifahshahid71-ops/dotfiles/main?style=for-the-badge&color=a6c9ff&labelColor=24292f)](https://github.com/huzaifahshahid71-ops/dotfiles/commits/main)
[![License: MIT](https://img.shields.io/badge/license-MIT-e8c58a?style=for-the-badge&labelColor=24292f)](LICENSE)
<!-- SUMI_BADGES_END -->

**12 desktops. One Sumi Deck. One install command.**

**8 Hyprland · 4 Niri · 74 login themes · 8 GRUB themes · 631 wallpapers**

[Download v6](https://github.com/huzaifahshahid71-ops/dotfiles/releases/tag/v6.0.0) · [Installation guide](https://github.com/huzaifahshahid71-ops/dotfiles/releases/download/v6.0.0/CachyOS-Sumi-v6-FHDplus.mp4) · [Wallpaper collection](https://github.com/huzaifahshahid71-ops/multi-rice-wallpapers)

</div>

Sumi brings twelve separate desktop profiles together with a shared desktop switcher, searchable shortcuts, music controls, login-theme previews and GRUB-theme selection. Install it on an existing **x86_64 CachyOS or compatible Arch Linux desktop**. Setup checks system and package compatibility before installation.

<p align="center">
<a href="screenshots/v6/006-Screenshot_2026-10-07_18-09-53.png"><img src="screenshots/v6/previews/sumi-deck.webp" width="900" alt="Sumi Deck desktop carousel in the v6 installation"></a><br>
<sub>Sumi Deck — switch desktops, preview login themes and choose GRUB themes.</sub>
</p>

[Install](#install-with-one-command) · [Desktop gallery](#v6-desktop-gallery) · [Login and boot](#login-and-boot-themes) · [Video](#installation-video) · [All 145 screenshots](#complete-screenshot-galleries)

## Install with one command

Run in your graphical desktop terminal, as your normal user:

```bash
curl -fsSL https://github.com/huzaifahshahid71-ops/dotfiles/releases/download/v6.0.0/ONLINE-INSTALL-v6.sh | bash
```

This opens **Sumi Setup**. Run preflight, choose your options, and start the backup and installation in the window. Authenticate when setup requests system changes. The command installs desktop customization on your existing Linux installation; install CachyOS itself first if you are starting from an empty machine.

<details>
<summary><strong>Setup screens: welcome and optional wallpapers</strong></summary>

<table>
<tr>
<td width="50%"><a href="screenshots/v6/001-Screenshot_2026-10-07_18-08-29.png"><img src="screenshots/v6/previews/setup-welcome.webp" alt="Sumi Setup"></a><br><strong>Sumi Setup</strong><br><sub>Twelve desktops in one guided installer</sub></td>
<td width="50%"><a href="screenshots/v6/002-Screenshot_2026-10-07_18-08-47.png"><img src="screenshots/v6/previews/setup-wallpapers.webp" alt="Bring your wallpapers"></a><br><strong>Bring your wallpapers</strong><br><sub>Choose the optional collection and destination folder</sub></td>
</tr>
</table>

</details>

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

## V6 desktop gallery

Captured from the new v6 installation. Click any preview for the original screenshot. Wallpaper, panel layout and colors vary with your choices.

<table>
<tr>
<td width="50%"><a href="screenshots/v6/029-Screenshot_2026-10-07_18-15-55.png"><img src="screenshots/v6/previews/aether.webp" alt="Aether"></a><br><strong>Aether</strong><br><sub>Caelestia · Hyprland</sub></td>
<td width="50%"><a href="screenshots/v6/033-Screenshot_2026-10-07_18-16-32.png"><img src="screenshots/v6/previews/obsidian.webp" alt="Obsidian"></a><br><strong>Obsidian</strong><br><sub>end4 · Hyprland</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v6/040-Screenshot_2026-10-07_18-17-43.png"><img src="screenshots/v6/previews/crimson.webp" alt="Crimson"></a><br><strong>Crimson</strong><br><sub>Ambxst · Hyprland</sub></td>
<td width="50%"><a href="screenshots/v6/051-Screenshot_2026-10-07_18-18-53.png"><img src="screenshots/v6/previews/materia.webp" alt="Materia"></a><br><strong>Materia</strong><br><sub>DankMaterialShell · Hyprland</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v6/063-Screenshot_2026-10-07_18-21-09.png"><img src="screenshots/v6/previews/aurora.webp" alt="Aurora"></a><br><strong>Aurora</strong><br><sub>Serpantinum · Hyprland</sub></td>
<td width="50%"><a href="screenshots/v6/073-Screenshot_2026-10-07_18-22-51.png"><img src="screenshots/v6/previews/nocturne.webp" alt="Nocturne"></a><br><strong>Nocturne</strong><br><sub>Noctalia · Hyprland</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v6/078-Screenshot_2026-10-07_18-23-44.png"><img src="screenshots/v6/previews/lumina.webp" alt="Lumina"></a><br><strong>Lumina</strong><br><sub>Sayconlun · Hyprland</sub></td>
<td width="50%"><a href="screenshots/v6/084-Screenshot_2026-10-07_18-25-19.png"><img src="screenshots/v6/previews/tsugumori.webp" alt="Tsugumori"></a><br><strong>Tsugumori</strong><br><sub>Tsugumori · Hyprland</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v6/092-Screenshot_2026-10-07_18-26-13.png"><img src="screenshots/v6/previews/solstice.webp" alt="Solstice"></a><br><strong>Solstice</strong><br><sub>JAQC · Niri</sub></td>
<td width="50%"><a href="screenshots/v6/104-Screenshot_2026-10-07_18-28-16.png"><img src="screenshots/v6/previews/cipher.webp" alt="Cipher"></a><br><strong>Cipher</strong><br><sub>Clavis · Niri</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v6/108-Screenshot_2026-10-07_18-28-58.png"><img src="screenshots/v6/previews/astra.webp" alt="Astra"></a><br><strong>Astra</strong><br><sub>Nixri · Niri</sub></td>
<td width="50%"><a href="screenshots/v6/117-Screenshot_2026-10-07_18-29-51.png"><img src="screenshots/v6/previews/eclipse.webp" alt="Eclipse"></a><br><strong>Eclipse</strong><br><sub>iNiR · Niri</sub></td>
</tr>
</table>

[Open the complete v6 gallery below](#complete-screenshot-galleries) for all 120 screenshots, including more launchers, panels, wallpaper pickers and desktop views.


## Shared controls

| Shortcut | Opens |
| --- | --- |
| **Super + Shift + D** | Sumi Deck: desktop, LOGIN and GRUB cards |
| **Super + /** | Searchable keyboard-shortcut menu, with readable action names |
| **Super + Shift + M** | Shared music controls |
| **Super + Shift + R** | Refresh-rate controls |

Native launchers, settings and other bindings vary by rice. Open **Super + /** to see the active profile's shortcuts.

<details>
<summary><strong>Shared shortcuts and music controls</strong></summary>

<table>
<tr>
<td width="50%"><a href="screenshots/v6/016-Screenshot_2026-10-07_18-13-44.png"><img src="screenshots/v6/previews/keyboard-shortcuts.webp" alt="Searchable shortcuts"></a><br><strong>Searchable shortcuts</strong><br><sub>Readable action names and key combinations</sub></td>
<td width="50%"><a href="screenshots/v6/018-Screenshot_2026-10-07_18-14-14.png"><img src="screenshots/v6/previews/music-controls.webp" alt="Shared music controls"></a><br><strong>Shared music controls</strong><br><sub>Local media playback and seeking</sub></td>
</tr>
</table>

</details>


## Login and boot themes

- **74 SDDM login cards**, including Frieren and four additional custom cards, with previews and authenticated selection in Sumi Deck → **LOGIN**.
- **Eight Evangelion GRUB cards** with previews and authenticated selection in Sumi Deck → **GRUB**. These require an existing GRUB installation.
- The fresh-machine fixes retain SDDM selection for the next boot and quiet GRUB configuration across theme changes.

SDDM cards customize the login screen. Desktop lock screens are provided by the active rice and its lock-screen tools.

<table>
<tr>
<td width="50%"><a href="screenshots/v6/007-Screenshot_2026-10-07_18-10-34.png"><img src="screenshots/v6/previews/login-selection.webp" alt="LOGIN in Sumi Deck"></a><br><strong>LOGIN in Sumi Deck</strong><br><sub>Browse and preview login themes</sub></td>
<td width="50%"><a href="screenshots/v6/058-Screenshot_2026-10-07_18-20-11.png"><img src="screenshots/v6/previews/login-pixel-sakura.webp" alt="Pixel Sakura"></a><br><strong>Pixel Sakura</strong><br><sub>A login-theme preview</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v6/052-Screenshot_2026-10-07_18-19-02.png"><img src="screenshots/v6/previews/grub-selection.webp" alt="GRUB in Sumi Deck"></a><br><strong>GRUB in Sumi Deck</strong><br><sub>Browse the eight Evangelion themes</sub></td>
<td width="50%"><a href="screenshots/v6/120-Screenshot_2026-10-07_18-30-37.png"><img src="screenshots/v6/previews/grub-ramiel.webp" alt="Ramiel at boot"></a><br><strong>Ramiel at boot</strong><br><sub>The selected GRUB theme</sub></td>
</tr>
</table>

<details>
<summary><strong>Authentication inside Sumi Deck</strong></summary>

[![Sumi Deck authentication dialog for applying a GRUB theme](screenshots/v6/previews/authentication.webp)](screenshots/v6/054-Screenshot_2026-10-07_18-19-12.png)

</details>


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

<!-- SUMI_COMPLETE_GALLERIES_START -->
## Complete screenshot galleries

All **120 v6 screenshots** and **25 earlier screenshots** are embedded below. Expand a section to browse its images; click any image to open the original at full resolution.

### V6 installation and desktop showcase

<details>
<summary><strong>V6 screenshots 001–012</strong></summary>

<table>
<tr>
<td width="50%"><a href="screenshots/v6/001-Screenshot_2026-10-07_18-08-29.png"><img src="screenshots/v6/001-Screenshot_2026-10-07_18-08-29.png" alt="V6 · 001 · 18:08:29" width="640" loading="lazy"></a><br><sub>V6 · 001 · 18:08:29</sub></td>
<td width="50%"><a href="screenshots/v6/002-Screenshot_2026-10-07_18-08-47.png"><img src="screenshots/v6/002-Screenshot_2026-10-07_18-08-47.png" alt="V6 · 002 · 18:08:47" width="640" loading="lazy"></a><br><sub>V6 · 002 · 18:08:47</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v6/003-Screenshot_2026-10-07_18-09-06.png"><img src="screenshots/v6/003-Screenshot_2026-10-07_18-09-06.png" alt="V6 · 003 · 18:09:06" width="640" loading="lazy"></a><br><sub>V6 · 003 · 18:09:06</sub></td>
<td width="50%"><a href="screenshots/v6/004-Screenshot_2026-10-07_18-09-27.png"><img src="screenshots/v6/004-Screenshot_2026-10-07_18-09-27.png" alt="V6 · 004 · 18:09:27" width="640" loading="lazy"></a><br><sub>V6 · 004 · 18:09:27</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v6/005-Screenshot_2026-10-07_18-09-43.png"><img src="screenshots/v6/005-Screenshot_2026-10-07_18-09-43.png" alt="V6 · 005 · 18:09:43" width="640" loading="lazy"></a><br><sub>V6 · 005 · 18:09:43</sub></td>
<td width="50%"><a href="screenshots/v6/006-Screenshot_2026-10-07_18-09-53.png"><img src="screenshots/v6/006-Screenshot_2026-10-07_18-09-53.png" alt="V6 · 006 · 18:09:53" width="640" loading="lazy"></a><br><sub>V6 · 006 · 18:09:53</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v6/007-Screenshot_2026-10-07_18-10-34.png"><img src="screenshots/v6/007-Screenshot_2026-10-07_18-10-34.png" alt="V6 · 007 · 18:10:34" width="640" loading="lazy"></a><br><sub>V6 · 007 · 18:10:34</sub></td>
<td width="50%"><a href="screenshots/v6/008-Screenshot_2026-10-07_18-10-57.png"><img src="screenshots/v6/008-Screenshot_2026-10-07_18-10-57.png" alt="V6 · 008 · 18:10:57" width="640" loading="lazy"></a><br><sub>V6 · 008 · 18:10:57</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v6/009-Screenshot_2026-10-07_18-11-11.png"><img src="screenshots/v6/009-Screenshot_2026-10-07_18-11-11.png" alt="V6 · 009 · 18:11:11" width="640" loading="lazy"></a><br><sub>V6 · 009 · 18:11:11</sub></td>
<td width="50%"><a href="screenshots/v6/010-Screenshot_2026-10-07_18-11-17.png"><img src="screenshots/v6/010-Screenshot_2026-10-07_18-11-17.png" alt="V6 · 010 · 18:11:17" width="640" loading="lazy"></a><br><sub>V6 · 010 · 18:11:17</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v6/011-Screenshot_2026-10-07_18-12-35.png"><img src="screenshots/v6/011-Screenshot_2026-10-07_18-12-35.png" alt="V6 · 011 · 18:12:35" width="640" loading="lazy"></a><br><sub>V6 · 011 · 18:12:35</sub></td>
<td width="50%"><a href="screenshots/v6/012-Screenshot_2026-10-07_18-12-39.png"><img src="screenshots/v6/012-Screenshot_2026-10-07_18-12-39.png" alt="V6 · 012 · 18:12:39" width="640" loading="lazy"></a><br><sub>V6 · 012 · 18:12:39</sub></td>
</tr>
</table>

</details>

<details>
<summary><strong>V6 screenshots 013–024</strong></summary>

<table>
<tr>
<td width="50%"><a href="screenshots/v6/013-Screenshot_2026-10-07_18-12-43.png"><img src="screenshots/v6/013-Screenshot_2026-10-07_18-12-43.png" alt="V6 · 013 · 18:12:43" width="640" loading="lazy"></a><br><sub>V6 · 013 · 18:12:43</sub></td>
<td width="50%"><a href="screenshots/v6/014-Screenshot_2026-10-07_18-13-21.png"><img src="screenshots/v6/014-Screenshot_2026-10-07_18-13-21.png" alt="V6 · 014 · 18:13:21" width="640" loading="lazy"></a><br><sub>V6 · 014 · 18:13:21</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v6/015-Screenshot_2026-10-07_18-13-23.png"><img src="screenshots/v6/015-Screenshot_2026-10-07_18-13-23.png" alt="V6 · 015 · 18:13:23" width="640" loading="lazy"></a><br><sub>V6 · 015 · 18:13:23</sub></td>
<td width="50%"><a href="screenshots/v6/016-Screenshot_2026-10-07_18-13-44.png"><img src="screenshots/v6/016-Screenshot_2026-10-07_18-13-44.png" alt="V6 · 016 · 18:13:44" width="640" loading="lazy"></a><br><sub>V6 · 016 · 18:13:44</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v6/017-Screenshot_2026-10-07_18-14-02.png"><img src="screenshots/v6/017-Screenshot_2026-10-07_18-14-02.png" alt="V6 · 017 · 18:14:02" width="640" loading="lazy"></a><br><sub>V6 · 017 · 18:14:02</sub></td>
<td width="50%"><a href="screenshots/v6/018-Screenshot_2026-10-07_18-14-14.png"><img src="screenshots/v6/018-Screenshot_2026-10-07_18-14-14.png" alt="V6 · 018 · 18:14:14" width="640" loading="lazy"></a><br><sub>V6 · 018 · 18:14:14</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v6/019-Screenshot_2026-10-07_18-14-17.png"><img src="screenshots/v6/019-Screenshot_2026-10-07_18-14-17.png" alt="V6 · 019 · 18:14:17" width="640" loading="lazy"></a><br><sub>V6 · 019 · 18:14:17</sub></td>
<td width="50%"><a href="screenshots/v6/020-Screenshot_2026-10-07_18-14-23.png"><img src="screenshots/v6/020-Screenshot_2026-10-07_18-14-23.png" alt="V6 · 020 · 18:14:23" width="640" loading="lazy"></a><br><sub>V6 · 020 · 18:14:23</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v6/021-Screenshot_2026-10-07_18-14-25.png"><img src="screenshots/v6/021-Screenshot_2026-10-07_18-14-25.png" alt="V6 · 021 · 18:14:25" width="640" loading="lazy"></a><br><sub>V6 · 021 · 18:14:25</sub></td>
<td width="50%"><a href="screenshots/v6/022-Screenshot_2026-10-07_18-14-29.png"><img src="screenshots/v6/022-Screenshot_2026-10-07_18-14-29.png" alt="V6 · 022 · 18:14:29" width="640" loading="lazy"></a><br><sub>V6 · 022 · 18:14:29</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v6/023-Screenshot_2026-10-07_18-14-35.png"><img src="screenshots/v6/023-Screenshot_2026-10-07_18-14-35.png" alt="V6 · 023 · 18:14:35" width="640" loading="lazy"></a><br><sub>V6 · 023 · 18:14:35</sub></td>
<td width="50%"><a href="screenshots/v6/024-Screenshot_2026-10-07_18-15-02.png"><img src="screenshots/v6/024-Screenshot_2026-10-07_18-15-02.png" alt="V6 · 024 · 18:15:02" width="640" loading="lazy"></a><br><sub>V6 · 024 · 18:15:02</sub></td>
</tr>
</table>

</details>

<details>
<summary><strong>V6 screenshots 025–036</strong></summary>

<table>
<tr>
<td width="50%"><a href="screenshots/v6/025-Screenshot_2026-10-07_18-15-07.png"><img src="screenshots/v6/025-Screenshot_2026-10-07_18-15-07.png" alt="V6 · 025 · 18:15:07" width="640" loading="lazy"></a><br><sub>V6 · 025 · 18:15:07</sub></td>
<td width="50%"><a href="screenshots/v6/026-Screenshot_2026-10-07_18-15-14.png"><img src="screenshots/v6/026-Screenshot_2026-10-07_18-15-14.png" alt="V6 · 026 · 18:15:14" width="640" loading="lazy"></a><br><sub>V6 · 026 · 18:15:14</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v6/027-Screenshot_2026-10-07_18-15-38.png"><img src="screenshots/v6/027-Screenshot_2026-10-07_18-15-38.png" alt="V6 · 027 · 18:15:38" width="640" loading="lazy"></a><br><sub>V6 · 027 · 18:15:38</sub></td>
<td width="50%"><a href="screenshots/v6/028-Screenshot_2026-10-07_18-15-50.png"><img src="screenshots/v6/028-Screenshot_2026-10-07_18-15-50.png" alt="V6 · 028 · 18:15:50" width="640" loading="lazy"></a><br><sub>V6 · 028 · 18:15:50</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v6/029-Screenshot_2026-10-07_18-15-55.png"><img src="screenshots/v6/029-Screenshot_2026-10-07_18-15-55.png" alt="V6 · 029 · 18:15:55" width="640" loading="lazy"></a><br><sub>V6 · 029 · 18:15:55</sub></td>
<td width="50%"><a href="screenshots/v6/030-Screenshot_2026-10-07_18-16-10.png"><img src="screenshots/v6/030-Screenshot_2026-10-07_18-16-10.png" alt="V6 · 030 · 18:16:10" width="640" loading="lazy"></a><br><sub>V6 · 030 · 18:16:10</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v6/031-Screenshot_2026-10-07_18-16-13.png"><img src="screenshots/v6/031-Screenshot_2026-10-07_18-16-13.png" alt="V6 · 031 · 18:16:13" width="640" loading="lazy"></a><br><sub>V6 · 031 · 18:16:13</sub></td>
<td width="50%"><a href="screenshots/v6/032-Screenshot_2026-10-07_18-16-20.png"><img src="screenshots/v6/032-Screenshot_2026-10-07_18-16-20.png" alt="V6 · 032 · 18:16:20" width="640" loading="lazy"></a><br><sub>V6 · 032 · 18:16:20</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v6/033-Screenshot_2026-10-07_18-16-32.png"><img src="screenshots/v6/033-Screenshot_2026-10-07_18-16-32.png" alt="V6 · 033 · 18:16:32" width="640" loading="lazy"></a><br><sub>V6 · 033 · 18:16:32</sub></td>
<td width="50%"><a href="screenshots/v6/034-Screenshot_2026-10-07_18-16-39.png"><img src="screenshots/v6/034-Screenshot_2026-10-07_18-16-39.png" alt="V6 · 034 · 18:16:39" width="640" loading="lazy"></a><br><sub>V6 · 034 · 18:16:39</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v6/035-Screenshot_2026-10-07_18-16-47.png"><img src="screenshots/v6/035-Screenshot_2026-10-07_18-16-47.png" alt="V6 · 035 · 18:16:47" width="640" loading="lazy"></a><br><sub>V6 · 035 · 18:16:47</sub></td>
<td width="50%"><a href="screenshots/v6/036-Screenshot_2026-10-07_18-17-18.png"><img src="screenshots/v6/036-Screenshot_2026-10-07_18-17-18.png" alt="V6 · 036 · 18:17:18" width="640" loading="lazy"></a><br><sub>V6 · 036 · 18:17:18</sub></td>
</tr>
</table>

</details>

<details>
<summary><strong>V6 screenshots 037–048</strong></summary>

<table>
<tr>
<td width="50%"><a href="screenshots/v6/037-Screenshot_2026-10-07_18-17-28.png"><img src="screenshots/v6/037-Screenshot_2026-10-07_18-17-28.png" alt="V6 · 037 · 18:17:28" width="640" loading="lazy"></a><br><sub>V6 · 037 · 18:17:28</sub></td>
<td width="50%"><a href="screenshots/v6/038-Screenshot_2026-10-07_18-17-31.png"><img src="screenshots/v6/038-Screenshot_2026-10-07_18-17-31.png" alt="V6 · 038 · 18:17:31" width="640" loading="lazy"></a><br><sub>V6 · 038 · 18:17:31</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v6/039-Screenshot_2026-10-07_18-17-35.png"><img src="screenshots/v6/039-Screenshot_2026-10-07_18-17-35.png" alt="V6 · 039 · 18:17:35" width="640" loading="lazy"></a><br><sub>V6 · 039 · 18:17:35</sub></td>
<td width="50%"><a href="screenshots/v6/040-Screenshot_2026-10-07_18-17-43.png"><img src="screenshots/v6/040-Screenshot_2026-10-07_18-17-43.png" alt="V6 · 040 · 18:17:43" width="640" loading="lazy"></a><br><sub>V6 · 040 · 18:17:43</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v6/041-Screenshot_2026-10-07_18-17-56.png"><img src="screenshots/v6/041-Screenshot_2026-10-07_18-17-56.png" alt="V6 · 041 · 18:17:56" width="640" loading="lazy"></a><br><sub>V6 · 041 · 18:17:56</sub></td>
<td width="50%"><a href="screenshots/v6/042-Screenshot_2026-10-07_18-18-03.png"><img src="screenshots/v6/042-Screenshot_2026-10-07_18-18-03.png" alt="V6 · 042 · 18:18:03" width="640" loading="lazy"></a><br><sub>V6 · 042 · 18:18:03</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v6/043-Screenshot_2026-10-07_18-18-12.png"><img src="screenshots/v6/043-Screenshot_2026-10-07_18-18-12.png" alt="V6 · 043 · 18:18:12" width="640" loading="lazy"></a><br><sub>V6 · 043 · 18:18:12</sub></td>
<td width="50%"><a href="screenshots/v6/044-Screenshot_2026-10-07_18-18-22.png"><img src="screenshots/v6/044-Screenshot_2026-10-07_18-18-22.png" alt="V6 · 044 · 18:18:22" width="640" loading="lazy"></a><br><sub>V6 · 044 · 18:18:22</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v6/045-Screenshot_2026-10-07_18-18-24.png"><img src="screenshots/v6/045-Screenshot_2026-10-07_18-18-24.png" alt="V6 · 045 · 18:18:24" width="640" loading="lazy"></a><br><sub>V6 · 045 · 18:18:24</sub></td>
<td width="50%"><a href="screenshots/v6/046-Screenshot_2026-10-07_18-18-26.png"><img src="screenshots/v6/046-Screenshot_2026-10-07_18-18-26.png" alt="V6 · 046 · 18:18:26" width="640" loading="lazy"></a><br><sub>V6 · 046 · 18:18:26</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v6/047-Screenshot_2026-10-07_18-18-29.png"><img src="screenshots/v6/047-Screenshot_2026-10-07_18-18-29.png" alt="V6 · 047 · 18:18:29" width="640" loading="lazy"></a><br><sub>V6 · 047 · 18:18:29</sub></td>
<td width="50%"><a href="screenshots/v6/048-Screenshot_2026-10-07_18-18-36.png"><img src="screenshots/v6/048-Screenshot_2026-10-07_18-18-36.png" alt="V6 · 048 · 18:18:36" width="640" loading="lazy"></a><br><sub>V6 · 048 · 18:18:36</sub></td>
</tr>
</table>

</details>

<details>
<summary><strong>V6 screenshots 049–060</strong></summary>

<table>
<tr>
<td width="50%"><a href="screenshots/v6/049-Screenshot_2026-10-07_18-18-39.png"><img src="screenshots/v6/049-Screenshot_2026-10-07_18-18-39.png" alt="V6 · 049 · 18:18:39" width="640" loading="lazy"></a><br><sub>V6 · 049 · 18:18:39</sub></td>
<td width="50%"><a href="screenshots/v6/050-Screenshot_2026-10-07_18-18-41.png"><img src="screenshots/v6/050-Screenshot_2026-10-07_18-18-41.png" alt="V6 · 050 · 18:18:41" width="640" loading="lazy"></a><br><sub>V6 · 050 · 18:18:41</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v6/051-Screenshot_2026-10-07_18-18-53.png"><img src="screenshots/v6/051-Screenshot_2026-10-07_18-18-53.png" alt="V6 · 051 · 18:18:53" width="640" loading="lazy"></a><br><sub>V6 · 051 · 18:18:53</sub></td>
<td width="50%"><a href="screenshots/v6/052-Screenshot_2026-10-07_18-19-02.png"><img src="screenshots/v6/052-Screenshot_2026-10-07_18-19-02.png" alt="V6 · 052 · 18:19:02" width="640" loading="lazy"></a><br><sub>V6 · 052 · 18:19:02</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v6/053-Screenshot_2026-10-07_18-19-06.png"><img src="screenshots/v6/053-Screenshot_2026-10-07_18-19-06.png" alt="V6 · 053 · 18:19:06" width="640" loading="lazy"></a><br><sub>V6 · 053 · 18:19:06</sub></td>
<td width="50%"><a href="screenshots/v6/054-Screenshot_2026-10-07_18-19-12.png"><img src="screenshots/v6/054-Screenshot_2026-10-07_18-19-12.png" alt="V6 · 054 · 18:19:12" width="640" loading="lazy"></a><br><sub>V6 · 054 · 18:19:12</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v6/055-Screenshot_2026-10-07_18-19-55.png"><img src="screenshots/v6/055-Screenshot_2026-10-07_18-19-55.png" alt="V6 · 055 · 18:19:55" width="640" loading="lazy"></a><br><sub>V6 · 055 · 18:19:55</sub></td>
<td width="50%"><a href="screenshots/v6/056-Screenshot_2026-10-07_18-19-59.png"><img src="screenshots/v6/056-Screenshot_2026-10-07_18-19-59.png" alt="V6 · 056 · 18:19:59" width="640" loading="lazy"></a><br><sub>V6 · 056 · 18:19:59</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v6/057-Screenshot_2026-10-07_18-20-07.png"><img src="screenshots/v6/057-Screenshot_2026-10-07_18-20-07.png" alt="V6 · 057 · 18:20:07" width="640" loading="lazy"></a><br><sub>V6 · 057 · 18:20:07</sub></td>
<td width="50%"><a href="screenshots/v6/058-Screenshot_2026-10-07_18-20-11.png"><img src="screenshots/v6/058-Screenshot_2026-10-07_18-20-11.png" alt="V6 · 058 · 18:20:11" width="640" loading="lazy"></a><br><sub>V6 · 058 · 18:20:11</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v6/059-Screenshot_2026-10-07_18-20-30.png"><img src="screenshots/v6/059-Screenshot_2026-10-07_18-20-30.png" alt="V6 · 059 · 18:20:30" width="640" loading="lazy"></a><br><sub>V6 · 059 · 18:20:30</sub></td>
<td width="50%"><a href="screenshots/v6/060-Screenshot_2026-10-07_18-20-36.png"><img src="screenshots/v6/060-Screenshot_2026-10-07_18-20-36.png" alt="V6 · 060 · 18:20:36" width="640" loading="lazy"></a><br><sub>V6 · 060 · 18:20:36</sub></td>
</tr>
</table>

</details>

<details>
<summary><strong>V6 screenshots 061–072</strong></summary>

<table>
<tr>
<td width="50%"><a href="screenshots/v6/061-Screenshot_2026-10-07_18-20-40.png"><img src="screenshots/v6/061-Screenshot_2026-10-07_18-20-40.png" alt="V6 · 061 · 18:20:40" width="640" loading="lazy"></a><br><sub>V6 · 061 · 18:20:40</sub></td>
<td width="50%"><a href="screenshots/v6/062-Screenshot_2026-10-07_18-20-57.png"><img src="screenshots/v6/062-Screenshot_2026-10-07_18-20-57.png" alt="V6 · 062 · 18:20:57" width="640" loading="lazy"></a><br><sub>V6 · 062 · 18:20:57</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v6/063-Screenshot_2026-10-07_18-21-09.png"><img src="screenshots/v6/063-Screenshot_2026-10-07_18-21-09.png" alt="V6 · 063 · 18:21:09" width="640" loading="lazy"></a><br><sub>V6 · 063 · 18:21:09</sub></td>
<td width="50%"><a href="screenshots/v6/064-Screenshot_2026-10-07_18-21-16.png"><img src="screenshots/v6/064-Screenshot_2026-10-07_18-21-16.png" alt="V6 · 064 · 18:21:16" width="640" loading="lazy"></a><br><sub>V6 · 064 · 18:21:16</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v6/065-Screenshot_2026-10-07_18-21-36.png"><img src="screenshots/v6/065-Screenshot_2026-10-07_18-21-36.png" alt="V6 · 065 · 18:21:36" width="640" loading="lazy"></a><br><sub>V6 · 065 · 18:21:36</sub></td>
<td width="50%"><a href="screenshots/v6/066-Screenshot_2026-10-07_18-22-07.png"><img src="screenshots/v6/066-Screenshot_2026-10-07_18-22-07.png" alt="V6 · 066 · 18:22:07" width="640" loading="lazy"></a><br><sub>V6 · 066 · 18:22:07</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v6/067-Screenshot_2026-10-07_18-22-14.png"><img src="screenshots/v6/067-Screenshot_2026-10-07_18-22-14.png" alt="V6 · 067 · 18:22:14" width="640" loading="lazy"></a><br><sub>V6 · 067 · 18:22:14</sub></td>
<td width="50%"><a href="screenshots/v6/068-Screenshot_2026-10-07_18-22-23.png"><img src="screenshots/v6/068-Screenshot_2026-10-07_18-22-23.png" alt="V6 · 068 · 18:22:23" width="640" loading="lazy"></a><br><sub>V6 · 068 · 18:22:23</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v6/069-Screenshot_2026-10-07_18-22-29.png"><img src="screenshots/v6/069-Screenshot_2026-10-07_18-22-29.png" alt="V6 · 069 · 18:22:29" width="640" loading="lazy"></a><br><sub>V6 · 069 · 18:22:29</sub></td>
<td width="50%"><a href="screenshots/v6/070-Screenshot_2026-10-07_18-22-33.png"><img src="screenshots/v6/070-Screenshot_2026-10-07_18-22-33.png" alt="V6 · 070 · 18:22:33" width="640" loading="lazy"></a><br><sub>V6 · 070 · 18:22:33</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v6/071-Screenshot_2026-10-07_18-22-36.png"><img src="screenshots/v6/071-Screenshot_2026-10-07_18-22-36.png" alt="V6 · 071 · 18:22:36" width="640" loading="lazy"></a><br><sub>V6 · 071 · 18:22:36</sub></td>
<td width="50%"><a href="screenshots/v6/072-Screenshot_2026-10-07_18-22-38.png"><img src="screenshots/v6/072-Screenshot_2026-10-07_18-22-38.png" alt="V6 · 072 · 18:22:38" width="640" loading="lazy"></a><br><sub>V6 · 072 · 18:22:38</sub></td>
</tr>
</table>

</details>

<details>
<summary><strong>V6 screenshots 073–084</strong></summary>

<table>
<tr>
<td width="50%"><a href="screenshots/v6/073-Screenshot_2026-10-07_18-22-51.png"><img src="screenshots/v6/073-Screenshot_2026-10-07_18-22-51.png" alt="V6 · 073 · 18:22:51" width="640" loading="lazy"></a><br><sub>V6 · 073 · 18:22:51</sub></td>
<td width="50%"><a href="screenshots/v6/074-Screenshot_2026-10-07_18-22-53.png"><img src="screenshots/v6/074-Screenshot_2026-10-07_18-22-53.png" alt="V6 · 074 · 18:22:53" width="640" loading="lazy"></a><br><sub>V6 · 074 · 18:22:53</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v6/075-Screenshot_2026-10-07_18-23-13.png"><img src="screenshots/v6/075-Screenshot_2026-10-07_18-23-13.png" alt="V6 · 075 · 18:23:13" width="640" loading="lazy"></a><br><sub>V6 · 075 · 18:23:13</sub></td>
<td width="50%"><a href="screenshots/v6/076-Screenshot_2026-10-07_18-23-23.png"><img src="screenshots/v6/076-Screenshot_2026-10-07_18-23-23.png" alt="V6 · 076 · 18:23:23" width="640" loading="lazy"></a><br><sub>V6 · 076 · 18:23:23</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v6/077-Screenshot_2026-10-07_18-23-40.png"><img src="screenshots/v6/077-Screenshot_2026-10-07_18-23-40.png" alt="V6 · 077 · 18:23:40" width="640" loading="lazy"></a><br><sub>V6 · 077 · 18:23:40</sub></td>
<td width="50%"><a href="screenshots/v6/078-Screenshot_2026-10-07_18-23-44.png"><img src="screenshots/v6/078-Screenshot_2026-10-07_18-23-44.png" alt="V6 · 078 · 18:23:44" width="640" loading="lazy"></a><br><sub>V6 · 078 · 18:23:44</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v6/079-Screenshot_2026-10-07_18-24-12.png"><img src="screenshots/v6/079-Screenshot_2026-10-07_18-24-12.png" alt="V6 · 079 · 18:24:12" width="640" loading="lazy"></a><br><sub>V6 · 079 · 18:24:12</sub></td>
<td width="50%"><a href="screenshots/v6/080-Screenshot_2026-10-07_18-24-16.png"><img src="screenshots/v6/080-Screenshot_2026-10-07_18-24-16.png" alt="V6 · 080 · 18:24:16" width="640" loading="lazy"></a><br><sub>V6 · 080 · 18:24:16</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v6/081-Screenshot_2026-10-07_18-24-34.png"><img src="screenshots/v6/081-Screenshot_2026-10-07_18-24-34.png" alt="V6 · 081 · 18:24:34" width="640" loading="lazy"></a><br><sub>V6 · 081 · 18:24:34</sub></td>
<td width="50%"><a href="screenshots/v6/082-Screenshot_2026-10-07_18-24-46.png"><img src="screenshots/v6/082-Screenshot_2026-10-07_18-24-46.png" alt="V6 · 082 · 18:24:46" width="640" loading="lazy"></a><br><sub>V6 · 082 · 18:24:46</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v6/083-Screenshot_2026-10-07_18-25-12.png"><img src="screenshots/v6/083-Screenshot_2026-10-07_18-25-12.png" alt="V6 · 083 · 18:25:12" width="640" loading="lazy"></a><br><sub>V6 · 083 · 18:25:12</sub></td>
<td width="50%"><a href="screenshots/v6/084-Screenshot_2026-10-07_18-25-19.png"><img src="screenshots/v6/084-Screenshot_2026-10-07_18-25-19.png" alt="V6 · 084 · 18:25:19" width="640" loading="lazy"></a><br><sub>V6 · 084 · 18:25:19</sub></td>
</tr>
</table>

</details>

<details>
<summary><strong>V6 screenshots 085–096</strong></summary>

<table>
<tr>
<td width="50%"><a href="screenshots/v6/085-Screenshot_2026-10-07_18-25-23.png"><img src="screenshots/v6/085-Screenshot_2026-10-07_18-25-23.png" alt="V6 · 085 · 18:25:23" width="640" loading="lazy"></a><br><sub>V6 · 085 · 18:25:23</sub></td>
<td width="50%"><a href="screenshots/v6/086-Screenshot_2026-10-07_18-25-26.png"><img src="screenshots/v6/086-Screenshot_2026-10-07_18-25-26.png" alt="V6 · 086 · 18:25:26" width="640" loading="lazy"></a><br><sub>V6 · 086 · 18:25:26</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v6/087-Screenshot_2026-10-07_18-25-41.png"><img src="screenshots/v6/087-Screenshot_2026-10-07_18-25-41.png" alt="V6 · 087 · 18:25:41" width="640" loading="lazy"></a><br><sub>V6 · 087 · 18:25:41</sub></td>
<td width="50%"><a href="screenshots/v6/088-Screenshot_2026-10-07_18-25-44.png"><img src="screenshots/v6/088-Screenshot_2026-10-07_18-25-44.png" alt="V6 · 088 · 18:25:44" width="640" loading="lazy"></a><br><sub>V6 · 088 · 18:25:44</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v6/089-Screenshot_2026-10-07_18-25-49.png"><img src="screenshots/v6/089-Screenshot_2026-10-07_18-25-49.png" alt="V6 · 089 · 18:25:49" width="640" loading="lazy"></a><br><sub>V6 · 089 · 18:25:49</sub></td>
<td width="50%"><a href="screenshots/v6/090-Screenshot_2026-10-07_18-25-54.png"><img src="screenshots/v6/090-Screenshot_2026-10-07_18-25-54.png" alt="V6 · 090 · 18:25:54" width="640" loading="lazy"></a><br><sub>V6 · 090 · 18:25:54</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v6/091-Screenshot_2026-10-07_18-26-02.png"><img src="screenshots/v6/091-Screenshot_2026-10-07_18-26-02.png" alt="V6 · 091 · 18:26:02" width="640" loading="lazy"></a><br><sub>V6 · 091 · 18:26:02</sub></td>
<td width="50%"><a href="screenshots/v6/092-Screenshot_2026-10-07_18-26-13.png"><img src="screenshots/v6/092-Screenshot_2026-10-07_18-26-13.png" alt="V6 · 092 · 18:26:13" width="640" loading="lazy"></a><br><sub>V6 · 092 · 18:26:13</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v6/093-Screenshot_2026-10-07_18-26-21.png"><img src="screenshots/v6/093-Screenshot_2026-10-07_18-26-21.png" alt="V6 · 093 · 18:26:21" width="640" loading="lazy"></a><br><sub>V6 · 093 · 18:26:21</sub></td>
<td width="50%"><a href="screenshots/v6/094-Screenshot_2026-10-07_18-26-24.png"><img src="screenshots/v6/094-Screenshot_2026-10-07_18-26-24.png" alt="V6 · 094 · 18:26:24" width="640" loading="lazy"></a><br><sub>V6 · 094 · 18:26:24</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v6/095-Screenshot_2026-10-07_18-26-34.png"><img src="screenshots/v6/095-Screenshot_2026-10-07_18-26-34.png" alt="V6 · 095 · 18:26:34" width="640" loading="lazy"></a><br><sub>V6 · 095 · 18:26:34</sub></td>
<td width="50%"><a href="screenshots/v6/096-Screenshot_2026-10-07_18-26-36.png"><img src="screenshots/v6/096-Screenshot_2026-10-07_18-26-36.png" alt="V6 · 096 · 18:26:36" width="640" loading="lazy"></a><br><sub>V6 · 096 · 18:26:36</sub></td>
</tr>
</table>

</details>

<details>
<summary><strong>V6 screenshots 097–108</strong></summary>

<table>
<tr>
<td width="50%"><a href="screenshots/v6/097-Screenshot_2026-10-07_18-26-59.png"><img src="screenshots/v6/097-Screenshot_2026-10-07_18-26-59.png" alt="V6 · 097 · 18:26:59" width="640" loading="lazy"></a><br><sub>V6 · 097 · 18:26:59</sub></td>
<td width="50%"><a href="screenshots/v6/098-Screenshot_2026-10-07_18-27-22.png"><img src="screenshots/v6/098-Screenshot_2026-10-07_18-27-22.png" alt="V6 · 098 · 18:27:22" width="640" loading="lazy"></a><br><sub>V6 · 098 · 18:27:22</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v6/099-Screenshot_2026-10-07_18-27-31.png"><img src="screenshots/v6/099-Screenshot_2026-10-07_18-27-31.png" alt="V6 · 099 · 18:27:31" width="640" loading="lazy"></a><br><sub>V6 · 099 · 18:27:31</sub></td>
<td width="50%"><a href="screenshots/v6/100-Screenshot_2026-10-07_18-27-35.png"><img src="screenshots/v6/100-Screenshot_2026-10-07_18-27-35.png" alt="V6 · 100 · 18:27:35" width="640" loading="lazy"></a><br><sub>V6 · 100 · 18:27:35</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v6/101-Screenshot_2026-10-07_18-27-37.png"><img src="screenshots/v6/101-Screenshot_2026-10-07_18-27-37.png" alt="V6 · 101 · 18:27:37" width="640" loading="lazy"></a><br><sub>V6 · 101 · 18:27:37</sub></td>
<td width="50%"><a href="screenshots/v6/102-Screenshot_2026-10-07_18-27-45.png"><img src="screenshots/v6/102-Screenshot_2026-10-07_18-27-45.png" alt="V6 · 102 · 18:27:45" width="640" loading="lazy"></a><br><sub>V6 · 102 · 18:27:45</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v6/103-Screenshot_2026-10-07_18-28-06.png"><img src="screenshots/v6/103-Screenshot_2026-10-07_18-28-06.png" alt="V6 · 103 · 18:28:06" width="640" loading="lazy"></a><br><sub>V6 · 103 · 18:28:06</sub></td>
<td width="50%"><a href="screenshots/v6/104-Screenshot_2026-10-07_18-28-16.png"><img src="screenshots/v6/104-Screenshot_2026-10-07_18-28-16.png" alt="V6 · 104 · 18:28:16" width="640" loading="lazy"></a><br><sub>V6 · 104 · 18:28:16</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v6/105-Screenshot_2026-10-07_18-28-21.png"><img src="screenshots/v6/105-Screenshot_2026-10-07_18-28-21.png" alt="V6 · 105 · 18:28:21" width="640" loading="lazy"></a><br><sub>V6 · 105 · 18:28:21</sub></td>
<td width="50%"><a href="screenshots/v6/106-Screenshot_2026-10-07_18-28-25.png"><img src="screenshots/v6/106-Screenshot_2026-10-07_18-28-25.png" alt="V6 · 106 · 18:28:25" width="640" loading="lazy"></a><br><sub>V6 · 106 · 18:28:25</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v6/107-Screenshot_2026-10-07_18-28-46.png"><img src="screenshots/v6/107-Screenshot_2026-10-07_18-28-46.png" alt="V6 · 107 · 18:28:46" width="640" loading="lazy"></a><br><sub>V6 · 107 · 18:28:46</sub></td>
<td width="50%"><a href="screenshots/v6/108-Screenshot_2026-10-07_18-28-58.png"><img src="screenshots/v6/108-Screenshot_2026-10-07_18-28-58.png" alt="V6 · 108 · 18:28:58" width="640" loading="lazy"></a><br><sub>V6 · 108 · 18:28:58</sub></td>
</tr>
</table>

</details>

<details>
<summary><strong>V6 screenshots 109–120</strong></summary>

<table>
<tr>
<td width="50%"><a href="screenshots/v6/109-Screenshot_2026-10-07_18-29-01.png"><img src="screenshots/v6/109-Screenshot_2026-10-07_18-29-01.png" alt="V6 · 109 · 18:29:01" width="640" loading="lazy"></a><br><sub>V6 · 109 · 18:29:01</sub></td>
<td width="50%"><a href="screenshots/v6/110-Screenshot_2026-10-07_18-29-07.png"><img src="screenshots/v6/110-Screenshot_2026-10-07_18-29-07.png" alt="V6 · 110 · 18:29:07" width="640" loading="lazy"></a><br><sub>V6 · 110 · 18:29:07</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v6/111-Screenshot_2026-10-07_18-29-21.png"><img src="screenshots/v6/111-Screenshot_2026-10-07_18-29-21.png" alt="V6 · 111 · 18:29:21" width="640" loading="lazy"></a><br><sub>V6 · 111 · 18:29:21</sub></td>
<td width="50%"><a href="screenshots/v6/112-Screenshot_2026-10-07_18-29-26.png"><img src="screenshots/v6/112-Screenshot_2026-10-07_18-29-26.png" alt="V6 · 112 · 18:29:26" width="640" loading="lazy"></a><br><sub>V6 · 112 · 18:29:26</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v6/113-Screenshot_2026-10-07_18-29-29.png"><img src="screenshots/v6/113-Screenshot_2026-10-07_18-29-29.png" alt="V6 · 113 · 18:29:29" width="640" loading="lazy"></a><br><sub>V6 · 113 · 18:29:29</sub></td>
<td width="50%"><a href="screenshots/v6/114-Screenshot_2026-10-07_18-29-35.png"><img src="screenshots/v6/114-Screenshot_2026-10-07_18-29-35.png" alt="V6 · 114 · 18:29:35" width="640" loading="lazy"></a><br><sub>V6 · 114 · 18:29:35</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v6/115-Screenshot_2026-10-07_18-29-46.png"><img src="screenshots/v6/115-Screenshot_2026-10-07_18-29-46.png" alt="V6 · 115 · 18:29:46" width="640" loading="lazy"></a><br><sub>V6 · 115 · 18:29:46</sub></td>
<td width="50%"><a href="screenshots/v6/116-Screenshot_2026-10-07_18-29-48.png"><img src="screenshots/v6/116-Screenshot_2026-10-07_18-29-48.png" alt="V6 · 116 · 18:29:48" width="640" loading="lazy"></a><br><sub>V6 · 116 · 18:29:48</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v6/117-Screenshot_2026-10-07_18-29-51.png"><img src="screenshots/v6/117-Screenshot_2026-10-07_18-29-51.png" alt="V6 · 117 · 18:29:51" width="640" loading="lazy"></a><br><sub>V6 · 117 · 18:29:51</sub></td>
<td width="50%"><a href="screenshots/v6/118-Screenshot_2026-10-07_18-30-04.png"><img src="screenshots/v6/118-Screenshot_2026-10-07_18-30-04.png" alt="V6 · 118 · 18:30:04" width="640" loading="lazy"></a><br><sub>V6 · 118 · 18:30:04</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v6/119-Screenshot_2026-10-07_18-30-25.png"><img src="screenshots/v6/119-Screenshot_2026-10-07_18-30-25.png" alt="V6 · 119 · 18:30:25" width="640" loading="lazy"></a><br><sub>V6 · 119 · 18:30:25</sub></td>
<td width="50%"><a href="screenshots/v6/120-Screenshot_2026-10-07_18-30-37.png"><img src="screenshots/v6/120-Screenshot_2026-10-07_18-30-37.png" alt="V6 · 120 · 18:30:37" width="640" loading="lazy"></a><br><sub>V6 · 120 · 18:30:37</sub></td>
</tr>
</table>

</details>

### Earlier setup gallery

These images document the earlier v3 setup and its native desktop interfaces.

<details>
<summary><strong>Frieren login themes · 2 screenshots</strong></summary>

<table>
<tr>
<td width="50%"><a href="screenshots/v3/01-frieren-sddm-login.webp"><img src="screenshots/v3/01-frieren-sddm-login.webp" alt="01 frieren sddm login" width="640" loading="lazy"></a><br><sub>01 frieren sddm login</sub></td>
<td width="50%"><a href="screenshots/v3/02-frieren-sddm-login-filled.webp"><img src="screenshots/v3/02-frieren-sddm-login-filled.webp" alt="02 frieren sddm login filled" width="640" loading="lazy"></a><br><sub>02 frieren sddm login filled</sub></td>
</tr>
</table>

</details>

<details>
<summary><strong>Aether / Caelestia · 7 screenshots</strong></summary>

<table>
<tr>
<td width="50%"><a href="screenshots/v3/03-caelestia-desktop.webp"><img src="screenshots/v3/03-caelestia-desktop.webp" alt="03 caelestia desktop" width="640" loading="lazy"></a><br><sub>03 caelestia desktop</sub></td>
<td width="50%"><a href="screenshots/v3/04-caelestia-notifications.webp"><img src="screenshots/v3/04-caelestia-notifications.webp" alt="04 caelestia notifications" width="640" loading="lazy"></a><br><sub>04 caelestia notifications</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v3/05-caelestia-quick-settings.webp"><img src="screenshots/v3/05-caelestia-quick-settings.webp" alt="05 caelestia quick settings" width="640" loading="lazy"></a><br><sub>05 caelestia quick settings</sub></td>
<td width="50%"><a href="screenshots/v3/06-caelestia-dashboard.webp"><img src="screenshots/v3/06-caelestia-dashboard.webp" alt="06 caelestia dashboard" width="640" loading="lazy"></a><br><sub>06 caelestia dashboard</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v3/07-caelestia-visualizer.webp"><img src="screenshots/v3/07-caelestia-visualizer.webp" alt="07 caelestia visualizer" width="640" loading="lazy"></a><br><sub>07 caelestia visualizer</sub></td>
<td width="50%"><a href="screenshots/v3/08-caelestia-multi-rice-switcher.webp"><img src="screenshots/v3/08-caelestia-multi-rice-switcher.webp" alt="08 caelestia multi rice switcher" width="640" loading="lazy"></a><br><sub>08 caelestia multi rice switcher</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v3/09-caelestia-wallpaper-picker.webp"><img src="screenshots/v3/09-caelestia-wallpaper-picker.webp" alt="09 caelestia wallpaper picker" width="640" loading="lazy"></a><br><sub>09 caelestia wallpaper picker</sub></td>
</tr>
</table>

</details>

<details>
<summary><strong>Obsidian / end4 · 3 screenshots</strong></summary>

<table>
<tr>
<td width="50%"><a href="screenshots/v3/10-end4-pc-desktop.webp"><img src="screenshots/v3/10-end4-pc-desktop.webp" alt="10 end4 pc desktop" width="640" loading="lazy"></a><br><sub>10 end4 pc desktop</sub></td>
<td width="50%"><a href="screenshots/v3/11-end4-pc-media.webp"><img src="screenshots/v3/11-end4-pc-media.webp" alt="11 end4 pc media" width="640" loading="lazy"></a><br><sub>11 end4 pc media</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v3/12-end4-pc-settings.webp"><img src="screenshots/v3/12-end4-pc-settings.webp" alt="12 end4 pc settings" width="640" loading="lazy"></a><br><sub>12 end4 pc settings</sub></td>
</tr>
</table>

</details>

<details>
<summary><strong>Crimson / Ambxst · 3 screenshots</strong></summary>

<table>
<tr>
<td width="50%"><a href="screenshots/v3/13-ambxst-dashboard.webp"><img src="screenshots/v3/13-ambxst-dashboard.webp" alt="13 ambxst dashboard" width="640" loading="lazy"></a><br><sub>13 ambxst dashboard</sub></td>
<td width="50%"><a href="screenshots/v3/14-ambxst-wallpaper-picker.webp"><img src="screenshots/v3/14-ambxst-wallpaper-picker.webp" alt="14 ambxst wallpaper picker" width="640" loading="lazy"></a><br><sub>14 ambxst wallpaper picker</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v3/15-ambxst-system-monitor.webp"><img src="screenshots/v3/15-ambxst-system-monitor.webp" alt="15 ambxst system monitor" width="640" loading="lazy"></a><br><sub>15 ambxst system monitor</sub></td>
</tr>
</table>

</details>

<details>
<summary><strong>Materia / DankMaterialShell · 5 screenshots</strong></summary>

<table>
<tr>
<td width="50%"><a href="screenshots/v3/16-dms-overview.webp"><img src="screenshots/v3/16-dms-overview.webp" alt="16 dms overview" width="640" loading="lazy"></a><br><sub>16 dms overview</sub></td>
<td width="50%"><a href="screenshots/v3/17-dms-launcher.webp"><img src="screenshots/v3/17-dms-launcher.webp" alt="17 dms launcher" width="640" loading="lazy"></a><br><sub>17 dms launcher</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v3/18-dms-weather.webp"><img src="screenshots/v3/18-dms-weather.webp" alt="18 dms weather" width="640" loading="lazy"></a><br><sub>18 dms weather</sub></td>
<td width="50%"><a href="screenshots/v3/19-dms-processes.webp"><img src="screenshots/v3/19-dms-processes.webp" alt="19 dms processes" width="640" loading="lazy"></a><br><sub>19 dms processes</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v3/25-dms-media.webp"><img src="screenshots/v3/25-dms-media.webp" alt="25 dms media" width="640" loading="lazy"></a><br><sub>25 dms media</sub></td>
</tr>
</table>

</details>

<details>
<summary><strong>Nocturne / Noctalia · 5 screenshots</strong></summary>

<table>
<tr>
<td width="50%"><a href="screenshots/v3/20-noctalia-system.webp"><img src="screenshots/v3/20-noctalia-system.webp" alt="20 noctalia system" width="640" loading="lazy"></a><br><sub>20 noctalia system</sub></td>
<td width="50%"><a href="screenshots/v3/21-noctalia-launcher.webp"><img src="screenshots/v3/21-noctalia-launcher.webp" alt="21 noctalia launcher" width="640" loading="lazy"></a><br><sub>21 noctalia launcher</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v3/22-noctalia-media.webp"><img src="screenshots/v3/22-noctalia-media.webp" alt="22 noctalia media" width="640" loading="lazy"></a><br><sub>22 noctalia media</sub></td>
<td width="50%"><a href="screenshots/v3/23-noctalia-btop.webp"><img src="screenshots/v3/23-noctalia-btop.webp" alt="23 noctalia btop" width="640" loading="lazy"></a><br><sub>23 noctalia btop</sub></td>
</tr>
<tr>
<td width="50%"><a href="screenshots/v3/24-noctalia-unimatrix-media.webp"><img src="screenshots/v3/24-noctalia-unimatrix-media.webp" alt="24 noctalia unimatrix media" width="640" loading="lazy"></a><br><sub>24 noctalia unimatrix media</sub></td>
</tr>
</table>

</details>

<!-- SUMI_COMPLETE_GALLERIES_END -->

## Sources and credits

Release sources are maintained on [`v6.0-tahoe-dev`](https://github.com/huzaifahshahid71-ops/dotfiles/tree/v6.0-tahoe-dev). The [v6 release](https://github.com/huzaifahshahid71-ops/dotfiles/releases/tag/v6.0.0) includes the matching **`sumi-installer-source-v6.0.0-r3.zip`**, split payload, setup runtime and checksums. Older release assets remain available for their corresponding revisions; use matching revision files together.

This setup builds on Caelestia, end4, Ambxst/axctl, DankMaterialShell, Serpantinum, Noctalia, Sayconlun, Tsugumori, JAQC, Clavis, Nixri, iNiR, Hyprland, Niri, Quickshell and the included SDDM/GRUB and icon themes. Third-party projects retain their respective licenses and credits.

Original Sumi installer code, tools and documentation are licensed under [MIT](LICENSE). Bundled and adapted third-party components retain their respective licenses; see [licensing scope](LICENSING.md).

**App developer: Huzaifah.**
