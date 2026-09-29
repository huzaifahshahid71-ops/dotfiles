#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REVO_URL="${REVO_URL:-https://github.com/vzbc/revo-shell.git}"
REVO_REF="${REVO_REF:-a15d62c87aa992ab8e5d366575bb4074eada7d98}"
REVO_ROOT="$HOME/.local/share/revo-shell"
PROFILE_ROOT="$HOME/.local/share/desktop-profiles"
QS_ROOT="$HOME/.config/quickshell"
STATE_DIR="$HOME/.config/desktop-profile"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$HOME/.local/share/desktop-profile-backups/revo-v5.1-$STAMP"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARNING:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

backup_path() {
    local src="$1" name="$2"
    [[ -e "$src" || -L "$src" ]] || return 0
    mkdir -p "$BACKUP"
    cp -aL "$src" "$BACKUP/$name" 2>/dev/null || cp -a "$src" "$BACKUP/$name"
}

rewrite_home_paths() {
    local root="$1"
    local esc
    esc="$(printf '%s' "$HOME" | sed 's/[\/&]/\\&/g')"
    while IFS= read -r -d '' file; do
        sed -i "s#/home/revo#$esc#g" "$file" 2>/dev/null || true
    done < <(grep -rIlZ '/home/revo' "$root" 2>/dev/null || true)
}

install_dependencies_arch() {
    [[ "${INSTALL_REVO_DEPS:-1}" == "1" ]] || return 0
    command -v pacman >/dev/null 2>&1 || {
        warn "Non-Arch system: skipping automatic Revo dependency install"
        return 0
    }

    log "Installing Revo dependency union"
    sudo pacman -S --needed --noconfirm \
        hyprland xdg-desktop-portal-hyprland hypridle hyprlock hyprpolkitagent hyprsunset polkit \
        qt6-base qt6-declarative qt6-5compat qt6-multimedia qt6-shadertools qt6-wayland qt6-svg qt6-tools qt6-imageformats qt6-location qt6-positioning qt6-lottie \
        git curl wget jq python python-pip libnotify xdg-utils procps-ng psmisc util-linux coreutils findutils fd gawk sed grep zenity \
        pipewire pipewire-pulse wireplumber libpulse playerctl cava mpv-mpris networkmanager bluez bluez-utils brightnessctl upower power-profiles-daemon lm_sensors rfkill ddcutil \
        grim slurp wf-recorder hyprshot hyprpicker ffmpeg imagemagick wl-clipboard cliphist wtype swappy matugen swww hyprpaper swaybg mpvpaper python-pywal swaync swayosd easyeffects \
        kitty nautilus thunar rofi-wayland wofi fastfetch starship fish gnome-calculator papirus-icon-theme adwaita-cursors xdg-desktop-portal-gtk \
        ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols-common noto-fonts noto-fonts-emoji base-devel cmake ninja pkgconf clang gcc || true

    local aur=""
    command -v paru >/dev/null 2>&1 && aur="paru"
    command -v yay  >/dev/null 2>&1 && aur="${aur:-yay}"

    if [[ -n "$aur" ]]; then
        "$aur" -S --needed --noconfirm \
            quickshell-git awww ttf-material-symbols-variable-git ttf-comicshannsmono-nerd ttf-meslo-nerd kde-material-you-colors hyprliquid || true
    else
        warn "No paru/yay found; install quickshell-git and hyprliquid manually if missing"
    fi

    mkdir -p "$HOME/.local/lib"
    if [[ -f /usr/lib/libhyprliquid.so ]]; then
        ln -sfn /usr/lib/libhyprliquid.so "$HOME/.local/lib/hyprliquid.so"
    fi
}

