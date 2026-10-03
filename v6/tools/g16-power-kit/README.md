# Zephyrus G16 power-fix maintenance kit

Recovered from the working `7.2.5-1-cachyos-vmdtest` source archive supplied
on 2026-10-03. That kernel is labelled **Linux stable** in GRUB. Windows is
the user's default boot selection. This kit does not change either entry.

## What was recovered

1. `0001-vmd-mtl016-complete-backport.patch`: the Meteor Lake VMD interrupt
   ordering fix, including its feature flag, per-device `features` member
   and initialization. Those supporting edits were missing from the retained
   old PKGBUILD. The primary upstream patch is identified in provenance.json.
2. `0002-vmd-aspm-host-defaults.patch`: the working controller-provided ASPM
   and CLKPM defaults, PCI host-bridge field/API and VMD changes. These were
   present in the modified source but absent from the old build recipe.
3. `patches/asusctl/`: the exact captured Git diff removing the permanently
   open hidraw handle; the device is opened for each transaction instead.
4. `power-settings/`: the installed ITE/mouse autosuspend rules, HDA options,
   finalizer unit and its Fish helper. These are recovery copies, not an
   automatic installation payload. The helper's USB bus path is specific to
   this laptop and must be reviewed if its enumeration changes.

`reference/` retains the relevant clean and modified source snapshots, the
old recipe, working kernel configuration and experimental ITE module. The
ITE module was **not loaded** in the supplied report and is never installed
or added to the new build. The archive is evidence of retained source; it
does not by itself prove every installed binary matches that source.

Personal GRUB settings, kernel command-line identifiers and the complete
host package inventory are deliberately not published in this bundle.

## Prepare the separate 7.2.8 build

Unzip the delivered kit into Downloads, then run as your ordinary user:

```sh
python3 ~/Downloads/g16-power-kit/prepare.py --prepare-source
```

This creates `~/kernel-g16-maintenance/7.2.8`, then invokes `makepkg --nobuild`.
It downloads, verifies and extracts signed CachyOS kernel source and runs the
preparation/configuration steps, including our guarded patches. It does not
compile/install the kernel, install dependencies or change GRUB. Missing build
dependencies stop preparation; do not bypass source/signature verification.
The source tarball is large; the source ZIP is not an offline kernel installer.

The package names are **linux-cachyos-g16** and **linux-cachyos-g16-headers**.
The existing **linux-cachyos-vmdtest** kernel remains separately installed.
The pinned recipe uses CachyOS's 7.2.8 source tag revision 1; this is a custom
build and is not claimed to reproduce the repository's `7.2.8-2` package.

If successful, send `~/kernel-g16-maintenance/7.2.8/prepare.log` for review.
If unsuccessful, send that log and leave the retained directory in place.
The helper refuses to overwrite a previous build directory. A new attempt
can use `--workdir ~/kernel-g16-maintenance/7.2.8-attempt2`.

Compilation is a later explicit step, after the repository update completes:

```sh
cd ~/kernel-g16-maintenance/7.2.8
makepkg --noextract
```

Use `--noextract` only following successful preparation in that same directory.
Do not use `--install`: review build results before installing the two kernel
packages. Existing NVIDIA open DKMS support needs successful matching-header
builds/initramfs hooks. Installing requires a separate explicit command and
must retain the working Linux stable entry and Windows default.

Before promoting any new kernel, boot it explicitly and check NVMe errors,
VMD link power states, idle battery consumption, keyboard/hotkeys/backlight,
audio, suspend/resume and NVIDIA module availability when the dGPU is enabled.
The current kernel remains available until the replacement passes those tests.

## Reuse for future kernels

Keep the whole kit in Git. Obtain/review the current CachyOS `linux-cachyos`
recipe and its matching config, then supply that directory and a fresh output:

```sh
python3 ~/Downloads/g16-power-kit/prepare.py \
  --recipe-dir ~/kernel-recipes/linux-cachyos \
  --workdir ~/kernel-g16-maintenance/NEXT-VERSION --prepare-source
```

The adapter checks known recipe anchors and inserts the same separately named
package and patch stage. The upstream recipe performs its normal source checks.
The G16 stage preflights the entire series on temporary copies; an incompatible
patch stops preparation before our patches alter the real source files.

To check another already-extracted kernel source tree without changing it:

```sh
python3 apply.py --kernel --source /path/to/kernel/source
```

Add `--apply` only to apply the verified result. For asusctl use `--asusctl`
with its source directory. Exact already-applied series are detected in reverse
order and skipped. A different upstream implementation of the same fix may not
match these patches: inspect it and retire/rebase the relevant patch rather than
forcing application. Patch application can be automated; compilation and live
hardware checks still take time for every new kernel.

## Validation and limits

Run `python3 tests/check_integration.py` for source-only checks. They verify
exact reconstruction of the captured three-file kernel changes, applicability
on fetched CachyOS 7.2.8 sources, idempotence, partial-series handling, rejection
of conflicting source without mutation, asusctl reconstruction and recipe
guards. No new kernel was compiled or booted in the remote workspace. Settings
and asusctl restoration are not automatically executed by this kit.

Captured targeted files cannot rule out undiscovered edits elsewhere in a
retained source tree. They recover the known VMD/ASPM and hidraw changes; the
reference snapshots and provenance document their scope explicitly.

## Licensing

Kernel source and recovered kernel modifications: GPL-2.0 as documented in
their source headers. `include/linux/pci.h` carries the Linux syscall exception.
The asusctl source/patch is MPL-2.0 from OpenGamingCollective/asusctl. Original
copyright notices are retained. The recovery/preparation Python helpers and
tests in this kit are offered under GPL-2.0-only. License texts are in LICENSES.

The old recipe is kept for comparison and must not be rerun as a complete
reproduction recipe; it omits the later edits described above.
