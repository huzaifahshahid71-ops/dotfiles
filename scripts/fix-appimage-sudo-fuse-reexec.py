#!/usr/bin/env python3
from pathlib import Path
import sys

root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").expanduser().resolve()
path = root / "installer-appimage-offline" / "AppRun"
text = path.read_text()

marker = "HUZ_FIX_ROOT_FUSE_REEXEC"
if marker in text:
    print("AppImage sudo/FUSE fix already applied.")
    raise SystemExit(0)

anchor = "set -u\n"
if anchor not in text:
    raise SystemExit("ERROR: could not locate AppRun header; file left unchanged")

block = r'''

# HUZ_FIX_ROOT_FUSE_REEXEC:
# A normally mounted AppImage is a user-owned FUSE mount. Commands run through
# sudo (pacman, install, cp, etc.) may be unable to read files beneath that
# mount. Keep the user experience as a normal double-click/direct launch, but
# transparently relaunch once using AppImage's extract-and-run mode so the
# bundled offline payload lives in an ordinary temporary directory readable by
# both the user and root.
if [[ -n "${APPIMAGE:-}" \
      && "${APPIMAGE_EXTRACT_AND_RUN:-0}" != "1" \
      && "${HUZ_APPIMAGE_REEXECED:-0}" != "1" ]]; then
    export HUZ_APPIMAGE_REEXECED=1
    export APPIMAGE_EXTRACT_AND_RUN=1
    exec "$APPIMAGE" "$@"
fi
'''

path.write_text(text.replace(anchor, anchor + block, 1))
print("Applied automatic extract-and-run relaunch to installer-appimage-offline/AppRun")
print("Normal AppImage launch remains: ./Huzaifah-...AppImage")
