# Zephyrus G16 — v6.0 development

Current scope: **12 rices, 8 Hyprland and 4 Niri**. The macOS-style desktop is
the working **Cipher/Niri Genie** profile. The earlier Tahoe Hyprland profile
was abandoned; Hyprliquid is not a release dependency or acceptance gate.
Development stays on `v6.0-tahoe-dev`; `main` remains unchanged.

## Profiles and switcher

- Preserve all eight installed Hyprland profiles, including Tsugumori. The
  repository baseline had seven; integrations must extend the host catalog
  additively rather than replace its metadata.
- Preserve Solstice/jaqc, Cipher/clavis and Astra/nixri. Add Eclipse/inir as
  the fourth Niri profile. Eclipse is the display name; `inir` remains its
  internal ID and runtime/service identity.
- The user confirmed iNiR installation, a live login and the modern switcher
  shortcut on 2026-10-03. After the host upgrade, the Waffle taskbar's
  content-derived input mask blocked hover and clicks. Binding its region to
  the panel dimensions restored both, confirmed live by the user and carried
  in the profile installer. Broader feature and cross-profile switching checks
  remain outstanding. See [the profile installer](tools/inir-profile/README.md).
- Preserve Sumi Deck and its existing switching backend, active selection,
  preview handling and saved theme preference. Super+Shift+D launches the
  modern switcher; do not reintroduce the old Fuzzel-only helper in Niri.
- Preserve Lumina's working music player and existing user service backends.
- Do not merge the draft v5.1 Revo collection or vendor unlicensed source.

## Cipher and application controls

The user confirmed Cipher's native Genie session, Qt decoration plugins,
Foot traffic lights, Lumina player controls, GTK/browser styling and the
removal of the unwanted Niri focus ring. Keep toolkit-specific behavior and
the stock Niri path used by other profiles. The offline installer must carry
the reviewed sources, notices, build requirements and recovery procedures.

## G16 kernel and power maintenance

The active host kernel is now `7.2.8-1-cachyos-g16`, with its first boot
confirmed by the user on 2026-10-03. The previous `7.2.5-1-cachyos-vmdtest`
remains labelled **Linux Stable** in GRUB. **Windows is the default boot
selection**. Preserve both choices; the rice installer must not rewrite them.

[The maintenance kit](tools/g16-power-kit/README.md) separately preserves:

- The complete VMD MTL016 interrupt backport, including supporting feature
  state edits, and the later VMD/ASPM host-default changes.
- The asusctl 6.5.0 hidraw transaction patch and installed USB/audio runtime
  PM rules and finalizer helper.
- Reference source/configuration and a separately named 7.2.8 kernel recipe.
  Exact source reconstruction, 7.2.8 patch applicability, repeat application,
  partial series and conflict rejection pass remotely.

The host repository upgrade completed successfully (384 packages), and the
user rebooted into the preserved vmdtest kernel. NVIDIA 615.71.09 DKMS modules
are installed for vmdtest, stock 7.2.8-2 and LTS 6.18.52-1; Python 3.12.14
starts. The separate 7.2.8 source preparation applied both kernel patches and
passed checksum/signature checks. Clang/LLVM was upgraded before the completed
build; the subsequent source check confirmed the complete patch series.

The user completed the custom build (22:00 local on 2026-10-03) and verified
that the complete kernel patch series remained applied. Both packages are now
installed; NVIDIA DKMS, initramfs generation, kernel signing and GRUB generation
completed without a reported failure. Snapper recorded snapshots 138/139.
The guarded [menu helper](tools/G16-GRUB-ENTRY.md) successfully added
**Advanced Linux Options > G16 Patched**, preserving the existing entries and
Windows default. Its host backup is `/var/backups/g16-grub-wvs0j_wm`.
The user then reported `uname -r` as `7.2.8-1-cachyos-g16` and NVIDIA
615.71.09 DKMS installed for that kernel and all three previous kernels.
This confirms first boot and the driver build, not live GPU operation or
resolution of the earlier stall. Initial live power-state checks and one
suspend/wake cycle now pass; controlled consumption comparison and longer
stability checks remain pending. The build uses
`linux-cachyos-g16` and its headers, preserving `linux-cachyos-vmdtest` as a
fallback. This is a manual G16 maintenance workflow, not a universal kernel
payload automatically installed on other machines. Keep hardware-specific
power settings, swap and hibernation out of automatic rice installation.

