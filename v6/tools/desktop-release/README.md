# Sumi v6 desktop fixes r3

Run on the HOST, as your normal user. Save the ZIP in Downloads:

```fish
unzip -o ~/Downloads/sumi-v6-desktop-release-v4.zip -d ~/Downloads
python3 ~/Downloads/sumi-v6-desktop-release-v4/release.py --publish
```

This is the build-and-publication kit. It does not install anything on the host, change the running VM, or delete files outside its own separate build output. The updated public installer is available only after the command prints `PUBLISHED DESKTOP r3`.

Requires the signed-in GitHub CLI account `huzaifahshahid71-ops`, Python 3, the retained appimagetool (or an installed appimagetool), and 14 GiB free for the separate build and possible recovery download. The VM bridge is not required.

The verified nine-file Crimson addition must remain in `sumi-v6-build-prep/crimson-repair/` under `~/Downloads/MULTI RICE DEVELOPMENT`. The legacy preparation directory is also supported. The accepted Cipher and Aether configuration changes are included in this kit, with checksums and portable home-directory tokens.

The builder reuses the latest appearance-r2 backend and frozen GUI. If the r2 candidate was removed during cleanup, it recovers the published split image and verifies it before extraction. Downloaded metadata and source archives must match the reviewed r2 server digests. A previously retained r2 candidate is checked against its assembly report and every registered payload hash.

Changes are exactly the nine Crimson wallpaper-picker UI files, Cipher Super+Space IPC routing, and Aether Qt6ct/Papirus shell launch settings. All unrelated user files, system files, packages, links, SDDM/GRUB restore records, icon archive, Lumina assets, 12 profiles, 74 login cards, eight GRUB cards and the 631-wallpaper pin remain unchanged. The collector is also patched so later builds retain these launch fixes and include Crimson's wallpaper-picker UI without importing downloaded wallpapers or caches.

Output: `~/multi-rice-v6-desktop-r3`. Identical reruns resume the image and uploads. Build only by omitting `--publish`. If appimagetool cannot be found automatically, supply `--appimagetool /absolute/path/to/appimagetool`.

Publication uses unique r3 asset names in the existing v6.0.0 release. It verifies each uploaded size and server SHA-256, then replaces the known r2 `ONLINE-INSTALL-v6.sh` launcher. A failed replacement upload attempts to restore the previous launcher. Unknown public launcher changes are preserved. The source commit updates only `v6.0-tahoe-dev`; it does not modify main.

After `PUBLISHED DESKTOP r3`, the established command uses all three fixes:

```sh
curl -fsSL https://github.com/huzaifahshahid71-ops/dotfiles/releases/download/v6.0.0/ONLINE-INSTALL-v6.sh | bash
```

Send `~/Downloads/sumi-v6-desktop-release-report.zip` after completion or if it stops. That report includes the error/traceback and saved build checkpoints. The source archive, split payload and online GUI are retained for future rebuilding.

Validation: thirty-five local regression tests pass, covering accepted configuration deltas, portability, repeatability, corrupt/missing/symlinked additions, baseline refusal, unrelated payload preservation, collector filters and launcher rollback. The collector transform also compiles against the current public development-branch source. The host command checks payload hashes, unchanged r2 backends, the packaged protocol and a GUI screenshot before publishing. The three constituent fixes were visually accepted in the fresh VM; the newly combined r3 image has not yet been installed and visually accepted.

## Kit v2 correction

The earlier r2 staging candidate retained RC5-era backend files while its final packed AppDir contained the updated backend. Kit v2 selects the final packed AppDir, checks its backend against the pinned published source archive, and snapshots the baseline only under the new r3 output. If no final packed AppDir remains, it verifies and extracts the published r2 image; a retained complete image can be reused. A failure that stopped during source preparation can migrate its kit identity after confirming the published baseline is unchanged. Verified downloads and the earlier input metadata are retained. Completed r3 candidates, images or publication output block that migration.

## Kit v3 correction

The whole installed VM Cipher configuration differs from the published portable template. Kit v3 recognizes the exact published template hash recorded in the uploaded, fully verified r2 payload report and changes only its known Super+Space search route. Reversing that single change must recover the original SHA-256; unrelated settings remain intact. An already-correct route is retained. Unknown templates and unknown binding syntax still stop the build.

An interrupted r3 candidate can migrate to this kit only when its entire file tree still matches the verified baseline snapshot and no completed candidate, image or publication state exists. The verified downloads and earlier kit identity are retained. New stop reports include the three relevant staged configuration files for exact comparison.

## Kit v4 correction

The original Crimson repair retains `addon.zip` and `manifest.json`; it does not extract a `home/` directory on the host. Kit v4 reads that archive directly. Its SHA-256 must match the accepted VM repair receipt, its members must match the nine-file manifest exactly, and every member size and SHA-256 are checked before import. Verified extracted exports remain supported. The r3 installer source ZIP also receives those exact verified bytes directly from the retained archive.

The archive is checked before downloads and the full payload scan. The unchanged failed v3 candidate can migrate using the existing baseline comparison; cached downloads are retained. Archive coverage uses the original repair's ZIP producer and checks corrupt members, altered manifests, duplicate or extra members, symlinks, discovery without an extracted folder, repeatability and payload preservation.
