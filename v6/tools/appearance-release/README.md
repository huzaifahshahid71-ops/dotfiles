# Sumi v6 appearance release r2

This kit integrates the repairs verified in the fresh CachyOS VM and after its
reboot. Run it on the **host**, as the normal `gamer` user, without sudo.
It uses the retained published payload, exported icon/Lumina repairs, and tested
fast online GUI. It does not install anything on the host or delete any VMs.

## Build and publish

Save `sumi-v6-appearance-release-v3.zip` in Downloads:

```fish
unzip -o ~/Downloads/sumi-v6-appearance-release-v3.zip -d ~/Downloads
python3 ~/Downloads/sumi-v6-appearance-release-v3/release.py --publish
```

Requires the existing signed-in GitHub CLI account `huzaifahshahid71-ops` and
at least 6 GiB free host space. Run without `--publish` to build only. The
script can be rerun to resume identical inputs and already verified uploads.
Output is `~/multi-rice-v6-appearance-r2`; the existing build outputs and source
folder are preserved. Reports go to
`~/Downloads/sumi-v6-appearance-release-report.zip`.

Changes:

- Select SDDM for the next boot, retain the live desktop, record the previous
  login routes in the protected system receipt, and restore them on uninstall.
- Keep GRUB quiet arguments inside Evangelion's owned configuration block,
  preserve other boot arguments, and filter routine loading notices. GRUB
  errors remain visible. Align existing manager/runtime ownership records when
  installing updated source files and retain their previous bytes for restore.
- Include the verified compressed MacTahoe archive: 164,921 files across three
  icon themes. Verify/extract in a batch; manage and restore the three folders.
  Initialize fresh Cipher settings with `MacTahoe-dark` and preserve existing
  Cipher preferences.
- Include the complete 20-file exported Lumina Rofi/Matugen collection.
- Retain all 12 profiles, 74 login cards, eight GRUB cards and the fast three-pack
  downloader for the 631 wallpapers.

The new payload/GUI/manifest/checksum assets use unique `r2` names under the
existing v6.0.0 release. The original offline and online-r1 assets are kept.
After every revised asset passes the server digest check, the established
`ONLINE-INSTALL-v6.sh` launcher is replaced with the revised launcher. The
verified previous launcher is retained and reuploaded if its replacement upload
fails. The source commit updates **only `v6.0-tahoe-dev`**, never `main`.

After `PUBLISHED APPEARANCE r2`, the established command uses these fixes:

```sh
curl -fsSL https://github.com/huzaifahshahid71-ops/dotfiles/releases/download/v6.0.0/ONLINE-INSTALL-v6.sh | bash
```

Publishing and switching that launcher happen on the host when the command
above runs. This delivered ZIP is a build/publication kit, not a prebuilt image.

## Replace old test VMs after publication

Export any wanted guest files and shut down both old VMs. With CachyVM installed:

```fish
CachyVM space
CachyVM retire-tests
CachyVM retire-tests --confirm legacy-test-disks
CachyVM make
```

The confirmation command irreversibly deletes only the original two test disks.
Reports/shared folders and exported repair sources stay. CachyVM refuses open
disks and requires the exported appearance inputs before deleting the fresh VM.

Manually install CachyOS in the new VM with GRUB and a Wayland desktop, shut it
down, then boot and configure its bridge:

```fish
CachyVM boot
CachyVM configure
vmrun-cachy --ping
vmrun-cachy --gui 'curl -fsSL https://github.com/huzaifahshahid71-ops/dotfiles/releases/download/v6.0.0/ONLINE-INSTALL-v6.sh | bash'
```

Choose installation in the VM GUI, including the full wallpaper collection in
the desired Pictures folder. Test Sumi Deck's login and GRUB selections, then
reboot the VM. The checker requires an actual reboot into SDDM and a selected
GRUB theme with active quiet arguments:

```fish
python3 ~/Downloads/sumi-v6-appearance-release-v3/test_new_vm.py
```

It checks all profile folders, installer receipt, card counts, SDDM, GRUB boot
arguments, icon inventory/defaults and Lumina Rofi/Matugen diagnostics. It does
not switch profiles, enter passwords, restart services or apply a palette. Also
manually check the actual login/GRUB appearance, Cipher icons, Lumina Super+S
and palette UI, and other profile UI/shortcuts. Send
`~/Downloads/sumi-v6-r2-new-vm-report.zip` with your results.

After successful acceptance and exporting wanted guest files:

```fish
CachyVM stop
# Wait until shutdown finishes.
CachyVM delete --confirm test
python3 ~/Downloads/sumi-v6-appearance-release-v3/storage_audit.py
```

Use the selected name with `--name NAME --confirm NAME` if it is not `test`.
Send `~/Downloads/sumi-storage-audit.json` to identify the remaining build/cache
folders for removal. The audit never deletes files. Keep the current r2 output,
retained source/repair folders, configuration backups and your wallpapers until
the cleanup review. Sparse disks, hard links and Btrfs snapshots affect actual
recovered space; do not infer free space from virtual disk sizes.

## Validation

The kit regression suite covers real transaction installation/restore/failure,
SDDM route guards, metadata ownership/restore, archive corruption/traversal,
the observed GRUB shell/AWK sources, and launcher replacement rollback. The
host build also runs the previous eight unchanged-SDDM restore regressions
against the actual revised root helper, checks payload hashes/backend imports,
and renders the reused GUI. The newly integrated image still requires the clean
VM acceptance run described above.

Kit v2 corrects the mistaken nine-file assumption using the observed 20-file export. All assets still require exact paths and matching sizes/SHA-256. The published payload revision remains r2.

Kit v3 targets validate_plan/install within their own functions, preserving the observed native-library checks and detailed system errors. The source transforms were checked against the uploaded 25-file source export. An early interrupted source-only build can resume after a kit update if all original/repair/source inputs match; any existing candidate, image or publication output blocks that migration. Earlier input metadata is retained.
