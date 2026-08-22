# One-command installer

This repository targets Arch/CachyOS + Hyprland and separates **portable dotfiles** from **machine-specific system state**.

## One command

Interactive install:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/huzaifahshahid71-ops/dotfiles/main/install.sh)"
```

The interactive installer defaults to safe choices. It does **not** silently replace SDDM configuration, change the UEFI boot order, enable G16 display timings, change GPU mode, or configure hibernation.

## Safe profiles

```bash
# Portable Hyprland / Caelestia / Fish / mpv / scripts / user services
bash -c "$(curl -fsSL https://raw.githubusercontent.com/huzaifahshahid71-ops/dotfiles/main/install.sh)" -- --base

# Generic ASUS support
bash -c "$(curl -fsSL https://raw.githubusercontent.com/huzaifahshahid71-ops/dotfiles/main/install.sh)" -- --asus

# G16-safe extras (no GPU switch, no display timing changes)
bash -c "$(curl -fsSL https://raw.githubusercontent.com/huzaifahshahid71-ops/dotfiles/main/install.sh)" -- --g16

# Frieren SDDM theme only; does not enable/replace the display manager
bash -c "$(curl -fsSL https://raw.githubusercontent.com/huzaifahshahid71-ops/dotfiles/main/install.sh)" -- --sddm-theme

# Portable base + automatically detected safe ASUS/G16 extras
bash -c "$(curl -fsSL https://raw.githubusercontent.com/huzaifahshahid71-ops/dotfiles/main/install.sh)" -- --all
```

`--all` is intentionally **safe-all**, not "restore every captured machine setting".

## Explicit machine-changing actions

These are never run by `--base` or `--all`:

```bash
# Install/configure rEFInd for the current machine.
# The installer detects the current ESP again after refind-install,
# preserves the previous BootOrder unless you explicitly choose otherwise,
# applies only the portable theme, and generates current-machine kernel options.
./install.sh --refind

# Enable the captured G16 120/240 Hz service.
# Requires a detected G16 + active Hyprland + eDP-1 at 2560x1600.
./install.sh --refresh

# Configure Btrfs swap storage for hibernation.
# This is explicit and does not silently edit bootloader resume parameters.
./install.sh --hibernate

# Exact captured SDDM restore.
# Guarded by captured/current DMI model matching plus confirmation.
./install.sh --sddm
```

If you deliberately need to apply an exact captured machine profile to a different model:

```bash
./install.sh --force-machine-profile --sddm
```

Use that override only when you understand the consequences.

## Why the safety split exists

`machine/` is a **backup of one specific machine**, not a portable installation profile.

In particular:

- `machine/sddm/` may contain display-manager/autologin/session state.
- `machine/refind/` may contain bootloader settings and old kernel options.
- `scripts/.local/bin/auto-refresh-rate` contains G16 panel-specific timings.
- hibernation layout depends on the target filesystem and available storage.

The portable installer therefore treats those as opt-in system actions instead of restoring them during the normal Stow phase.

## rEFInd behavior

The safe rEFInd path:

1. verifies UEFI mode and refuses unsigned setup while Secure Boot is enabled;
2. detects a mounted FAT ESP, preferring `/boot/efi`, then `/efi`, then `/boot`;
3. saves the existing UEFI `BootOrder`;
4. runs `refind-install` only when needed;
5. **re-detects the ESP and `refind.conf` after installation**;
6. applies the saved `rEFInd-minimal` theme without replacing target-machine boot entries;
7. uses `mkrlconf` when available to generate target-machine Linux options;
8. keeps the previous boot order unless the user explicitly chooses to make rEFInd first.

The captured full `refind.conf` and captured hard-coded root device are not copied onto another machine.

## SDDM behavior

`--sddm-theme` copies the Frieren theme and writes only:

```ini
[Theme]
Current=sddm-frieren-theme
```

It does **not**:

- enable SDDM;
- replace another display manager;
- restore autologin;
- overwrite the complete captured `/etc/sddm.conf`.

The exact snapshot remains available through the explicit guarded `--sddm` action.

## Repository roles

- `caelestia/` — portable DiM Caelestia user configuration
- `fish/` — Fish configuration (`fish_variables` is not deployed)
- `hypr/` — Hyprland configuration
- `mpv/` — mpv/MPRIS configuration
- `scripts/` — helper scripts under `~/.local/bin`
- `systemd/` — user services; machine-specific services are not enabled automatically
- `machine/` — captured package lists, system metadata, SDDM backup, sanitized rEFInd backup
- `hardware/` — ASUS, Zephyrus G16, and rEFInd notes
- `install.sh` — one-command safe bootstrap/installer
- `system-setup.sh` — guarded machine/system actions

## Capture the current machine

```bash
./system-setup.sh capture
git status
git diff
```

Capture synchronizes the user configs, package lists, SDDM snapshot, sanitized rEFInd backup/theme, and machine metadata.

It intentionally excludes or sanitizes:

- NVIDIA/CUDA package automation;
- Secure-Boot signing automation;
- Fish universal variables;
- `.env`, token, secret, credential, cache, PID, lock and log files;
- rEFInd `root=/dev/...` device paths (converted to a root UUID placeholder).

The custom Quickshell development repository is not nested inside this repository; only its origin/branch/commit metadata is recorded.
