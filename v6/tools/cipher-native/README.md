# Cipher native controls in normal Multi-Rice

This promotes the working **Cipher Genie (test)** runtime into the existing
**Cipher / clavis** profile. Select **Huzaifah Multi-Rice** at the login screen
after installation; selecting Cipher in the existing switcher then uses its
private Genie compositor. Solstice and Astra keep stock Niri; Hyprland profiles
keep their existing UWSM route. The switcher, profile IDs and active selection
are retained.

Run from the working Cipher Genie test session as your normal user:

```fish
python3 ~/Downloads/cipher-native/install.py --install
```

The installer asks sudo to update the single system login launcher at
`/usr/local/bin/multi-rice-session`, after preparing and checking the runtime.
It creates a root-owned recovery copy and preserves unreviewed launcher edits.
It reloads systemd's unit definitions without starting or restarting a service.
Close Chrome normally, log out, choose **Huzaifah Multi-Rice**, and log in with
Cipher selected. Keep Chrome Appearance on GTK and system title bar disabled.

Run this after login:

```fish
python3 ~/Downloads/cipher-native/install.py --status
multi-rice-control status
```

Check Qt, Foot, Chrome and Lumina: close, minimize with Genie, restore from the
Dock, maximize and restore. Switch once to Solstice or Astra, then back to Cipher.
These actual login/switch checks remain on-device acceptance checks.

## Runtime and recovery

The independent runtime lives at
`~/.local/share/desktop-profiles/clavis/native`. It carries the tested Niri
binary, private shell/Dock assets, configuration and resolved includes, approved
Qt5/Qt6 plugins, the patched Foot, all three Lumina window themes, and 10px GTK3
controls. It preserves the approved focus-ring-off setting. No new build is
required on this already-tested laptop.

The test runtime, services and login entry are retained. Manager PATH,
NIRI_CONFIG, Qt/GTK settings and the production music selector are restored on
exit, including failure. Global music launches route to the production player
only inside production Cipher and delegate to the previous launcher elsewhere.
Qt/GTK compatibility guards remain in place. Chrome's existing GTK preference
is retained; browser profiles, shared GTK settings and dconf are not edited.

From the test session, another rice, or a text console after leaving normal
Cipher:

```fish
python3 ~/Downloads/cipher-native/install.py --rollback
```

Rollback restores the previous system/user login launchers, user units and
music dispatcher from checked backups. It preserves files edited after install
and retains the private runtime for diagnosis. Roll back this promotion before
using the earlier Qt/GTK test-package rollback commands.

This is host integration on `v6.0-tahoe-dev`, not a new public release or rebuilt
offline AppImage. The repository's normal dispatcher supports the private
runtime when installed and otherwise uses stock Niri. Fresh machines need an
independently prepared matching runtime before promotion; this package does not
claim to provide portable prebuilt compositor or Qt binaries. GTK4/libadwaita,
Flatpak and custom application title bars retain their existing differences.

## Validation

The actual Python transaction and generated Bash launchers pass fixture checks
for production Cipher dispatch, stock Solstice/Astra, the Hyprland route, absent
native-runtime fallback, independent settings/shell copies, login without test
files present, Qt/GTK/music activation and exact manager cleanup. Capability IPC
and native executables are emulated in these fixture tests. On installation,
the laptop checks its real running Genie capabilities, matching compositor
revision and hashes, Qt plugin loadability, GTK module/CSS, Foot configuration,
Niri configuration and systemd service parsing before activating the route.

Rollback passes byte/mode-exact restoration, user-edit protection, partial user
write recovery and recovery after a system launcher commit. The earlier Qt/GTK
installation and compatibility regressions are also exercised.

```bash
python3 tests/check_integration.py RECOVERED_SESSION BUTTONS_PACKAGE GTK_PACKAGE
```
