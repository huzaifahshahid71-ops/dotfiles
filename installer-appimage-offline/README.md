# Huzaifah Multi-Rice OFFLINE AppImage

This directory builds a **single x86_64 AppImage designed to install and service the Multi-Rice setup with networking disabled**.

The current offline control-center edition bundles:

- ✦ Caelestia and its saved user configuration
- ◈ end4-dots + end4-pC source snapshots, including local patches
- ◆ Ambxst source snapshot + pinned/current `axctl`
- ● DankMaterialShell (DMS) profile and saved configuration
- ⇄ `SUPER + SHIFT + D` dynamic Multi-Rice switcher
- ↻ `SUPER + SHIFT + R` hardware-aware refresh-rate switcher
  - Zephyrus G16: tested 60/90/120/144/165/180/240 Hz profile + automatic 120 Hz battery / 240 Hz AC policy
  - other machines: OEM/EDID modes only, discovered from Hyprland
- 🌙 Frieren SDDM login theme
- the complete package dependency closure as `.pkg.tar.*` archives
- an embedded local pacman repository database
- fonts, icons, Qt, Quickshell and Hyprland dependencies
- ASUS support packages (`asusctl`, ROG Control Center, power-profiles-daemon)
- guarded Zephyrus G16 extras (`supergfxctl` is bundled but GPU mode is never switched automatically)
- Btrfs hibernation tooling
- the current dotfiles working-tree snapshot

## AppImage menu

Launching the AppImage presents a control-center menu rather than immediately modifying the machine:

1. **Preflight** — validates the embedded payload, DMI model and known package conflicts without changing the system.
2. **Install Multi-Rice** — installs all six rices, switchers and Frieren SDDM from the embedded package repository.
3. **Refresh switcher** — installs/reconfigures the hardware-aware refresh switcher.
4. **Frieren SDDM** — theme only; does not replace the configured display manager or enable autologin.
5. **ASUS support** — generic ASUS tooling with DMI warning on non-ASUS machines.
6. **Zephyrus G16 extras** — guarded G16-specific support.
7. **Hibernation** — guarded Btrfs swap-storage setup.
8. **Status** — shows machine, ASUS, refresh and payload status.

Dangerous actions remain opt-in and include additional confirmation gates.

## Build

Build on the working CachyOS/Arch x86_64 machine while internet is available:

```bash
cd ~/dotfiles
git pull --ff-only
bash installer-appimage-offline/build-multi-rice.sh
```

The wrapper uses the proven dependency-closure builder in an isolated temporary copy of the repository. It adds the offline ASUS/G16 and hibernation toolbox packages to the bundle without making the normal online installer install them on every machine.

To intentionally skip the builder's full system update:

```bash
bash installer-appimage-offline/build-multi-rice.sh --skip-system-update
```

The normal build is recommended.

Output:

```text
dist/Huzaifah-Multi-Rice-OFFLINE-v4.1.0-x86_64.AppImage
dist/Huzaifah-Multi-Rice-OFFLINE-v4.1.0-x86_64.sha256
```

The build step itself needs internet because it resolves/rebuilds AUR packages and downloads exact official package archives. **The resulting AppImage does not require internet for installation or for the bundled setup tools.**

Expect several GB of temporary disk usage. The final file will likely be around the 1–1.5+ GiB range depending on the current dependency closure and bundled package versions.

## Reliability model

The offline image avoids GitHub/AUR/DNS/mirror failures during installation by using one embedded local pacman repository. Its builder validates that every package in the resolved dependency closure has a package archive before creating the image and writes SHA-256 checksums for the payload.

The target machine can still have local incompatibilities. The preflight therefore reports known provider conflicts before the full restore. In particular, if `noctalia-qs` is installed, the Multi-Rice install can explicitly replace that provider with the bundled `quickshell-git` before the rest of the package transaction.

Arch is rolling release, so for the most predictable result use the image on Arch/CachyOS systems reasonably close in age to the build snapshot.

The Frieren asset is used only by SDDM; the installer does not replace the desktop wallpaper.