patch_revo_autostart() {
    local conf tmp lua

    for conf in \
        "$PROFILE_ROOT/revo/hypr/config/autostart.conf" \
        "$PROFILE_ROOT/revo/hypr/configs/autostart.conf"; do
        [[ -f "$conf" ]] || continue
        tmp="$(mktemp)"
        awk '
            /# HUZAIFAH_REVO_V51_SHELL/ { next }
            /^[[:space:]]*exec-once/ && /revo-shell-launch/ { next }
            /^[[:space:]]*exec-once/ && /quickshell/ && (/Main\.qml/ || /TopBar\.qml/ || /Floating\.qml/) {
                print "# v5.1 disabled stock shell: " $0
                next
            }
            { print }
        ' "$conf" > "$tmp"
        printf '\n# HUZAIFAH_REVO_V51_SHELL\nexec-once = ~/.local/bin/revo-shell-launch\n' >> "$tmp"
        mv "$tmp" "$conf"
    done

    lua="$PROFILE_ROOT/revo/hypr/configs/autostart.lua"
    if [[ -f "$lua" ]]; then
        python - "$lua" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
marker = "-- HUZAIFAH_REVO_V51_SHELL"

if marker not in text:
    for command in (
        '    hl.exec_cmd("quickshell -p ~/.config/hypr/scripts/quickshell/Main.qml")',
        '    hl.exec_cmd("quickshell -p ~/.config/hypr/scripts/quickshell/TopBar.qml")',
        '    hl.exec_cmd("quickshell -p ~/.config/hypr/scripts/quickshell/Floating.qml")',
    ):
        text = text.replace(command, "    -- v5.1 disabled stock shell: " + command.strip())

    needle = 'hl.on("hyprland.start", function()\n'
    if needle not in text:
        raise SystemExit("Revo autostart.lua layout changed; refusing unsafe patch")

    text = text.replace(
        needle,
        needle
        + "    " + marker + "\n"
        + '    hl.exec_cmd(os.getenv("HOME") .. "/.local/bin/revo-shell-launch")\n',
        1,
    )

path.write_text(text, encoding="utf-8")
PY
    fi
}

patch_revo_lua_safety() {
    local lua="$PROFILE_ROOT/revo/hypr/hyprland.lua"
    [[ -f "$lua" ]] || return 0

    python - "$lua" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
marker = "-- HUZAIFAH_REVO_V51_BRAIN_KEYS_GUARD"

if marker not in text:
    pattern = r'dofile\(".*?/\.config/Brain_Shell/Brain_ShellKeybinds\.lua"\)'
    replacement = '''-- HUZAIFAH_REVO_V51_BRAIN_KEYS_GUARD
local brain_keys = os.getenv("HOME") .. "/.config/Brain_Shell/Brain_ShellKeybinds.lua"
local brain_keys_file = io.open(brain_keys, "r")
if brain_keys_file then
    brain_keys_file:close()
    pcall(dofile, brain_keys)
end'''
    text, count = re.subn(pattern, replacement, text, count=1)
    if count == 0:
        raise SystemExit("Revo Brain_Shell keybind include changed; refusing unsafe patch")

path.write_text(text, encoding="utf-8")
PY
}

patch_revo_keybinds() {
    local conf

    for conf in \
        "$PROFILE_ROOT/revo/hypr/config/keybindings.conf" \
        "$PROFILE_ROOT/revo/hypr/configs/keybinds.conf"; do
        [[ -f "$conf" ]] || continue
        grep -q 'HUZAIFAH_REVO_V51_SWITCHERS' "$conf" && continue
        cat >> "$conf" <<'EOF'

# HUZAIFAH_REVO_V51_SWITCHERS
bind = SUPER SHIFT, D, exec, qs -c multi-rice-switcher
bind = SUPER SHIFT, Q, exec, foot -e qs-list
EOF
    done

    conf="$PROFILE_ROOT/revo/hypr/configs/keybinds.lua"
    if [[ -f "$conf" ]] && ! grep -q 'HUZAIFAH_REVO_V51_SWITCHERS' "$conf"; then
        cat >> "$conf" <<'EOF'

-- HUZAIFAH_REVO_V51_SWITCHERS
hl.bind("SUPER + SHIFT + D", hl.dsp.exec_cmd("qs -c multi-rice-switcher"))
hl.bind("SUPER + SHIFT + Q", hl.dsp.exec_cmd("foot -e qs-list"))
EOF
    fi
}

patch_revo_dots_browser() {
    local dots="$PROFILE_ROOT/revo/hypr/scripts/quickshell/DotsBrowser.qml"
    [[ -f "$dots" ]] || {
        warn "Revo DotsBrowser.qml not found; Super+B integration skipped"
        return 0
    }

    python "$REPO_ROOT/v5.1/revo/patch-revo-dots-browser.py" "$dots"
    ok "Revo DotsBrowser now uses the unified 31-profile backend"
}

install_revo_switch_helpers() {
    local toggle="$PROFILE_ROOT/revo/hypr/scripts/toggle_qs_dots.sh"

    install -Dm755 \
        "$REPO_ROOT/v5.1/revo/toggle_qs_dots-unified.sh" \
        "$toggle"

    install -Dm755 \
        "$REPO_ROOT/v5.1/revo/qs-list" \
        "$QS_ROOT/qs-list"
}

