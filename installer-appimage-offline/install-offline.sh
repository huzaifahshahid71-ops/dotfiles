#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PAYLOAD="$HERE/payload"
REPO="$PAYLOAD/repo"
PKG_DIR="$PAYLOAD/packages"
SOURCE_DIR="$PAYLOAD/sources"
BIN_DIR="$PAYLOAD/bin"
TARGETS_FILE="$PAYLOAD/targets.txt"
PROFILE_ROOT="$HOME/.local/share/desktop-profiles"
BACKUP_ROOT="$HOME/.local/share/desktop-profile-backups"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$BACKUP_ROOT/offline-restore-$STAMP"

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
    jq --arg home "$HOME" '
      walk(if type == "string"
           then sub("^/home/[^/]+/"; ($home + "/"))
           else . end)
    ' "$file" > "$tmp"
    mv "$tmp" "$file"
}

preflight_payload() {
    [[ -d "$REPO/dual-rice" ]] || die "Offline payload is missing the dotfiles snapshot"
    [[ -d "$PKG_DIR" ]] || die "Offline payload is missing package archives"
    [[ -f "$PKG_DIR/huzaifah-offline.db" || -f "$PKG_DIR/huzaifah-offline.db.tar.gz" ]] || die "Offline pacman repository database is missing"
    [[ -s "$TARGETS_FILE" ]] || die "Offline target package list is missing"

    for profile in caelestia end4 ambxst; do
        [[ -d "$REPO/dual-rice/profiles/$profile/hypr" ]] || die "Missing $profile profile in offline payload"
        [[ -f "$REPO/dual-rice/profiles/$profile/hypr/hyprland.lua" ]] || die "Missing $profile hyprland.lua in offline payload"
    done

    [[ -d "$SOURCE_DIR/end4-dots" ]] || die "Bundled end4-dots source is missing"
    [[ -d "$SOURCE_DIR/end4-pC" ]] || die "Bundled end4-pC source is missing"
    [[ -d "$SOURCE_DIR/ambxst" ]] || die "Bundled Ambxst source is missing"
    [[ -x "$BIN_DIR/axctl" ]] || die "Bundled axctl binary is missing"
    [[ -d "$REPO/machine/sddm/themes/sddm-frieren-theme" ]] || die "Bundled Frieren SDDM theme is missing"
}

