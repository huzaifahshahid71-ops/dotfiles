# Cipher Chrome controls preview

The 10px preview was approved on the laptop. To activate it for normal native
GTK3 applications in Cipher Genie, run:

```fish
python3 ~/Downloads/cipher-chrome-preview/install.py --install
```

Then close Chrome normally, log out, and select **Cipher Genie (test)** again.
In normal Chrome's Appearance settings, select **GTK** if it is not already
selected. Leave system title bar/borders disabled. Chrome's theme choice is a
browser preference; the custom controls themselves are enabled only through
the Cipher session environment. This installer does not edit browser profiles.
Chrome normally selects GTK3 on a non-GNOME desktop; if yours was explicitly
configured to use GTK4, close it and launch `google-chrome --gtk-version=3`.

The installer builds and checks the private module before modifying the
approved Cipher session launcher. It records and restores the previous manager
values of GTK_MODULES and the module's two private flags on logout, preserving
set, empty, and unset values. It keeps the existing Qt/Foot/Lumina rollback
receipt valid, and activates only after its GTK compatibility check succeeds.
Missing/changed private GTK assets fall back to standard GTK controls.
No live services are restarted. The shared GTK files and GSettings/dconf
database are not changed. Native GTK3 apps that use title buttons can inherit
the controls; GTK4, Flatpak, and application-specific title bars remain separate.

To remove only this GTK extension:

```fish
python3 ~/Downloads/cipher-chrome-preview/install.py --rollback
```

Logout completes removal from already-running processes. Rollback preserves
files edited after installation and retains the private assets for diagnosis.

## Preview only

Run from the working, activated Cipher Genie desktop:

```fish
python3 ~/Downloads/cipher-chrome-preview/preview.py
```

The script compiles a small GTK3 module, parses its CSS with your installed GTK3,
and launches native Chrome/Chromium on Wayland with a fresh browser profile.
The module changes only the in-process button layout and title-button CSS.
No GSettings/dconf values, shared GTK files, login scripts, Chrome launchers,
or existing browser profiles are changed. Chrome's sandbox stays enabled.

The intended layout is close/red, minimize/yellow, maximize/green on the left.
The circles use a 10px CSS diameter, reduced from the first preview's 12px,
with the same colors as the private Foot renderer. Click targets remain the
same size. Existing GTK
colors and normal widgets remain supplied by your current theme. Standard glyphs
appear on hover. The module keeps this process's layout stable if GTK settings
are refreshed by a portal or settings service.

Check yellow-button Genie minimization and Dock restore, green maximize/restore,
and red close. The preview is separate from your existing Chrome windows. The
Dock may group it under Chrome. If controls remain unstyled, open Appearance
inside the preview and select GTK; keep system title bar/borders disabled.

Its isolated profile and log are printed, under:
`~/.local/share/desktop-profiles/cipher-genie-session/buttons/chrome-controls-preview-*`.
The log should contain `CIPHER_GTK_OK` when GTK loads the module. This preview
does not read cookies, history, bookmarks, credentials, or Preferences from
your ordinary browser. Close the preview when done; retain the log for diagnosis.

This is a device-test preview for native GTK3 Chrome/Chromium. GTK4/libadwaita,
Flatpak, Electron
custom title bars, and applications that ignore toolkit decorations require
separate checks. No desktop/compositor restart is required.

Validation: compilation with warnings treated as errors, native GTK3 CSS
parsing, module opt-in/layout-refresh checks, and execution of the actual
generated Bash launcher against a systemd fixture. GTK/Qt manager restoration,
module-path idempotence, changed-asset fallback, byte/mode-exact rollback,
protection of user edits, recovery from a partial installation, and cleanup
after compositor failure passed. The 10px Chrome preview was approved on the
laptop. The user confirmed normal-login activation, Chrome GTK selection and the smaller controls on the laptop. Promotion into normal Multi-Rice is handled by ../cipher-native/install.py.

References: Chromium's `ui/gtk/nav_button_provider_gtk.cc` and
`ui/gtk/settings_provider_gtk.cc`, plus GTK3's gtk-decoration-layout property.
The module, CSS, and circle SVGs in this preview were written for this task;
they contain no copied third-party theme assets.
