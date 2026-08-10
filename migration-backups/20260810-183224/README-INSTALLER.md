# One-command installer

This repository is designed for Arch/CachyOS with GNU Stow.

## One command

Interactive install:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/huzaifahshahid71-ops/dotfiles/main/install.sh)"
```

Direct profiles:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/huzaifahshahid71-ops/dotfiles/main/install.sh)" -- --base
bash -c "$(curl -fsSL https://raw.githubusercontent.com/huzaifahshahid71-ops/dotfiles/main/install.sh)" -- --asus
bash -c "$(curl -fsSL https://raw.githubusercontent.com/huzaifahshahid71-ops/dotfiles/main/install.sh)" -- --g16
bash -c "$(curl -fsSL https://raw.githubusercontent.com/huzaifahshahid71-ops/dotfiles/main/install.sh)" -- --g16 --refind
bash -c "$(curl -fsSL https://raw.githubusercontent.com/huzaifahshahid71-ops/dotfiles/main/install.sh)" -- --all
```

## Repository roles

- `caelestia/` — DiM Caelestia user configuration
- `fish/` — Fish configuration
- `hypr/` — Hyprland configuration
- `mpv/` — mpv/MPRIS configuration
- `scripts/` — helper scripts under `~/.local/bin`
- `systemd/` — user services
- `machine/` — captured package lists, system metadata, and sanitized rEFInd backup
- `hardware/` — ASUS, Zephyrus G16, and rEFInd notes
- `install.sh` — one-command bootstrap and Stow installer
- `system-setup.sh` — capture/restore/hardware commands

## Capture current machine

```bash
./system-setup.sh capture
git status
git diff
```

`capture` synchronizes the user configs into the Stow packages, records
official/AUR package lists, saves a sanitized rEFInd configuration and theme,
and records machine metadata.

The capture intentionally excludes:

- NVIDIA/CUDA packages and driver automation
- Secure-Boot signing/tool automation
- Fish universal variables
- obvious `.env`, token, secret, credential and cache files

The custom Quickshell development repo is **not** nested inside this dotfiles
repository. Its origin/branch/commit are recorded in `machine/custom-shell.txt`.
