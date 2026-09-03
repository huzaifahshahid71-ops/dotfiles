#!/usr/bin/env python3
from pathlib import Path
import sys

root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").expanduser().resolve()
path = root / "installer-appimage-offline" / "build.sh"
text = path.read_text()

marker = "HUZ_FIX_QUICKSHELL_PROVIDER"
if marker in text:
    print("Quickshell provider fix already applied.")
    raise SystemExit(0)

old = '''mapfile -t TARGETS < "$TARGETS_FILE"
log "Installing any missing direct triple-rice targets on the build machine"
paru -S --needed --noconfirm --skipreview --sudoloop "${TARGETS[@]}"
'''

new = '''mapfile -t TARGETS < "$TARGETS_FILE"
log "Installing any missing direct Multi-Rice targets on the build machine"

# HUZ_FIX_QUICKSHELL_PROVIDER:
# dms-shell depends on the virtual `quickshell` provider.  Asking paru to solve
# the entire target set in one transaction can make it choose noctalia-qs even
# when quickshell-git is the provider we explicitly want, which then conflicts
# with quickshell-git.  Pin quickshell-git first and install only missing direct
# targets one transaction at a time so paru preserves the installed provider.
if printf '%s\\n' "${TARGETS[@]}" | grep -Fxq quickshell-git; then
    log "Pinning quickshell-git as the Quickshell provider"
    paru -S --needed --noconfirm --skipreview --sudoloop quickshell-git
fi

for target in "${TARGETS[@]}"; do
    [[ "$target" == "quickshell-git" ]] && continue
    if pacman -Q "$target" >/dev/null 2>&1; then
        continue
    fi
    log "Preparing direct target: $target"
    paru -S --needed --noconfirm --skipreview --sudoloop "$target"
done
'''

if old not in text:
    raise SystemExit("ERROR: expected direct-target install block was not found; build.sh was left unchanged")

path.write_text(text.replace(old, new, 1))
print("Applied Quickshell provider fix to installer-appimage-offline/build.sh")
