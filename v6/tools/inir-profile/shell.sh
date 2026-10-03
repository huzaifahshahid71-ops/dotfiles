#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
eval "$(/usr/bin/python3 "$ROOT/environment.py" --shell)"
export PATH="$ROOT/bin:$PATH"
cd "$HOME"
mkdir -p "$XDG_CACHE_HOME/tmp" "$XDG_STATE_HOME/quickshell/user"
# Clipboard watchers are children of this profile's shell service.
if command -v wl-paste >/dev/null && command -v cliphist >/dev/null; then
    wl-paste --no-newline --type text --watch "$ROOT/runtime/scripts/clipboard-store.py" &
    wl-paste --type image --watch "$ROOT/runtime/scripts/clipboard-image-store.sh" &
fi
exec /usr/bin/qs -p "$ROOT/runtime"
