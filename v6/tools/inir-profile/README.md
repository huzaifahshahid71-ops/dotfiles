# iNiR — Multi-Rice profile 12

Adds **iNiR**, the fourth Niri profile, to the installed Sumi Deck catalog. Starts with the iRiS panel family; Super+Shift+W cycles iRiS, ii and Waffle. Existing profiles, including Tsugumori, are retained by wrapping the installed metadata functions instead of replacing their table.

Upstream: https://github.com/snowarch/iNiR
Pinned source: `c08bb928fe71c6a00bfede3e99ef26fb1825ebe2`, version 2.32.0, GPL-3.0. The installer downloads this exact source into a separate cache and retains upstream licensing. Adapter source: https://github.com/huzaifahshahid71-ops/dotfiles/tree/v6.0-tahoe-dev/v6/tools/inir-profile

## Install

Run as your normal user from your working rice. Your existing Multi-Rice, Sumi Deck, shared Lumina player, `/usr/bin/niri` and `/usr/bin/qs` must already be installed.

```fish
unzip -o ~/Downloads/inir-profile.zip -d ~/Downloads
python3 ~/Downloads/inir-profile/install.py --install --install-deps
```

`--install-deps` installs missing official Arch dependencies with pacman. It does not install the upstream iNiR meta-package or replace the existing Quickshell/Niri packages. Omit this flag to receive a missing-package list instead. The source download and the private color-generator environment need internet access. Dependency installation is a separate package-manager operation and is retained if profile preparation subsequently fails.

The installer checks the Niri config with `niri validate --config PATH`, parses service files, runs the actual palette generator, and compiles the shell/settings/welcome QML on a private D-Bus with an offscreen renderer. It does **not** instantiate the new desktop in your current Cipher session. QML check output is retained with preparation diagnostics if an error occurs.

On success, close and reopen Sumi Deck with **Super+Shift+D**, choose **iNiR**, then log in using **Huzaifah Multi-Rice**. Selecting a rice ends the current session through the existing switcher. Installation itself does not change the selected rice, your `~/.config/niri` link, or restart a desktop.

## Shared shortcuts

| Shortcut | Action |
| --- | --- |
| Super+Shift+D | Sumi Deck |
| Super+Shift+R | Niri refresh picker; advertised modes with a 10-second revert |
| Super+Shift+M | Shared Lumina player |
| Super+O / I / P | Previous / play-pause / next |
| Super+Space | iNiR launcher |
| Super+, | iNiR settings |
| Super+Shift+W | Cycle panel families |
| Super+Ctrl+Shift+S | iNiR screen recording with sound |

## Isolation and lifecycle

Runtime lives under `~/.local/share/desktop-profiles/inir`. The compositor runs the stock `/usr/bin/niri` with this profile's config. The approved Cipher Genie compositor/buttons remain in their own runtime.

iNiR's shell and helpers receive private HOME/XDG directories and a keyfile GSettings backend. App launchers restore the incoming HOME/XDG/Qt environment, including unset versus empty values, so browsers keep the normal user profile. User media directories remain available. Dynamic palette generation stays enabled for iNiR, while external app restyling, upstream setup, automatic source updates and global conflict killing are disabled. The upstream browser/terminal launcher and detached QML application paths use the environment adapter. Shell-script helpers retain the private context; optional third-party custom scripts must use `environment.py -- COMMAND` when launching ordinary applications.

`huzaifah-inir.service` wants the iNiR shell; the shell is ordered after the compositor publishes its Wayland/IPC environment and before desktop autostart. The two units have no global enable links. Clipboard watchers stay in the shell cgroup. Apps are launched in transient scopes so shell restarts can clean up helpers without killing launched apps. The login wrapper restores its temporary PATH/NIRI_CONFIG manager changes on exit.

## Status and rollback

```fish
python3 ~/Downloads/inir-profile/install.py --status
```

First select another rice and leave iNiR, then:

```fish
python3 ~/Downloads/inir-profile/install.py --rollback
```

Rollback restores the exact previous profile table, user service files, preview and login launchers, and retains your iNiR settings/runtime for recovery. Files edited after installation are preserved and cause rollback to stop. Roll back iNiR **before** rolling back the earlier Cipher promotion or Sumi preview bundle, because these installers share the login route/metadata or preview directory. Existing preview files are not replaced by this installer.

## Validation limits

Remote checks cover pinned source adaptation, Qt 6.11.2 syntax parsing, catalog preservation, routing, environment restoration, install interruption and rollback. The real Quickshell component check runs on your laptop during installation. Rendering, panel-family transitions, lock screen, tray, notifications, display modes and app launch behavior need a live iNiR login; passing syntax/component checks does not establish that these were tested on your laptop.

Developer fixture command, with a clean pinned upstream checkout:

```bash
python3 tests/check_integration.py /path/to/iNiR
```
