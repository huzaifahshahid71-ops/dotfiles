# Tested VM Base Image

The release-validation VM for **Huzaifah Multi-Rice OFFLINE v2.0.1** was installed from the following official CachyOS Desktop ISO:

- **ISO:** `cachyos-desktop-linux-260809.iso`
- **Release:** CachyOS Desktop `260809`
- **SHA256:** `959f6577f45e25ee9fd8c220fd221b08e4ea79412c7315c0f922dd6d86d5e33c`
- **Official download:** `https://iso.cachyos.org/desktop/260809/cachyos-desktop-linux-260809.iso`
- **Official validation page:** `https://wiki.cachyos.org/cachyos_basic/download/`

Verify a freshly downloaded copy with:

```bash
sha256sum cachyos-desktop-linux-260809.iso
```

Expected result:

```text
959f6577f45e25ee9fd8c220fd221b08e4ea79412c7315c0f922dd6d86d5e33c  cachyos-desktop-linux-260809.iso
```

The ISO itself is intentionally **not mirrored in this repository**. Redownload it from an official CachyOS source and verify the SHA256 before recreating the test VM.
