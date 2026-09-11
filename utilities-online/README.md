# Huzaifah Utilities

A small **online** GUI AppImage for fresh CachyOS/Arch installs. Unlike the Multi-Rice offline installer, this AppImage does not bundle application packages; it installs current versions from the official repositories and AUR when run.

## Included utilities

- Google Chrome (`google-chrome`, AUR)
- ONLYOFFICE Desktop Editors (`onlyoffice-bin`, AUR)
- Waydroid (`waydroid`) with first-run initialization and container service enablement
- QEMU/KVM virtual-machine stack (`qemu-full`, `virt-manager`, `virt-viewer`, `libvirt`, `dnsmasq`, `edk2-ovmf`, `swtpm`, `iptables-nft`)
- btop (`btop`)
- Dolphin (`dolphin`) as the current graphical file-manager / file-tree explorer entry

The GUI supports installing any subset and checking installation status. Already-installed packages are skipped safely.

## Build

```bash
cd utilities-online
./build.sh
```

The build script downloads `appimagetool` on first use and produces:

- `Huzaifah-Utilities-ONLINE-v1.0.0-x86_64.AppImage`
- matching `.sha256`

## Notes

- Target: CachyOS / Arch Linux, x86_64.
- Internet access is required at install time.
- Chrome and ONLYOFFICE are AUR packages. The installer uses `paru`, then `yay`, or bootstraps `paru-bin` if neither is installed.
- VM setup adds the current user to `libvirt` and `kvm`; log out/in once before expecting group membership to apply.
- Waydroid downloads its Android image during `waydroid init`.
- The `v4.0.0` release/tag remains a frozen restore point; this folder is post-v4 development on `main` and can later roll into v5.0.0.
