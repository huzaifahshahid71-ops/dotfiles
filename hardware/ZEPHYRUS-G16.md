# ASUS ROG Zephyrus G16 profile

Run:

```bash
./install.sh --g16
```

The G16 profile extends the generic ASUS profile and keeps the existing
machine-specific behavior in these dotfiles:

- Hyprland display scale: `1.25`
- ~120 Hz on battery
- 240 Hz on AC
- `auto-refresh-rate.service`

The profile recognizes common `GU603`/`GU605` DMI identifiers and can be
forced interactively for another G16 revision.

GPU switching is deliberately manual. If you choose to install
`supergfxctl`, inspect its current state/help first:

```bash
supergfxctl --help
supergfxctl --mode Hybrid
supergfxctl --mode Integrated
```

The installer never changes GPU mode automatically and never installs or
modifies NVIDIA/CUDA drivers.
