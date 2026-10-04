# v6.0 launcher and installation flow

Design requested on 2026-10-04 (Riyadh). Wallpaper publication is complete.
The shared online/offline GUI and lightweight transport/user recovery backend
are implemented as candidate 1 under `v6/installer`; the twelve-profile offline
payload, system recovery and release acceptance remain unfinished.
Development remains on `v6.0-tahoe-dev`; no changes to `main` or v5 releases.

## Delivery

A small, versioned `install_multi_rice.sh` entry point launches a single setup
window. Publish the entry point under the final `v6.0.0` tag only after release
acceptance. A raw GitHub file URL is needed for a shell download command;
the ordinary GitHub page URL is not an executable installer endpoint.

The lightweight component includes welcome art/thumbnails, host preflight,
download/cache handling, progress UI, installation-state inspection and
uninstall/restore. None of these requires the large AppImage. Keep a local
copy of this component after installation so maintenance also works offline.
Provide terminal mode with the same decisions when there is no graphical
session. Choose the GUI toolkit after checking the minimal supported host;
any frontend dependency setup must be explicit and precede launch.

The large release payload remains an AppImage with offline packages and all
12 profiles. Publish a separate small offline launcher bundle alongside the
online launcher. Both share the same frontend, backend protocol and installation
pages; only the content source changes. Source tree inspection shows the current `AppRun` uses repeated
Zenity/Yad/KDialog menus and a terminal child. Replacing just its first dialog
would not satisfy the requested single-window experience.

## Separate offline edition

Additional user requirement recorded on 2026-10-04: the offline edition must
work from locally supplied wallpapers and split AppImage files, with exactly
the same Sumi Deck styling and overall workflow as the online edition.

- Package the shared frontend, artwork, release manifest/checksums and small
  preflight/maintenance tools in the offline launcher bundle. Required GUI
  runtime availability must be solved without fetching the large payload or
  contacting the network; include necessary runtime support or provide the
  documented local prerequisite and terminal fallback.
- Host preflight checks the same machine/configuration/space requirements.
  Internet connectivity is not a requirement, and offline mode does not
  silently fall back to downloads, repository refreshes or online package
  installs. Offline payload/prerequisite availability is reported separately.
- The wallpaper page provides **Choose folder** and **Skip**. Preview/count
  readable images in the chosen directory and copy them to
  `~/Pictures/Wallpapers`, which is also the online edition's default destination.
  Keep the source folder intact, retain existing destination content, resolve
  filename conflicts visibly and skip unsupported files with a report. An
  empty/missing folder lets the user choose another directory or skip.
- The payload page provides **Choose parts folder**, **Select files**, and
  **Scan this folder**. Limit scanning to the user-selected directory; do not
  search the entire disk. Recognize only the pinned release's expected parts,
  show found/missing/invalid files, and allow another folder to supply missing
  parts. An already assembled matching AppImage is also accepted after full
  verification. A name or extension alone is not proof of a valid payload.
- Use the bundled release manifest and SHA-256 expectations for per-part
  verification, assembly order, total lengths and final AppImage verification.
  Do not trust an arbitrary nearby checksum file as the sole expected release
  identity. Stop before execution on missing, mixed-version or corrupt parts.
- Join valid split parts in installer-owned staging, verify the assembled
  image, then use the same backend entry point and progress events as online
  setup. Extraction, where needed by the backend, occurs after image validation.
  Continue through the same review, backup, install, optional GRUB and finish
  pages without opening a second installer window.
- Copy/assembly progress shows real bytes/items. Cleanup removes only managed
  staging/cache copies, retaining user-selected source wallpapers/parts and
  recovery backups. Reuse a valid retained staged image on the next run.
- Preflight and uninstall/restore remain usable with no parts or AppImage
  present. The interface may show an Online/Offline badge; layout, theme,
  navigation, advanced options and outcome handling remain shared.

## Pages in one window

1. **Welcome:** Huzaifah Multi-Rice greeting, twelve profile previews, Install,
   Preflight and Uninstall/Restore actions. Detect an existing installation
   and cached release, without starting any compositor.
