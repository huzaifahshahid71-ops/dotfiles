# Cipher Genie native controls — device-test package

Prepared for the existing working Cipher Genie (test) session. This package
adds the approved WhiteSur Qt 5/6 decorations, a private Foot build with left
traffic lights, and ordinary windows for the three Lumina player themes.

Run as your normal user, without sudo:

```bash
python3 install.py --install
python3 install.py --preview
```

The first command verifies the original session hash and approved Qt receipt,
compiles a private Foot 1.28.0 against your installed libraries, parses its
configuration, and loads all three player themes through your actual Quickshell
with a harmless controller stub. It updates launchers only after all checks
pass. Native build checks run on the laptop; no native build success is claimed
for the preparation container.

The second command opens a Qt test, Foot and Lumina in the current Genie
session. Test yellow → Genie minimize → Dock restore; green → maximize and
restore; red → close. Lumina has its own application ID and Dock metadata.
Switch between Nexus, Glass and Material in the player to verify all three.
The player backend and library are retained. Repeating the player shortcut does
not create a duplicate; use the Dock to restore an already-open player.

No running service or compositor is restarted by installation or preview.
Session-wide decorations apply on the next normal Cipher Genie login. Current
applications keep their existing decoration until relaunched. The global player
launcher delegates to its exact original outside the modified session; existing
profile switching and main are unchanged.

## Requirements

Keep the approved `~/Downloads/test-cipher-app-buttons.py`, its private build
receipt, plugins and probe executables. Their hashes, plugin loadability and Qt
runtime versions must match. The retained full Foot source checkout is reused;
only if it is absent is tag 1.28.0 fetched from the official repository, with its
commit and original renderer hash verified before patching.

The laptop must have git, meson, ninja, a C compiler, pkg-config, Quickshell and
Foot build dependencies (notably fcft, tllist, wayland-protocols, wayland, pixman,
libxkbcommon, fontconfig and utf8proc). Missing dependencies or failed builds stop
preparation without changing the session. The preparation directory is printed;
Meson and per-theme QML logs remain there.

## Rollback

```bash
python3 install.py --rollback
```

Original launchers and desktop entries are restored from byte-checked backups.
Rollback refuses to overwrite a file edited after installation. Private logs and
binaries remain in a renamed folder for diagnosis. If you already logged in
with the modifications, log out once afterwards to restore that login's scoped
environment. If a future Qt update makes the plugins incompatible, the login
continues with standard decorations rather than failing to start.

## Validation completed before delivery

- Actual installer writes and byte/mode-exact rollback in an isolated fixture.
- Preservation of user edits and rollback after an injected write failure.
- Actual generated Bash login: manager-variable restoration, including spaces,
  empty values and originally-unset variables.
- Qt compatibility failure keeps the login working with its original environment.
- Compositor startup failure still restores the manager environment.
- 61,464 checks of the modified Foot geometry across widths 0–2560, six scales,
  and all minimize/maximize capability combinations.
- Python compilation and Bash syntax checks.

Full Foot compilation, installed-Quickshell loading, visual appearance, native
Genie animation and Dock restore remain on-device checks. Chrome and GTK
applications retain their own decoration implementations; this package targets
Qt, Foot and the three recovered Lumina themes.

Sources: the user's approved Qt preview bundle and Lumina/Foot source snapshot;
WhiteSur pinned revision c68082c3e9019e7ea27d06fdc8d8b242c6e12961;
Foot pinned revision ab33c9a19d626f8d0ac0bd1adfdba21946ada948.
Quickshell FloatingWindow reference:
https://quickshell.org/docs/v0.3.1/types/Quickshell/FloatingWindow/
