# Huzaifah Multi-Rice — Sumi Deck desktop previews

Adds your eleven desktop screenshots inside the existing Sumi Deck cards.
Card size, carousel fan, rotations, navigation, profile switching, title, and ACTIVE badge are preserved.
Images use aspect-preserving cropping, rounded transparent corners, and a subtle caption gradient.
A profile with a missing or unreadable image keeps the original icon artwork.

## Install from this package

Close Sumi Deck before installing. Run as your usual user, without sudo:

```fish
python v6/tools/install-sumi-previews.py --check
python v6/tools/install-sumi-previews.py --install
```

Reopen with **Super + Shift + D**. No compositor reload, logout, or reboot is needed.
Use the existing THEMES button to select Sumi Deck if another theme is active.

The installer edits only the installed Sumi Deck QML and these preview assets:

```
~/.local/share/desktop-switcher/themes/sumi-deck/DotsBrowser.qml
~/.local/share/desktop-switcher/previews/
```

It verifies asset SHA256 checksums and validates the expected installed QML before writing.
If qmlformat is installed, it also checks the candidate QML syntax before installation.
No backend, profile metadata, keybind, rice configuration, or theme preference is changed.
All existing files it replaces are saved under
`~/.local/state/huzaifah-switcher/preview-backups/` (or `$XDG_STATE_HOME`).
Repeated installation of identical files makes no changes.

## Roll back

```fish
python v6/tools/install-sumi-previews.py --rollback
```

Close and reopen Sumi Deck afterward. Rollback refuses to overwrite files that
were independently changed after installation.

## Verify live

Navigate through all eleven cards. Confirm correct screenshots, readable titles,
and the ACTIVE badge. Close with Esc; no rice switch is needed to test artwork.
Runtime errors can be inspected with:

```fish
tail -n 80 ~/.local/state/huzaifah-switcher/sumi-deck.log
```

## Screenshot mapping

| Capture | Profile | Backend ID |
| --- | --- | --- |
| 1 | Lumina | sayconlun |
| 2 | Aether | caelestia |
| 3 | Obsidian | end4 |
| 4 | Crimson | ambxst |
| 5 | Materia | dms |
| 6 | Nocturne | noctalia |
| 7 | Aurora | serpantinum |
| 8 | Tsugumori | tsugumori |
| 9 | Solstice | jaqc |
| 10 | Cipher | clavis |
| 11 | Astra | nixri |

Assets are 1320 × 720 WebP images, with the card radius baked into transparency.
They match the pinned card interior at three times its logical resolution and
need no shader-effects module. The six-pixel card radius remains unchanged.
The upstream Revo QML is not distributed in this package or vendored in the repository.
This update patches the existing, locally installed Sumi Deck.
