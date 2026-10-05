Sumi v6.0.0 final build and publication kit v1

Run ON THE HOST, as gamer without sudo:
  python3 ~/Downloads/sumi-v6-final-release-v1/release.py --publish

The VM must be running and vmrun must respond. The command:
1. Checks the tested RC5 AppImage and payload hashes.
2. Requires all current backend/GUI sources to match RC5 except the exact tested
   login restore guard. Reuses the GUI and every profile/theme/package input.
3. Creates ~/multi-rice-v6-release-final, builds the final-named AppImage, verifies
   payload files, split/reassembly hashes, host and VM restore regressions, GUI render.
4. Commits current installer Python sources and this release workflow to the
   remote v6.0-tahoe-dev branch, with a non-forced branch update. main is unchanged.
5. Creates an owned draft release v6.0.0, uploads five split parts and the GUI,
   source, manifest, checksums, assembler and release notes. Verifies GitHub's
   SHA-256 digest and byte count for every asset before publishing stable/latest.

The complete AppImage is larger than GitHub's per-asset limit, so release users
assemble it from verified parts. assemble-v6.py downloads missing parts automatically.

The existing RC5 output and all installed VM configurations remain untouched.
VM tests use only a temporary fake filesystem, not the current installation.
No authentication prompt or desktop restart is requested by this release workflow.
A release publication is explicitly enabled by --publish. Omit it to build only.

Resume by rerunning the same command with unchanged inputs. A changed input, public
release mismatch, unknown draft, changed draft asset, or branch race stops instead of
clobbering existing data. Completed uploads are reused after checking their digests.
Do not rename RC5 to final: the new AppImage must contain the restore fix.

Required retained host paths:
  ~/Downloads/sumi-v6-build-prep
  ~/multi-rice-v6-packaged-rc5-final
  ~/VMs/vm-share
At least 8 GiB host free space, gh CLI signed in as huzaifahshahid71-ops, and vmrun.

Success ends with:
  PUBLISHED: https://github.com/huzaifahshahid71-ops/dotfiles/releases/tag/v6.0.0

On a failure, send ~/Downloads/sumi-v6-final-release-report.zip.
The accepted VM results are for an existing CachyOS VM, not a claim of fresh-install
coverage across every Arch derivative. The release notes state that limitation.
