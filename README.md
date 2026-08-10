# Huzaifah's CachyOS / Hyprland Dotfiles

Personal dotfiles and setup automation for my CachyOS/Arch Linux workstation, centered around **Hyprland**, **DiM Caelestia**, **Fish**, and an ASUS ROG Zephyrus G16 workflow.

The goal of this repository is simple: after a reinstall, I should be able to clone one repository, run one command, and restore the core desktop experience without manually rebuilding every configuration from scratch.

> This is primarily a personal configuration repository. It is designed around my own hardware and workflow, especially CachyOS/Arch and ASUS ROG laptops. Read the scripts before using them on a different machine.

---

## What this repository restores

The installer is intended to restore the user-facing configuration and supporting utilities that make up the desktop environment:

- Hyprland configuration
- DiM Caelestia user configuration
- Fish shell configuration
- mpv / MPRIS configuration
- personal helper scripts in `~/.local/bin`
- user-level systemd services
- saved official repository and AUR package lists
- ASUS laptop utilities
- Zephyrus G16-specific helpers
- rEFInd configuration and theme
- optional refresh-rate automation
- optional Btrfs hibernation swap setup

The repository deliberately keeps hardware-sensitive or security-sensitive operations out of the automatic path where possible.

---

# Quick install

For a fresh CachyOS/Arch installation:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/huzaifahshahid71-ops/dotfiles/main/install.sh)"
```

The default command starts the interactive installer.

For a direct Zephyrus G16 setup with rEFInd:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/huzaifahshahid71-ops/dotfiles/main/install.sh)" -- --g16 --refind
```

For the complete supported setup:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/huzaifahshahid71-ops/dotfiles/main/install.sh)" -- --all
```

---

# Installer profiles

The installer supports separate profiles so machine-specific configuration does not have to be mixed into the normal desktop setup.

| Option | Purpose |
|---|---|
| `--base` | Base CachyOS/Arch desktop configuration |
| `--asus` | Generic ASUS laptop support |
| `--g16` | ASUS ROG Zephyrus G16-specific additions |
| `--refind` | rEFInd installation/restoration |
| `--refresh` | Enable AC/battery refresh-rate automation |
| `--hibernate` | Configure the saved Btrfs hibernation setup |
| `--all` | Install the full supported configuration |
| `--status` | Show system and configuration status |

Example:

```bash
./install.sh --g16 --refind
```

---

# Base desktop setup

The base profile is intended for CachyOS/Arch and installs/restores the normal desktop environment.

The core stack is:

- **CachyOS / Arch Linux**
- **Hyprland**
- **DiM Caelestia**
- **Fish**
- **GNU Stow**
- **mpv**
- **playerctl**
- supporting shell and desktop utilities

The installer uses GNU Stow-style package directories so the repository remains readable and configuration files still appear at their normal locations inside `$HOME`.

Before replacing a regular file, the installer moves conflicting files into a timestamped backup directory under:

```text
~/dotfiles-backup/
```

This makes reinstalling much safer than blindly overwriting an existing setup.

---

# DiM Caelestia

The daily shell is based on the **DiM Caelestia** fork.

The dotfiles repository stores the user configuration for Caelestia rather than embedding the entire upstream shell source tree.

The experimental development shell is kept separate at:

```text
~/.config/quickshell/huzaifah-shell-dev
```

That development repository is intentionally **not nested inside this dotfiles repository**. When the system is captured, its Git origin, branch, and commit can be recorded in:

```text
machine/custom-shell.txt
```

This keeps the main dotfiles repository clean while still preserving exactly which custom-shell revision was being used.

---

# ASUS laptop support

Install the ASUS profile with:

```bash
./install.sh --asus
```

The ASUS profile installs the ASUS laptop control utilities used by this setup and exposes the normal management commands without automatically changing GPU mode.

Typical commands include:

```bash
asusctl --help
asusctl profile -n
rog-control-center
```

The installer avoids silently replacing another active power-management stack. If something such as TLP or tuned is already active, it leaves that decision to the user.

---

# ASUS ROG Zephyrus G16 profile

Install the G16 profile with:

```bash
./install.sh --g16
```

This profile builds on the generic ASUS setup and is intended for the ROG Zephyrus G16 family used with these dotfiles.

The current desktop assumptions include:

- Hyprland display scale around `1.25`
- high-refresh internal panel
- approximately `120 Hz` on battery
- `240 Hz` on AC power
- an optional user systemd service for automatic refresh-rate switching

The installer can detect common G16 DMI identifiers and also allows the profile to be applied manually when the exact revision is different.

## GPU switching

GPU mode is intentionally not changed automatically.

Optional GPU switching tools may be installed, but commands such as the following should be run manually only after checking the current system state:

```bash
supergfxctl --help
supergfxctl --mode Hybrid
supergfxctl --mode Integrated
```

This is intentional: changing graphics mode can terminate the graphical session or require a reboot depending on the hardware and current driver state.

---

# Refresh-rate automation

The optional refresh profile enables the existing user service:

```text
auto-refresh-rate.service
```

Its purpose is to keep the internal display at the preferred high refresh rate on AC power and a lower high-refresh mode on battery.

Enable it with:

```bash
./install.sh --refresh
```

The exact behavior remains defined by the scripts/service files stored in this repository, so it can be reviewed or changed without editing the installer itself.

---


# Frieren SDDM login theme

The repository also backs up and restores my **exact SDDM login screen**, not
just the name of the theme.

The live theme is captured from:

```text
/usr/share/sddm/themes/sddm-frieren-theme
```

and stored in:

```text
machine/sddm/themes/sddm-frieren-theme/
```

The capture preserves the complete theme directory as it exists on the
working machine, including its QML layout, configuration, images, theme
metadata, positioning, sizing, and other customizations.

The active SDDM configuration is also captured from:

```text
/etc/sddm.conf
/etc/sddm.conf.d/
```

when those paths exist. Their repository copies live under:

```text
machine/sddm/etc/
```

This means a fresh install restores the **same Frieren login-screen format and
configuration**, rather than installing a generic copy of the theme.

The normal one-command installer restores this automatically during the base
installation whenever an SDDM snapshot exists:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/huzaifahshahid71-ops/dotfiles/main/install.sh)"
```

