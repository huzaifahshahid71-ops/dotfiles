# Solstice

Solstice is the Niri profile based on JAQC-shell.

## Upstream

JAQC-shell:
https://github.com/MystiaFin/JAQC-shell

Pinned commit:

`e3158623d1c5c2e0089aeb5270cd486545546164`

The upstream JAQC-shell source is not vendored here. The installer retrieves
the pinned upstream revision and applies `solstice-customize.py`.

## Huzaifah Multi-Rice customizations

- Niri integration
- profile-isolated desktop-profile paths
- wallpaper startup fallback
- 60 FPS Cava visualizer
- event-driven external/keyboard volume refresh
- seekable MPRIS media timeline
- settings IPC endpoint
- SUPER+SPACE: launcher
- SUPER+S: settings
- SUPER+T: Foot terminal
- SUPER+Q: close window
- SUPER+SHIFT+D: Huzaifah Multi-Rice switcher

`solstice-customize.py` verifies the expected pristine upstream SHA-256 for
every modified file before applying changes and verifies the resulting file
hash afterward. It is safe to run repeatedly on an already-customized tree.