The initial new-kernel report shows Lumina (`sayconlun`) active, audio
`power_save=10` and `power_save_controller=Y`, and one battery discharge
sample of 8.22 W at 80%. This is not a controlled power comparison.
NVIDIA is built but did not initialize: D3cold/device-inaccessible probe
errors persist. Subsequent queries confirm `dgpu_disable=1` and
`gpu_mux_mode=1` (Integrated mode), consistent with an inaccessible dGPU;
live NVIDIA operation with the GPU enabled remains untested.
The Intel Port F/VBT warning, NVIDIA errors and GPU
audio codec failures also appear in the supplied 7.2.5 boot log. The new
report contains no NVMe timeout, OOM kill or lockup report. Both VMD links
show ASPM L1 enabled and PCI/ASPM L1.1/L1.2 enabled. The display is at 60 Hz
and the audio controller is suspended. ITE 0b05:19b6 has autosuspend set
to auto with a 2000 ms delay; the finalizer succeeded and the device
suspended after 15 seconds idle, with no hidraw holder reported by fuser.
The later battery sample is 8.75 W. Three 5-second turbostat intervals in
Quiet mode report package power falling 4.94 -> 4.75 -> 4.57 W, CPU busy
2.62-2.92%, C8 residency rising 13.27 -> 20.31 -> 23.72%, temperatures
44-46 C and no reported core thermal throttling. Battery Quiet / AC
Performance policy is configured. These samples support working power
states, not a controlled before/after consumption comparison.
At 23:20 local the log records s2idle entry and suspend exit, with Intel
GuC/HuC initialization messages and no errors in the supplied filtered
output. The user confirmed display, input, sound and Wi-Fi operation after
waking, plus automatic Bluetooth headphone reconnection. Initial kernel
acceptance checks are complete; longer stability testing remains pending.
The installed asusctl 6.5.0 source uses positional
queries (`asusctl armoury get dgpu_disable`), not `--property`.

## Profile service ownership

The host's inspected refresh and Lumina wallpaper units both use
`WantedBy=default.target` and have no session ownership. The refresh script
polls UPower every second and calls the Hyprland-only backend on state changes
and every 30 seconds. The Lumina timer sleeps for its configured interval,
then calls wallpaper/theme and bar helpers without checking the active profile.
The installed switch backend exits the compositor for both same- and
cross-compositor switches; Hyprland is owned by UWSM's `hyprland.desktop`
session, while Eclipse/Cipher use their separate Niri routers.

[The scoped-service fix](tools/profile-service-fix/README.md) migrates existing
enable links to UWSM's later Hyprland autostart target and adds profile/live-session
conditions. Refresh remains available to all eight Hyprland profiles; Lumina
rotation is limited to `sayconlun`. Existing scripts, preferences, catalog and
session routes are retained. The first version installed but blocked UWSM
logout: its drop-in could not clear the base wallpaper service's `After=`
dependency. Version 2 retains that dependency and moves activation after
graphical readiness. Real base-unit/drop-in tests reproduce the v1 cycle and
pass with v2, including staged verification over an existing v1 installation.
Profile, stale-environment, rollback, repeat and direct-upgrade checks pass.
The user subsequently completed the live Lumina -> Eclipse -> Lumina cycle:
both helpers were inactive/dead in Eclipse and active/running back in Lumina
(confirmed just after midnight on 2026-10-04 Riyadh time). The updated enable
target was reported on the host, and switching no longer hit the v1 cycle.
Broader twelve-profile and charger-transition acceptance remains pending.

## v6.0 installer experience

The user requested a small command-launched, single-window setup on
2026-10-04: greeting/previews, payload-independent preflight and uninstall,
optional curated/full wallpaper downloads, resumable split-AppImage retrieval
with per-part and assembled-image verification, backup and installation,
collapsed advanced device options, optional GRUB, cache cleanup/reuse and a
thank-you/reboot choice. See [the concrete design](INSTALLER-DESIGN.md).
The separate offline edition uses the same Sumi Deck frontend: choose or skip
a local wallpaper folder, copy images to `~/Pictures/Wallpapers`, select/scan
local parts, verify each and the assembled AppImage, then use the same backup,
installation, GRUB and finish flow. It requires no online fallback and keeps
preflight/restore independent of the large payload. Both editions share UI
and backend code so their behavior and appearance remain consistent.
This is the next implementation scope; the new launcher and GUI are not yet
implemented and the host Wallpapers collection has not been uploaded.

## Before the release

1. Recover and preserve the working power fixes before the host update.
2. Review the full repository upgrade log, especially kernel/NVIDIA DKMS and
   initramfs hooks. The supplied report has 384 repository updates and no
   Niri, Quickshell or Qt runtime upgrade; refreshed transactions may differ.
3. Validate the updated host, its working kernel, app controls, shell services,
   refresh-rate behavior, sleep/wake and power settings.
   The freeze journals show Hyprland refresh polling and Lumina wallpaper
   rotation running in Eclipse; apply and validate the prepared ownership fix
   before release.
   No NVMe timeout, OOM kill or kernel-lockup report was observed around that
   stall; the supplied journals do not establish a confirmed freeze cause.
4. Complete a switching/login check across all 12 profiles. Eclipse, Cipher,
   DMS and Noctalia require explicit post-update checks.
5. Build and validate the new patched G16 kernel separately before promoting
   it. Confirm NVMe operation, link power states, battery idle consumption,
   keyboard/hotkeys/backlight, audio, suspend and NVIDIA module availability.
6. Prepare the offline installer/AppImage with pinned source manifests,
   recovery paths, asset license notices, checksums and optional split parts.
7. Validate the release candidate in a VM and on the host before a public tag.

The user's current request is to finish system/kernel maintenance before
starting the v6.0 release. No public release or main-branch update is authorized
by the maintenance work alone.

## Historical design references

The earlier Hyprland Tahoe/Hyprliquid exploration remains in Git history and
[TAHOE-WINDOW-MANAGEMENT.md](TAHOE-WINDOW-MANAGEMENT.md). Its proposed extra
Hyprland rice, plugin compatibility checks and rendering prototype are
historical notes, not current release requirements.
