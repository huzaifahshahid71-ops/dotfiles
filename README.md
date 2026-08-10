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

<!-- CACHYOS-INSTALL-GUIDE:START -->
# Installing CachyOS from scratch

This repository is designed so that the desktop can be rebuilt after a fresh
CachyOS installation. Install the operating system first; after the first
successful boot, this repository restores the desktop and machine-specific
configuration.

These instructions follow the official CachyOS documentation. Always re-check
the official guides before partitioning because installer recommendations can
change:

- [CachyOS Downloads and ISO Verification](https://wiki.cachyos.org/cachyos_basic/download/)
- [CachyOS Desktop/Laptop Installation](https://wiki.cachyos.org/installation/installation_on_root/)
- [CachyOS Boot Managers](https://wiki.cachyos.org/installation/boot_managers/)
- [CachyOS Boot Manager Configuration](https://wiki.cachyos.org/configuration/boot_manager_configuration/)
- [CachyOS Secure Boot Setup](https://wiki.cachyos.org/configuration/secure_boot_setup/)

> **Important:** Never blindly copy device names such as `nvme0n1p3` from
> this README onto another computer. Identify disks by size, filesystem,
> labels and contents before formatting anything.

## 1. Back up important data first

Back up personal files separately before touching partitions.

This repository restores configuration. It is **not** a backup for documents,
photos, games, music libraries, Windows partitions, passwords, tokens or
Secure Boot keys.

## 2. Download and verify CachyOS

Download the latest **CachyOS Desktop Edition** ISO from an official CachyOS
source.

Do not hard-code an ISO version or checksum from this README. CachyOS publishes
new ISOs regularly.

Download the matching `.sha256` file and verify the ISO.

On Linux:

```bash
cd ~/Downloads
sha256sum -c cachyos-desktop-linux-*.iso.sha256
```

The result should report the ISO as `OK`.

CachyOS also publishes a GPG signature for authenticity verification.

## 3. Create a bootable USB

Create the USB with a suitable image-writing tool. CachyOS documents options
including Rufus, Ventoy and `dd`.

When using `dd`, identify the **whole USB device** correctly. Writing to the
wrong device destroys its existing partition table.

## 4. Prepare Windows for dual boot

If Windows is being kept, disable Windows Fast Startup and Windows hibernation
before the Linux installation.

Run from an Administrator PowerShell or Command Prompt:

```powershell
powercfg /H off
```

Check BitLocker status before modifying any Windows-owned partition:

```powershell
manage-bde -status
```

The official CachyOS dual-boot guide recommends disabling BitLocker for its
Windows-partition workflow. On this machine, never format an existing
BitLocker partition merely because the Linux installer can see it.

## 5. Prepare UEFI/BIOS

For the CachyOS UEFI installation:

- boot the USB in **UEFI mode**
- disable **CSM**
- disable **Secure Boot during installation**
- leave Legacy USB Support on `Auto` where applicable

Secure Boot can be configured separately after installation. This repository
does not automate Secure Boot key creation or enrollment.

From the live ISO, verify UEFI mode with:

```bash
efibootmgr -v
```

If EFI variables are unavailable, the USB was probably booted in Legacy/BIOS
mode instead of UEFI mode.

## 6. Launch the installer

Boot the USB and select **Launch Installer**.

Configure language, region/time zone, keyboard layout and networking.

CachyOS does not allow multiple desktop environments to be selected during the
installation process.

For this setup, select **Hyprland**.

## 7. Use manual partitioning

CachyOS currently warns that `Install alongside` and `Replace partition` are
not completely reliable and strongly prefers **Manual partitioning**.

For this setup the intended Linux layout is:

```text
/boot   FAT32
/       Btrfs
```

The repository's hibernation setup assumes Btrfs for the Linux root
filesystem.

CachyOS currently documents a dedicated FAT32 `/boot` partition for rEFInd and
systemd-boot installations. Review the current official size recommendation
when installing rather than relying on an old value copied into this README.

Review the installer's final partition summary very carefully before clicking
**Install Now**.

---

## Reinstalling CachyOS on my current Zephyrus G16

This section records the disk layout that existed when this recovery repository
was created.

It is a **reference snapshot**, not permission to blindly format partitions by
device name. NVMe numbering can change. Always inspect the real disks first:

```bash
lsblk -o NAME,PATH,SIZE,FSTYPE,LABEL,PARTLABEL,UUID,PARTUUID,MOUNTPOINTS
```

At the time of capture, this G16 used two NVMe drives.

### Windows / ASUS drive

The first NVMe contained the Windows OS, Windows EFI partition, recovery
partitions and ASUS recovery data.

These are **not Linux installation targets** during a Linux-only reinstall.

### Mixed data + Linux drive

The second NVMe contained:

```text
p1  Microsoft Reserved
p2  BitLocker "HUZAIFAHS_G16 PROGRAMS ..."
p3  BitLocker "HUZAIFAHS_G16 DATA ..."
p4  FAT32 Linux EFI/boot partition, mounted at /boot
p5  Btrfs CachyOS partition, providing /, /home and Btrfs subvolumes
```

The critical rule is:

> **Do not touch the BitLocker PROGRAMS or DATA partitions during a Linux-only
> reinstall.**

Identify the Linux FAT32 and Btrfs partitions by filesystem, size, labels and
contents, not only by `p4`/`p5`.

The recovery snapshot recorded this active Linux boot layout:

```text
Linux ESP mount:       /boot
rEFInd EFI loader:     /boot/EFI/refind/refind_x64.efi
rEFInd configuration:  /boot/EFI/refind/refind.conf
Linux boot options:    /boot/refind_linux.conf
Root filesystem:       Btrfs
```

The machine also had firmware entries for systemd-boot and rEFInd. The
customized graphical boot manager restored by this repository is rEFInd.

### Recommended reinstall flow on this exact machine

1. boot the CachyOS USB in UEFI mode
2. choose Manual partitioning
3. identify and preserve every Windows and BitLocker partition
4. assign the dedicated Linux FAT32 partition to `/boot`
5. assign the dedicated Linux Btrfs partition to `/`
6. choose rEFInd as the boot manager if available
7. choose Hyprland as the desktop environment
8. inspect the final partition summary again
9. install CachyOS
10. reboot into the fresh system

Formatting Linux filesystems normally gives them new identifiers. The rEFInd
backup therefore stores the Linux root identifier using a portable placeholder
and substitutes the fresh installation's identifier during restoration.

If the real disk layout ever differs from this README, trust the real disk
layout and stop before formatting anything uncertain.

## 8. First boot

After installation, verify the basics:

```bash
uname -a
ip link
lsblk -f
efibootmgr -v
```

Make sure networking works and the expected `/` and `/boot` partitions are
mounted.

Update the fresh installation:

```bash
sudo pacman -Syu
```

## 9. Restore this desktop

Interactive recovery:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/huzaifahshahid71-ops/dotfiles/main/install.sh)"
```

Full supported machine profile:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/huzaifahshahid71-ops/dotfiles/main/install.sh)" -- --all
```

The recovery can restore the supported configuration for:

- Hyprland
- DiM Caelestia
- Fish
- helper scripts
- user systemd services
- ASUS support
- Zephyrus G16-specific setup
- AC/battery refresh-rate automation
- the exact Frieren SDDM theme and SDDM configuration
- rEFInd configuration and rEFInd-minimal theme
- Btrfs hibernation setup

Restore the saved explicit package lists when required:

```bash
cd ~/dotfiles
./system-setup.sh packages
```

## 10. Restore rEFInd

Run:

```bash
cd ~/dotfiles
./system-setup.sh refind
```

or:

```bash
./install.sh --refind
```

The saved rEFInd recovery data includes:

```text
machine/refind/refind.conf
machine/refind/refind_linux.conf
machine/refind/themes/rEFInd-minimal/
```

The current installation's Linux root identifier is inserted into the restored
boot options instead of reusing an obsolete filesystem identifier.

## 11. Verify the restored system

Run:

```bash
./system-setup.sh status
```

Then verify manually that:

- Hyprland starts
- DiM Caelestia starts
- the Frieren SDDM screen appears
- rEFInd appears at boot
- Windows still boots
- networking and audio work
- brightness control works
- the internal display uses the expected refresh rate
- ASUS controls work
- suspend works

Do not assume hibernation works merely because a swapfile exists. Test it only
after verifying the kernel, initramfs, resume configuration and Btrfs swap
resume offset.

## 12. NVIDIA / hybrid graphics

NVIDIA/CUDA installation and automatic GPU-mode switching are deliberately
outside this repository's destructive automation.

After a fresh install, first inspect what CachyOS hardware detection installed
for the actual G16 before changing GPU drivers.

## 13. Secure Boot

Secure Boot is a separate post-install task.

CachyOS currently documents Secure Boot using `sbctl`, with ASUS-specific
warnings for key enrollment and firmware settings.

Never publish or restore private Secure Boot keys through a public dotfiles
repository.

---

## Short version: complete reinstall

```text
Back up personal files
        ↓
Download + verify latest CachyOS Desktop ISO
        ↓
Create bootable USB
        ↓
Boot in UEFI mode with Secure Boot/CSM disabled
        ↓
Launch Installer
        ↓
Manual partitioning
        ↓
Preserve all Windows / BitLocker partitions
        ↓
Use dedicated FAT32 Linux /boot + Btrfs /
        ↓
Choose Hyprland + rEFInd
        ↓
Install and boot fresh CachyOS
        ↓
Run the dotfiles installer
        ↓
Restore packages / G16 / SDDM / rEFInd / hibernation as required
        ↓
Reboot and verify
```

If anything in the live disk layout disagrees with this README, stop and
identify the partitions before formatting them.

<!-- CACHYOS-INSTALL-GUIDE:END -->

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


# Widget-only installation

People who only want the **Desktop Lyrics** and/or **Desktop Audio Visualiser**
do not need to install my complete dotfiles or any G16-specific setup.

The repository includes a portable profile captured from my Caelestia
configuration:

```text
widgets/caelestia-widget-profile.json
```

The widget installer merges only those widget-related settings into the
user's existing `~/.config/caelestia/shell.json`. It does not replace the
rest of their Caelestia configuration.

## Desktop Lyrics only

```bash
./install.sh --widgets lyrics
```

One-command remote install:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/huzaifahshahid71-ops/dotfiles/main/install.sh)" -- --widgets lyrics
```

## Desktop Audio Visualiser only

Both spellings are accepted:

```bash
./install.sh --widgets visualiser
./install.sh --widgets visualizer
```

One-command remote install:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/huzaifahshahid71-ops/dotfiles/main/install.sh)" -- --widgets visualiser
```

## Lyrics + Visualiser

```bash
./install.sh --widgets lyrics,visualiser
```

or directly from GitHub:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/huzaifahshahid71-ops/dotfiles/main/install.sh)" -- --widgets lyrics,visualiser
```

Widget-only mode installs the Caelestia shell/CLI and the minimum
widget-specific configuration. It intentionally does **not** install or
modify the repository's Hyprland, Fish, Frieren SDDM, rEFInd, ASUS/G16,
hibernation, refresh-rate, personal-script, or systemd profiles.

Before changing an existing Caelestia `shell.json`, the installer creates a
timestamped backup next to the original file.

Desktop Lyrics requires a compatible active media player and lyrics available
through the configured Caelestia lyrics backend. The Audio Visualiser reacts
to audio through Caelestia's audio service.

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
├── widgets/
│   └── caelestia-widget-profile.json
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
