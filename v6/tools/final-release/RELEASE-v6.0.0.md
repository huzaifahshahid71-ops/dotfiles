<!-- sumi-v6-final-release-v1 -->
# Huzaifah Multi-Rice v6.0.0 — Sumi

Twelve desktops, one Sumi Deck: Aether, Obsidian, Crimson, Materia, Aurora,
Nocturne, Lumina, Tsugumori, Solstice, Cipher, Astra and Eclipse.

- 74 SDDM login theme cards and eight Evangelion GRUB theme cards, with previews and authenticated selection.
- Shared Sumi Deck, shortcut search with readable Lua action names, music controls and refresh-rate controls.
- Repaired native shell startup and wallpaper support; Eclipse layout and settings launchers included.
- A pinned collection of 631 wallpapers, available as an optional separate download.
- Offline package handling preserves installed versions and compatible providers, adding compatible missing packages.
- Configuration backups and guarded restore. Packages remain installed after restore. The reinstall restore check now accepts unchanged login-theme files while preserving protections for edited files or theme removal.

## Download and run

Download `assemble-v6.py`, put it in an empty folder, and run:

```sh
python3 assemble-v6.py
APPIMAGE_EXTRACT_AND_RUN=1 ./multi-rice-v6.0.0-x86_64.AppImage
```

The assembler downloads `release.json` and any missing split parts, verifies SHA-256,
and creates the AppImage. You can also download all `.partNNN` files and `release.json`
first, then run the assembler offline. Keep `release.json` beside the AppImage.
Allow several minutes for the first launch and use setup's preflight for storage requirements.
Python 3 and an active graphical session are required. Authenticate when setup requests system changes.

The optional `sumi-setup-v6.0.0-x86_64.tar.xz` contains the smaller standalone setup GUI.
Extract it with tar to preserve links. Its online launcher obtains the matching payload;
its offline launcher requires the AppImage or all split parts beside it.

## Validation and compatibility

All twelve desktops, shared shortcuts/configurations, GRUB and login themes were
manually tested in the CachyOS VM. Installation and configuration restore were also
confirmed there. The final build preserves that RC5 payload and adds the tested restore
check repair, with hash checks, backend regression tests and a GUI render check.
This is validation on the existing CachyOS test VM; it does not establish every hardware
combination or a fresh-install test on every Arch derivative.

The payload contains CachyOS-optimized packages. Preflight and dependency checks decide
whether a system can use it. Do not bypass package compatibility checks. No kernel or
GPU driver change is part of desktop setup. GRUB cards require an existing GRUB installation.

Wallpapers: https://github.com/huzaifahshahid71-ops/multi-rice-wallpapers/releases/tag/wallpapers-0aa529a78a8430dc

The installer source archive is included. Third-party desktops/themes retain their
respective licenses and credits. Release code is pinned from `v6.0-tahoe-dev`; `main`
is unchanged.