2. **Preflight:** supported Arch/CachyOS host and x86_64 architecture, user
   identity, essential tools, disk space on cache/install/backup filesystems,
   network availability for missing downloads, existing installation and
   backup state. Show actionable failures and rerun controls. Payload checks
   are a separate later stage; host preflight must not require the image.
3. **Wallpapers:** after preflight passes, ask Yes/No for the curated pack;
   offer the full collection as another choice. Show thumbnails, counts,
   destination and size. Default to `~/Pictures/Wallpapers`; allow the user
   to select another directory in either edition. Download into that directory,
   retain existing images and avoid overwriting unrelated names. Missing or
   interrupted optional downloads offer retry or skip.
4. **Prepare installer:** show the planned download and disk requirements,
   then ask to proceed. Reuse matching cached files, resume incomplete parts,
   download missing parts and verify each. Reassemble them in manifest order,
   verify the complete AppImage, then mark it executable. Split byte streams
   are joined, not unpacked as ZIP archives.
5. **Review installation:** show the twelve-profile scope, backup destination
   and selected options. Keep device-specific controls in a collapsed
   Advanced area. Hardware, swap/hibernation, GPU/kernel changes and GRUB
   options are opt-in. Show whether a post-install GRUB prompt is applicable.
6. **Back up and install:** create and validate the restore snapshot before
   replacing configurations. Execute the payload's noninteractive backend
   while this same window displays progress, logs and failures. Persist the
   receipt and lightweight restore tool before declaring success.
7. **Optional GRUB:** after successful desktop installation, ask whether to
   configure the GRUB theme/menu. Show the concrete changes, then apply only
   accepted choices with a separate boot configuration backup. Preserve
   existing default OS, menu entries, custom kernels and fallbacks. Skip this
   step on non-GRUB systems. A failed/declined optional step is distinct from
   the outcome of desktop installation.
8. **Finish:** thank the user, show installed profiles and backup/log paths,
   and ask whether to clean up downloaded installation files. Show reclaimed
   size before confirmation. Offer Reboot now or Later; reboot only on an
   explicit choice. Do not close the window before cleanup/reboot decisions.

## Wallpaper distribution

Inventory the actual host Wallpapers folder first: size, file count, duplicate
content, formats, resolution, credits and redistribution terms. These files
remain on the working laptop. The 302-image collection is published at
`huzaifahshahid71-ops/multi-rice-wallpapers`, pinned by `wallpapers-source.json`.

Recommended arrangement is a dedicated public wallpaper repository linked
from dotfiles, with browsable images/preview index and individual downloads.
Publish curated and complete archives as release assets, split when needed.
This supports one-image and whole-pack downloads without making every
dotfiles clone fetch the entire library. Final placement depends on the
inventory; ordinary Git storage is appropriate only for a modest collection.
No Git LFS client should be required for the installer download path.

Use a versioned manifest containing stable IDs, relative output paths,
original/preview URLs, size, SHA-256, collection membership and available
credit/license metadata. The selected manifest version is pinned for an
installation, and optional wallpaper content stays outside the AppImage.

GitHub currently documents an under-2-GiB limit per release asset. Use an
explicitly smaller split size and verify final asset sizes. Regular repository
files above 100 MiB are blocked, and GitHub recommends keeping repositories
small. Sources:

- https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases
- https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-large-files-on-github

## Downloads, verification and reuse

Pin one release manifest for the entire operation: release/version,
architecture, ordered part names, byte lengths and SHA-256 values, complete
AppImage size/hash, payload protocol and lightweight maintenance version.
Retain human-readable `.sha256` files alongside the release assets.

Cache by release and architecture under an installer-owned user cache
directory. Matching names alone never establish a valid cache hit. Rehash a
cached image against the pinned manifest; if valid, skip part downloads and
assembly. Otherwise retain valid parts and download only missing/bad ones.
Use `.partial` files, validated range responses and atomic completed-file
promotion. A changed release or malformed manifest must not mix releases.

