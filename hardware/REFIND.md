# rEFInd profile

Run:

```bash
./install.sh --refind
```

The profile:

1. Refuses to automate Secure-Boot signing.
2. Installs the distro `refind` and `efibootmgr` packages.
3. Detects an ESP at `/boot`, `/boot/efi`, or `/efi`.
4. Makes a timestamped backup of the installed `refind.conf`.
5. Restores `machine/refind/refind.conf`.
6. Replaces `__ROOT_UUID__` with the current machine's root UUID.
7. Restores `machine/refind/themes/rEFInd-minimal` when present.
8. Ensures `use_graphics_for + linux` is active.
9. Can generate a machine-local `refind_linux.conf` with `mkrlconf`.

The stored rEFInd configuration should contain a UUID placeholder instead of a
real root UUID so the repository remains portable across reinstalls.
