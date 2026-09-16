#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$REPO_ROOT/dual-rice"
PROFILE_ROOT="$HOME/.local/share/desktop-profiles"
BACKUP_ROOT="$HOME/.local/share/desktop-profile-backups"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$BACKUP_ROOT/multi-rice-restore-$STAMP"

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


configure_sddm_multi_rice() {
    local dm=""
    local state_dir="/var/lib/sddm"
    local state="$state_dir/state.conf"
    local backup="$state_dir/state.conf.before-multi-rice"
    local absent="$state_dir/state.conf.before-multi-rice.absent"
    local session="/usr/share/wayland-sessions/huzaifah-multi-rice.desktop"
    local tmp=""
    local out=""

    dm="$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null || true)"

    if [[ "${dm##*/}" != "sddm.service" ]] &&
       ! systemctl is-active --quiet sddm.service
    then
        warn "SDDM is not active; leaving display-manager session state unchanged."
        return 0
    fi

    [[ -f "$session" ]] ||
        die "Multi-Rice SDDM session file is missing: $session"

    if ! sudo test -d "$state_dir"; then
        sudo install -d -o sddm -g sddm -m 0750 "$state_dir"
    fi

    # Preserve the original pre-Multi-Rice state exactly once.
    # Re-running the installer must never replace this rollback snapshot.
    if sudo test -f "$state"; then
        if ! sudo test -e "$backup" &&
           ! sudo test -e "$absent"
        then
            sudo cp -a "$state" "$backup"
            ok "Saved pre-Multi-Rice SDDM state"
        fi
    else
        if ! sudo test -e "$backup" &&
           ! sudo test -e "$absent"
        then
            sudo install -o root -g root -m 0644 /dev/null "$absent"
            ok "Recorded that no pre-Multi-Rice SDDM state existed"
        fi
    fi

    tmp="$(mktemp)"
    out="$(mktemp)"

    if sudo test -f "$state"; then
        sudo cat "$state" > "$tmp"
    else
        : > "$tmp"
    fi

    if grep -Eq "^[[:space:]]*Session[[:space:]]*=" "$tmp"; then
        sed -E \
            "0,/^[[:space:]]*Session[[:space:]]*=/s#^[[:space:]]*Session[[:space:]]*=.*#Session=$session#" \
            "$tmp" > "$out"
    elif grep -Eq "^\[Last\][[:space:]]*$" "$tmp"; then
        sed -E \
            "/^\[Last\][[:space:]]*$/a Session=$session" \
            "$tmp" > "$out"
    else
        cat "$tmp" > "$out"
        printf "\n[Last]\nSession=%s\n" "$session" >> "$out"
    fi

    sudo install -o root -g root -m 0644 "$out" "$state"

    rm -f "$tmp" "$out"

    ok "SDDM will remember Huzaifah Multi-Rice for the next login"
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

HYPR_PROFILES=(caelestia end4 ambxst dms serpantinum noctalia sayconlun)
NIRI_PROFILES=(jaqc clavis nixri)

for profile in "${HYPR_PROFILES[@]}"; do
    [[ -d "$SRC/profiles/$profile/hypr" ]] || die "Missing Hyprland profile: $profile"
    [[ -f "$SRC/profiles/$profile/hypr/hyprland.lua" ]] || die "Missing $profile hyprland.lua"
done

[[ -f "$SRC/profiles/sayconlun/support/quickshell/lumina/shell.qml" ]] || die "Missing Lumina Quickshell runtime support"

for profile in "${NIRI_PROFILES[@]}"; do
    [[ -d "$SRC/profiles/$profile/niri" ]] || die "Missing Niri profile: $profile"
    [[ -f "$SRC/profiles/$profile/niri/config.kdl" ]] || die "Missing $profile config.kdl"
    [[ -d "$SRC/profiles/$profile/support" ]] || die "Missing $profile runtime support"
done

log "Updating the system before Multi-Rice restore"
sudo pacman -Syu

ensure_paru

log "Installing Multi-Rice dependencies"
paru -S --needed \
    git curl unzip rsync jq fish stow foot kitty alacritty mpv mpv-mpris fuzzel \
    hyprland niri uwsm hypridle hyprlock hyprsunset wl-clipboard wl-clip-persist cliphist \
    brightnessctl playerctl cava matugen-bin imagemagick upower hyprpicker grim \
    slurp swappy wf-recorder tesseract tesseract-data-eng ydotool gnome-keyring \
    easyeffects libqalculate qt6-positioning ttf-readex-pro ttf-jetbrains-mono-nerd \
    dim-caelestia-shell-git caelestia-cli quickshell-git dms-shell dms-shell-hyprland noctalia \
    tmux network-manager-applet blueman pavucontrol ffmpeg x264 qt6-base \
    qt6-declarative qt6-wayland qt6-svg qt6-tools qt6-imageformats qt6-multimedia \
    qt6-shadertools libwebp libavif syntax-highlighting breeze-icons papirus-icon-theme hicolor-icon-theme \
    ddcutil sqlite wlsunset wtype zbar glib2 python-pipx zenity inetutils \
    power-profiles-daemon python312 libnotify ttf-roboto ttf-roboto-mono ttf-dejavu \
    ttf-liberation noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-nerd-fonts-symbols \
    gpu-screen-recorder mpvpaper gradia ttf-phosphor-icons ttf-league-gothic \
    adw-gtk-theme inter-font ttf-fira-code

# Multi-Rice uses compositor-managed DMS startup. A global DMS user service would
# overlap with Caelestia/end4/Ambxst, so keep it disabled.
systemctl --user disable --now dms.service >/dev/null 2>&1 || true

log "Creating safety backup before profile restore"
mkdir -p "$BACKUP"
backup_path "$HOME/.config/quickshell/multi-rice-switcher" "multi-rice-switcher"
backup_path "$HOME/.config/quickshell/lumina" "quickshell-lumina"
backup_path "$HOME/.config/environment.d/20-multi-rice-icons.conf" "multi-rice-icons.conf"
backup_path "$HOME/.local/share/desktop-switcher/profile-metadata.sh" "profile-metadata.sh"
backup_path "$HOME/.local/bin/multi-rice-control" "multi-rice-control"
backup_path "/usr/local/bin/multi-rice-session" "multi-rice-session"
backup_path "/usr/share/wayland-sessions/huzaifah-multi-rice.desktop" "huzaifah-multi-rice.desktop"
backup_path "$HOME/.config/hypr" "hypr"
backup_path "$HOME/.config/niri" "niri"
backup_path "$HOME/.config/caelestia" "caelestia"
backup_path "$HOME/.config/illogical-impulse" "illogical-impulse"
backup_path "$HOME/.config/ambxst" "ambxst-config"
backup_path "$HOME/.config/DankMaterialShell" "dms-config"
backup_path "$HOME/.config/noctalia" "noctalia-config"
backup_path "$HOME/.local/state/noctalia" "noctalia-state"
backup_path "$HOME/.local/share/ambxst" "ambxst-share"
backup_path "$HOME/.local/src/ambxst" "ambxst-source"
backup_path "$HOME/.cache/ambxst/wallpapers.json" "ambxst-wallpapers.json"
backup_path "$HOME/.config/desktop-switcher" "desktop-switcher"
backup_path "$PROFILE_ROOT" "desktop-profiles"
backup_path "$HOME/.local/bin/desktop-switch" "desktop-switch"
backup_path "$HOME/.local/bin/recover-caelestia" "recover-caelestia"
backup_path "$HOME/.local/bin/ambxst" "ambxst-launcher"
backup_path "$HOME/.local/bin/nixri-dms" "nixri-dms"
backup_path "$HOME/.local/bin/nixri-dms-ipc" "nixri-dms-ipc"
backup_path "$HOME/.local/bin/nixri-dms-restart" "nixri-dms-restart"

log "Restoring seven Hyprland profiles"
for profile in "${HYPR_PROFILES[@]}"; do
    mkdir -p "$PROFILE_ROOT/$profile/hypr"
    rsync -a --delete "$SRC/profiles/$profile/hypr/" "$PROFILE_ROOT/$profile/hypr/"
done

log "Restoring Lumina runtime support"
mkdir -p "$PROFILE_ROOT/sayconlun/support"
rsync -a --delete "$SRC/profiles/sayconlun/support/" "$PROFILE_ROOT/sayconlun/support/"

while IFS= read -r json; do
    rewrite_home_paths_json "$json"
done < <(find "$PROFILE_ROOT/sayconlun/support" -type f -name '*.json' -print)

mkdir -p "$HOME/.config/quickshell"
rm -f "$HOME/.config/quickshell/lumina"
ln -s "$PROFILE_ROOT/sayconlun/support/quickshell/lumina" "$HOME/.config/quickshell/lumina"

log "Restoring three Niri profiles and runtime support"
for profile in "${NIRI_PROFILES[@]}"; do
    mkdir -p "$PROFILE_ROOT/$profile/niri" "$PROFILE_ROOT/$profile/support"
    rsync -a --delete "$SRC/profiles/$profile/niri/" "$PROFILE_ROOT/$profile/niri/"
    rsync -a --delete "$SRC/profiles/$profile/support/" "$PROFILE_ROOT/$profile/support/"

    while IFS= read -r json; do
        rewrite_home_paths_json "$json"
    done < <(find "$PROFILE_ROOT/$profile/support" -type f -name '*.json' -print)
done

log "Installing Niri Quickshell discovery links"
mkdir -p "$HOME/.config/quickshell"
rm -rf "$HOME/.config/quickshell/solstice" "$HOME/.config/quickshell/clavis"
ln -s "$PROFILE_ROOT/jaqc/support/quickshell/solstice" "$HOME/.config/quickshell/solstice"
ln -s "$PROFILE_ROOT/clavis/support/quickshell/clavis" "$HOME/.config/quickshell/clavis"

log "Installing Astra runtime launch helpers"
mkdir -p "$HOME/.local/bin"
for helper in nixri-dms nixri-dms-ipc nixri-dms-restart; do
    if [[ -e "$HOME/.local/bin/$helper" || -L "$HOME/.local/bin/$helper" ]]; then
        rm -f "$HOME/.local/bin/$helper"
    fi
    ln -s "$PROFILE_ROOT/nixri/support/bin/$helper" "$HOME/.local/bin/$helper"
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

if [[ -f "$SRC/ambxst/wallpapers.json" ]]; then
    log "Restoring Ambxst wallpaper directory state"
    mkdir -p "$HOME/.cache/ambxst"
    cp -a "$SRC/ambxst/wallpapers.json" "$HOME/.cache/ambxst/wallpapers.json"
    rewrite_home_paths_json "$HOME/.cache/ambxst/wallpapers.json"
fi

if [[ -d "$SRC/dms/config" ]] && find "$SRC/dms/config" -mindepth 1 -print -quit | grep -q .; then
    log "Restoring DMS user configuration"
    mkdir -p "$HOME/.config/DankMaterialShell"
    rsync -a --delete "$SRC/dms/config/" "$HOME/.config/DankMaterialShell/"
    while IFS= read -r json; do
        rewrite_home_paths_json "$json"
    done < <(find "$HOME/.config/DankMaterialShell" -type f -name '*.json' -print)
fi

if [[ -d "$SRC/noctalia" ]]; then
    log "Restoring Noctalia v5 configuration"
    mkdir -p "$HOME/.config/noctalia" "$HOME/.local/state/noctalia"
    [[ -f "$SRC/noctalia/config.toml" ]] && cp -a "$SRC/noctalia/config.toml" "$HOME/.config/noctalia/config.toml"
    [[ -f "$SRC/noctalia/settings.toml" ]] && cp -a "$SRC/noctalia/settings.toml" "$HOME/.local/state/noctalia/settings.toml"
    [[ -f "$SRC/noctalia/.setup-complete" ]] && cp -a "$SRC/noctalia/.setup-complete" "$HOME/.local/state/noctalia/.setup-complete"
fi

log "Installing Huzaifah Multi-Rice v5 runtime"

for required in \
    bin/multi-rice-control \
    bin/multi-rice-session \
    lib/profile-metadata.sh \
    quickshell/multi-rice-switcher/shell.qml \
    environment.d/20-multi-rice-icons.conf \
    wayland-sessions/huzaifah-multi-rice.desktop
do
    [[ -e "$SRC/$required" ]] || die "Missing v5 runtime file: $required"
done

mkdir -p \
    "$HOME/.local/bin" \
    "$HOME/.local/share/desktop-switcher" \
    "$HOME/.config/quickshell/multi-rice-switcher" \
    "$HOME/.config/environment.d"

rsync -a --delete \
    "$SRC/quickshell/multi-rice-switcher/" \
    "$HOME/.config/quickshell/multi-rice-switcher/"

install -m 0755 \
    "$SRC/bin/multi-rice-control" \
    "$HOME/.local/bin/multi-rice-control"

install -m 0644 \
    "$SRC/lib/profile-metadata.sh" \
    "$HOME/.local/share/desktop-switcher/profile-metadata.sh"

install -m 0644 \
    "$SRC/environment.d/20-multi-rice-icons.conf" \
    "$HOME/.config/environment.d/20-multi-rice-icons.conf"

if [[ -f "$SRC/bin/recover-caelestia" ]]; then
    install -m 0755 \
        "$SRC/bin/recover-caelestia" \
        "$HOME/.local/bin/recover-caelestia"
fi

sudo install -m 0755 \
    "$SRC/bin/multi-rice-session" \
    /usr/local/bin/multi-rice-session

sudo install -d -m 0755 \
    /usr/share/wayland-sessions

sudo install -m 0644 \
    "$SRC/wayland-sessions/huzaifah-multi-rice.desktop" \
    /usr/share/wayland-sessions/huzaifah-multi-rice.desktop

# v5 uses the unified Quickshell switcher.
rm -f "$HOME/.local/bin/desktop-switch"

ok "Multi-Rice v5 controller, switcher and dynamic session installed"

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

if [[ -f "$SRC/versions/ambxst-local.patch" ]]; then
    git -C "$HOME/.local/src/ambxst" apply "$SRC/versions/ambxst-local.patch" || warn "Could not reapply saved Ambxst local patch"
fi

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

log "Activating the saved v5 profile pointer"
active="caelestia"
if [[ -f "$SRC/state/active" ]]; then
    active="$(tr -d "[:space:]" < "$SRC/state/active")"
fi

case "$active" in
    caelestia|end4|ambxst|dms|serpantinum|noctalia|sayconlun|jaqc|clavis|nixri) ;;
    *)
        warn "Unknown saved active profile $active; defaulting to Caelestia"
        active="caelestia"
        ;;