Verification runs on every part and again on the assembled image before any
payload code executes. Check file lengths, ordering, image identity and the
backend protocol as well. SHA-256 detects corrupted/mismatched downloads; it
is not independent publisher authentication when the files and hashes come
from the same source. Do not advertise this as signature verification.

Calculate peak space for parts plus the assembled image, extraction if used,
wallpapers, installation and backups. Joining parts temporarily needs both
the parts and the complete image. Preserve useful downloads on interruption.

## Backend and restore boundary

Refactor the current installer into reusable host preflight, backup/restore,
payload installation and optional system setup components. The lightweight
restore path uses installed receipts/backups and does not call `verify_payload`
or resolve a missing AppImage as a prerequisite. Existing v5 restore state
must be detected and handled through its documented format or an explicit
compatibility adapter, rather than assumed to match the new receipt schema.

The GUI owns all installation choices. Add an explicit payload backend mode
that consumes a validated options file and emits versioned JSON-line events:
stage, operation, completed/total bytes or items, message, severity, result
and receipt/log references. Backend mode must bypass `AppRun`'s normal chooser
and must not spawn another installer window or request choices through an
invisible terminal. System authentication can use the host's normal prompt.
Use the same backend for graphical and terminal frontends.

Root privileges belong only to operations that need them. User configuration
and cache remain owned by the desktop user. Retain the existing transactional
backup semantics and guarded device-specific behavior; this GUI redesign is
not authorization to enable G16 maintenance on generic hardware.

Lightweight uninstall restores backed-up user/system configuration with clear
confirmation and reports edited/unknown files instead of silently discarding
them. Packages are retained by default; package removal is a separate explicit
choice based on the package-addition receipt and dependency checks. Restoring
desktop configuration must remain possible after the download cache is deleted.

Cleanup is restricted to the installer's owned download/assembly/extraction
paths. It never deletes configuration backups, receipts, maintenance tools,
installed profiles or the downloaded Wallpapers directory. Show selectable
cache items; preserve the AppImage if the user chooses to keep it.

## Visual direction and progress

Match Sumi Deck: restrained Japanese-inspired typography, profile artwork,
rounded cards, soft glass effects and a clear active step. Prioritize readable
contrast, keyboard navigation, focus indicators, resizing, display scaling
and a reduced-motion option. The launcher runs before rice configuration is
installed, so it must not depend on the installed shell, wallpaper daemon,
Quickshell profile or compositor-specific effects.

Show current stage, real download bytes/total, speed, completed parts and an
estimated remaining time where measurable. Installation progress uses known
operations/items. Unknown-duration tasks display activity and an honest stage
label rather than invented percentages. Logs/details are expandable. Cancel
and retry are supported at safe boundaries; explain when a package or file
transaction must finish before cancellation.

## Implementation and acceptance order

1. Complete remaining post-upgrade profile checks; inventory wallpapers.
2. Extract lightweight host preflight and restore, with v5 compatibility.
3. Implement version-pinned manifest/download/cache/assembly verification.
4. Add backend options and event protocol; integrate twelve profiles and the
   accepted Cipher/Eclipse/service changes into the release payload.
5. Build and review a working single-window GUI, then publish wallpaper packs.
6. Exercise fresh install, existing install, curated/full/skip wallpapers,
   missing GUI runtime/TTY mode, interrupted/resumed downloads, corrupt part,
   corrupt final image, insufficient space and valid cached-image reuse.
7. Verify backup/rollback, optional GRUB accept/decline/failure, Windows default
   and kernel fallback preservation, hardware options remaining opt-in,
   cleanup preserving restoration, and uninstall without the AppImage.
8. Validate the final payload and tagged launcher together before v6.0.0.

Offline acceptance additionally covers network disabled, local folder import
and skip, empty wallpaper directories, duplicate destination names, parts on
removable storage, incomplete/mixed/corrupt part sets, complete-image reuse,
missing frontend prerequisites, source files surviving cleanup, and maintenance
with no payload present. Confirm the same page structure and Sumi Deck visual
styling in both editions.
