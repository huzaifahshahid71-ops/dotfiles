#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${OFFLINE_REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SRC="$REPO_ROOT/dual-rice"
SOURCE_ROOT="${OFFLINE_SOURCE_ROOT:?OFFLINE_SOURCE_ROOT must point to bundled source snapshots}"
PROFILE_ROOT="$HOME/.local/share/desktop-profiles"
BACKUP_ROOT="$HOME/.local/share/desktop-profile-backups"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$BACKUP_ROOT/multi-rice-offline-$STAMP"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARNING:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

is_arch_family() {
    [[ -r /etc/os-release ]] || return 1
    . /etc/os-release
    [[ "${ID:-}" == "arch" || "${ID:-}" == "cachyos" || "${ID_LIKE:-}" == *arch* ]]
}

backup_path() {
    local path="$1" name="$2"
    [[ -e "$path" || -L "$path" ]] || return 0
    mkdir -p "$BACKUP"
    cp -aL "$path" "$BACKUP/$name" 2>/dev/null || cp -a "$path" "$BACKUP/$name"
}

rewrite_home_paths_json() {
    local file="$1" tmp
    [[ -f "$file" ]] || return 0
    jq empty "$file" >/dev/null 2>&1 || return 0
    tmp="$(mktemp)"
    jq --arg home "$HOME" 'walk(if type == "string" then sub("^/home/[^/]+/"; ($home + "/")) else . end)' "$file" > "$tmp"
    mv "$tmp" "$file"
}

copy_tree() {
    local src="$1" dst="$2"
    [[ -d "$src" ]] || die "Bundled source is missing: $src"
    rm -rf "$dst"
    mkdir -p "$(dirname "$dst")"
    cp -a "$src" "$dst"
}

install_ambxst_launcher() {
    mkdir -p "$HOME/.local/bin"
    cat > "$HOME/.local/bin/ambxst" <<'EOF'
#!/usr/bin/env bash
export PATH="$HOME/.local/bin:$PATH"
export QML2_IMPORT_PATH="$HOME/.local/lib/qml:${QML2_IMPORT_PATH:-}"
export QML_IMPORT_PATH="$QML2_IMPORT_PATH"
exec "$HOME/.local/src/ambxst/cli.sh" "$@"
EOF
    chmod +x "$HOME/.local/bin/ambxst"

    sudo tee /usr/local/bin/ambxst >/dev/null <<'EOF'
#!/usr/bin/env bash
exec "$HOME/.local/bin/ambxst" "$@"
EOF
    sudo chmod +x /usr/local/bin/ambxst
    command -v fish >/dev/null 2>&1 && fish -c 'fish_add_path ~/.local/bin' >/dev/null 2>&1 || true
}

is_arch_family || die "Offline restore supports Arch/CachyOS-family systems only"
[[ "$(uname -m)" == "x86_64" ]] || die "This offline snapshot targets x86_64"
for profile in caelestia end4 ambxst dms; do
    [[ -f "$SRC/profiles/$profile/hypr/hyprland.lua" ]] || die "Missing backed-up $profile profile"
done
for source in end4-dots end4-pC ambxst; do
    [[ -d "$SOURCE_ROOT/$source" ]] || die "Missing bundled source tree: $source"
done
[[ -x "$SOURCE_ROOT/axctl" ]] || die "Missing bundled axctl binary"

log "Creating safety backup"
mkdir -p "$BACKUP"
backup_path "$HOME/.config/hypr" hypr
backup_path "$HOME/.config/caelestia" caelestia
backup_path "$HOME/.config/illogical-impulse" illogical-impulse
backup_path "$HOME/.config/ambxst" ambxst-config
backup_path "$HOME/.config/DankMaterialShell" dms-config
backup_path "$HOME/.local/share/ambxst" ambxst-share
backup_path "$HOME/.local/src/ambxst" ambxst-source
backup_path "$HOME/.cache/ambxst/wallpapers.json" ambxst-wallpapers.json
backup_path "$HOME/.config/desktop-switcher" desktop-switcher
backup_path "$PROFILE_ROOT" desktop-profiles
backup_path "$HOME/.local/bin/desktop-switch" desktop-switch
backup_path "$HOME/.local/bin/recover-caelestia" recover-caelestia

log "Restoring Caelestia, end4-pC, Ambxst and DMS profiles"
for profile in caelestia end4 ambxst dms; do
    mkdir -p "$PROFILE_ROOT/$profile/hypr"
    rsync -a --delete "$SRC/profiles/$profile/hypr/" "$PROFILE_ROOT/$profile/hypr/"
done

if [[ -d "$SRC/caelestia" ]]; then
    mkdir -p "$HOME/.config/caelestia"
    rsync -a --delete "$SRC/caelestia/" "$HOME/.config/caelestia/"
    rewrite_home_paths_json "$HOME/.config/caelestia/shell.json"
fi

if [[ -f "$SRC/end4/config.json" ]]; then
    mkdir -p "$HOME/.config/illogical-impulse"
    cp -a "$SRC/end4/config.json" "$HOME/.config/illogical-impulse/config.json"
    rewrite_home_paths_json "$HOME/.config/illogical-impulse/config.json"
    tmp="$(mktemp)"
    jq '.overview = (.overview // {}) | .overview.enable = false' "$HOME/.config/illogical-impulse/config.json" > "$tmp" && mv "$tmp" "$HOME/.config/illogical-impulse/config.json"
