# iNiR: proposed 12th profile / fourth Niri rice

Upstream: https://github.com/snowarch/iNiR
Inspected commit: c08bb928fe71c6a00bfede3e99ef26fb1825ebe2 (2026-10-03).

Inventory would become eight Hyprland profiles and four Niri profiles. Use
`inir` as the internal profile ID; keep its upstream display name iNiR until a
separate branding choice is made.

It is a Niri-first Quickshell shell. Its three panel families are Material ii,
Waffle, and iRiS. Qt 6.9+ is required; the captured laptop has Qt 6.11.2 and
Quickshell 0.3.1, which satisfy the stated Qt minimum. Runtime compatibility
still requires a live check of this exact upstream revision.

Do not run the full upstream setup on the multi-rice installation. It manages
shared GTK/Qt/terminal theming, system configuration, autostart/service links and
updates. Its inir.service owns org.kde.StatusNotifierWatcher and is tied to
niri.service. Those defaults need adapting to the selected-profile lifecycle,
and must not run alongside Clavis in the current Genie test session.

Integration sequence:
1. Pin upstream source under the inir profile; retain GPL-3.0 license/credits.
2. Audit scripts/inir and shell configuration/state/cache path handling. Relocate
   their writes to the profile where possible; explicitly document unavoidable
   shared user resources. Disable upstream global theming and auto-update paths
   until isolation is demonstrated.
3. Reuse installed dependencies; add only missing core dependencies. Optional
   AI/network services and the separately downloaded mascot pack stay optional.
4. Adapt its service ordering and notification/tray ownership to the existing
   multi-rice session launcher, starting/stopping only when inir is selected.
5. Add a profile-specific Niri configuration with the laptop's monitor settings,
   refresh switcher and shared music/media shortcuts. Reserve Super+Shift+D for
   Sumi Deck; examine conflicts with upstream shortcuts.
6. Add metadata, preview art and startup hooks to the existing switcher/control
   system; validate switch-away cleanup and restoration of shared environment.
7. Test first in a separate profile session or VM. Test both stock Niri and the
   Genie fork separately before making any shared-compositor promise.

iNiR has been inspected, not installed or registered by the Cipher package.
Finish and verify Cipher's controls before activating another shell.
