# ASUS laptop profile

Run:

```bash
./install.sh --asus
```

This profile installs `asusctl` and `rog-control-center`, preferring enabled
pacman/CachyOS repositories and falling back to the configured AUR helper.

It does **not** change GPU mode or install NVIDIA/CUDA drivers.

Useful commands after installation:

```bash
asusctl --help
asusctl profile -n
rog-control-center
```

If TLP or tuned is already active, the installer leaves it alone rather than
silently replacing it with `power-profiles-daemon`.
