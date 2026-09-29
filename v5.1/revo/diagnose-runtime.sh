#!/usr/bin/env bash
set +e

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
LOG_DIR="$STATE_HOME/revo-v5.1"

echo "=== REVO V5.1 RUNTIME DIAGNOSTIC ==="
date
echo

echo "=== STATE ==="
cat "$CONFIG_HOME/desktop-profile/active" 2>/dev/null || true
cat "$CONFIG_HOME/desktop-profile/revo-shell" 2>/dev/null || true
"$HOME/.local/bin/multi-rice-control" status 2>&1 || true
echo

echo "=== PROCESSES ==="
pgrep -af 'quickshell|(^|/)qs |ryoku-shell|awww' || true
echo

echo "=== WAYLAND ENV ==="
printf 'WAYLAND_DISPLAY=%s\n' "${WAYLAND_DISPLAY:-}"
printf 'HYPRLAND_INSTANCE_SIGNATURE=%s\n' "${HYPRLAND_INSTANCE_SIGNATURE:-}"
printf 'XDG_RUNTIME_DIR=%s\n' "${XDG_RUNTIME_DIR:-}"
echo

echo "=== HYPRLIQUID ==="
readlink -f "$HOME/.local/lib/hyprliquid.so" 2>/dev/null || true
hyprctl plugin list 2>&1 || true
echo

echo "=== WALLPAPER ==="
find "$HOME/Pictures/Wallpapers/Revo" -maxdepth 1 -type f 2>/dev/null | head -n 5
if command -v awww >/dev/null 2>&1; then
    awww query 2>&1 || true
elif command -v swww >/dev/null 2>&1; then
    swww query 2>&1 || true
else
    echo "no supported wallpaper engine found"
fi
echo

echo "=== LAUNCHER LOG ==="
tail -n 100 "$LOG_DIR/launcher.log" 2>/dev/null || true
echo

echo "=== SHELL LOGS ==="
for f in "$LOG_DIR"/*.log; do
    [[ -f "$f" ]] || continue
    echo "--- $f ---"
    tail -n 80 "$f"
done
echo

echo "=== MAC LEGACY LOG ==="
tail -n 100 "$HOME/macos.log" 2>/dev/null || true
echo

echo "=== RECENT COREDUMPS ==="
coredumpctl --no-pager --reverse 2>/dev/null | head -n 15 || true