install_local_packages() {
    local conf
    conf="$(mktemp --suffix=.conf)"
    trap 'rm -f "$conf"' RETURN

    cat > "$conf" <<EOF
[options]
Architecture = auto
CheckSpace
SigLevel = Never
LocalFileSigLevel = Never

[huzaifah-offline]
SigLevel = Never
Server = file://$PKG_DIR
EOF

    mapfile -t targets < <(grep -Ev '^[[:space:]]*(#|$)' "$TARGETS_FILE" | sort -u)
    ((${#targets[@]})) || die "Offline target package list is empty"

    log "Installing ${#targets[@]} direct targets from the bundled local pacman repository"
    printf '    No internet connection is used in this step.\n'
    sudo pacman --config "$conf" -S --needed --noconfirm "${targets[@]}"

    rm -f "$conf"
    trap - RETURN
}

restore_profiles_and_configs() {
    local src="$REPO/dual-rice"

    log "Creating safety backup before profile restore"
    mkdir -p "$BACKUP"
    backup_path "$HOME/.config/hypr" "hypr"
    backup_path "$HOME/.config/caelestia" "caelestia"
    backup_path "$HOME/.config/illogical-impulse" "illogical-impulse"
    backup_path "$HOME/.config/ambxst" "ambxst-config"
    backup_path "$HOME/.local/share/ambxst" "ambxst-share"
    backup_path "$HOME/.local/src/ambxst" "ambxst-source"
    backup_path "$HOME/.cache/ambxst/wallpapers.json" "ambxst-wallpapers.json"
    backup_path "$HOME/.config/desktop-switcher" "desktop-switcher"
    backup_path "$PROFILE_ROOT" "desktop-profiles"
    backup_path "$HOME/.local/bin/desktop-switch" "desktop-switch"
    backup_path "$HOME/.local/bin/recover-caelestia" "recover-caelestia"
    backup_path "$HOME/.local/bin/ambxst" "ambxst-launcher"

    log "Restoring Caelestia, end4-pC and Ambxst Hyprland profiles"
    for profile in caelestia end4 ambxst; do
        mkdir -p "$PROFILE_ROOT/$profile/hypr"
        rsync -a --delete "$src/profiles/$profile/hypr/" "$PROFILE_ROOT/$profile/hypr/"
    done

    if [[ -d "$src/caelestia" ]]; then
        mkdir -p "$HOME/.config/caelestia"
        rsync -a --delete "$src/caelestia/" "$HOME/.config/caelestia/"
        rewrite_home_paths_json "$HOME/.config/caelestia/shell.json"
    fi

    if [[ -f "$src/end4/config.json" ]]; then
        mkdir -p "$HOME/.config/illogical-impulse"
        cp -a "$src/end4/config.json" "$HOME/.config/illogical-impulse/config.json"
        rewrite_home_paths_json "$HOME/.config/illogical-impulse/config.json"
    fi

    if [[ -d "$src/ambxst/config" ]] && find "$src/ambxst/config" -mindepth 1 -print -quit | grep -q .; then
        mkdir -p "$HOME/.config/ambxst"
        rsync -a --delete "$src/ambxst/config/" "$HOME/.config/ambxst/"
    fi

    if [[ -f "$src/ambxst/wallpapers.json" ]]; then
        mkdir -p "$HOME/.cache/ambxst"
        cp -a "$src/ambxst/wallpapers.json" "$HOME/.cache/ambxst/wallpapers.json"
        rewrite_home_paths_json "$HOME/.cache/ambxst/wallpapers.json"
    fi

    if [[ -d "$src/desktop-switcher" ]]; then
        mkdir -p "$HOME/.config/desktop-switcher"
        rsync -a --delete "$src/desktop-switcher/" "$HOME/.config/desktop-switcher/"
    fi

    mkdir -p "$HOME/.local/bin"
    for bin in desktop-switch recover-caelestia; do
        if [[ -f "$src/bin/$bin" ]]; then
            install -m 0755 "$src/bin/$bin" "$HOME/.local/bin/$bin"
        fi
    done

    if [[ -f "$src/systemd/user/background-music.service" ]]; then
        mkdir -p "$HOME/.config/systemd/user"
        cp -a "$src/systemd/user/background-music.service" "$HOME/.config/systemd/user/background-music.service"
        sed -Ei "s#/home/[^/]+/#$HOME/#g" "$HOME/.config/systemd/user/background-music.service" || true
    fi

    if compgen -G "$src/music/*.m3u8" >/dev/null; then
        mkdir -p "$HOME/Music"
        for playlist in "$src"/music/*.m3u8; do
            local dest="$HOME/Music/$(basename "$playlist")"
            cp -a "$playlist" "$dest"
            sed -Ei "s#/home/[^/]+/#$HOME/#g" "$dest" || true
        done
    fi
}

restore_bundled_sources() {
    log "Installing bundled end4-pC, end4-dots and Ambxst sources"
    mkdir -p "$HOME/.config/quickshell" "$HOME/.local/src"

    rm -rf "$HOME/.local/src/end4-dots"
    cp -a "$SOURCE_DIR/end4-dots" "$HOME/.local/src/end4-dots"

    rm -rf "$HOME/.config/quickshell/ii"
    [[ -d "$HOME/.local/src/end4-dots/dots/.config/quickshell/ii" ]] || die "Bundled end4-dots source does not contain quickshell/ii"
    cp -a "$HOME/.local/src/end4-dots/dots/.config/quickshell/ii" "$HOME/.config/quickshell/ii"

    rm -rf "$HOME/.config/quickshell/end4-pC"
    cp -a "$SOURCE_DIR/end4-pC" "$HOME/.config/quickshell/end4-pC"

    rm -rf "$HOME/.local/src/ambxst"
    cp -a "$SOURCE_DIR/ambxst" "$HOME/.local/src/ambxst"
    chmod +x "$HOME/.local/src/ambxst/cli.sh"

    sudo install -m 0755 "$BIN_DIR/axctl" /usr/local/bin/axctl

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

    mkdir -p "$HOME/.local/share/ambxst"
    rm -f \
        "$HOME/.local/share/ambxst/hyprland.lua" \
        "$HOME/.local/share/ambxst/hyprland.conf" \
        "$HOME/.local/share/ambxst/axctl.toml"
    "$HOME/.local/bin/ambxst" version >/dev/null 2>&1 || true
}

configure_end4_search_only() {
    local config="$HOME/.config/illogical-impulse/config.json" tmp
    mkdir -p "$(dirname "$config")"
    [[ -f "$config" ]] || printf '{}\n' > "$config"
    jq empty "$config" >/dev/null 2>&1 || { warn "end4 config is not valid JSON; leaving overview setting unchanged"; return; }
    tmp="$(mktemp)"
    jq '.overview = (.overview // {}) | .overview.enable = false' "$config" > "$tmp"
    mv "$tmp" "$config"
}

install_frieren_theme() {
    local theme_src="$REPO/machine/sddm/themes/sddm-frieren-theme"
    local theme_dst="/usr/share/sddm/themes/sddm-frieren-theme"
    local root_backup="/var/backups/huzaifah-triple-rice/sddm-$STAMP"

    log "Installing bundled Frieren SDDM login theme"
    sudo mkdir -p "$root_backup" /etc/sddm.conf.d /usr/share/sddm/themes

    if sudo test -d "$theme_dst"; then
        sudo cp -a "$theme_dst" "$root_backup/"
    fi
    if sudo test -f /etc/sddm.conf.d/90-huzaifah-theme.conf; then
        sudo cp -a /etc/sddm.conf.d/90-huzaifah-theme.conf "$root_backup/90-huzaifah-theme.conf"
    fi

    sudo rm -rf "$theme_dst"
    sudo cp -a "$theme_src" "$theme_dst"
    printf '[Theme]\nCurrent=sddm-frieren-theme\n' | sudo tee /etc/sddm.conf.d/90-huzaifah-theme.conf >/dev/null

    ok "Frieren SDDM theme installed (display manager state/autologin unchanged)"
}

activate_saved_profile() {
    local active="caelestia"
    if [[ -f "$REPO/dual-rice/state/active" ]]; then
        active="$(tr -d '[:space:]' < "$REPO/dual-rice/state/active")"
    fi
    case "$active" in
        caelestia|end4|ambxst) ;;
        *) warn "Unknown saved active profile '$active'; defaulting to Caelestia"; active="caelestia" ;;
    esac

    rm -rf "$HOME/.config/hypr"
    ln -s "$PROFILE_ROOT/$active/hypr" "$HOME/.config/hypr"
    mkdir -p "$HOME/.config/desktop-profile"
    printf '%s\n' "$active" > "$HOME/.config/desktop-profile/active"

    systemctl --user daemon-reload 2>/dev/null || true
    if [[ -f "$HOME/.config/systemd/user/background-music.service" ]]; then
        systemctl --user enable background-music.service 2>/dev/null || true
    fi
}

main() {
    clear 2>/dev/null || true
    printf '\n  Huzaifah Triple-Rice OFFLINE Installer\n'
    printf '  =======================================\n\n'
    printf '  ✦ Caelestia\n  ◈ end4-pC\n  ◆ Ambxst\n  🌙 Frieren SDDM login theme\n'
    printf '  ⇄ SUPER + SHIFT + D switcher\n\n'

    is_arch_family || die "This offline installer supports Arch/CachyOS-family systems only"
    [[ "$(uname -m)" == "x86_64" ]] || die "This offline build targets x86_64 only"

    preflight_payload

    log "Verifying bundled payload checksums"
    if [[ -f "$PAYLOAD/SHA256SUMS" ]]; then
        (cd "$PAYLOAD" && sha256sum -c SHA256SUMS)
    else
        warn "Payload checksum manifest is missing; continuing without file verification"
    fi

    install_local_packages
    restore_profiles_and_configs
    restore_bundled_sources
    configure_end4_search_only
    install_frieren_theme
    activate_saved_profile

    printf '\n'
    ok "Fully offline triple-rice installation completed"
    printf '\nInstalled entirely from this AppImage:\n'
    printf '  ✦ Caelestia\n  ◈ end4-pC\n  ◆ Ambxst + axctl\n'
    printf '  🌙 Frieren SDDM login theme\n  ⇄ SUPER + SHIFT + D switcher\n'
    printf '\nNo internet connection was required.\n'
    printf 'Desktop wallpaper was not changed by the installer.\n'
    printf 'Safety backup: %s\n' "$BACKUP"
    printf '\nLog out and back into Hyprland when ready.\n'
}

main "$@"