esac

hypr_active="caelestia"
niri_active="jaqc"

case "$active" in
    jaqc|clavis|nixri)
        niri_active="$active"
        ;;
    *)
        hypr_active="$active"
        ;;
esac

rm -rf "$HOME/.config/hypr" "$HOME/.config/niri"

ln -s "$PROFILE_ROOT/$hypr_active/hypr" "$HOME/.config/hypr"
ln -s "$PROFILE_ROOT/$niri_active/niri" "$HOME/.config/niri"

mkdir -p "$HOME/.config/desktop-profile"
printf "%s\n" "$active" > "$HOME/.config/desktop-profile/active"

configure_sddm_multi_rice

systemctl --user daemon-reload 2>/dev/null || true
if [[ -f "$HOME/.config/systemd/user/background-music.service" ]]; then
    systemctl --user enable background-music.service 2>/dev/null || true
fi

ok "Multi-Rice restore complete"
printf '\nInstalled:\n'
printf '  ✦ Caelestia profile\n'
printf '  ◈ end4-pC profile + saved local patches\n'
printf '  ◆ Ambxst profile + saved local patches + pinned axctl integration\n'
printf '  ● DankMaterialShell profile (standalone compositor-managed startup)\n'
printf '  ⇄ SUPER + SHIFT + D dynamic desktop switcher\n'
printf '\nDesktop wallpaper is not changed by this restore.\n'
printf '\nActive profile: %s\n' "$active"
printf 'Hyprland target: %s\n' "$(readlink -f "$HOME/.config/hypr")"
printf 'Safety backup: %s\n' "$BACKUP"
printf '\nLog out and back into Hyprland to start the restored profile.\n'
printf 'Emergency recovery: ~/.local/bin/recover-caelestia\n'