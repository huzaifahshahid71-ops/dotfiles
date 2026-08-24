#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$REPO_ROOT/dual-rice"
PROFILE_ROOT="$HOME/.local/share/desktop-profiles"
BACKUP_ROOT="$HOME/.local/share/desktop-profile-backups"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$BACKUP_ROOT/triple-rice-restore-$STAMP"

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

install_axctl() {
    local version_file="$SRC/versions/axctl.txt"
    local desired=""
    local current=""
    local arch asset url tmp

    if [[ -f "$version_file" ]]; then
        desired="$(grep -Eo 'v?[0-9]+(\.[0-9]+)+' "$version_file" | head -n1 || true)"
        desired="${desired#v}"
    fi

    if command -v axctl >/dev/null 2>&1; then
        current="$(axctl --version 2>/dev/null | grep -Eo 'v?[0-9]+(\.[0-9]+)+' | head -n1 || true)"
        current="${current#v}"
        if [[ -z "$desired" || "$current" == "$desired" ]]; then
            log "axctl already installed: $(axctl --version 2>/dev/null || true)"
            return
        fi
        log "Replacing axctl $current with pinned $desired"
    else
        log "Installing axctl${desired:+ $desired}"
    fi

    if [[ -z "$desired" ]]; then
        curl -fsSL https://raw.githubusercontent.com/Axenide/axctl/main/install.sh | bash
        command -v axctl >/dev/null 2>&1 || die "axctl installation failed"
        return
    fi

    arch="$(uname -m)"
    case "$arch" in
        x86_64) asset="axctl_linux_amd64" ;;
        i386|i686) asset="axctl_linux_386" ;;
        aarch64) asset="axctl_linux_arm64" ;;
        armv7l|armv7|armv6l) asset="axctl_linux_armv7" ;;
        *) die "Unsupported architecture for axctl: $arch" ;;
    esac

    url="https://github.com/Axenide/axctl/releases/download/v${desired}/${asset}"
    tmp="$(mktemp)"
    curl -fL "$url" -o "$tmp"
    sudo install -m 0755 "$tmp" /usr/local/bin/axctl
    rm -f "$tmp"

    current="$(axctl --version 2>/dev/null | grep -Eo 'v?[0-9]+(\.[0-9]+)+' | head -n1 || true)"
    current="${current#v}"
    [[ "$current" == "$desired" ]] || die "Expected axctl $desired after install, got ${current:-unknown}"
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

    if command -v fish >/dev/null 2>&1; then
        fish -c 'fish_add_path ~/.local/bin' >/dev/null 2>&1 || true
    fi
}

is_arch_family || die "This restore currently supports Arch/CachyOS only"
for profile in caelestia end4 ambxst; do
    [[ -d "$SRC/profiles/$profile/hypr" ]] || die "Missing backed-up $profile profile. Run backup-dual-rice.sh first."
    [[ -f "$SRC/profiles/$profile/hypr/hyprland.lua" ]] || die "Backed-up $profile hyprland.lua missing"
done

log "Updating the system before triple-rice restore"
sudo pacman -Syu

ensure_paru

log "Installing triple-rice dependencies"
paru -S --needed \
    git curl unzip rsync jq fish stow foot kitty mpv mpv-mpris fuzzel \
    hyprland hypridle hyprlock hyprsunset wl-clipboard wl-clip-persist cliphist \
    brightnessctl playerctl cava matugen-bin imagemagick upower hyprpicker grim \
    slurp swappy wf-recorder tesseract tesseract-data-eng ydotool gnome-keyring \
    easyeffects libqalculate qt6-positioning ttf-readex-pro ttf-jetbrains-mono-nerd \
    dim-caelestia-shell-git caelestia-cli quickshell-git tmux network-manager-applet \
    blueman pavucontrol ffmpeg x264 qt6-base qt6-declarative qt6-wayland qt6-svg \
    qt6-tools qt6-imageformats qt6-multimedia qt6-shadertools libwebp libavif \
    syntax-highlighting breeze-icons hicolor-icon-theme ddcutil sqlite wlsunset \
    wtype zbar glib2 python-pipx zenity inetutils power-profiles-daemon python312 \
    libnotify ttf-roboto ttf-roboto-mono ttf-dejavu ttf-liberation noto-fonts \
    noto-fonts-cjk noto-fonts-emoji ttf-nerd-fonts-symbols gpu-screen-recorder \
    mpvpaper gradia ttf-phosphor-icons ttf-league-gothic adw-gtk-theme

