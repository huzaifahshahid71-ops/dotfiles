#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$REPO_ROOT/dual-rice"
PROFILE_ROOT="$HOME/.local/share/desktop-profiles"
BACKUP_ROOT="$HOME/.local/share/desktop-profile-backups"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$BACKUP_ROOT/dual-rice-restore-$STAMP"
FRIEREN_SRC="$REPO_ROOT/machine/sddm/themes/sddm-frieren-theme/Backgrounds/frieren.jpg"
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
FRIEREN_DST="$WALLPAPER_DIR/frieren.jpg"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARNING:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

is_arch_family() {
    [[ -r /etc/os-release ]] || return 1
    . /etc/os-release
    [[ "${ID:-}" == "arch" || "${ID:-}" == "cachyos" || "${ID_LIKE:-}" == *arch* ]]
}

ensure_paru() {
    if command -v paru >/dev/null 2>&1; then
        return
    fi
    log "Installing paru"
    sudo pacman -S --needed base-devel git
    local tmp
    tmp="$(mktemp -d)"
    git clone https://aur.archlinux.org/paru.git "$tmp/paru"
    (
        cd "$tmp/paru"
        makepkg -si --needed --noconfirm
    )
    rm -rf "$tmp"
}

backup_path() {
    local path="$1" name="$2"
    [[ -e "$path" || -L "$path" ]] || return 0
    mkdir -p "$BACKUP"
    cp -aL "$path" "$BACKUP/$name" 2>/dev/null || cp -a "$path" "$BACKUP/$name"
}

clone_pinned() {
    local url="$1" dest="$2" commit_file="$3"
    local commit=""
    [[ -f "$commit_file" ]] && commit="$(tr -d '[:space:]' < "$commit_file")"

    rm -rf "$dest"
    git clone "$url" "$dest"
    if [[ -n "$commit" ]]; then
        git -C "$dest" checkout --detach "$commit"
    fi
}

rewrite_home_paths_json() {
    local file="$1" tmp
    [[ -f "$file" ]] || return 0
    jq empty "$file" >/dev/null 2>&1 || return 0
    tmp="$(mktemp)"
    jq --arg home "$HOME" '
      walk(if type == "string"
           then sub("^/home/[^/]+/"; ($home + "/"))
           else . end)
    ' "$file" > "$tmp"
    mv "$tmp" "$file"
}

is_arch_family || die "This restore currently supports Arch/CachyOS only"
[[ -d "$SRC/profiles/caelestia/hypr" ]] || die "Missing backed-up Caelestia profile. Run backup-dual-rice.sh first."
[[ -d "$SRC/profiles/end4/hypr" ]] || die "Missing backed-up end4 profile. Run backup-dual-rice.sh first."
[[ -f "$SRC/profiles/caelestia/hypr/hyprland.lua" ]] || die "Backed-up Caelestia hyprland.lua missing"
[[ -f "$SRC/profiles/end4/hypr/hyprland.lua" ]] || die "Backed-up end4 hyprland.lua missing"

# Never use pacman -Sy by itself on Arch-family systems.
log "Updating the system before dual-rice restore"
sudo pacman -Syu

ensure_paru

log "Installing dual-rice dependencies"
paru -S --needed \
    git \
    rsync \
    jq \
    fish \
    stow \
    foot \
    kitty \
    mpv \
    mpv-mpris \
    fuzzel \
    hyprland \
    hypridle \
    hyprlock \
    hyprsunset \
    wl-clipboard \
    cliphist \
    brightnessctl \
    playerctl \
    cava \
    matugen-bin \
    imagemagick \
    upower \
    hyprpicker \
    slurp \
    swappy \
    wf-recorder \
    tesseract \
    tesseract-data-eng \
    ydotool \
    gnome-keyring \
    easyeffects \
    libqalculate \
    qt6-positioning \
    ttf-readex-pro \
    ttf-jetbrains-mono-nerd \
    dim-caelestia-shell-git \
    caelestia-cli \
    quickshell-git

log "Creating safety backup before profile restore"
mkdir -p "$BACKUP"
backup_path "$HOME/.config/hypr" "hypr"
backup_path "$HOME/.config/caelestia" "caelestia"
backup_path "$HOME/.config/illogical-impulse" "illogical-impulse"
backup_path "$HOME/.config/desktop-switcher" "desktop-switcher"
backup_path "$PROFILE_ROOT" "desktop-profiles"
backup_path "$HOME/.local/bin/desktop-switch" "desktop-switch"
backup_path "$HOME/.local/bin/recover-caelestia" "recover-caelestia"
backup_path "$FRIEREN_DST" "frieren-wallpaper.jpg"

log "Installing Frieren desktop wallpaper"
[[ -f "$FRIEREN_SRC" ]] || die "Frieren wallpaper asset is missing: $FRIEREN_SRC"
mkdir -p "$WALLPAPER_DIR"
cp -a "$FRIEREN_SRC" "$FRIEREN_DST"

log "Restoring both Hyprland profiles"
mkdir -p "$PROFILE_ROOT/caelestia/hypr" "$PROFILE_ROOT/end4/hypr"
rsync -a --delete "$SRC/profiles/caelestia/hypr/" "$PROFILE_ROOT/caelestia/hypr/"
rsync -a --delete "$SRC/profiles/end4/hypr/" "$PROFILE_ROOT/end4/hypr/"

