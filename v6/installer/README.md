# Sumi Setup · v6 development candidate 1

The online and offline editions now share one PySide6 window and one small
Python backend. This candidate is **not the v6.0.0 release**. Its development
manifest intentionally disables AppImage preparation and installation until a
complete twelve-profile payload and system restore path pass acceptance.

The shared Lumina Music integration passed the user's live check on October 4,
2026. The public wallpaper collection is already available separately. The
repository's existing v5 AppImage does not contain the complete tested twelve
profiles; renaming that image to v6 would not produce the requested release.

## Preview and lightweight maintenance

On Arch/CachyOS, install `python-pyside6` if it is not already available. The
application never automatically installs its GUI dependency. The offline
edition requires it locally; terminal checks and user recovery only need Python.

```sh
python3 app.py
python3 app.py --offline
python3 app.py --preflight
python3 app.py --restore ~/.local/share/huzaifah-multi-rice/v6-installations/INSTALL_ID/receipt.json
```

The welcome page lists all twelve named profiles. Five existing v3 screenshots
are reused as temporary preview artwork; these are not new v6 acceptance
screenshots. Actual Sumi Deck preview assets are requested by the source
collector before completing the artwork set.

The preflight action checks the host without requiring an AppImage or network.
It reports a missing graphical toolkit before launch, unsupported distributions,
root execution, missing tools and insufficient space. No package, desktop or
service changes are made by preflight.

## Implemented and tested

- One window with welcome, checks, wallpapers, preparation, review, progress
  and completion pages. Both editions use the same window class. Worker threads
  keep download and verification work off the UI thread.
- Pinned release manifest validation: twelve profiles, release version,
  architecture, backend protocol, unique filenames, lengths and SHA-256.
- Download resume validation: reject incorrect ranges and lengths, restart
  when a server ignores a range, reject bad hashes and promote atomically.
- Offline assembly: verify each part, join in manifest order, verify the full
  image and only then make it executable. Accept a verified assembled image.
  Sources remain untouched and offline mode never falls back to downloads.
- Optional wallpapers go to `~/Pictures/Wallpapers`. Existing content is
  retained; different images with the same name get a hash suffix. Identical
  files are reused. Online uses the pinned published manifest; offline copies
  supported images from the selected folder. The 36-image selection is a
  deterministic sample, pending visual curation before final publication.
- Marked, locked, user-owned cache; cleanup is limited to this cache. The cache
  is separate from sources, wallpapers and installation recovery records.
- Payload-independent **user configuration** snapshot/restore with checksums,
  symlink preservation, edit detection, backup validation and rollback after
  partial restore failure. Replaced installed configuration is retained.
  This does not yet uninstall system configuration or provide v5 recovery.
- A bounded JSON-lines backend runner that rejects the old interactive v5
  installer protocol. Successful installation requires a valid v6 receipt.

```sh
python3 -m unittest discover -s tests -v
QT_QPA_PLATFORM=offscreen python3 app.py --screenshot PREVIEW.png
```

Transport/recovery tests run against controlled corrupt/interrupted/offline
fixtures. A real download of the published 134,787-byte wallpaper manifest
also passed its pinned length and SHA-256, and all 36 selected IDs resolved.
These checks are not fresh-machine installation, rollback or reboot tests.

## Release inputs from the working laptop

```sh
python3 collect-release-inputs.py
```

Run without sudo. It writes `~/Downloads/multi-rice-v6-release-inputs.zip`.
It reads allowlisted source/configuration/artwork types for the installed
profiles, Sumi Deck and shared music, plus installed package/version metadata.
It inventories private Cipher executables and any retained Genie source build
revision/diff, without collecting executables. It does not upload files, read
the entire home directory, collect playlists, modify configuration or restart
anything. Review the ZIP's report before sharing privately; pattern-based
credential detection is a precaution, not a privacy guarantee. Source files
are reviewed before any public commit. Binary inventories are needed to build
the matching package closure on an Arch/CachyOS builder.

## Remaining release gates

1. Review the actual Tsugumori source, current switcher/assets, music controller
   and Cipher private runtime/build inventory collected from the working host.
2. Build a reproducible twelve-profile offline payload, including Eclipse's
   pinned runtime and Python dependencies, matching native Cipher binaries,
   licenses and exact offline package dependency closure.
3. Replace the payload AppRun with the noninteractive protocol described below;
   connect system authentication without hidden terminal prompts. Persist the
   maintenance runtime and both user and system recovery receipts.
4. Finish system restore, v5 upgrade/restore handling and the separate optional
   GRUB step. Preserve the user's Windows default, custom entries and kernels.
   Complete opt-in device recipes without enabling them on generic hardware.
5. Finish all artwork, wallpaper visual curation, selected-file offline input,
   interruption/cancellation UX and verified space calculations for backups.
6. Validate fresh install, v5 upgrade, all twelve profile launch/switch paths,
   offline/no-network installation, rollback, edited files and cache cleanup
   in disposable Arch/CachyOS environments, plus the user's live checks.
7. Generate the real AppImage parts, part/full SHA256SUMS, ready release manifest,
   shared offline launcher ZIP and versioned online bootstrap. Upload/verify
   release assets before publishing `v6.0.0` and its one-command endpoint.

Development is restricted to `v6.0-tahoe-dev`. Existing releases and main are
not changed. The production `v6.0.0/install_multi_rice.sh` URL is not live yet.

## Payload interface

The frontend executes only a hash-verified image:

```sh
APPIMAGE_EXTRACT_AND_RUN=1 IMAGE --multi-rice-backend OPTIONS_JSON
```

Options are protocol/version/action/home/profiles and explicit booleans for
hardware changes, GRUB and package removal. The initial desktop install keeps
all three booleans false. AppRun must bypass all old menus. Stdout/stderr is a
JSON-line stream; every record includes `protocol: 1`, a `stage`, a human
`message`, and optional real `completed`/`total` counts. The final successful
record includes `result: "installed"` and an existing validated `receipt`.
Errors produce a failure record and nonzero exit. Arbitrary terminal output,
hidden prompts, incomplete records and absent final receipts are failures.

SHA-256 establishes matching publisher-provided content, not an independent
signature or proof that the publisher's software is safe.
