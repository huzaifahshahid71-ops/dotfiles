# Huzaifah's Hyprland Triple-Rice Dotfiles

A complete Hyprland customization built around **Caelestia**, **end4-pC**, and **Ambxst**, with a one-command installer, Frieren SDDM theme, and a desktop-profile switcher.

This repository is for people who already have an **Arch/CachyOS-family Linux installation** and want the desktop customization. It does **not** contain an operating-system installation guide.

## ✨ What you get

The default installer sets up the full desktop automatically:

- ✦ **Caelestia** rice and user configuration
- ◈ **end4-pC** rice based on pctrade/end4-pC
- ◆ **Ambxst** rice with axctl compositor integration
- isolated Hyprland profile for each rice
- saved end4 widget and top-bar layout
- **125% end4/Ambxst display scale** from the captured profiles
- **Frieren SDDM login theme**
- `SUPER + SHIFT + D` triple-rice profile switcher
- polished Fuzzel profile selector
- album-art fixes for Base64 MPRIS artwork in end4-pC
- desktop media widget artwork support
- search-only end4 launcher with the workspace grid hidden
- Caelestia desktop lyrics / visualiser configuration
- background-music service and Favorites playlist metadata when present
- pinned end4, end4-pC, and Ambxst revisions for reproducible restores

**The installer does not replace your desktop wallpaper.**

The three desktop profiles are isolated from each other. Switching changes the `~/.config/hypr` symlink to the selected profile and starts that rice on the next login.

## 🚀 Install

### Requirements

You need:

- an existing Arch Linux / CachyOS-family installation
- internet access
- `sudo` access

The installer handles the required desktop packages, AUR helper setup when needed, Caelestia, Quickshell, end4-pC, Ambxst, axctl, and supporting utilities.

### One command

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/huzaifahshahid71-ops/dotfiles/main/install.sh)"
```

With **no flags**, `install.sh` automatically installs:

```text
Huzaifah Desktop
├── ✦ Caelestia
├── ◈ end4-pC
├── ◆ Ambxst + axctl
├── 🔎 Search-only end4 launcher
├── 🌙 Frieren SDDM theme
├── ⇄ SUPER + SHIFT + D triple-rice switcher
└── end4-pC album-art patches
```

The restore creates a safety backup of existing relevant configuration before replacing it.

When installation finishes, **log out and log back into Hyprland**.

## ⇄ Switching between all three rices

Press:

```text
SUPER + SHIFT + D
```

Choose:

```text
✦ Caelestia
◈ end4-pC
◆ Ambxst
```

Confirm the switch and the session logs out. Log back in and the selected rice starts with its own Hyprland profile.

CLI equivalents are also available:

```bash
desktop-switch status
desktop-switch caelestia --now
desktop-switch end4 --now
desktop-switch ambxst --now
```

## ◆ Ambxst integration

Ambxst is installed from the official **Axenide/Ambxst** repository. Its shell runs through Quickshell while **axctl** provides compositor IPC and generates Ambxst's Hyprland configuration under:

```text
~/.local/share/ambxst/
```

The isolated profile lives at:

```text
~/.local/share/desktop-profiles/ambxst/hypr/
```

On a normal boot it loads Ambxst's generated `hyprland.lua`. On a fresh restore, the profile can bootstrap Ambxst directly once so axctl can regenerate that file from the restored Ambxst configuration.

## 🧩 Installer options

The default command installs the full customization. These flags are available when you want only part of it:

| Option | Action |
| --- | --- |
| `--customization` | Full customization; same as no flags |
| `--triple-rice` | Full customization alias |
| `--triple-rice-only` | Caelestia + end4-pC + Ambxst without changing SDDM |
| `--no-sddm-theme` | Same rice setup but skip SDDM |
| `--sddm-theme-only` | Install only the Frieren SDDM theme |
| `--dual-rice` | Compatibility alias for `--triple-rice` |
| `--dual-rice-only` | Compatibility alias for `--triple-rice-only` |
| `--status` | Show system-setup status |

Example:

```bash
./install.sh --triple-rice-only
```

### Optional machine-specific extras

These are **never run automatically**:

```text
--asus
--g16
--refind
--refresh
--hibernate
```

They exist for my own hardware/setup workflows and should only be used when you know you want them.

## 🌙 Frieren SDDM theme

The repository contains the Frieren theme used for the login screen under:

```text
machine/sddm/themes/sddm-frieren-theme/
```

The image at:

```text
machine/sddm/themes/sddm-frieren-theme/Backgrounds/frieren.jpg
```

is simply an asset **inside the SDDM theme**. It is not installed as your desktop wallpaper.

## 🎵 end4-pC album-art fix

Some MPRIS players, including an mpv + mpv-mpris setup, can expose embedded cover art as a Base64 data URI:

```text
data:image/jpeg;base64,...
```

This repository preserves local patches for the regular player and desktop media widget so embedded cover art displays correctly after a restore.

The patch is stored as:

```text
dual-rice/versions/end4-pC-local.patch
```

## 🛟 Recovery

If any rice prevents the desktop from loading, switch to a TTY and run:

```bash
~/.local/bin/recover-caelestia
```

Then log back in or reboot if necessary.

Timestamped restore backups are stored under:

```text
~/.local/share/desktop-profile-backups/
```

## 💾 Backing up the current rice

The historical script name is retained for compatibility, but it now captures all **three** rices:

```bash
cd ~/dotfiles
./scripts/backup-dual-rice.sh
```

Review the changes, then push them with:

```bash
./scripts/backup-dual-rice.sh --push
```

The backup captures:

- all three Hyprland profiles
- Caelestia user configuration
- end4-pC widget/bar configuration from `~/.config/illogical-impulse/config.json`
- Ambxst user configuration from `~/.config/ambxst`
- desktop switcher configuration
- helper scripts
- package/version manifests
- pinned end4/end4-pC/Ambxst commits
- Ambxst and axctl versions
- local end4 patches
- playlist metadata

Caches, `.env` files, SSH private keys and obvious secret/token files are deliberately excluded or blocked from automatic pushing.

## 📁 Repository layout

```text
.
├── install.sh
├── scripts/
│   ├── backup-dual-rice.sh
│   └── restore-dual-rice.sh
├── dual-rice/                 # historical path name kept for compatibility
│   ├── profiles/
│   │   ├── caelestia/hypr/
│   │   ├── end4/hypr/
│   │   └── ambxst/hypr/
│   ├── caelestia/
│   ├── end4/
│   ├── ambxst/
│   ├── desktop-switcher/
│   ├── bin/
│   ├── packages/
│   ├── versions/
│   └── state/
├── machine/
│   └── sddm/themes/sddm-frieren-theme/
└── system-setup.sh
```

## 🔧 Upstream projects

This setup builds on excellent upstream work:

- **Caelestia / DiM Caelestia** — the Caelestia shell and desktop experience
- **end-4/dots-hyprland** — illogical-impulse and the original end4 Hyprland setup
- **pctrade/end4-pC** — the end4-pC custom Quickshell fork used by the second rice
- **Axenide/Ambxst** — the third shell/rice
- **Axenide/axctl** — compositor IPC used by Ambxst
- **Hyprland** and **Quickshell**

Their code remains under their respective upstream licenses. Local patches/configuration in this repository are intended to customize those projects, not replace their upstream work.

## ⚠️ Notes

This is a desktop customization repository, not a universal Linux installer. The automatic path focuses on the visual/user-session setup. Bootloader, refresh-rate automation, hibernation and hardware-specific ASUS/G16 operations remain explicit opt-ins.

If you only want the desktop customization, run the default installer and ignore the machine-specific flags.
