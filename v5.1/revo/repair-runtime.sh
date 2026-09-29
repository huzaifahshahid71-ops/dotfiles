#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
PROFILE_ROOT="$HOME/.local/share/desktop-profiles"
REVO_RUNTIME="$HOME/.local/share/revo-shell"
QS_ROOT="$CONFIG_HOME/quickshell"

log() { printf '==> %s\n' "$*"; }
ok()  { printf '✓ %s\n' "$*"; }

log "Installing current v5.1 runtime helpers"
install -Dm755 "$REPO_ROOT/dual-rice/bin/multi-rice-control" "$HOME/.local/bin/multi-rice-control"
install -Dm755 "$REPO_ROOT/dual-rice/bin/revo-shell-launch" "$HOME/.local/bin/revo-shell-launch"
install -Dm755 "$REPO_ROOT/dual-rice/bin/multi-rice-switcher" "$HOME/.local/bin/multi-rice-switcher"
install -Dm644 "$REPO_ROOT/dual-rice/lib/profile-metadata.sh" "$HOME/.local/share/desktop-switcher/profile-metadata.sh"

mkdir -p "$QS_ROOT/multi-rice-switcher"
install -Dm644     "$REPO_ROOT/dual-rice/quickshell/multi-rice-switcher/shell.qml"     "$QS_ROOT/multi-rice-switcher/shell.qml"

wall_dir="$PROFILE_ROOT/revo/hypr/scripts/wallpapers"
if [[ -d "$wall_dir" ]]; then
    log "Repairing Revo wallpaper source"
    cat > "$wall_dir/random.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

WALLPAPERS_DIR="${REVO_WALLPAPERS_DIR:-$HOME/Pictures/Wallpapers/Revo}"
[[ -d "$WALLPAPERS_DIR" ]] || exit 0

find "$WALLPAPERS_DIR" -type f \
    \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) \
    -print 2>/dev/null | shuf -n 1
EOF
    chmod +x "$wall_dir/random.sh"

    cat > "$wall_dir/set-random.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

scripts="$HOME/.config/hypr/scripts/wallpapers"
wall="$("$scripts/random.sh")"
[[ -n "$wall" && -f "$wall" ]] || exit 0
"$scripts/set.sh" "$wall"
EOF
    chmod +x "$wall_dir/set-random.sh"
fi

if [[ -d "$REVO_RUNTIME/wallpapers" ]]; then
    mkdir -p "$HOME/Pictures/Wallpapers/Revo"
    rsync -a "$REVO_RUNTIME/wallpapers/" "$HOME/Pictures/Wallpapers/Revo/"
fi

autostart="$PROFILE_ROOT/revo/hypr/configs/autostart.lua"
if [[ -f "$autostart" ]]; then
    sed -i 's/h\.exec_once(/hl.exec_cmd(/g' "$autostart"
fi

ok "Runtime repair applied"
printf 'backend: %s\n' "$HOME/.local/bin/multi-rice-control"
printf 'launcher: %s\n' "$HOME/.local/bin/revo-shell-launch"
printf 'wallpapers: %s\n' "$HOME/Pictures/Wallpapers/Revo"

if [[ -x "$wall_dir/set-random.sh" ]] && command -v awww >/dev/null 2>&1; then
    "$wall_dir/set-random.sh" >/dev/null 2>&1 || true
fi
