# Huzaifah's Hyprland Dual-Rice Dotfiles

A complete Hyprland customization built around **Caelestia** and **end4-pC**, with a one-command installer, a Frieren theme, and a desktop-profile switcher.

This repository is for people who already have an **Arch/CachyOS-family Linux installation** and want the desktop customization. It does **not** contain an operating-system installation guide.

## ✨ What you get

The default installer sets up the full desktop automatically:

- ✦ **Caelestia** rice and user configuration
- ◈ **end4-pC** rice based on pctrade/end4-pC
- saved end4 widget and top-bar layout
- **125% end4 display scale** from the captured Hyprland profile
- **Frieren desktop wallpaper**
- **Frieren SDDM login theme**
- `SUPER + SHIFT + D` desktop-profile switcher
- polished Fuzzel profile selector
- album-art fixes for Base64 MPRIS artwork in end4-pC
- desktop media widget artwork support
- Caelestia desktop lyrics / visualiser configuration
- background-music service and Favorites playlist metadata when present
- pinned end4/end4-pC revisions so restores are reproducible

The two desktop profiles are isolated from each other. Switching does not mix their Hyprland configs; the selected profile becomes active on the next login.

## 🚀 Install

### Requirements

You need:

- an existing Arch Linux / CachyOS-family installation
- internet access
- `sudo` access

The installer handles the required desktop packages, AUR helper setup when needed, Caelestia, Quickshell, end4-pC and the supporting utilities.

### One command

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/huzaifahshahid71-ops/dotfiles/main/install.sh)"
```

With **no flags**, `install.sh` automatically installs:

```text
Huzaifah Desktop
├── ✦ Caelestia
├── ◈ end4-pC
├── 🖼 Frieren wallpaper
├── 🌙 Frieren SDDM theme
├── ⇄ SUPER + SHIFT + D switcher
└── end4-pC album-art patches
```

The dual-rice restore creates a safety backup of existing relevant configuration before replacing it.

When installation finishes, **log out and log back into Hyprland**.

## ⇄ Switching between Caelestia and end4-pC

Press:

```text
SUPER + SHIFT + D
```

Choose either:

```text
✦ Caelestia
◈ end4-pC
```

Confirm the switch, log back in, and the selected rice starts with its own Hyprland configuration.

CLI equivalents are also available:

```bash
desktop-switch status
desktop-switch caelestia --now
desktop-switch end4 --now
```

## 🧩 Installer options

The default command installs the full customization. These flags are available when you want only part of it:

| Option | Action |
| --- | --- |
| `--customization` | Full customization; same as no flags |
| `--dual-rice` | Full customization alias |
| `--dual-rice-only` | Caelestia + end4-pC + wallpaper, without changing SDDM theme |
| `--no-sddm-theme` | Same as `--dual-rice-only` |
| `--sddm-theme-only` | Install only the Frieren SDDM theme |
| `--status` | Show system-setup status |

Example:

```bash
./install.sh --dual-rice-only
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

## 🖼 Frieren theme and wallpaper

The repository already contains the Frieren asset used by the SDDM theme:

```text
machine/sddm/themes/sddm-frieren-theme/Backgrounds/frieren.jpg
```

During the normal customization install it is also copied to:

```text
~/Pictures/Wallpapers/frieren.jpg
```

The end4-pC restored configuration points to this portable per-user path, and the Caelestia wallpaper directory is rewritten to the current user's `~/Pictures/Wallpapers` instead of retaining my username.

## 🎵 end4-pC album-art fix

Some MPRIS players, including an mpv + mpv-mpris setup, can expose embedded cover art as a Base64 data URI:

```text
data:image/jpeg;base64,...
```

The upstream end4-pC player originally handled normal files/URLs but did not handle this case everywhere. This repository preserves small local patches for both the regular player and the desktop media widget so embedded cover art displays correctly after a restore.

The patches are stored as:

```text
dual-rice/versions/end4-pC-local.patch
```

## 🛟 Recovery

If an end4 change ever prevents the desktop from loading, switch to a TTY and run:

```bash
~/.local/bin/recover-caelestia
```

Then log back in or reboot if necessary.

The dual-rice restore also creates timestamped backups under:

```text
~/.local/share/desktop-profile-backups/
```

## 💾 Backing up the current rice

The working desktop can be captured back into this repository with:

```bash
cd ~/dotfiles
./scripts/backup-dual-rice.sh
```

Review the changes, then push them with:

```bash
./scripts/backup-dual-rice.sh --push
```

The backup captures:

- both Hyprland profiles
- Caelestia user configuration
- end4-pC widget/bar configuration from `~/.config/illogical-impulse/config.json`
- desktop switcher configuration
- helper scripts
- package/version manifests
- pinned end4/end4-pC commits
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
├── dual-rice/
│   ├── profiles/
│   │   ├── caelestia/hypr/
│   │   └── end4/hypr/
│   ├── caelestia/
│   ├── end4/
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
- **Hyprland** and **Quickshell**

Their code remains under their respective upstream licenses. Local patches/configuration in this repository are intended to customize those projects, not replace their upstream work.

## ⚠️ Notes

This is a desktop customization repository, not a universal Linux installer. The automatic path focuses on the visual/user-session setup. Bootloader, refresh-rate automation, hibernation and hardware-specific ASUS/G16 operations remain explicit opt-ins.

If you only want the rice, just run the default installer and ignore the machine-specific flags.
