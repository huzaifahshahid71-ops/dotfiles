#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "${2:-.}" && pwd)"
DIST="$ROOT/dist"
SRC="$ROOT/installer-appimage-offline"
BUILD="$SRC/.build"
TOOL="$BUILD/appimagetool-modern-x86_64.AppImage"
WORK="$BUILD/repack-tested-fixed"
OUT="$DIST/Huzaifah-Multi-Rice-OFFLINE-FIXED-x86_64.AppImage"
OUT_SHA="$OUT.sha256"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()  { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

INPUT="${1:-}"
if [[ -z "$INPUT" ]]; then
    for candidate in \
        "$DIST/Huzaifah-Multi-Rice-OFFLINE-x86_64.AppImage" \
        "$DIST/Huzaifah-Triple-Rice-Offline-x86_64.AppImage"; do
        if [[ -f "$candidate" ]]; then
            INPUT="$candidate"
            break
        fi
    done
fi

[[ -n "$INPUT" && -f "$INPUT" ]] || die "Could not find the previously tested offline AppImage in $DIST"
INPUT="$(realpath "$INPUT")"
[[ -f "$SRC/AppRun" ]] || die "Missing fixed AppRun"
[[ -f "$ROOT/dual-rice/profiles/caelestia/hypr/hyprland.lua" ]] || die "Missing fixed Caelestia profile"

log "Repacking the already-tested offline payload; no package resolution or system changes"
rm -rf "$WORK"
mkdir -p "$WORK" "$BUILD" "$DIST"

log "Extracting tested AppImage"
(
    cd "$WORK"
    "$INPUT" --appimage-extract >/dev/null
)
APPDIR="$WORK/squashfs-root"
ENGINE="$APPDIR/install-offline.sh"
[[ -d "$APPDIR/payload/packages" ]] || die "Extracted AppImage does not contain the offline package payload"
[[ -f "$ENGINE" ]] || die "Extracted AppImage is missing install-offline.sh"

# IMPORTANT: the tested AppImage contains the newer action-aware Multi-Rice engine.
# GitHub/main still has an older triple-rice engine, so never overwrite the tested
# engine with the repository copy while repacking.
grep -q 'preflight)' "$ENGINE" || die "Tested input does not contain the action-aware installer engine"
grep -qi 'dms' "$ENGINE" || die "Tested input does not appear to contain the four-rice/DMS engine"

log "Preserving tested Multi-Rice engine and overlaying only verified release fixes"
install -m 0755 "$SRC/AppRun" "$APPDIR/AppRun"
install -m 0644 \
    "$ROOT/dual-rice/profiles/caelestia/hypr/hyprland.lua" \
    "$APPDIR/payload/repo/dual-rice/profiles/caelestia/hypr/hyprland.lua"

# Patch Frieren/SDDM behavior directly into the tested engine instead of replacing it.
python3 - "$ENGINE" <<'PY'
from pathlib import Path
import re
import sys

p = Path(sys.argv[1])
text = p.read_text()

if "HUZ_OFFLINE_ACTION=" not in text:
    m = re.search(r'^(BACKUP=.*)$', text, re.MULTILINE)
    if not m:
        raise SystemExit("ERROR: could not locate BACKUP variable in tested engine")
    text = text[:m.end()] + '\nHUZ_OFFLINE_ACTION="${1:-install}"' + text[m.end():]

if "HUZ_FIX_ACTIVATE_SDDM" not in text:
    anchor = "install_frieren_theme() {\n"
    if anchor not in text:
        raise SystemExit("ERROR: could not locate install_frieren_theme() in tested engine")
    helper = r'''# HUZ_FIX_ACTIVATE_SDDM:
# Change the display-manager choice for the next boot without killing this session.
activate_sddm_for_next_boot() {
    local dm_link="/etc/systemd/system/display-manager.service"
    local current_dm=""

    if [[ -L "$dm_link" ]]; then
        current_dm="$(basename "$(readlink -f "$dm_link" 2>/dev/null || true)")"
    fi

    if [[ -n "$current_dm" && "$current_dm" != "sddm.service" ]]; then
        log "Replacing $current_dm with SDDM for the next boot"
        sudo systemctl disable "$current_dm" >/dev/null 2>&1 || true
    fi

    sudo systemctl disable greetd.service >/dev/null 2>&1 || true
    sudo systemctl enable sddm.service >/dev/null
    sudo systemctl set-default graphical.target >/dev/null
    ok "SDDM enabled for next boot; current graphical session was left running"
}

'''
    text = text.replace(anchor, helper + anchor, 1)

text = text.replace(
    "/etc/sddm.conf.d/90-huzaifah-theme.conf",
    "/etc/sddm.conf.d/99-huzaifah-theme.conf",
)

if "HUZ_FIX_SDDM_CONFIG_PRECEDENCE" not in text:
    theme_write = "    printf '[Theme]\\nCurrent=sddm-frieren-theme\\n' | sudo tee /etc/sddm.conf.d/99-huzaifah-theme.conf >/dev/null"
    if theme_write not in text:
        raise SystemExit("ERROR: could not locate Frieren theme selection write in tested engine")
    replacement = r'''    # HUZ_FIX_SDDM_CONFIG_PRECEDENCE:
    # /etc/sddm.conf overrides drop-ins when present, so keep it consistent too.
    if sudo test -f /etc/sddm.conf; then
        sudo cp -a /etc/sddm.conf "$root_backup/sddm.conf"
        if sudo grep -qE '^[[:space:]]*Current[[:space:]]*=' /etc/sddm.conf; then
            sudo sed -Ei 's#^[[:space:]]*Current[[:space:]]*=.*#Current=sddm-frieren-theme#' /etc/sddm.conf
        elif sudo grep -qE '^[[:space:]]*\[Theme\][[:space:]]*$' /etc/sddm.conf; then
            sudo sed -i '/^[[:space:]]*\[Theme\][[:space:]]*$/a Current=sddm-frieren-theme' /etc/sddm.conf
        else
            printf '\n[Theme]\nCurrent=sddm-frieren-theme\n' | sudo tee -a /etc/sddm.conf >/dev/null
        fi
    fi

    printf '[Theme]\nCurrent=sddm-frieren-theme\n' | sudo tee /etc/sddm.conf.d/99-huzaifah-theme.conf >/dev/null

    # Full install selects SDDM for the next boot; the standalone sddm action stays theme-only.
    if [[ "$HUZ_OFFLINE_ACTION" == "install" ]]; then
        activate_sddm_for_next_boot
    fi'''
    text = text.replace(theme_write, replacement, 1)

text = text.replace(
    'ok "Frieren SDDM theme installed (display manager state/autologin unchanged)"',
    'ok "Frieren SDDM theme installed"',
)

p.write_text(text)
PY

# The original test exposed missing executable bits in staged repository scripts.
find "$APPDIR/payload/repo" -type f -name '*.sh' -exec chmod 0755 {} +
if [[ -d "$APPDIR/payload/repo/dual-rice/bin" ]]; then
    find "$APPDIR/payload/repo/dual-rice/bin" -maxdepth 1 -type f -exec chmod 0755 {} +
fi
chmod 0755 "$APPDIR/AppRun" "$ENGINE"

bash -n "$APPDIR/AppRun"
bash -n "$ENGINE"
grep -q 'HUZ_FIX_ACTIVATE_SDDM' "$ENGINE" || die "SDDM activation patch did not land"
grep -q 'HUZ_FIX_ROOT_FUSE_REEXEC' "$APPDIR/AppRun" || die "sudo/FUSE re-exec patch is missing from AppRun"

if [[ ! -x "$TOOL" ]]; then
    log "Downloading modern appimagetool"
    curl -fL --retry 3 \
        https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage \
        -o "$TOOL"
    chmod +x "$TOOL"
fi

log "Building fixed single-file AppImage"
rm -f "$OUT" "$OUT_SHA"
ARCH=x86_64 APPIMAGE_EXTRACT_AND_RUN=1 "$TOOL" "$APPDIR" "$OUT"
chmod +x "$OUT"
sha256sum "$OUT" > "$OUT_SHA"

# Exercise the new runtime normally; this catches the old libfuse.so.2 problem.
"$OUT" --appimage-version >/dev/null

ok "Fixed AppImage built from the tested action-aware Multi-Rice payload"
ls -lh "$OUT" "$OUT_SHA"
printf '\nNo packages were installed, removed, upgraded, or re-resolved while repacking.\n'
