#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else ".").expanduser().resolve()

FILES = {
    "apprun": ROOT / "installer-appimage-offline" / "AppRun",
    "build": ROOT / "installer-appimage-offline" / "build.sh",
    "engine": ROOT / "installer-appimage-offline" / "install-offline.sh",
    "caelestia": ROOT / "dual-rice" / "profiles" / "caelestia" / "hypr" / "hyprland.lua",
}

changed: list[str] = []


def read(name: str) -> str:
    p = FILES[name]
    if not p.is_file():
        raise SystemExit(f"ERROR: missing expected file: {p}")
    return p.read_text()


def write(name: str, text: str) -> None:
    p = FILES[name]
    p.write_text(text)
    changed.append(str(p.relative_to(ROOT)))


# 1) AppRun terminal fallback:
# command substitution must capture only "preflight"/"install"/etc, never menu text.
text = read("apprun")
if "HUZ_FIX_MENU_OUTPUT_TO_TTY" not in text:
    fn = "choose_action_terminal() {\n"
    read_line = "    read -r -p 'Choose: ' choice < /dev/tty || return 1"
    if fn not in text or read_line not in text:
        raise SystemExit("ERROR: could not locate terminal menu block in AppRun")
    text = text.replace(
        fn,
        fn + "    # HUZ_FIX_MENU_OUTPUT_TO_TTY: keep menu text out of command substitution.\n    {\n",
        1,
    )
    text = text.replace(
        read_line,
        "    } >/dev/tty\n" + read_line,
        1,
    )
    write("apprun", text)


# 2) Build: use modern AppImage tooling/runtime and normalize executable bits.
text = read("build")
updated = text
updated = updated.replace(
    'TOOL="$BUILD/appimagetool-x86_64.AppImage"',
    'TOOL="$BUILD/appimagetool-modern-x86_64.AppImage"',
)
updated = updated.replace(
    "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage",
    "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage",
)
if "HUZ_FIX_PAYLOAD_EXEC_BITS" not in updated:
    anchor = 'copy_tree "$ROOT" "$PAYLOAD/repo"\n'
    if anchor not in updated:
        raise SystemExit("ERROR: could not locate payload copy step in build.sh")
    block = r'''
# HUZ_FIX_PAYLOAD_EXEC_BITS: git/archive copies may lose executable metadata.
log "Normalizing executable permissions in the bundled repository payload"
find "$PAYLOAD/repo" -type f -name '*.sh' -exec chmod 0755 {} +
if [[ -d "$PAYLOAD/repo/dual-rice/bin" ]]; then
    find "$PAYLOAD/repo/dual-rice/bin" -maxdepth 1 -type f -exec chmod 0755 {} +
fi
[[ -x "$PAYLOAD/repo/scripts/install-refresh-switcher.sh" ]] \
    || die "Bundled refresh switcher installer is not executable after staging"
'''
    updated = updated.replace(anchor, anchor + block + "\n", 1)

# Make the build-time smoke test exercise the normal runtime, not only extract-and-run.
if '"$OUT" --appimage-version >/dev/null' not in updated:
    updated = updated.replace(
        'APPIMAGE_EXTRACT_AND_RUN=1 "$OUT" --appimage-version >/dev/null',
        '"$OUT" --appimage-version >/dev/null\nAPPIMAGE_EXTRACT_AND_RUN=1 "$OUT" --appimage-version >/dev/null',
    )
if updated != text:
    write("build", updated)


# 3) Caelestia: only pin the ASUS-specific iGPU symlink when it actually exists.
text = read("caelestia")
if "HUZ_FIX_PORTABLE_AQ_DRM_DEVICES" not in text:
    old = 'hl.env("AQ_DRM_DEVICES", "/dev/dri/intel-igpu")'
    if old not in text:
        raise SystemExit("ERROR: could not locate hard-coded AQ_DRM_DEVICES in Caelestia profile")
    new = r'''-- HUZ_FIX_PORTABLE_AQ_DRM_DEVICES:
-- Keep the preferred ASUS iGPU on the real laptop, but let VMs/other PCs auto-detect.
local aq_drm_device = "/dev/dri/intel-igpu"
local aq_drm_exists = os.execute("test -e " .. aq_drm_device)
if aq_drm_exists == true or aq_drm_exists == 0 then
    hl.env("AQ_DRM_DEVICES", aq_drm_device)
end'''
    text = text.replace(old, new, 1)
    write("caelestia", text)


# 4) Frieren SDDM: full "install" action should switch the next boot from
# greetd/other DM to SDDM, but the standalone "sddm" action remains theme-only.
text = read("engine")
updated = text
if "HUZ_OFFLINE_ACTION=" not in updated:
    anchor_re = re.compile(r'^(BACKUP=.*)$', re.MULTILINE)
    m = anchor_re.search(updated)
    if not m:
        raise SystemExit("ERROR: could not locate BACKUP variable in install-offline.sh")
    updated = updated[:m.end()] + '\nHUZ_OFFLINE_ACTION="${1:-install}"' + updated[m.end():]

if "HUZ_FIX_ACTIVATE_SDDM" not in updated:
    anchor = "install_frieren_theme() {\n"
    if anchor not in updated:
        raise SystemExit("ERROR: could not locate install_frieren_theme() in install-offline.sh")
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

    # CachyOS Hyprland commonly ships greetd; this is harmless if absent.
    sudo systemctl disable greetd.service >/dev/null 2>&1 || true

    sudo systemctl enable sddm.service >/dev/null
    sudo systemctl set-default graphical.target >/dev/null
    ok "SDDM enabled for next boot; current graphical session was left running"
}

'''
    updated = updated.replace(anchor, helper + anchor, 1)

# Replace the old 90- drop-in with a later 99- drop-in.
updated = updated.replace(
    "/etc/sddm.conf.d/90-huzaifah-theme.conf",
    "/etc/sddm.conf.d/99-huzaifah-theme.conf",
)

if "HUZ_FIX_SDDM_CONFIG_PRECEDENCE" not in updated:
    theme_write = (
        "    printf '[Theme]\\nCurrent=sddm-frieren-theme\\n' | sudo tee "
        "/etc/sddm.conf.d/99-huzaifah-theme.conf >/dev/null"
    )
    if theme_write not in updated:
        raise SystemExit("ERROR: could not locate Frieren SDDM Current= write in install-offline.sh")
    replacement = r'''    # HUZ_FIX_SDDM_CONFIG_PRECEDENCE:
    # /etc/sddm.conf has higher precedence than drop-ins, so update its Theme
    # selection too when it already exists.
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

    # Full Multi-Rice install means SDDM should actually become the login manager.
    # The dedicated "sddm" toolbox action intentionally remains theme-only.
    if [[ "$HUZ_OFFLINE_ACTION" == "install" ]]; then
        activate_sddm_for_next_boot
    fi'''
    updated = updated.replace(theme_write, replacement, 1)

if updated != text:
    write("engine", updated)


print("Applied offline-installer release fixes:")
for rel in changed:
    print(f"  - {rel}")
if not changed:
    print("  (already applied; no files changed)")

print()
print("Next checks:")
print("  bash -n installer-appimage-offline/AppRun")
print("  bash -n installer-appimage-offline/install-offline.sh")
print("  bash -n installer-appimage-offline/build.sh")
print("  git diff --check")
