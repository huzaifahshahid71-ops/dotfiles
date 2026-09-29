# Huzaifah Multi-Rice v5.1 — Revo integration

v5.1 changes the hierarchy: Revo Shell becomes the Hyprland shell platform and the Huzaifah profiles join the same switch fabric.

## Architecture

- Revo upstream is cloned in full at install time to `~/.local/share/revo-shell`.
- The upstream snapshot is pinned to commit `a15d62c87aa992ab8e5d366575bb4074eada7d98`.
- Revo's Hyprland configuration is installed as the shared `revo` desktop profile.
- All 21 Revo Quickshell configs are deployed to `~/.config/quickshell`.
- The existing 10 Huzaifah profiles remain first-class profiles:
  - Hyprland: Aether, Obsidian, Crimson, Materia, Aurora, Nocturne, Lumina
  - Niri: Solstice, Cipher, Astra
- Both front ends call the same backend:
  - Huzaifah graphical switcher: `qs -c multi-rice-switcher`
  - Revo/terminal switcher: `qs-list`
- Revo-to-Revo changes are shell-only hot switches.
- Huzaifah-to-Revo, Revo-to-Huzaifah, and Hyprland-to-Niri changes keep the existing profile/session handoff.

## Why Revo is cloned instead of vendored

At the time this integration was created, the Revo repository did not declare a repository license. The v5.1 branch therefore does not republish the entire upstream source tree inside this public repository. The installer clones the exact upstream revision and applies the Huzaifah integration locally.

This keeps Revo as the upstream/base project while avoiding an unnecessary source-code mirror.

## Install

From this branch:

```bash
git clone -b v5.1.0-revo-dev https://github.com/huzaifahshahid71-ops/dotfiles.git
cd dotfiles
bash scripts/install-revo-v5.1.sh
```

The installer does not automatically activate Revo. After installation, open either switcher and select any Revo shell.
