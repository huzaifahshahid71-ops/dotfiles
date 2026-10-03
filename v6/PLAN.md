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

The active host kernel is `7.2.5-1-cachyos-vmdtest`, labelled **Linux stable**
in GRUB. **Windows is the default boot selection**, confirmed by the user on
2026-10-03. Preserve both choices; the rice installer must not rewrite them.

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
passed checksum/signature checks. The subsequent Clang/LLVM upgrade requires
refreshing preparation before compilation.

The user completed the custom build (22:00 local on 2026-10-03) and verified
that the complete kernel patch series remained applied. Both packages are now
installed; NVIDIA DKMS, initramfs generation, kernel signing and GRUB generation
completed without a reported failure. Snapper recorded snapshots 138/139.
The custom GRUB menu still lacks a G16 entry; the guarded
[menu helper](tools/G16-GRUB-ENTRY.md) adds it under Advanced Linux Options.
No first boot or new-kernel power validation has been reported yet. The build uses
`linux-cachyos-g16` and its headers, preserving `linux-cachyos-vmdtest` as a
fallback. This is a manual G16 maintenance workflow, not a universal kernel
payload automatically installed on other machines. Keep hardware-specific
power settings, swap and hibernation out of automatic rice installation.

## Before the release

1. Recover and preserve the working power fixes before the host update.
2. Review the full repository upgrade log, especially kernel/NVIDIA DKMS and
   initramfs hooks. The supplied report has 384 repository updates and no
   Niri, Quickshell or Qt runtime upgrade; refreshed transactions may differ.
3. Validate the updated host, its working kernel, app controls, shell services,
   refresh-rate behavior, sleep/wake and power settings.
   The freeze journals show Hyprland refresh polling and Lumina wallpaper
   rotation running in Eclipse; fix their profile ownership before release.
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