if [[ -d "$SRC/caelestia" ]]; then
    log "Restoring Caelestia user configuration"
    mkdir -p "$HOME/.config/caelestia"
    rsync -a --delete "$SRC/caelestia/" "$HOME/.config/caelestia/"
    rewrite_home_paths_json "$HOME/.config/caelestia/shell.json"
    if [[ -f "$HOME/.config/caelestia/shell.json" ]]; then
        tmp="$(mktemp)"
        jq --arg dir "$WALLPAPER_DIR" '.paths = (.paths // {}) | .paths.wallpaperDir = $dir' \
            "$HOME/.config/caelestia/shell.json" > "$tmp"
        mv "$tmp" "$HOME/.config/caelestia/shell.json"
    fi
fi

if [[ -f "$SRC/end4/config.json" ]]; then
    log "Restoring end4-pC widget and bar layout"
    mkdir -p "$HOME/.config/illogical-impulse"
    cp -a "$SRC/end4/config.json" "$HOME/.config/illogical-impulse/config.json"
    rewrite_home_paths_json "$HOME/.config/illogical-impulse/config.json"
    tmp="$(mktemp)"
    jq --arg wallpaper "$FRIEREN_DST" '
        .background = (.background // {})
        | .background.wallpaperPath = $wallpaper
        | .background.thumbnailPath = ""
    ' "$HOME/.config/illogical-impulse/config.json" > "$tmp"
    mv "$tmp" "$HOME/.config/illogical-impulse/config.json"
else
    warn "No backed-up end4 config.json yet; end4 will use its defaults until a fresh dual-rice backup is pushed."
fi

if [[ -d "$SRC/desktop-switcher" ]]; then
    mkdir -p "$HOME/.config/desktop-switcher"
    rsync -a --delete "$SRC/desktop-switcher/" "$HOME/.config/desktop-switcher/"
fi

mkdir -p "$HOME/.local/bin"
for bin in desktop-switch recover-caelestia; do
    if [[ -f "$SRC/bin/$bin" ]]; then
        install -m 0755 "$SRC/bin/$bin" "$HOME/.local/bin/$bin"
    fi
done

log "Restoring end4-pC and illogical-impulse Quickshell sources"
mkdir -p "$HOME/.config/quickshell" "$HOME/.local/src"
clone_pinned \
    https://github.com/end-4/dots-hyprland.git \
    "$HOME/.local/src/end4-dots" \
    "$SRC/versions/end4-dots.commit"

rm -rf "$HOME/.config/quickshell/ii"
if [[ -d "$HOME/.local/src/end4-dots/dots/.config/quickshell/ii" ]]; then
    cp -a "$HOME/.local/src/end4-dots/dots/.config/quickshell/ii" \
        "$HOME/.config/quickshell/ii"
else
    die "Pinned end4 repository does not contain quickshell/ii"
fi

clone_pinned \
    https://github.com/pctrade/end4-pC.git \
    "$HOME/.config/quickshell/end4-pC" \
    "$SRC/versions/end4-pC.commit"

if [[ -f "$SRC/versions/end4-pC-local.patch" ]]; then
    git -C "$HOME/.config/quickshell/end4-pC" apply "$SRC/versions/end4-pC-local.patch" || \
        warn "Could not reapply saved end4-pC local patch"
fi
if [[ -f "$SRC/versions/end4-dots-local.patch" ]]; then
    git -C "$HOME/.local/src/end4-dots" apply "$SRC/versions/end4-dots-local.patch" || \
        warn "Could not reapply saved end4-dots local patch"
fi

if [[ -f "$SRC/systemd/user/background-music.service" ]]; then
    log "Restoring background music service"
    mkdir -p "$HOME/.config/systemd/user"
    cp -a "$SRC/systemd/user/background-music.service" \
        "$HOME/.config/systemd/user/background-music.service"
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

log "Activating the saved profile pointer"
active="caelestia"
if [[ -f "$SRC/state/active" ]]; then
    active="$(tr -d '[:space:]' < "$SRC/state/active")"
fi
case "$active" in
    caelestia|end4) ;;
    *) warn "Unknown saved active profile '$active'; defaulting to Caelestia"; active="caelestia" ;;
esac

target="$PROFILE_ROOT/$active/hypr"
rm -rf "$HOME/.config/hypr"
ln -s "$target" "$HOME/.config/hypr"
mkdir -p "$HOME/.config/desktop-profile"
printf '%s\n' "$active" > "$HOME/.config/desktop-profile/active"

systemctl --user daemon-reload 2>/dev/null || true
if [[ -f "$HOME/.config/systemd/user/background-music.service" ]]; then
    systemctl --user enable background-music.service 2>/dev/null || true
fi

ok "Dual-rice restore complete"
printf '\nInstalled:\n'
printf '  ✦ Caelestia profile\n'
printf '  ◈ end4-pC profile + saved local patches\n'
printf '  ⇄ SUPER + SHIFT + D desktop switcher\n'
printf '  🖼 Frieren wallpaper: %s\n' "$FRIEREN_DST"
printf '\nActive profile: %s\n' "$active"
printf 'Hyprland target: %s\n' "$(readlink -f "$HOME/.config/hypr")"
printf 'Safety backup: %s\n' "$BACKUP"
printf '\nLog out and back into Hyprland to start the restored profile.\n'
printf 'Emergency recovery: ~/.local/bin/recover-caelestia\n'
