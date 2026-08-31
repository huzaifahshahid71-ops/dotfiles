#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
WORK="$TMP/dotfiles"
DIST="$ROOT/dist"
OLD_OUT="$WORK/dist/Huzaifah-Triple-Rice-Offline-x86_64.AppImage"
NEW_OUT="$DIST/Huzaifah-Multi-Rice-OFFLINE-x86_64.AppImage"
NEW_SHA="$DIST/Huzaifah-Multi-Rice-OFFLINE-x86_64.sha256"

cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

[[ "$(uname -m)" == x86_64 ]] || die "This builder currently targets x86_64 only"
[[ -f "$ROOT/installer-appimage-offline/build.sh" ]] || die "Historical offline builder is missing"
[[ -f "$ROOT/installer-appimage-offline/multi-rice-offline.sh" ]] || die "Multi-Rice offline engine is missing"

for cmd in rsync python3 bash; do
    command -v "$cmd" >/dev/null 2>&1 || die "$cmd is required"
done

log "Preparing isolated Multi-Rice offline build tree"
mkdir -p "$WORK" "$DIST"
rsync -a \
    --exclude '.git/' \
    --exclude 'dist/' \
    --exclude 'installer-appimage-offline/.build/' \
    "$ROOT/" "$WORK/"

# The proven historical builder expects these legacy filenames. Substitute the
# current Multi-Rice launcher/engine inside the isolated build tree only.
cp "$ROOT/installer-appimage-offline/AppRun" \
   "$WORK/installer-appimage-offline/AppRun"
cp "$ROOT/installer-appimage-offline/multi-rice-offline.sh" \
   "$WORK/installer-appimage-offline/install-offline.sh"
chmod +x \
    "$WORK/installer-appimage-offline/AppRun" \
    "$WORK/installer-appimage-offline/install-offline.sh"

# Bundle support packages required by optional offline toolbox actions. They are
# added to the direct-target list used by the existing dependency-closure builder
# without changing what the online Multi-Rice installer installs on normal users.
python3 - "$WORK/scripts/restore-dual-rice.sh" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
s = p.read_text()
needle = "    adw-gtk-theme inter-font ttf-fira-code\n"
addition = (
    "    adw-gtk-theme inter-font ttf-fira-code \\\n"
    "    sbctl refind efibootmgr asusctl rog-control-center supergfxctl btrfs-progs\n"
)
if needle not in s:
    raise SystemExit("Could not locate the final Multi-Rice package line in restore-dual-rice.sh")
p.write_text(s.replace(needle, addition, 1))
PY

# Rebrand the desktop metadata in the isolated tree while retaining the legacy
# filename expected by build.sh.
cat > "$WORK/installer-appimage-offline/huzaifah-triple-rice-offline.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Huzaifah Multi-Rice OFFLINE
Comment=Offline Multi-Rice installer, ASUS/G16 tools, rEFInd and guided Secure Boot setup
Exec=AppRun
Icon=huzaifah-triple-rice-offline
Terminal=false
Categories=System;Settings;
StartupNotify=true
EOF

log "Syntax-checking the Multi-Rice launcher and engine"
bash -n "$WORK/installer-appimage-offline/AppRun"
bash -n "$WORK/installer-appimage-offline/install-offline.sh"

log "Running the proven dependency-closure offline builder"
(
    cd "$WORK"
    bash installer-appimage-offline/build.sh "$@"
)

[[ -f "$OLD_OUT" ]] || die "Underlying builder completed without producing the expected AppImage"

log "Publishing Multi-Rice offline artifact"
rm -f "$NEW_OUT" "$NEW_SHA"
mv "$OLD_OUT" "$NEW_OUT"
chmod +x "$NEW_OUT"
sha256sum "$NEW_OUT" > "$NEW_SHA"

printf '\n'
printf 'Built:\n'
ls -lh "$NEW_OUT" "$NEW_SHA"
printf '\nThis AppImage contains:\n'
printf '  ✦ Caelestia\n'
printf '  ◈ end4-pC\n'
printf '  ◆ Ambxst\n'
printf '  ● DankMaterialShell\n'
printf '  ⇄ Multi-Rice switcher\n'
printf '  ↻ hardware-aware refresh switcher\n'
printf '  🌙 Frieren SDDM theme\n'
printf '  ◇ ASUS / Zephyrus G16 setup tools\n'
printf '  ◇ rEFInd configuration\n'
printf '  ◇ guided sbctl Secure Boot setup\n'
printf '  ◇ guarded Btrfs hibernation storage setup\n'
printf '\nInstallation/runtime network requirement: none.\n'