It can also be restored manually with:

```bash
./system-setup.sh sddm
```

or:

```bash
./install.sh --sddm
```

Before replacing the installed theme or `/etc` configuration, the installer
makes a timestamped root-owned backup under:

```text
/var/backups/huzaifah-dotfiles/sddm/
```

If another display manager is already configured, the files are restored but
the installer does not silently replace that display manager.

> The Frieren screen described here is the **SDDM login screen**. The in-session
> Super+L lock screen remains part of Caelestia and is separate from SDDM.

---

# rEFInd

The rEFInd profile is intended to restore the customized boot manager after a reinstall.

Run:

```bash
./install.sh --refind
```

The setup process is designed to:

1. detect the EFI System Partition
2. install rEFInd when necessary
3. create a timestamped backup of the active `refind.conf`
4. restore the repository's rEFInd configuration
5. replace the stored root UUID placeholder with the current machine's root UUID
6. restore the saved `rEFInd-minimal` theme when available
7. preserve graphical Linux boot configuration

The rEFInd snapshot also stores `/boot/refind_linux.conf`, which contains the Linux kernel boot options used by rEFInd. During capture, the current root filesystem UUID is replaced with `__ROOT_UUID__`; during restore, the installer substitutes the UUID of the fresh Linux installation.

The stored configuration uses:

```text
__ROOT_UUID__
```

instead of hard-coding the UUID of one installation.

That allows the same repository to be reused after repartitioning or reinstalling.

## Secure Boot

Secure-Boot signing is intentionally not automated by this repository.

If Secure Boot is enabled, the installer stops before performing configuration that assumes unsigned rEFInd binaries.

This is kept manual because signing keys and Secure-Boot enrollment are machine-security credentials, not normal dotfiles.

---

# Hibernation

The optional hibernation profile is for the Btrfs-based setup used on the target machine.

Run:

```bash
./install.sh --hibernate
```

The current profile is designed around:

```text
/swap/swapfile
```

with a size of:

```text
20G
```

It creates/configures the Btrfs swapfile, adds it to `/etc/fstab`, configures the hibernation image size, and displays the Btrfs resume offset needed for verification.

The script **does not automatically hibernate the machine**.

Because hibernation depends on the active kernel/initramfs/boot configuration, the resulting setup should always be verified before relying on it.

---

# Package backup and restore

The machine capture command stores separately:

```text
machine/packages/pacman.txt
machine/packages/aur.txt
```

