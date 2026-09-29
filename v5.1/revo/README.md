# Huzaifah Multi-Rice v5.1 — Revo-first integration

v5.1 changes the hierarchy: Revo Shell becomes the Hyprland shell platform and the existing Huzaifah profiles join the same switch fabric.

## Architecture

- Revo upstream is cloned in full at install time to `~/.local/share/revo-shell`.
- The upstream snapshot is pinned to commit `a15d62c87aa992ab8e5d366575bb4074eada7d98`.
- Revo's Hyprland configuration is installed as the shared `revo` desktop profile.
- All 21 Revo Quickshell configs are deployed to `~/.config/quickshell`; **19 are selectable desktop shells**. `11` is HyprQuickFrame (a screenshot overlay) and `macduo` is the Mac lid-animation companion, so those two remain installed as utilities instead of rice cards.
- The existing 10 Huzaifah profiles remain first-class profiles:
  - Hyprland: Aether, Obsidian, Crimson, Materia, Aurora, Nocturne, Lumina
  - Niri: Solstice, Cipher, Astra
- Unified catalog: **29 selectable profiles total** — **26 Hyprland + 3 Niri**.
- Every switcher calls the same `multi-rice-control` backend:
  - Revo graphical switcher: **Super+B** → patched `DotsBrowser.qml`
  - Huzaifah graphical switcher: **Super+Shift+D** → `qs -c multi-rice-switcher`
  - Unified terminal switcher: **Super+Shift+Q** → `qs-list`
  - Revo's Rofi/cycle helper is also redirected through the same backend.
- Revo-to-Revo changes are shell-only hot switches; Hyprland is not restarted.
- Huzaifah-to-Revo, Revo-to-Huzaifah, and Hyprland-to-Niri changes keep the existing safe profile/session handoff.
- Revo's shell-specific launch behavior is preserved, including macOS + K4 Dynamic Island + MacDuo companion and Ryoku's native process.
- The pinned Revo revision already contains its Hyprliquid configuration; the installer adds `hyprliquid` and provides Revo's expected `~/.local/lib/hyprliquid.so` path when the system library is available.

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

The installer creates a safety backup and does **not** automatically activate Revo. After installation, open either graphical switcher and select any installed profile.
