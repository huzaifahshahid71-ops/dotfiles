# Profile ownership for refresh and wallpaper services — v2

Fix for the inspected 2026-10-03 host configuration. Both services were enabled
under `default.target`, so the user manager kept them alive through Niri logins.
The refresh watcher retained its startup environment and repeatedly called
Hyprland without a signature. Lumina's wallpaper timer could rotate and retheme
the desktop while Eclipse was active.

The installer adds two owned systemd drop-ins and a condition helper. It moves
existing enable links to
`wayland-session-xdg-autostart@hyprland.desktop.target`, orders startup after
graphical readiness, the compositor and UWSM's environment wait, and propagates
stop from the Hyprland session and `graphical-session.target`.

Version 1 blocked logout with an ordering cycle on the host. It attempted to
clear `After=` in a drop-in, but systemd only allows adding dependencies there.
Version 2 retains the original ordering and uses UWSM's later autostart target.
It upgrades the exact known v1 guard and drop-ins directly, removing the old
activation links. It does not add a dependency which starts Hyprland when
somebody manually starts a helper from a different desktop.

| Service | Allowed profiles |
| --- | --- |
| `refresh-rate-auto.service` | Aether, Obsidian, Crimson, Materia, Aurora, Nocturne, Lumina, Tsugumori |
| `rice-wallpaper-auto.service` | Lumina only |

The condition also requires an active UWSM Hyprland compositor, its current
Wayland/signature environment and a successful read-only monitor query.
Solstice, Cipher, Astra and Eclipse skip both helpers before probing Hyprland.
An `ExecCondition` skip leaves the service inactive rather than entering its
restart loop. The activation target starts the helpers again at the next
Hyprland login; the wallpaper condition selects Lumina at that point.

## Run as the desktop user

```sh
python3 ~/Downloads/profile-service-fix/install.py --apply
python3 ~/Downloads/profile-service-fix/install.py --status
```

Omit `--apply` for preflight only. Do not use sudo. The tool validates the
installed base units, loaded drop-ins, UWSM units, backend paths and activation
links. Unknown configurations are retained rather than overwritten. It verifies
the real staged base-unit, drop-in and enable-link layout with the host's
`systemd-analyze --user verify` before application. Removed activation links
are masked only in staging, and cycle diagnostics fail preparation even if
the verifier returns zero after dropping optional jobs.

Only the two helpers are stopped and, when appropriate for the current session,
restarted with the manager's current environment. A running desktop, shell,
music player and wallpaper daemon are not directly restarted. Restarting the
wallpaper timer starts a fresh rotation interval. Existing disabled enable
state is retained; normal future `systemctl enable` uses the scoped target.

The original scripts and service files are not rewritten. Refresh rates,
custom modelines, auto/manual refresh preference, wallpaper enable state,
rotation interval, palette generation, catalogs, switcher and session routers
are preserved. No kernel, system unit, package, login entry or GRUB setting is
changed.

## Recovery

A private backup directory and JSON receipt are printed before mutation.
Publication/reload failures restore the managed destinations and original
activation links and attempt to resume the previously active helpers.

To explicitly revert a successful application:

```sh
python3 ~/Downloads/profile-service-fix/install.py --restore /home/USER/.local/share/desktop-profiles/profile-services-backup-SUFFIX
```

Use the exact directory printed by this version on your host. Restoring its
backup of a v1 installation also restores v1's logout cycle; retain v2 for the
normal Lumina/Eclipse switching test. Restoration refuses to overwrite
managed files edited after application. It restores original global activation
links, so it restores the prior startup behavior as well. It only resumes a
previously active helper if the current profile and live compositor permit it.

## Verification

Run `python3 tests/check_integration.py` from this directory. Checks cover all
12 known profile IDs, invalid/stale session environments, check-only behavior,
activation migration, preservation of base units, repeat application, explicit
restoration, rollback after an injected reload failure, unknown override
rejection, installation from Eclipse without launching a worker/compositor,
and known-v1 upgrades. Real systemd base-unit/drop-in fixtures reproduce the
v1 ordering cycle and pass with v2; staged verification also runs over an
installed v1 layout. Local checks pass on systemd 255.4; preparation verifies
against the host's installed systemd. Live switching remains a host acceptance
check.

On the host, validate Lumina -> Eclipse -> Lumina using Sumi Deck. In Eclipse,
both services should be inactive and there should be no new refresh polling or
Lumina wallpaper rotation. Back in Lumina, refresh watching should run;
wallpaper rotation runs if its existing auto preference is enabled. In another
Hyprland profile, refresh watching should run and Lumina rotation should skip.
Verify charger transitions preserve the configured refresh targets.

References: [UWSM](https://github.com/Vladimir-csp/uwsm),
[systemd unit dependencies](https://man.archlinux.org/man/systemd.unit.5.en),
[ExecCondition](https://man.archlinux.org/man/systemd.service.5.en).