log "Creating safety backup before profile restore"
mkdir -p "$BACKUP"
backup_path "$HOME/.config/hypr" "hypr"
backup_path "$HOME/.config/caelestia" "caelestia"
backup_path "$HOME/.config/illogical-impulse" "illogical-impulse"
backup_path "$HOME/.config/ambxst" "ambxst-config"
backup_path "$HOME/.local/share/ambxst" "ambxst-share"
backup_path "$HOME/.local/src/ambxst" "ambxst-source"
backup_path "$HOME/.config/desktop-switcher" "desktop-switcher"
backup_path "$PROFILE_ROOT" "desktop-profiles"
backup_path "$HOME/.local/bin/desktop-switch" "desktop-switch"
backup_path "$HOME/.local/bin/recover-caelestia" "recover-caelestia"
backup_path "$HOME/.local/bin/ambxst" "ambxst-launcher"

log "Restoring all three Hyprland profiles"
for profile in caelestia end4 ambxst; do
    mkdir -p "$PROFILE_ROOT/$profile/hypr"
    rsync -a --delete "$SRC/profiles/$profile/hypr/" "$PROFILE_ROOT/$profile/hypr/"
done

if [[ -d "$SRC/caelestia" ]]; then
    log "Restoring Caelestia user configuration"
    mkdir -p "$HOME/.config/caelestia"
    rsync -a --delete "$SRC/caelestia/" "$HOME/.config/caelestia/"
    rewrite_home_paths_json "$HOME/.config/caelestia/shell.json"
fi

if [[ -f "$SRC/end4/config.json" ]]; then
    log "Restoring end4-pC widget and bar layout"
    mkdir -p "$HOME/.config/illogical-impulse"
    cp -a "$SRC/end4/config.json" "$HOME/.config/illogical-impulse/config.json"
    rewrite_home_paths_json "$HOME/.config/illogical-impulse/config.json"
else
    warn "No backed-up end4 config.json yet; end4 will use its defaults until a fresh backup is pushed."
fi

if [[ -d "$SRC/ambxst/config" ]] && find "$SRC/ambxst/config" -mindepth 1 -print -quit | grep -q .; then
    log "Restoring Ambxst user configuration"
    mkdir -p "$HOME/.config/ambxst"
    rsync -a --delete "$SRC/ambxst/config/" "$HOME/.config/ambxst/"
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
clone_pinned https://github.com/end-4/dots-hyprland.git \
    "$HOME/.local/src/end4-dots" "$SRC/versions/end4-dots.commit"

rm -rf "$HOME/.config/quickshell/ii"
if [[ -d "$HOME/.local/src/end4-dots/dots/.config/quickshell/ii" ]]; then
    cp -a "$HOME/.local/src/end4-dots/dots/.config/quickshell/ii" "$HOME/.config/quickshell/ii"
else
    die "Pinned end4 repository does not contain quickshell/ii"
fi

clone_pinned https://github.com/pctrade/end4-pC.git \
    "$HOME/.config/quickshell/end4-pC" "$SRC/versions/end4-pC.commit"

if [[ -f "$SRC/versions/end4-pC-local.patch" ]]; then
    git -C "$HOME/.config/quickshell/end4-pC" apply "$SRC/versions/end4-pC-local.patch" || warn "Could not reapply saved end4-pC local patch"
fi
if [[ -f "$SRC/versions/end4-dots-local.patch" ]]; then
    git -C "$HOME/.local/src/end4-dots" apply "$SRC/versions/end4-dots-local.patch" || warn "Could not reapply saved end4-dots local patch"
fi

log "Installing pinned Ambxst source"
clone_pinned https://github.com/Axenide/Ambxst.git \
    "$HOME/.local/src/ambxst" "$SRC/versions/ambxst.commit"
chmod +x "$HOME/.local/src/ambxst/cli.sh"
install_ambxst_launcher
install_axctl

mkdir -p "$HOME/.local/share/ambxst"
rm -f \
    "$HOME/.local/share/ambxst/hyprland.lua" \
    "$HOME/.local/share/ambxst/hyprland.conf" \
    "$HOME/.local/share/ambxst/axctl.toml"

"$HOME/.local/bin/ambxst" version >/dev/null 2>&1 || true

if [[ -f "$SRC/systemd/user/background-music.service" ]]; then
    log "Restoring background music service"
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

log "Activating the saved profile pointer"
active="caelestia"
if [[ -f "$SRC/state/active" ]]; then
    active="$(tr -d '[:space:]' < "$SRC/state/active")"
fi
case "$active" in
    caelestia|end4|ambxst) ;;
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

ok "Triple-rice restore complete"
printf '\nInstalled:\n'
printf '  ✦ Caelestia profile\n'
printf '  ◈ end4-pC profile + saved local patches\n'
printf '  ◆ Ambxst profile + pinned axctl integration\n'
printf '  ⇄ SUPER + SHIFT + D desktop switcher\n'
printf '\nDesktop wallpaper is not changed by this restore.\n'
printf '\nActive profile: %s\n' "$active"
printf 'Hyprland target: %s\n' "$(readlink -f "$HOME/.config/hypr")"
printf 'Safety backup: %s\n' "$BACKUP"
printf '\nLog out and back into Hyprland to start the restored profile.\n'
printf 'Emergency recovery: ~/.local/bin/recover-caelestia\n'
