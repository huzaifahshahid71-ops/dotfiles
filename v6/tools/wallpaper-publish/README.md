# Wallpaper collection publisher

Run this on the laptop containing `~/Pictures/Wallpapers`. The collection is
not available to the remote development workspace, and the GitHub connector
does not provide repository creation or binary release-upload operations.

The publisher uses the signed-in GitHub CLI to create the public
`huzaifahshahid71-ops/multi-rice-wallpapers` repository, then uploads individual
images, a full ZIP, a v6 installer manifest and SHA-256 checksums. It publishes
a download index as the repository README. The large images are release assets,
not Git blobs; the dotfiles repository and its `main` branch are untouched.

```fish
sudo pacman -S --needed github-cli
gh auth status --hostname github.com; or gh auth login --hostname github.com --git-protocol https --web
python3 ~/Downloads/wallpaper-publish-v1/publish.py --upload
```

Sign in as `huzaifahshahid71-ops`. The Python publisher runs without sudo.
Use `--source PATH` for another image directory. Without `--upload`, it only
prepares files locally. No tokens are copied into the publisher or shared here.

The reported host collection is 302 files and about 1.3 GiB. Supported image
extensions are selected, while hidden files, symlinks and other file types are
skipped. Original bytes and folder structure are kept in the full ZIP. Individual
release asset names are made unique, with original relative names in the index
and manifest. The source folder is not modified. Credits/licenses are not
inferred, and the README does not apply a blanket license to the artwork.

Preparation retains image snapshots and the ZIP in
`~/.local/share/multi-rice-wallpaper-publish/`. Allow about 2.6 GiB extra local
space and roughly 2.6 GiB of upload traffic for the reported collection:
individual originals plus the full ZIP. Already compressed images are stored
in the ZIP without another expensive compression pass.

The collection tag is derived from paths and content hashes. The release stays
a draft until every asset's remote byte length and GitHub SHA-256 digest match.
The publisher then makes the release public and writes the individual/full-pack
download index. Hashes establish transferred content integrity, not copyright
permissions or independent publisher authentication.

Interrupted runs retain valid local preparation and completed uploaded assets.
The initial host run prepared all 302 images and created the repository and
draft, then failed because the by-tag REST endpoint could not resolve the
unpublished draft. Version 1.1 finds it through authenticated paginated release
listing and uses its numeric ID for asset inspection. A regression fixture
explicitly returns 404 for the old lookup and verifies the existing draft is
reused without creating another repository or release.
Rerun the same command to verify and skip those assets. An interrupted individual
asset must restart; this does not claim byte-range resumable GitHub uploads.
An empty `starter` asset in this publisher's draft release can be removed for
retry. Other conflicting assets, unrelated releases, private repositories and
unmanaged READMEs are preserved and cause a clear stop. Published assets are
not clobbered. The wrong GitHub account stops before repository creation.

The tool publishes the full collection first. Curated selection and preview
artwork can be added later without including wallpapers in the giant installer.
Both installer editions default to the desktop user's `~/Pictures/Wallpapers`.

Local tests use temporary image fixtures and mocked GitHub responses; they do
not upload test data or validate a live GitHub session:

```sh
python3 tests/check_publish.py
```

References:

- https://cli.github.com/manual/gh_repo_create
- https://cli.github.com/manual/gh_release_create
- https://cli.github.com/manual/gh_release_upload
- https://cli.github.com/manual/gh_release_edit
- https://docs.github.com/en/rest/releases/assets
