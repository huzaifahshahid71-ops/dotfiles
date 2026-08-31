#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE="$ROOT/scripts/restore-dual-rice.sh"
TMP="$(mktemp --suffix=.sh)"
trap 'rm -f "$TMP"' EXIT

[[ -f "$BASE" ]] || { echo "Missing $BASE" >&2; exit 1; }
cp "$BASE" "$TMP"

python3 - "$TMP" <<'PY'
from pathlib import Path
import re, shlex, sys

p = Path(sys.argv[1])
s = p.read_text()
pat = re.compile(r'log "Installing Multi-Rice dependencies"\nparu -S --needed \\\n(?P<body>.*?)(?=\n\n# Multi-Rice uses)', re.S)
m = pat.search(s)
if not m:
    raise SystemExit("Could not locate Multi-Rice dependency block")

raw = m.group('body')
parts = []
for line in raw.splitlines():
    line = line.strip()
    if line.endswith('\\'):
        line = line[:-1].strip()
    if line:
        parts.extend(shlex.split(line))

sensitive = {
    'quickshell-git',
    'dim-caelestia-shell-git',
    'caelestia-cli',
    'dms-shell',
    'dms-shell-hyprland',
}
rest = [x for x in parts if x not in sensitive]

wrapped = []
for i in range(0, len(rest), 8):
    chunk = ' '.join(rest[i:i+8])
    if i + 8 < len(rest):
        wrapped.append('    ' + chunk + ' \\')
    else:
        wrapped.append('    ' + chunk)

new = '''log "Preparing the Quickshell provider before Multi-Rice dependencies"
if pacman -Q noctalia-qs >/dev/null 2>&1; then
    warn "Existing noctalia-qs conflicts with the Multi-Rice Quickshell provider."
    warn "Replacing noctalia-qs with quickshell-git before continuing."
    sudo pacman -Rdd --noconfirm noctalia-qs
fi

paru -S --needed quickshell-git dim-caelestia-shell-git caelestia-cli
sudo pacman -S --needed dms-shell dms-shell-hyprland

log "Installing remaining Multi-Rice dependencies"
paru -S --needed \\
''' + '\n'.join(wrapped)

s = s[:m.start()] + new + s[m.end():]
p.write_text(s)
PY

bash -n "$TMP"
exec bash "$TMP" "$@"
