# Huzaifah's Hyprland Multi-Rice Dotfiles

A complete Hyprland customization built around **Caelestia**, **end4-pC**, **Ambxst**, and **DankMaterialShell (DMS)**, with a one-command installer, Frieren SDDM theme, and a dynamic desktop-profile switcher.

This repository is for people who already have an **Arch/CachyOS-family Linux installation** and want the desktop customization. It does **not** install an operating system.

## ✨ What you get

The default installer sets up:

- ✦ **Caelestia** rice and user configuration
- ◈ **end4-pC** rice based on pctrade/end4-pC
- ◆ **Ambxst** rice with axctl compositor integration
- ● **DankMaterialShell (DMS)** as an isolated fourth rice
- a separate Hyprland profile for every rice
- a dynamic `SUPER + SHIFT + D` Multi-Rice switcher
- saved end4 widget/top-bar layout and local album-art patches
- search-only end4 launcher with the workspace grid hidden
- **Frieren SDDM login theme**
- safety backups before profile restoration

**The installer does not choose or replace your desktop wallpaper.** The Frieren image belongs to the SDDM login theme only.

## 🚀 Install

Requirements:

- Arch Linux / CachyOS-family installation
- internet access
- `sudo` access

Run:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/huzaifahshahid71-ops/dotfiles/main/install.sh)"
```

With no flags, the installer sets up the complete Multi-Rice desktop:

```text
Huzaifah Desktop
├── ✦ Caelestia
├── ◈ end4-pC
├── ◆ Ambxst + axctl
├── ● DankMaterialShell
├── 🔎 Search-only end4 launcher
├── 🌙 Frieren SDDM login theme
└── ⇄ SUPER + SHIFT + D dynamic Multi-Rice switcher
```

When installation finishes, log out and back into Hyprland.

## ⇄ Switching rices

Press:

```text
SUPER + SHIFT + D
```

The preferred order is:

```text
✦ Caelestia
◈ end4-pC
◆ Ambxst
● DankMaterialShell
```

The switcher also discovers additional valid profiles placed under `~/.local/share/desktop-profiles`, so the design is not hard-coded to four rices.

CLI examples:

```bash
desktop-switch list
desktop-switch status
desktop-switch caelestia --now
desktop-switch end4 --now
desktop-switch ambxst --now
desktop-switch dms --now
```

Switching atomically repoints `~/.config/hypr` to the chosen profile and logs out so the next Hyprland session starts that rice.

## ● DankMaterialShell integration

DMS is deliberately **not** enabled as a global `dms.service`. In a Multi-Rice environment that could make DMS start on top of Caelestia, end4-pC, or Ambxst. Instead, the DMS Hyprland profile starts it with `dms run` only when the DMS rice is active.

The tested profile is based on DMS **v1.5.3** and uses Alacritty. Custom DMS shortcuts included in this setup are:

```text
SUPER                  DMS application launcher
SUPER + SHIFT + S      region screenshot
SUPER + SHIFT + D      Multi-Rice switcher
SUPER + T              Alacritty
SUPER + Q              close window
SUPER + SHIFT + E      exit Hyprland
```

DMS wallpaper selection remains user-controlled; the installer does not force a wallpaper directory or replace the current desktop wallpaper.

## ◆ Ambxst integration

Ambxst is installed from the official `Axenide/Ambxst` repository. Its shell runs through Quickshell while axctl provides compositor IPC and generates Ambxst's supporting Hyprland state under:

```text
~/.local/share/ambxst/
```

The isolated profile lives at:

```text
~/.local/share/desktop-profiles/ambxst/hypr/
```

## 🧩 Installer options

| Option | Action |
| --- | --- |
| `--customization` | Full customization; same as no flags |
| `--multi-rice` | Full customization alias |
| `--multi-rice-only` | Install all four rices without changing SDDM |
| `--no-sddm-theme` | Install Multi-Rice but skip SDDM |
| `--sddm-theme-only` | Install only the Frieren SDDM login theme |
| `--triple-rice` / `--triple-rice-only` | Compatibility aliases |
| `--dual-rice` / `--dual-rice-only` | Compatibility aliases |
| `--status` | Show system-setup status |

Example:

```bash
./install.sh --multi-rice-only
```

Machine-specific extras remain opt-in only:

```text
--asus
--g16
--refind
--refresh
--hibernate
```

## 📦 AppImage installer

The **Huzaifah Multi-Rice Installer v2.0.0** release provides a lightweight x86_64 AppImage graphical front-end. It launches the same online installer used by the one-command method, so upstream packages and source trees are downloaded during installation.

Release assets include:

```text
Huzaifah-Multi-Rice-Installer-x86_64.AppImage
Huzaifah-Multi-Rice-Installer-x86_64.tar.gz
SHA256SUMS.txt
```

The tarball contains the same AppImage while preserving its executable bit after extraction.

The repository also contains work for a much larger fully-offline AppImage payload. That offline artifact is separate from the lightweight release above and should not be assumed to be current until it is explicitly rebuilt and published.

## 🌙 Frieren SDDM theme

The login theme lives under:

```text
machine/sddm/themes/sddm-frieren-theme/
```

Its image asset:

```text
machine/sddm/themes/sddm-frieren-theme/Backgrounds/frieren.jpg
```

is used by SDDM only. It is not installed as your desktop wallpaper.

## 🛟 Recovery

If a rice prevents the desktop from loading, switch to a TTY and run:

```bash
~/.local/bin/recover-caelestia
```

Timestamped safety backups are stored under:

```text
~/.local/share/desktop-profile-backups/
```

## 💾 Backing up the current Multi-Rice setup

The historical script/path names are retained for compatibility:

```bash
cd ~/dotfiles
./scripts/backup-dual-rice.sh
```

To review, commit, and push the snapshot automatically:

```bash
./scripts/backup-dual-rice.sh --push
```

The backup script now captures all four Hyprland profiles, Caelestia configuration, end4 layout, Ambxst configuration, DMS configuration when present, switcher files, package/version manifests, pinned source revisions, local patches, and selected portable state. Caches, `.env` files, private keys, and obvious credential/token files are excluded or block automatic pushing.

## 📁 Repository layout

```text
.
├── install.sh
├── scripts/
│   ├── backup-dual-rice.sh             # historical filename retained
│   ├── restore-dual-rice.sh            # online Multi-Rice restore
│   └── restore-triple-rice-offline.sh  # historical filename retained
├── dual-rice/                           # historical path name retained
│   ├── profiles/
│   │   ├── caelestia/hypr/
│   │   ├── end4/hypr/
│   │   ├── ambxst/hypr/
│   │   └── dms/hypr/
│   ├── caelestia/
│   ├── end4/
│   ├── ambxst/
│   ├── dms/
│   ├── desktop-switcher/
│   ├── bin/
│   ├── packages/
│   ├── versions/
│   └── state/
├── installer-appimage/
├── machine/
│   └── sddm/themes/sddm-frieren-theme/
└── system-setup.sh
```

## 🔧 Upstream projects

This setup builds on:

- **Caelestia / DiM Caelestia**
- **end-4/dots-hyprland**
- **pctrade/end4-pC**
- **Axenide/Ambxst** and **axctl**
- **AvengeMedia/DankMaterialShell**
- **Hyprland** and **Quickshell**

Their code remains under their respective upstream licenses. Local configuration and patches in this repository customize those projects rather than replace them.

## ⚠️ Notes

This is a desktop-customization repository, not a universal Linux installer. Bootloader changes, refresh-rate automation, hibernation, and hardware-specific ASUS/G16 actions remain explicit opt-ins.
