#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
DIST="$ROOT/dist"
TAG="multi-rice-offline-v2.0.1"
TITLE="Huzaifah Multi-Rice OFFLINE v2.0.1"
SOURCE="$DIST/Huzaifah-Multi-Rice-OFFLINE-FIXED-x86_64.AppImage"
ASSET_NAME="Huzaifah-Multi-Rice-OFFLINE-x86_64.AppImage"
SHA_NAME="Huzaifah-Multi-Rice-OFFLINE-x86_64.sha256"
ASSET="$DIST/$ASSET_NAME"
SHA="$DIST/$SHA_NAME"

[[ -f "$SOURCE" ]] || { echo "ERROR: missing tested build: $SOURCE" >&2; exit 1; }
command -v gh >/dev/null 2>&1 || {
  echo "ERROR: GitHub CLI (gh) is not installed." >&2
  echo "On CachyOS/Arch: sudo pacman -S --needed github-cli" >&2
  exit 1
}

gh auth status >/dev/null

cp -f "$SOURCE" "$ASSET"
(
  cd "$DIST"
  sha256sum "$ASSET_NAME" > "$SHA_NAME"
)

NOTES="$(mktemp)"
trap 'rm -f "$NOTES"' EXIT
cat > "$NOTES" <<'EOF'
## Huzaifah Multi-Rice OFFLINE v2.0.1

Release-tested offline installer for CachyOS/Arch-family x86_64 systems.

### Included
- Caelestia
- end4-pC
- Ambxst
- DankMaterialShell (DMS)
- Multi-Rice desktop switcher
- Hardware-aware refresh-rate switcher
- Frieren SDDM login theme
- ASUS / Zephyrus G16 setup tools
- rEFInd configuration
- Guided sbctl Secure Boot setup
- Guarded Btrfs hibernation setup

### v2.0.1 fixes
- Modern AppImage type2 runtime; target systems no longer need the old `libfuse2` runtime path used by the previous build.
- Normal double-click/direct AppImage launch now transparently handles root/sudo access to the bundled offline package repository.
- Fixed executable permissions for bundled shell scripts and desktop-switcher helpers.
- Fixed terminal fallback action selection.
- Full install now activates SDDM for the next boot and selects the Frieren theme while leaving the current graphical session alive.
- Fixed SDDM theme precedence when `/etc/sddm.conf` exists.
- Caelestia now keeps the ASUS-specific DRM device preference only when that device exists, allowing VMs and other PCs to auto-detect GPUs.
- No Noctalia package is required by this release.

### Validation
Tested in a CachyOS QEMU/KVM VM:
- AppImage launches normally.
- Offline preflight passes.
- Full offline installation completes successfully.
- Frieren SDDM appears after reboot.
- Caelestia, end4-pC, Ambxst and DMS all launch and switch successfully.
- Installation does not require an internet connection.

### Usage
1. Download `Huzaifah-Multi-Rice-OFFLINE-x86_64.AppImage`.
2. If your file manager did not preserve executable permission, run `chmod +x Huzaifah-Multi-Rice-OFFLINE-x86_64.AppImage` once.
3. Double-click the AppImage.
4. Run **Preflight**.
5. Choose **Install**.
6. Reboot and log in through Frieren SDDM.

The `.sha256` asset is provided for integrity verification.
EOF

if gh release view "$TAG" >/dev/null 2>&1; then
  echo "==> Updating existing $TAG release"
  gh release upload "$TAG" "$ASSET" "$SHA" --clobber
  gh release edit "$TAG" --title "$TITLE" --notes-file "$NOTES"
else
  echo "==> Creating $TAG release and uploading ~1.2 GB AppImage"
  gh release create "$TAG" "$ASSET" "$SHA" \
    --repo huzaifahshahid71-ops/dotfiles \
    --target main \
    --title "$TITLE" \
    --notes-file "$NOTES"
fi

echo
printf 'SHA256: '
awk '{print $1}' "$SHA"
printf 'Release: '
gh release view "$TAG" --repo huzaifahshahid71-ops/dotfiles --json url --jq '.url'
