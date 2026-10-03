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

Remote fixture checks cover copying the boot arguments, preserving existing
entry order and classes, duplicate/unknown input rejection, staged publication
and restoration after a generator failure. Actual GRUB parsing happens on the
host; those commands are mocked in the fixture. A first boot and power,
storage, suspend/resume and GPU validation remain necessary.

```bash
python3 tests/check_g16_grub_entry.py
```
