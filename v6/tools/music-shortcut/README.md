# Shared Lumina Music shortcut

Target: Super+Shift+M opens the same installed Lumina Music player in all twelve
profiles. Preserve the current theme, playlist/settings and Cipher's private
decoration/Genie route. Resolve conflicts in the effective binding sources,
not just an unused copy of a profile config.

The host source collection received on 2026-10-04 confirms all twelve profiles.
Most effective bindings already used `huzaifah-lumina-music`; Eclipse used
`lumina-player-overlay`. The latter's non-Cipher fallback still reached the
old Amberol development launcher through a Hyprland-only dispatch helper.
The new integration gives both launcher names the same Quickshell route.

## Install the shared shortcut

Unpack `multi-rice-music-v1.zip` into Downloads, then run as the desktop user
from the working Wayland session, without sudo:

```sh
python3 ~/Downloads/multi-rice-music-v1/install.py --install
python3 ~/Downloads/multi-rice-music-v1/install.py --status
```

All eight Hyprland entry files end with the shared binding, after their normal
user overrides. Solstice, Astra, Eclipse and both stock/native Cipher configs
use an absolute launcher path. `lumina-player-overlay` remains a compatible
alias. Cipher's private PATH alias also forwards to this route when present.
Cipher retains the native Qt compatibility and live Genie capability
checks; other profiles open the original overlay UI. The three themes and
`~/.config/quickshell/lumina-music-theme.ini` preference are retained. The
existing executable `~/.local/bin/lumina-music-ctl` backend is required and
not replaced. Libraries, playlists and mpv playback state are not rewritten.

Before writing, the installer checks all thirteen binding files, verifies its
payload hashes, parses the eight Lua configs and validates all five Niri config
routes using the installed compositors. It compiles both music shells and
their six theme components on the existing Wayland backend, without creating
music windows or player processes. Its checker runs on a private D-Bus and has
a bounded timeout with process-group cleanup. `luac` (normally the `lua`
package) is required for syntax checks. An error leaves the current files
unchanged and retains preparation for diagnosis.

Changes have hashed backups and a receipt under
`~/.local/share/multi-rice-music`. Repeat installation is a checked no-op.
Partial write failures restore already-written files. Changed managed files
or changed backups block automatic rollback, preserving user edits.

```sh
python3 ~/Downloads/multi-rice-music-v1/install.py --rollback
```

Hyprland reloads its config and the installer checks the current live chord;
Niri watches its config files. Neither compositor nor a shell service is
restarted. Close any player window opened before installing, then press
Super+Shift+M. Repeat presses use IPC and Quickshell's no-duplicate launch flag.
Only the UI starts; playback is controlled through the existing backend.

## Live acceptance before v6.0.0

Test the shortcut after logging into Aether, Obsidian, Crimson, Materia,
Aurora, Nocturne, Lumina, Tsugumori, Solstice, Cipher, Astra and Eclipse. Check
all three themes, saved selection, mouse/touch input, existing library, playback
and repeated presses. In Cipher also check traffic lights and Dock restore.
Run `--status` in each profile and retain any failure output. Local fixture
tests do not substitute for these graphical checks.

The repository's base installer still has the older profile payload; packaging
the complete twelve-profile runtime and the new online/offline installer is
separate release work. This shortcut archive is not the v6.0.0 release.

## Source collector

`collect.py` is a read-only desktop-user source collector. It gathers profile
Lua/KDL/conf files, selected session/music launchers and music QML/JS sources
into `~/Downloads/multi-rice-music-sources.zip`. It does not collect playlists,
user JSON settings, caches, journals, process environment or window titles.
Paths outside the desktop user's home and backup files are excluded. The report
records present profiles, symlink aliases and source hashes. It never executes
collected launchers or restarts a session. Existing output files are preserved;
use `--output` to choose a different filename when repeating a collection.

Run without sudo, then attach the resulting ZIP for integration:

```sh
python3 collect.py
```

The collector does not install the shortcut or publish a release. For fixture
integration tests against an unpacked collection, set `MUSIC_HOST_FIXTURE` to
its `home` directory and run `tests/check_integration.py`. These tests cover
all actual binding edits, source preservation, repeat/rollback/write failures,
Eclipse environment restoration and guarded Cipher routing. The graphical
Niri/QML checks are performed by the host installer.