These represent explicitly installed official-repository and foreign/AUR packages.

Restore them with:

```bash
./system-setup.sh packages
```

The package capture intentionally excludes categories that should not be blindly reproduced on another install, especially GPU/NVIDIA/CUDA and Secure-Boot tooling.

---

# Capturing the current machine

After changing the desktop configuration, update the repository with:

```bash
cd ~/dotfiles
./system-setup.sh capture
git status
git diff
```

The capture command synchronizes supported configuration into the repository and records machine-specific metadata.

It can capture:

- Caelestia configuration
- Fish configuration
- Hyprland configuration
- mpv configuration
- `~/.local/bin`
- user systemd units
- package lists
- sanitized rEFInd configuration
- rEFInd theme files
- hardware/system metadata
- custom Quickshell development revision metadata

After reviewing:

```bash
git add -A
git commit -m "chore: update system snapshot"
git push
```

---

# Repository structure

```text
dotfiles/
├── caelestia/                 # ~/.config/caelestia
├── fish/                      # ~/.config/fish
├── hypr/                      # ~/.config/hypr
├── mpv/                       # ~/.config/mpv
├── scripts/                   # ~/.local/bin helpers
├── systemd/                   # ~/.config/systemd/user
├── hardware/
│   ├── ASUS.md
│   ├── ZEPHYRUS-G16.md
│   └── REFIND.md
├── machine/
│   ├── packages/
│   │   ├── pacman.txt
│   │   └── aur.txt
│   ├── refind/
│   ├── sddm/
│   │   ├── themes/sddm-frieren-theme/
│   │   └── etc/
│   ├── current-system.txt
│   └── custom-shell.txt
├── install.sh
├── system-setup.sh
└── README.md
```

Some `machine/` files only appear after running a capture.

---

# System management commands

The lower-level helper can also be called directly:

```bash
./system-setup.sh capture
./system-setup.sh packages
./system-setup.sh asus
./system-setup.sh g16
./system-setup.sh refind
./system-setup.sh sddm
./system-setup.sh refresh
./system-setup.sh hibernate
./system-setup.sh status
```

Use:

```bash
./system-setup.sh --help
```

or:

```bash
./install.sh --help
```

to see the available options.

---

# What is intentionally NOT automated

A reinstall script should not make every possible system decision automatically.

This repository deliberately avoids automatically managing:

- NVIDIA driver installation or replacement
- CUDA installation
- automatic GPU-mode switching
- Secure-Boot key creation
- Secure-Boot signing/enrollment
- destructive partitioning
- BIOS/UEFI settings
- automatic hibernation testing
- secrets, tokens, passwords, or credentials

Those operations are either hardware-specific, security-sensitive, or capable of leaving the machine unbootable if applied incorrectly.

---

# Secret and cache handling

The capture process excludes common temporary or sensitive files such as:

```text
.env
.env.*
*token*
*secret*
*credential*
*.log
*.pid
*.lock
cache/
.cache/
build/
```

Fish universal variables are also excluded from the automatic capture.

Before pushing a new snapshot, always review:

```bash
git status
git diff
```

This repository is public-facing, so secret review remains important even with automatic exclusions.

---

# Reinstall workflow

A typical reinstall looks like this:

```text
1. Install CachyOS / Arch Linux
2. Connect to the internet
3. Run the one-command installer
4. Choose the G16/ASUS/rEFInd options required by the machine
5. Reboot when appropriate
6. Verify graphics, display refresh rate, audio, networking and hibernation
```

Then future updates to the current machine can be saved using:

```bash
cd ~/dotfiles
./system-setup.sh capture
git add -A
git commit -m "chore: update dotfiles"
git push
```

---

# Notes for other users

These files are published primarily as a backup and reproducible configuration for my own machines.

If you want to use them:

- fork the repository first
- inspect `install.sh` and `system-setup.sh`
- remove hardware-specific assumptions you do not need
- review Hyprland monitor configuration
- review ASUS/G16 services
- review rEFInd paths before installing
- never reuse someone else's Secure-Boot keys or credentials

The base Stow layout can still be useful even if none of the hardware profiles apply to your system.

---

## Current focus

The repository is now focused on maintaining a **stable, reproducible daily desktop** rather than continuously modifying the Caelestia shell itself.

Experimental shell/widget work can remain in its own development repository, while this dotfiles repository stays responsible for making the working system easy to restore.
