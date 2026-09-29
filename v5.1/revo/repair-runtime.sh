#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
PROFILE_ROOT="$HOME/.local/share/desktop-profiles"
REVO_RUNTIME="$HOME/.local/share/revo-shell"
QS_ROOT="$CONFIG_HOME/quickshell"

log() { printf '==> %s\n' "$*"; }
ok()  { printf '✓ %s\n' "$*"; }

rewrite_revo_symlinks() {
    local root="$1"
    local link target new_target
    local fixed=0

    [[ -d "$root" ]] || return 0

    while IFS= read -r -d '' link; do
        target="$(readlink "$link" 2>/dev/null || true)"
        [[ -n "$target" ]] || continue

        case "$target" in
            /home/revo/*)
                new_target="$HOME/${target#/home/revo/}"
                ln -sfn "$new_target" "$link"
                fixed=$((fixed + 1))
                ;;
        esac
    done < <(find "$root" -type l -print0 2>/dev/null)

    if (( fixed > 0 )); then
        ok "Rewrote $fixed absolute Revo symlink target(s)"
    fi
}

log "Installing current v5.1 runtime helpers"
install -Dm755 "$REPO_ROOT/dual-rice/bin/multi-rice-control" "$HOME/.local/bin/multi-rice-control"
install -Dm755 "$REPO_ROOT/dual-rice/bin/revo-shell-launch" "$HOME/.local/bin/revo-shell-launch"
install -Dm755 "$REPO_ROOT/dual-rice/bin/multi-rice-switcher" "$HOME/.local/bin/multi-rice-switcher"
install -Dm644 "$REPO_ROOT/dual-rice/lib/profile-metadata.sh" "$HOME/.local/share/desktop-switcher/profile-metadata.sh"

mkdir -p "$QS_ROOT/multi-rice-switcher"
install -Dm644     "$REPO_ROOT/dual-rice/quickshell/multi-rice-switcher/shell.qml"     "$QS_ROOT/multi-rice-switcher/shell.qml"

log "Repairing Revo absolute symlinks"
rewrite_revo_symlinks "$QS_ROOT"
rewrite_revo_symlinks "$PROFILE_ROOT/revo/hypr"

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

if [[ -d "$wall_dir" ]]; then
    cat > "$wall_dir/set.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
wall="${1:-}"
[[ -n "$wall" && -f "$wall" ]] || exit 0

if command -v awww >/dev/null 2>&1; then
    pgrep -x awww-daemon >/dev/null 2>&1 || {
        setsid -f awww-daemon >/tmp/revo-awww.log 2>&1
        sleep 0.3
    }
    awww img --transition-type center --transition-step 90 "$wall"
elif command -v swww >/dev/null 2>&1; then
    pgrep -x swww-daemon >/dev/null 2>&1 || {
        setsid -f swww-daemon >/tmp/revo-swww.log 2>&1
        sleep 0.3
    }
    swww img "$wall" --transition-type center
elif command -v hyprctl >/dev/null 2>&1; then
    hyprctl hyprpaper preload "$wall" >/dev/null 2>&1 || true
    hyprctl hyprpaper wallpaper ",$wall" >/dev/null 2>&1 || true
fi

command -v wal >/dev/null 2>&1 && wal -i "$wall" >/dev/null 2>&1 || true
EOF
    chmod +x "$wall_dir/set.sh"
fi

manager="$PROFILE_ROOT/revo/hypr/scripts/qs_manager.sh"
if [[ -f "$manager" ]] && ! grep -q 'HUZAIFAH_REVO_V51_ANY_SHELL_GUARD' "$manager"; then
    log "Stopping Revo base UI from respawning behind selected shells"
    python - "$manager" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
needle = """waffle_active() {
"""
replacement = """waffle_active() {
    # HUZAIFAH_REVO_V51_ANY_SHELL_GUARD
    active_file="$HOME/.config/desktop-profile/active"
    if [[ -f "$active_file" ]] && grep -q '^revo-' "$active_file"; then
        return 0
    fi
"""
if needle in text:
    text = text.replace(needle, replacement, 1)
path.write_text(text, encoding="utf-8")
PY
fi

# Remove any already-running copy of Revo's default base UI. The selected
# rice lives under ~/.config/quickshell and is left untouched.
pkill -9 -f "$CONFIG_HOME/hypr/scripts/quickshell/Main.qml" >/dev/null 2>&1 || true
pkill -9 -f "$CONFIG_HOME/hypr/scripts/quickshell/TopBar.qml" >/dev/null 2>&1 || true
pkill -9 -f "$CONFIG_HOME/hypr/scripts/quickshell/Powermenu.qml" >/dev/null 2>&1 || true

autostart="$PROFILE_ROOT/revo/hypr/configs/autostart.lua"
if [[ -f "$autostart" ]]; then
    sed -i 's/h\.exec_once(/hl.exec_cmd(/g' "$autostart"
fi

log "Preparing special Revo runtimes, VM graphics compatibility and K4 state"
bash "$REPO_ROOT/v5.1/revo/setup-special-shells.sh" --all || true

ok "Runtime repair applied"
printf 'backend: %s\n' "$HOME/.local/bin/multi-rice-control"
printf 'launcher: %s\n' "$HOME/.local/bin/revo-shell-launch"
printf 'wallpapers: %s\n' "$HOME/Pictures/Wallpapers/Revo"

if [[ -x "$wall_dir/set-random.sh" ]] &&
   { command -v awww >/dev/null 2>&1 || command -v swww >/dev/null 2>&1; }; then
    "$wall_dir/set-random.sh" >/dev/null 2>&1 || true
fi
