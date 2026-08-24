# Huzaifah Triple-Rice Offline Installer

This directory builds a **single x86_64 AppImage that can install the complete triple-rice setup with networking disabled**.

The offline edition bundles:

- Caelestia and its saved user configuration
- end4-dots + end4-pC source snapshots, including the current local patches
- Ambxst source snapshot, including the current local patches
- pinned/current `axctl` binary
- the complete package dependency closure as `.pkg.tar.*` archives
- an embedded local pacman repository database
- fonts, icons, Qt/Quickshell/Hyprland dependencies used by the restore
- Frieren SDDM login theme assets
- desktop profile switcher and saved profile state
- the current dotfiles working-tree snapshot

The builder deliberately installs any missing direct dependencies on the **build machine** first. This is how it avoids reproducing the earlier size-test problem where some direct packages were absent and therefore missing from the estimate.

## Build

Run on the working CachyOS/Arch x86_64 machine while internet is available:

```bash
cd ~/dotfiles
bash installer-appimage-offline/build.sh
```

The builder performs a full system update by default to avoid creating a partial-upgrade Arch package set. To explicitly skip that step:

```bash
bash installer-appimage-offline/build.sh --skip-system-update
```

The normal/default build is recommended.

Output:

```text
dist/Huzaifah-Triple-Rice-Offline-x86_64.AppImage
dist/Huzaifah-Triple-Rice-Offline-x86_64.sha256
```

The builder needs several GB of temporary free disk space because it holds package archives, source trees and the AppDir while creating the final AppImage. The current measured payload suggests a final file around roughly 1–1.5 GiB, but the builder reports the real size after all previously missing dependencies have been included.

## Offline installation

After building, the AppImage can be copied to another x86_64 Arch/CachyOS-family machine and run with networking disabled.

It does **not** `curl`, `git clone`, contact the AUR, or use online pacman mirrors during the installation. Packages are installed from the embedded `huzaifah-offline` pacman repository and the three rice source trees are copied from the AppImage itself.

The installer does not change the desktop wallpaper. The Frieren asset is used only as the SDDM login theme.

## Safety/compatibility

Arch is rolling release. The offline installer uses normal pacman dependency resolution against its bundled repository and `--needed`, so a target machine that already has suitable packages can keep them instead of blindly reinstalling the entire package closure. For the most predictable result, use the offline image on systems reasonably close in age to the build snapshot.

The offline installer makes a user configuration safety backup before replacing the three rice profiles and backs up an existing Frieren SDDM theme/config before installing the bundled login theme.
