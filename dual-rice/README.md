# Caelestia + end4-pC dual-rice backup

This directory is the portable snapshot for the working CachyOS/Hyprland dual-rice setup.

## What is backed up

- Exact Caelestia Hyprland profile
- Exact end4 Hyprland profile, including the `end4-pC` `qsConfig` override and custom switcher keybind
- Caelestia user configuration
- Desktop switcher theme
- `desktop-switch` and `recover-caelestia`
- `background-music.service` when present
- `Favorites.m3u8` / `favorites.m3u8` when present
- Explicit pacman and AUR package manifests
- Hyprland, Quickshell and Caelestia version information
- Pinned Git commits for `end4-pC` and `end-4/dots-hyprland`
- Local Git patches for those upstream repositories when local modifications exist
- The currently selected desktop profile

Large disaster-recovery snapshots, caches, browser data, SSH keys, `.env` files, tokens and other obvious secrets are intentionally excluded.

## Back up the currently working machine

From the repository checkout:

```bash
./scripts/backup-dual-rice.sh
```

Review `git status`, then push the snapshot:

```bash
./scripts/backup-dual-rice.sh --push
```

The backup script refuses an automatic push if it detects obvious credential-like assignments inside the snapshot.

## Restore on CachyOS / Arch

Clone the repository, then run:

```bash
./scripts/restore-dual-rice.sh
```

The restore script:

1. Installs the required Hyprland, Caelestia, Quickshell and end4 dependencies.
2. Creates a timestamped safety backup of any existing profile/configuration.
3. Restores both saved Hyprland profiles.
4. Restores the desktop switcher and recovery command.
5. Checks out the pinned end4 and end4-pC upstream commits.
6. Restores the original `ii` Quickshell configuration required by end4-pC.
7. Recreates `~/.config/hypr` as the profile symlink.
8. Restores the saved active profile.

After restore, log out and back into Hyprland.

## Switching desktops

Graphical switcher:

```text
SUPER + SHIFT + D
```

CLI:

```bash
desktop-switch status
desktop-switch caelestia --now
desktop-switch end4 --now
```

Emergency fallback:

```bash
~/.local/bin/recover-caelestia
```

Then log out/reboot if required.

## Layout after a live backup

```text
dual-rice/
├── profiles/
│   ├── caelestia/hypr/
│   └── end4/hypr/
├── caelestia/
├── desktop-switcher/
├── bin/
│   ├── desktop-switch
│   └── recover-caelestia
├── systemd/user/
├── music/
├── packages/
├── versions/
├── state/
└── README.md
```

The source trees for `end4-pC` and `end-4/dots-hyprland` are not vendored into this repository. Their exact Git commit IDs are recorded and restored from upstream instead, keeping this repo small while retaining reproducibility.
