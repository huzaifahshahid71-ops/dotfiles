# G16 entry for the existing custom GRUB menu

The G16 kernel and headers installed successfully on 2026-10-03, including
NVIDIA DKMS, initramfs generation and kernel signing. The host's custom GRUB
script hardcodes Windows, Linux Stable/vmdtest, stock CachyOS and LTS, so a
normal regeneration did not expose the newly installed kernel.

Run the separately delivered helper after the installed G16 boot files exist:

```fish
sudo python3 ~/Downloads/g16-grub-entry.py --apply
```

The helper locates the unique executable custom menu script using the supplied
Stable/Advanced menu structure. It copies the existing Stable boot stanza,
changes only the title/ID and kernel/initramfs filenames in the copy, and adds
**Advanced Linux Options > G16 Patched** after the stock and LTS entries.
Windows remains entry 0; the helper does not edit GRUB defaults or bootloader
environment variables. The installed vmdtest kernel is preserved.

The script and generated configuration are backed up under
`/var/backups/g16-grub-*`. GRUB syntax is checked before modifying the source.
The installed `grub-mkconfig` writes a temporary candidate; existing Evangelion
menu classes are retained, menu order/default checks run, and GRUB syntax is
checked again before publishing. A generation or validation failure restores
the original menu source and configuration. A repeated or unsupported menu
structure stops without another insertion. No reboot, package installation,
EFI bootloader reinstall or firmware setting change is performed.

## Promote the tested G16 kernel to the main menu

After the host booted `7.2.8-1-cachyos-g16` successfully, the user requested
this layout on 2026-10-04:

| Main entry | Contents |
| --- | --- |
| Windows | Existing Windows EFI chainloader; default remains entry 0 |
| Linux G16 | Existing patched G16 kernel and initramfs |
| Advanced Linux Options | CachyOS, CachyOS LTS, Linux Stable (older kernel) |
| BIOS | Existing UEFI firmware setup action |

Download the updated helper and run:

```fish
sudo python3 ~/Downloads/g16-grub-entry.py --promote --apply
```

Without `--apply`, `--promote` checks and previews the layout only. The original
add-entry action remains available for the earlier menu state.

Promotion accepts only the inspected installed layout, preserves the boot
commands of every existing entry, moves G16 out of the submenu and moves
vmdtest into it. The G16 entry's stable ID is retained. Evangelion index
classes follow the new main/submenu positions, and these classes are written
to the persistent menu source so regeneration can carry them forward.
The generated menu must contain exactly the requested order/hierarchy, retain
every boot command and keep default entry 0. Unknown layouts, extra standalone
commands or differences between source and generated boot stanzas stop before
application. An already-applied source/menu pair is a no-op.

The same backup, syntax-check, staging and rollback flow applies. This is a
menu reorganization, not a kernel update or EFI bootloader reinstall. It does
not reboot or alter firmware boot order. Local fixture checks pass; this new
menu layout still needs host generation and a subsequent menu/boot check.

Remote fixture checks cover copying the boot arguments, preserving existing
entry order and classes, duplicate/unknown input rejection, staged publication
and restoration after a generator failure. Actual GRUB parsing happens on the
host; those commands are mocked in the fixture. Promotion tests additionally
cover the exact hierarchy/theme indexes, repeat application, unsupported
layout rejection and rollback after generation, changed boot-command,
changed-default and syntax failures. The host's initial G16 kernel boot,
power-state and suspend checks have already passed; longer freeze stability
and live dGPU operation remain unproven.

```bash
python3 tests/check_g16_grub_entry.py
```