fi

if [[ -d "$SRC/ambxst/config" ]]; then
    mkdir -p "$HOME/.config/ambxst"
    rsync -a --delete "$SRC/ambxst/config/" "$HOME/.config/ambxst/"
fi
if [[ -f "$SRC/ambxst/wallpapers.json" ]]; then
    mkdir -p "$HOME/.cache/ambxst"
    cp -a "$SRC/ambxst/wallpapers.json" "$HOME/.cache/ambxst/wallpapers.json"
    rewrite_home_paths_json "$HOME/.cache/ambxst/wallpapers.json"
fi

if [[ -d "$SRC/dms/config" ]] && find "$SRC/dms/config" -mindepth 1 -print -quit | grep -q .; then
    mkdir -p "$HOME/.config/DankMaterialShell"
    rsync -a --delete "$SRC/dms/config/" "$HOME/.config/DankMaterialShell/"
    while IFS= read -r json; do
        rewrite_home_paths_json "$json"
    done < <(find "$HOME/.config/DankMaterialShell" -type f -name '*.json' -print)
fi

if [[ -d "$SRC/desktop-switcher" ]]; then
    mkdir -p "$HOME/.config/desktop-switcher"
    rsync -a --delete "$SRC/desktop-switcher/" "$HOME/.config/desktop-switcher/"
fi

mkdir -p "$HOME/.local/bin"
for bin in desktop-switch recover-caelestia; do
    [[ -f "$SRC/bin/$bin" ]] && install -m 0755 "$SRC/bin/$bin" "$HOME/.local/bin/$bin"
done

log "Installing bundled end4 and Ambxst source snapshots"
copy_tree "$SOURCE_ROOT/end4-dots" "$HOME/.local/src/end4-dots"
mkdir -p "$HOME/.config/quickshell"
rm -rf "$HOME/.config/quickshell/ii"
[[ -d "$HOME/.local/src/end4-dots/dots/.config/quickshell/ii" ]] || die "Bundled end4-dots snapshot has no quickshell/ii"
cp -a "$HOME/.local/src/end4-dots/dots/.config/quickshell/ii" "$HOME/.config/quickshell/ii"
copy_tree "$SOURCE_ROOT/end4-pC" "$HOME/.config/quickshell/end4-pC"
copy_tree "$SOURCE_ROOT/ambxst" "$HOME/.local/src/ambxst"
chmod +x "$HOME/.local/src/ambxst/cli.sh"

sudo install -m 0755 "$SOURCE_ROOT/axctl" /usr/local/bin/axctl
install_ambxst_launcher

mkdir -p "$HOME/.local/share/ambxst"
rm -f "$HOME/.local/share/ambxst/hyprland.lua" "$HOME/.local/share/ambxst/hyprland.conf" "$HOME/.local/share/ambxst/axctl.toml"
"$HOME/.local/bin/ambxst" version >/dev/null 2>&1 || true

# Multi-Rice launches DMS only from the DMS compositor profile.
systemctl --user disable --now dms.service >/dev/null 2>&1 || true

if [[ -f "$SRC/systemd/user/background-music.service" ]]; then
    mkdir -p "$HOME/.config/systemd/user"
    cp -a "$SRC/systemd/user/background-music.service" "$HOME/.config/systemd/user/background-music.service"
    sed -Ei "s#/home/[^/]+/#$HOME/#g" "$HOME/.config/systemd/user/background-music.service" || true
fi
if compgen -G "$SRC/music/*.m3u8" >/dev/null; then
    mkdir -p "$HOME/Music"
    for playlist in "$SRC"/music/*.m3u8; do
        dest="$HOME/Music/$(basename "$playlist")"
        cp -a "$playlist" "$dest"
        sed -Ei "s#/home/[^/]+/#$HOME/#g" "$dest" || true
    done
fi

active="caelestia"
[[ -f "$SRC/state/active" ]] && active="$(tr -d '[:space:]' < "$SRC/state/active")"
case "$active" in caelestia|end4|ambxst|dms) ;; *) active=caelestia ;; esac
rm -rf "$HOME/.config/hypr"
ln -s "$PROFILE_ROOT/$active/hypr" "$HOME/.config/hypr"
mkdir -p "$HOME/.config/desktop-profile"
printf '%s\n' "$active" > "$HOME/.config/desktop-profile/active"

systemctl --user daemon-reload 2>/dev/null || true
[[ -f "$HOME/.config/systemd/user/background-music.service" ]] && systemctl --user enable background-music.service 2>/dev/null || true

ok "Offline Multi-Rice restore complete"
printf '\nInstalled from the AppImage payload with no network access:\n'
printf '  ✦ Caelestia\n  ◈ end4-pC\n  ◆ Ambxst + axctl\n  ● DankMaterialShell\n  ⇄ SUPER + SHIFT + D dynamic switcher\n'
printf '\nSafety backup: %s\n' "$BACKUP"