build_native_shells() {
    local qs="$QS_ROOT"
    if [[ -f "$qs/shell/CMakeLists.txt" ]]; then
        log "Building Revo Caelestia native shell"
        cmake -S "$qs/shell" -B "$qs/shell/build" -G Ninja -DCMAKE_BUILD_TYPE=Release -DVERSION=1.0.0 -DGIT_REVISION=v5.1 -DENABLE_MODULES='extras;plugin;shell' || true
        cmake --build "$qs/shell/build" -j"$(nproc)" || true
        sudo cmake --install "$qs/shell/build" || true
    fi

    if [[ -f "$qs/imported-1789667132/CMakeLists.txt" ]]; then
        log "Building Revo Clavis native shell"
        cmake -S "$qs/imported-1789667132" -B "$qs/imported-1789667132/build" -G Ninja -DCMAKE_BUILD_TYPE=Release || true
        cmake --build "$qs/imported-1789667132/build" -j"$(nproc)" || true
        sudo cmake --install "$qs/imported-1789667132/build" || true
    fi
}

command -v git >/dev/null 2>&1 || die "git is required"
command -v rsync >/dev/null 2>&1 || die "rsync is required"

install_dependencies_arch

log "Backing up current switch/runtime integration"
backup_path "$REVO_ROOT" "revo-shell-runtime"
backup_path "$PROFILE_ROOT/revo" "revo-profile"
backup_path "$HOME/.local/bin/multi-rice-control" "multi-rice-control"
backup_path "$HOME/.local/bin/revo-shell-launch" "revo-shell-launch"
backup_path "$HOME/.local/bin/qs-list" "qs-list"
backup_path "$HOME/.local/share/desktop-switcher/profile-metadata.sh" "profile-metadata.sh"

log "Cloning complete Revo upstream snapshot"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
git clone "$REVO_URL" "$tmp/revo-shell"
git -C "$tmp/revo-shell" checkout --detach "$REVO_REF"
rm -rf "$REVO_ROOT"
mkdir -p "$(dirname "$REVO_ROOT")"
mv "$tmp/revo-shell" "$REVO_ROOT"
ok "Revo runtime pinned at $REVO_REF"

log "Installing Revo Hyprland as a Multi-Rice profile"
rm -rf "$PROFILE_ROOT/revo"
mkdir -p "$PROFILE_ROOT/revo/hypr"
rsync -a --exclude '.git' "$REVO_ROOT/hypr/" "$PROFILE_ROOT/revo/hypr/"
rewrite_home_paths "$PROFILE_ROOT/revo/hypr"
patch_revo_autostart
patch_revo_lua_safety
patch_revo_keybinds
patch_revo_dots_browser

log "Deploying all Revo Quickshell configs"
mkdir -p "$QS_ROOT"
rsync -a --exclude '.git' "$REVO_ROOT/quickshell/" "$QS_ROOT/"
rewrite_home_paths "$QS_ROOT"

log "Restoring Huzaifah switcher after Revo overlay"
rm -rf "$QS_ROOT/multi-rice-switcher"
rsync -a "$REPO_ROOT/dual-rice/quickshell/multi-rice-switcher/" "$QS_ROOT/multi-rice-switcher/"

log "Installing unified switch backend and both switcher entry points"
install -Dm755 "$REPO_ROOT/dual-rice/bin/multi-rice-control" "$HOME/.local/bin/multi-rice-control"
install -Dm755 "$REPO_ROOT/dual-rice/bin/revo-shell-launch" "$HOME/.local/bin/revo-shell-launch"
install -Dm755 "$REPO_ROOT/v5.1/revo/qs-list" "$HOME/.local/bin/qs-list"
install -Dm644 "$REPO_ROOT/dual-rice/lib/profile-metadata.sh" "$HOME/.local/share/desktop-switcher/profile-metadata.sh"
install_revo_switch_helpers

mkdir -p "$STATE_DIR"
if [[ ! -s "$STATE_DIR/revo-shell" ]]; then
    printf 'lucid\n' > "$STATE_DIR/revo-shell"
fi

mkdir -p "$HOME/Pictures/Wallpapers/Revo"
rsync -a "$REVO_ROOT/wallpapers/" "$HOME/Pictures/Wallpapers/Revo/" 2>/dev/null || true

python -m pip install --user --upgrade materialyoucolor pillow numpy click loguru tqdm icalendar recurring-ical-events evdev pywal requests distro psutil PySide6 || true
build_native_shells

ok "Revo v5.1 integration installed"
printf '\n'
printf 'Revo shells: 21\n'
printf 'Huzaifah profiles: 10\n'
printf 'Unified total: 31\n'
printf 'Revo GUI:     SUPER+B (DotsBrowser)\n'
printf 'Huzaifah GUI: SUPER+SHIFT+D or qs -c multi-rice-switcher\n'
printf 'Unified CLI:  SUPER+SHIFT+Q or qs-list\n'
printf '\nNothing was activated automatically. Choose a profile from either switcher.\n'
