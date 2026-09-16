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

prompt_yes_no() {
    local prompt="$1" default="${2:-n}" ans
    if [[ ! -r /dev/tty ]]; then
        [[ "$default" == y ]]
        return
    fi
    if [[ "$default" == y ]]; then
        read -r -p "$prompt [Y/n] " ans < /dev/tty || true
        ans="${ans:-y}"
    else
        read -r -p "$prompt [y/N] " ans < /dev/tty || true
        ans="${ans:-n}"
    fi
    [[ "$ans" =~ ^[Yy]$ ]]
}

current_vendor() { cat /sys/class/dmi/id/sys_vendor 2>/dev/null || echo unknown; }
current_product() { cat /sys/class/dmi/id/product_name 2>/dev/null || echo unknown; }

is_g16() {
    local v p
    v="$(current_vendor)"; p="$(current_product)"
    [[ "$v" == *ASUS* || "$v" == *ASUSTeK* ]] || return 1
    [[ "$p" =~ GU60[35] || "$p" == *"Zephyrus G16"* || "$p" == *"ROG Zephyrus G16"* ]]
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


# HUZ_V3_TRANSACTIONAL_ROLLBACK
# v5.0.0 records the machine state BEFORE any Multi-Rice mutation.
# The snapshot preserves files/directories/symlinks exactly with tar.

managed_user_paths() {
    printf "%s\n" \
        ".config/hypr" \
        ".config/niri" \
        ".config/quickshell/multi-rice-switcher" \
        ".config/quickshell/solstice" \
        ".config/quickshell/clavis" \
        ".config/quickshell/lumina" \
        ".local/bin/nixri-dms" \
        ".local/bin/nixri-dms-ipc" \
        ".local/bin/nixri-dms-restart" \
        ".config/environment.d/20-multi-rice-icons.conf" \
        ".local/share/desktop-switcher" \
        ".local/bin/multi-rice-control" \
        ".local/bin/grub-themes" \
        ".local/bin/Grub-themes" \
        ".config/foot/foot.ini" \
        ".config/fish/config.fish" \
        ".config/fish/functions/fish_greeting.fish" \
        ".config/fish/functions/foot_cmd_start.fish" \
        ".config/fish/functions/foot_cmd_end.fish" \
        ".config/fish/conf.d/99-huz-fastfetch.fish" \
        ".config/fish/conf.d/foot-command-markers.fish" \
        ".local/share/huz-terminal/fastfetch.jsonc" \
        ".config/caelestia" \
        ".config/illogical-impulse" \
        ".config/ambxst" \
        ".config/DankMaterialShell" \
        ".config/noctalia" \
        ".config/serpantinum" \
        ".local/state/serpantinum" \
        ".config/desktop-switcher" \
        ".config/desktop-profile" \
        ".config/quickshell/ii" \
        ".config/quickshell/end4-pC" \
        ".config/systemd/user/background-music.service" \
        ".local/bin/background-music" \
        ".local/lib/huzaifah/mpv-mpris/mpris.so" \
        ".local/bin/background-music-stop" \
        ".local/bin/toggle-night-light" \
        ".config/huzaifah/hyprsunset.conf" \
        "Music/Favorites.m3u8" \
        ".config/systemd/user/dms.service" \
        ".config/systemd/user/end4-media-backend.service" \
        ".local/share/desktop-profiles" \
        ".local/share/ambxst" \
        ".local/share/serpantinum" \
        ".local/state/noctalia" \
        ".local/src/ambxst" \
        ".local/src/end4-dots" \
        ".local/bin/desktop-switch" \
        ".local/bin/recover-caelestia" \
        ".local/bin/ambxst" \
        ".local/bin/serpantinum" \
        ".local/bin/serpantinumd" \
        ".local/bin/end4-media-backend" \
        ".local/bin/refresh-switch" \
        ".cache/ambxst/wallpapers.json"
}

managed_system_paths() {
    printf "%s\n" \
        "usr/local/bin/axctl" \
        "usr/local/bin/ambxst" \
        "usr/local/bin/multi-rice-session" \
        "usr/share/wayland-sessions/huzaifah-multi-rice.desktop" \
        "var/lib/sddm/state.conf" \
        "var/lib/sddm/state.conf.before-multi-rice" \
        "var/lib/sddm/state.conf.before-multi-rice.absent" \
        "usr/local/bin/eva" \
        "usr/local/share/evangelion" \
        "var/lib/evangelion-grub" \
        "etc/default/grub" \
        "etc/grub.d/99_evangelion" \
        "boot/grub/grub.cfg" \
        "boot/grub/themes/evangelion" \
        "boot/grub2/grub.cfg" \
        "boot/grub2/themes/evangelion" \
        "usr/share/sddm/themes/sddm-frieren-theme" \
        "etc/sddm.conf.d/90-huzaifah-theme.conf" \
        "etc/systemd/system/display-manager.service"
}

record_path_state() {
    local path="$1" label="$2" out="$3" kind target=""
    if [[ -L "$path" ]]; then
        kind=symlink
        target="$(readlink "$path" 2>/dev/null || true)"
    elif [[ -d "$path" ]]; then
        kind=directory
    elif [[ -f "$path" ]]; then
        kind=file
    elif [[ -e "$path" ]]; then
        kind=other
    else
        kind=absent
    fi
    printf "%s\t%s\t%s\n" "$label" "$kind" "$target" >> "$out"
}

create_install_snapshot() {
    local root="$HOME/.local/share/huzaifah-multi-rice/installations"
    local state="$root/$STAMP"
    local system_state="/var/backups/huzaifah-multi-rice/$STAMP"
    local rel abs legacy archive meta
    local -a existing_user=()
    local -a existing_system=()

    HUZ_INSTALL_STATE="$state"
    HUZ_SYSTEM_STATE="$system_state"

    log "Creating transactional v5.0.0 rollback snapshot BEFORE installation"
    mkdir -p "$state/packages"
    sudo mkdir -p "$system_state"

    {
        printf "version=5.0.0\n"
        printf "install_id=%s\n" "$STAMP"
        printf "created=%s\n" "$(date --iso-8601=seconds)"
        printf "user=%s\n" "$USER"
        printf "home=%s\n" "$HOME"
        printf "hostname=%s\n" "$(hostname)"
        printf "system_snapshot=%s\n" "$system_state"
        printf "status=in-progress\n"
    } > "$state/manifest"

    pacman -Qq 2>/dev/null | sort -u > "$state/packages-before.txt"
    pacman -Qqe 2>/dev/null | sort -u > "$state/packages-explicit-before.txt"

    systemctl --user is-enabled dms.service > "$state/dms-enabled-before.txt" 2>&1 || true
    systemctl --user is-active dms.service > "$state/dms-active-before.txt" 2>&1 || true
    systemctl --user is-active end4-media-backend.service > "$state/end4-media-backend-active-before.txt" 2>&1 || true
    systemctl --user is-enabled background-music.service > "$state/background-music-enabled-before.txt" 2>&1 || true
    systemctl --user is-active background-music.service > "$state/background-music-active-before.txt" 2>&1 || true
    systemctl --user is-enabled hyprsunset.service > "$state/hyprsunset-enabled-before.txt" 2>&1 || true
    systemctl --user is-active hyprsunset.service > "$state/hyprsunset-active-before.txt" 2>&1 || true

    if command -v serpantinumd >/dev/null 2>&1 &&        serpantinumd status 2>/dev/null | grep -qi "running"; then
        echo active > "$state/serpantinum-active-before.txt"
    else
        echo inactive > "$state/serpantinum-active-before.txt"
    fi

    if [[ -L "$HOME/.config/hypr" ]]; then
        readlink "$HOME/.config/hypr" > "$state/hypr-target-before.txt" || true
    fi

    : > "$state/user-paths.tsv"
    while IFS= read -r rel; do
        [[ -n "$rel" ]] || continue
        abs="$HOME/$rel"
        record_path_state "$abs" "$rel" "$state/user-paths.tsv"
        if [[ -e "$abs" || -L "$abs" ]]; then
            existing_user+=("$rel")
        fi
    done < <(managed_user_paths)

    if ((${#existing_user[@]})); then
        tar -C "$HOME" -cpf "$state/user-home.tar" -- "${existing_user[@]}"
    else
        tar -C "$HOME" -cpf "$state/user-home.tar" --files-from /dev/null
    fi

    : > "$state/system-paths.tsv"
    while IFS= read -r rel; do
        [[ -n "$rel" ]] || continue
        abs="/$rel"
        record_path_state "$abs" "$rel" "$state/system-paths.tsv"
        if [[ -e "$abs" || -L "$abs" ]]; then
            existing_system+=("$rel")
        fi
    done < <(managed_system_paths)

    if ((${#existing_system[@]})); then
        sudo tar -C / -cpf "$system_state/root.tar" -- "${existing_system[@]}"
    else
        sudo tar -C / -cpf "$system_state/root.tar" --files-from /dev/null
    fi

    if legacy="$(pacman -Q noctalia-qs 2>/dev/null)"; then
        printf "%s\n" "$legacy" > "$state/legacy-noctalia-qs-before.txt"

        while IFS= read -r -d "" archive; do
            meta="$(LC_ALL=C pacman -Qp "$archive" 2>/dev/null || true)"
            if [[ "$meta" == "$legacy" ]]; then
                cp -f "$archive" "$state/packages/"
                break
            fi
        done < <(find /var/cache/pacman/pkg -maxdepth 1 -type f \
            -name "noctalia-qs-*.pkg.tar.*" ! -name "*.sig" -print0 2>/dev/null)
        if ! find "$state/packages" -maxdepth 1 -type f -name "noctalia-qs-*.pkg.tar.*" ! -name "*.sig" -print -quit | grep -q .; then
            die "Legacy noctalia-qs is installed, but its exact package archive is not cached; refusing migration because exact rollback would be impossible"
        fi
    fi

    pacman -Q quickshell-git > "$state/quickshell-git-before.txt" 2>/dev/null || true
    pacman -Q noctalia > "$state/noctalia-before.txt" 2>/dev/null || true

    ln -sfn "$state" "$root/latest"

    ok "Rollback snapshot created: $state"
}

finalize_install_snapshot() {
    [[ -n "${HUZ_INSTALL_STATE:-}" && -d "$HUZ_INSTALL_STATE" ]] || return 0

    pacman -Qq 2>/dev/null | sort -u > "$HUZ_INSTALL_STATE/packages-after.txt"
    comm -13 \
        "$HUZ_INSTALL_STATE/packages-before.txt" \
        "$HUZ_INSTALL_STATE/packages-after.txt" \
        > "$HUZ_INSTALL_STATE/packages-added.txt"

    sed -i "s/^status=.*/status=complete/" "$HUZ_INSTALL_STATE/manifest"
    printf "%s\n" "$(date --iso-8601=seconds)" > "$HUZ_INSTALL_STATE/completed-at"

    ok "Rollback manifest finalized"
}

latest_install_snapshot() {
    local latest="$HOME/.local/share/huzaifah-multi-rice/installations/latest"
    [[ -L "$latest" ]] || return 1
    readlink -f "$latest"
}

uninstall_multi_rice() {
    local state root system_state rel legacy_archive=""
    local -a added=()
    local dms_enabled="" dms_active=""
    local background_music_enabled="" background_music_active=""
    local end4_backend_active="" serpantinum_active=""

    state="$(latest_install_snapshot || true)"

    if [[ -z "$state" || ! -d "$state" || ! -f "$state/manifest" ]]; then
        printf "\nNo Huzaifah Multi-Rice installation/rollback snapshot was found.\n"
        printf "Nothing was changed.\n"
        return 0
    fi

    if [[ -s "$state/legacy-noctalia-qs-before.txt" ]]; then
        legacy_archive="$(find "$state/packages" -maxdepth 1 -type f -name "noctalia-qs-*.pkg.tar.*" ! -name "*.sig" -print -quit 2>/dev/null || true)"
        [[ -n "$legacy_archive" ]] || die "Rollback snapshot is missing the saved legacy noctalia-qs archive; exact rollback cannot continue"
    fi

    if [[ -f "$state/restored-at" ]]; then
        printf "\nThis v5.0.0 rollback snapshot has already been restored.\n"
        printf "Nothing was changed.\n"
        return 0
    fi

    printf "\nHuzaifah Multi-Rice v5.0.0 rollback\n"
    printf "====================================\n"
    printf "Snapshot: %s\n\n" "$state"

    warn "This will remove Multi-Rice-managed desktop files and restore the exact pre-install snapshot."
    warn "Packages are NOT removed by the default uninstall."

    prompt_yes_no "Restore the previous desktop configuration now?" n || {
        log "Uninstall cancelled"
        return 0
    }

    root="$HOME/.local/share/huzaifah-multi-rice/installations"
    system_state="$(grep "^system_snapshot=" "$state/manifest" | cut -d= -f2- || true)"

    systemctl --user stop background-music.service >/dev/null 2>&1 || true
    systemctl --user stop hyprsunset.service >/dev/null 2>&1 || true
    systemctl --user stop end4-media-backend.service >/dev/null 2>&1 || true
    if command -v serpantinumd >/dev/null 2>&1; then
        serpantinumd stop >/dev/null 2>&1 || true
    fi

    log "Removing Multi-Rice-managed user paths"
    while IFS= read -r rel; do
        [[ -n "$rel" ]] || continue
        rm -rf -- "$HOME/$rel"
    done < <(managed_user_paths)

    if [[ -f "$state/user-home.tar" ]]; then
        log "Restoring exact pre-install user files and symlinks"
        tar -C "$HOME" -xpf "$state/user-home.tar"
    fi

    log "Restoring system files changed by Multi-Rice"
    while IFS= read -r rel; do
        [[ -n "$rel" ]] || continue
        sudo rm -rf -- "/$rel"
    done < <(managed_system_paths)

    if [[ -n "$system_state" ]] && sudo test -f "$system_state/root.tar"; then
        sudo tar -C / -xpf "$system_state/root.tar"
    fi

    sudo systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl --user daemon-reload >/dev/null 2>&1 || true

    dms_enabled="$(head -n1 "$state/dms-enabled-before.txt" 2>/dev/null || true)"
    dms_active="$(head -n1 "$state/dms-active-before.txt" 2>/dev/null || true)"

    case "$dms_enabled" in
        enabled) systemctl --user enable dms.service >/dev/null 2>&1 || true ;;
        disabled) systemctl --user disable dms.service >/dev/null 2>&1 || true ;;
    esac

    case "$dms_active" in
        active) systemctl --user start dms.service >/dev/null 2>&1 || true ;;
        inactive|failed) systemctl --user stop dms.service >/dev/null 2>&1 || true ;;
    esac

    background_music_enabled="$(head -n1 "$state/background-music-enabled-before.txt" 2>/dev/null || true)"
    background_music_active="$(head -n1 "$state/background-music-active-before.txt" 2>/dev/null || true)"

    case "$background_music_enabled" in
        enabled) systemctl --user enable background-music.service >/dev/null 2>&1 || true ;;
        disabled) systemctl --user disable background-music.service >/dev/null 2>&1 || true ;;
        masked) systemctl --user mask background-music.service >/dev/null 2>&1 || true ;;
    esac

    case "$background_music_active" in
        active) systemctl --user start background-music.service >/dev/null 2>&1 || true ;;
        inactive|failed) systemctl --user stop background-music.service >/dev/null 2>&1 || true ;;
    esac

    hyprsunset_enabled="$(head -n1 "$state/hyprsunset-enabled-before.txt" 2>/dev/null || true)"
    hyprsunset_active="$(head -n1 "$state/hyprsunset-active-before.txt" 2>/dev/null || true)"

    case "$hyprsunset_enabled" in
        enabled) systemctl --user enable hyprsunset.service >/dev/null 2>&1 || true ;;
        disabled) systemctl --user disable hyprsunset.service >/dev/null 2>&1 || true ;;
        masked) systemctl --user mask hyprsunset.service >/dev/null 2>&1 || true ;;
    esac

    case "$hyprsunset_active" in
        active) systemctl --user start hyprsunset.service >/dev/null 2>&1 || true ;;
        inactive|failed) systemctl --user stop hyprsunset.service >/dev/null 2>&1 || true ;;
    esac

    end4_backend_active="$(head -n1 "$state/end4-media-backend-active-before.txt" 2>/dev/null || true)"
    serpantinum_active="$(head -n1 "$state/serpantinum-active-before.txt" 2>/dev/null || true)"

    case "$end4_backend_active" in
        active)
            systemctl --user start end4-media-backend.service >/dev/null 2>&1 || true
            ;;
        inactive|failed)
            systemctl --user stop end4-media-backend.service >/dev/null 2>&1 || true
            ;;
    esac

    case "$serpantinum_active" in
        active)
            if command -v serpantinumd >/dev/null 2>&1; then
                serpantinumd start >/dev/null 2>&1 || true
            fi
            ;;
        *)
            if command -v serpantinumd >/dev/null 2>&1; then
                serpantinumd stop >/dev/null 2>&1 || true
            fi
            ;;
    esac

    if [[ -n "$legacy_archive" ]]; then
        log "Restoring legacy noctalia-qs provider state"
        if [[ ! -s "$state/quickshell-git-before.txt" ]] && pacman -Q quickshell-git >/dev/null 2>&1; then
            sudo pacman -Rdd --noconfirm quickshell-git
        fi
        if [[ ! -s "$state/noctalia-before.txt" ]] && pacman -Q noctalia >/dev/null 2>&1; then
            sudo pacman -Rdd --noconfirm noctalia
        fi
        sudo pacman -U --noconfirm "$legacy_archive"
        ok "Legacy noctalia-qs provider state restored"
    fi

    if [[ -f "$state/packages-added.txt" ]]; then
        mapfile -t added < "$state/packages-added.txt"
    fi

    printf "%s\n" "$(date --iso-8601=seconds)" > "$state/restored-at"
    sed -i "s/^status=.*/status=restored/" "$state/manifest"
    ln -sfn "$state" "$root/latest"

    ok "Previous desktop configuration restored"

    if ((${#added[@]})); then
        printf "\n%d package(s) were added during the original Multi-Rice install.\n" "${#added[@]}"
        printf "They were intentionally left installed for safety.\n"
        printf "The package list is preserved at:\n  %s/packages-added.txt\n" "$state"
    fi

    printf "\nLog out and back in, or reboot, to complete the desktop rollback.\n"
}


preflight_payload() {
    local expected_serp_commit payload_serp_commit expected_eva_commit payload_eva_commit
    [[ -d "$REPO/dual-rice" ]] || die "Offline payload is missing the dotfiles snapshot"
    [[ -f "$REPO/foot/.config/foot/foot.ini" ]] || die "Bundled Foot configuration is missing"
    [[ -f "$REPO/fish/.config/fish/config.fish" ]] || die "Bundled Fish configuration is missing"
    [[ -f "$REPO/fish/.config/fish/functions/fish_greeting.fish" ]] || die "Bundled Fish greeting is missing"
    [[ -f "$REPO/fish/.config/fish/functions/foot_cmd_start.fish" ]] || die "Bundled Fish Foot preexec hook is missing"
    [[ -f "$REPO/fish/.config/fish/functions/foot_cmd_end.fish" ]] || die "Bundled Fish Foot postexec hook is missing"
    [[ -f "$REPO/fish/.config/fish/conf.d/99-huz-fastfetch.fish" ]] || die "Bundled Fish Fastfetch hook is missing"
    [[ -f "$REPO/fish/.config/fish/conf.d/foot-command-markers.fish" ]] || die "Bundled Fish Foot marker loader is missing"
    [[ -f "$REPO/fish/.local/share/huz-terminal/fastfetch.jsonc" ]] || die "Bundled Fastfetch configuration is missing"
    [[ -d "$PKG_DIR" ]] || die "Offline payload is missing package archives"
    [[ -f "$PKG_DIR/huzaifah-offline.db" || -f "$PKG_DIR/huzaifah-offline.db.tar.gz" ]] || die "Offline pacman repository database is missing"
    [[ -s "$TARGETS_FILE" ]] || die "Offline target package list is missing"
    for profile in caelestia end4 ambxst dms serpantinum noctalia sayconlun; do
        [[ -f "$REPO/dual-rice/profiles/$profile/hypr/hyprland.lua" ]] || die "Missing $profile profile in offline payload"
    done
    for profile in jaqc clavis nixri; do
        [[ -f "$REPO/dual-rice/profiles/$profile/niri/config.kdl" ]] || die "Missing $profile Niri profile in offline payload"
        [[ -d "$REPO/dual-rice/profiles/$profile/support" ]] || die "Missing $profile runtime support in offline payload"
    done
    [[ -f "$REPO/dual-rice/profiles/jaqc/support/quickshell/solstice/shell.qml" ]] || die "Bundled Solstice shell is missing"
    [[ -f "$REPO/dual-rice/profiles/sayconlun/support/quickshell/lumina/shell.qml" ]] || die "Bundled Lumina shell is missing"
    [[ -f "$REPO/dual-rice/profiles/clavis/support/quickshell/clavis/shell.qml" ]] || die "Bundled Cipher shell is missing"
    [[ -f "$REPO/dual-rice/profiles/clavis/support/qml/Clavis/Cava/libClavisCava.so" ]] || die "Bundled Cipher Cava runtime library is missing"
    [[ -x "$REPO/dual-rice/profiles/clavis/support/bin/clavis-shell" ]] || die "Bundled Cipher launcher is missing or not executable"
    [[ -d "$REPO/dual-rice/profiles/clavis/support/qml/Clavis" ]] || die "Bundled Cipher QML imports are missing"
    [[ -x "$REPO/dual-rice/profiles/nixri/support/bin/nixri-dms" ]] || die "Bundled Astra runtime launcher is missing or not executable"

    [[ -f "$REPO/dual-rice/noctalia/config.toml" ]] || die "Missing Noctalia config in offline payload"
    [[ -f "$REPO/dual-rice/noctalia/settings.toml" ]] || die "Missing Noctalia settings in offline payload"
    [[ -d "$SOURCE_DIR/end4-dots" ]] || die "Bundled end4-dots source is missing"
    [[ -d "$SOURCE_DIR/end4-pC" ]] || die "Bundled end4-pC source is missing"
    [[ -d "$SOURCE_DIR/ambxst" ]] || die "Bundled Ambxst source is missing"
    [[ -d "$SOURCE_DIR/serpantinum/src" ]] || die "Bundled Serpantinum source is missing"
    [[ -x "$SOURCE_DIR/serpantinum/bin/serpantinum" ]] || die "Bundled serpantinum launcher is missing"
    [[ -x "$SOURCE_DIR/serpantinum/bin/serpantinumd" ]] || die "Bundled serpantinum daemon is missing"
    [[ -f "$SOURCE_DIR/serpantinum/config/serpantinum/settings.json" ]] || die "Bundled Serpantinum settings are missing"
    [[ -f "$SOURCE_DIR/serpantinum/version.txt" ]] || die "Bundled Serpantinum version marker is missing"
    [[ "$(cat "$SOURCE_DIR/serpantinum/version.txt")" == "2.1.6" ]] || die "Bundled Serpantinum source is not version 2.1.6"
    [[ -f "$REPO/dual-rice/versions/serpantinum.commit" ]] || die "Bundled Serpantinum commit marker is missing"

    expected_serp_commit="$(tr -d "[:space:]" < "$REPO/dual-rice/versions/serpantinum.commit")"
    [[ "$expected_serp_commit" =~ ^[0-9a-f]{40}$ ]] || die "Bundled Serpantinum commit marker is invalid"

    if [[ -f "$PAYLOAD/manifest.txt" ]]; then
        payload_serp_commit="$(grep -m1 "^serpantinum_commit=" "$PAYLOAD/manifest.txt" 2>/dev/null | cut -d= -f2- || true)"
        [[ -n "$payload_serp_commit" ]] || die "Payload manifest is missing the Serpantinum commit"
        [[ "$payload_serp_commit" == "$expected_serp_commit" ]] || die "Payload Serpantinum commit does not match the bundled pin"
    fi
    [[ -d "$SOURCE_DIR/evangelion" ]] || die "Bundled Evangelion source is missing"
    [[ -x "$SOURCE_DIR/evangelion/install.sh" ]] || die "Bundled Evangelion installer is missing"
    [[ -x "$SOURCE_DIR/evangelion/bin/eva" ]] || die "Bundled Evangelion manager is missing"
    [[ -f "$REPO/dual-rice/versions/evangelion.commit" ]] || die "Evangelion commit pin is missing"
    [[ -x "$REPO/dual-rice/bin/grub-themes" ]] || die "GRUB theme wrapper is missing"

    expected_eva_commit="$(tr -d "[:space:]" < "$REPO/dual-rice/versions/evangelion.commit")"
    [[ "$expected_eva_commit" =~ ^[0-9a-f]{40}$ ]] ||
        die "Evangelion commit pin is invalid"

    grep -Fq "result = source" "$SOURCE_DIR/evangelion/bin/boot-console.awk" ||
        die "Bundled Evangelion source does not contain the silent-boot patch"

    if [[ -f "$PAYLOAD/manifest.txt" ]]; then
        payload_eva_commit="$(grep -m1 "^evangelion_commit=" "$PAYLOAD/manifest.txt" 2>/dev/null | cut -d= -f2- || true)"
        [[ -n "$payload_eva_commit" ]] ||
            die "Payload manifest is missing the Evangelion commit"
        [[ "$payload_eva_commit" == "$expected_eva_commit" ]] ||
            die "Payload Evangelion commit does not match the bundled pin"
    fi

    [[ -x "$REPO/dual-rice/bin/end4-media-backend" ]] || die "Bundled End4 artwork backend is missing"
    [[ -f "$REPO/dual-rice/systemd/user/end4-media-backend.service" ]] || die "Bundled End4 artwork service is missing"
    [[ -x "$REPO/dual-rice/bin/background-music" ]] || die "Bundled background-music command is missing"
    [[ -f "$BIN_DIR/mpv-mpris-huzaifah.so" ]] || die "Bundled patched mpv-mpris module is missing"
    [[ -f "$REPO/dual-rice/systemd/user/background-music.service" ]] || die "Bundled background music service is missing"
    [[ -s "$REPO/dual-rice/music/Favorites.m3u8" ]] || die "Bundled Favorites.m3u8 playlist is missing"
    [[ -x "$REPO/dual-rice/bin/toggle-night-light" ]] || die "Bundled night-light toggle is missing"
    grep -qxF "hyprsunset" "$TARGETS_FILE" || die "Offline target list is missing hyprsunset"
    [[ -x "$BIN_DIR/axctl" ]] || die "Bundled axctl binary is missing"
    [[ -x "$REPO/scripts/install-refresh-switcher.sh" ]] || die "Bundled refresh switcher installer is missing"
    [[ -d "$REPO/machine/sddm/themes/sddm-frieren-theme" ]] || die "Bundled Frieren SDDM theme is missing"
}

verify_payload() {
    preflight_payload
    if [[ -f "$PAYLOAD/SHA256SUMS" ]]; then
        log "Verifying bundled payload checksums"
        (cd "$PAYLOAD" && sha256sum -c SHA256SUMS)
    else
        warn "Payload checksum manifest is missing"
    fi
}

make_pacman_conf() {
    local conf="$1"
    cat > "$conf" <<EOF
[options]
Architecture = auto
CheckSpace
SigLevel = Never
LocalFileSigLevel = Never
DisableSandbox

[huzaifah-offline]
SigLevel = Never
Server = file://$PKG_DIR
EOF
}

local_repo_has() {
    local pkg="$1" conf rc
    conf="$(mktemp --suffix=.conf)"
    make_pacman_conf "$conf"
    if pacman --config "$conf" -Sl huzaifah-offline 2>/dev/null | awk -v want="$pkg" '$2 == want { found=1 } END { exit !found }'; then
        rc=0
    else
        rc=$?
    fi
    rm -f "$conf"
    return "$rc"
}
install_named_local() {
    local conf
    conf="$(mktemp --suffix=.conf)"
    make_pacman_conf "$conf"
    sudo pacman --config "$conf" -Syy --noconfirm >/dev/null
    sudo pacman --config "$conf" -S --needed --noconfirm "$@"
    rm -f "$conf"
}

handle_legacy_noctalia_qs_transition() {
    pacman -Q noctalia-qs >/dev/null 2>&1 || return 0
    local_repo_has quickshell-git || die "noctalia-qs is installed, but bundled quickshell-git is missing"

    warn "Legacy noctalia-qs conflicts with the bundled Caelestia/Quickshell stack."
    warn "The installer can replace its Quickshell provider with bundled quickshell-git before continuing."
    prompt_yes_no "Replace legacy noctalia-qs with bundled quickshell-git?" y || die "Cannot install Multi-Rice while noctalia-qs owns the conflicting Quickshell provider"

    sudo pacman -Rdd --noconfirm noctalia-qs
    install_named_local quickshell-git
    ok "Provider transition complete: noctalia-qs -> quickshell-git"
}

install_all_local_packages() {
    local conf
    mapfile -t targets < <(grep -Ev '^[[:space:]]*(#|$)' "$TARGETS_FILE" | sort -u)
    ((${#targets[@]})) || die "Offline target package list is empty"

    handle_legacy_noctalia_qs_transition

    conf="$(mktemp --suffix=.conf)"
    make_pacman_conf "$conf"
    log "Installing ${#targets[@]} targets from the embedded local pacman repository"
    sudo pacman --config "$conf" -Syy --noconfirm
    sudo pacman --config "$conf" -S --needed --noconfirm "${targets[@]}"
    rm -f "$conf"
}

preflight_report() {
    verify_payload
    printf '\nHuzaifah Multi-Rice OFFLINE Preflight\n'
    printf '====================================\n'
    printf 'OS:            '; grep '^PRETTY_NAME=' /etc/os-release 2>/dev/null | cut -d= -f2- | tr -d '"'
    printf 'Architecture:  %s\n' "$(uname -m)"
    printf 'Machine:       %s / %s\n' "$(current_vendor)" "$(current_product)"
    printf 'UEFI boot:     %s\n' "$([[ -d /sys/firmware/efi ]] && echo yes || echo no)"
    printf 'G16 profile:   %s\n' "$(is_g16 && echo yes || echo no)"
    printf 'Free space /:  %s\n' "$(df -h --output=avail / | tail -1 | xargs)"
    if pacman -Q noctalia-qs >/dev/null 2>&1; then
        printf 'Conflict:      legacy noctalia-qs detected; migration to bundled quickshell-git available\n'
    else
        printf 'Conflict:      no known Quickshell provider conflict detected\n'
    fi
    printf 'Network:       not required\n'
    printf '\nPRE-FLIGHT RESULT: payload is complete and ready for offline installation.\n'
}

restore_profiles_and_configs() {
    local src="$REPO/dual-rice"
    log "Creating safety backup before profile restore"
    mkdir -p "$BACKUP"
    backup_path "$HOME/.config/hypr" hypr
    backup_path "$HOME/.config/foot/foot.ini" foot.ini
    backup_path "$HOME/.config/fish/config.fish" config.fish
    backup_path "$HOME/.config/fish/functions/fish_greeting.fish" fish_greeting.fish
    backup_path "$HOME/.config/fish/functions/foot_cmd_start.fish" foot_cmd_start.fish
    backup_path "$HOME/.config/fish/functions/foot_cmd_end.fish" foot_cmd_end.fish
    backup_path "$HOME/.config/fish/conf.d/99-huz-fastfetch.fish" 99-huz-fastfetch.fish
    backup_path "$HOME/.config/fish/conf.d/foot-command-markers.fish" foot-command-markers.fish
    backup_path "$HOME/.local/share/huz-terminal/fastfetch.jsonc" huz-fastfetch.jsonc
    backup_path "$HOME/.config/caelestia" caelestia
    backup_path "$HOME/.config/illogical-impulse" illogical-impulse
    backup_path "$HOME/.config/ambxst" ambxst-config
    backup_path "$HOME/.config/DankMaterialShell" dms-config
    backup_path "$HOME/.config/noctalia" noctalia-config
    backup_path "$HOME/.local/state/noctalia" noctalia-state
    backup_path "$HOME/.config/serpantinum" serpantinum-config
    backup_path "$HOME/.local/state/serpantinum" serpantinum-state
    backup_path "$HOME/.local/share/serpantinum" serpantinum-share
    backup_path "$HOME/.local/bin/serpantinum" serpantinum-launcher
    backup_path "$HOME/.local/bin/serpantinumd" serpantinum-daemon
    backup_path "$HOME/.local/bin/end4-media-backend" end4-media-backend
    backup_path "$HOME/.config/systemd/user/end4-media-backend.service" end4-media-backend-service
    backup_path "$HOME/.local/bin/background-music" background-music
    backup_path "$HOME/.local/lib/huzaifah/mpv-mpris/mpris.so" mpv-mpris-huzaifah-so
    backup_path "$HOME/.local/bin/background-music-stop" background-music-stop
    backup_path "$HOME/.config/systemd/user/background-music.service" background-music-service
    backup_path "$HOME/Music/Favorites.m3u8" background-music-playlist
    backup_path "$HOME/.local/bin/toggle-night-light" toggle-night-light
    backup_path "$HOME/.config/huzaifah/hyprsunset.conf" hyprsunset-shared-config
    backup_path "$HOME/.config/hypr/hyprsunset.conf" hyprsunset-active-config
    backup_path "$HOME/.local/share/ambxst" ambxst-share
    backup_path "$HOME/.local/src/ambxst" ambxst-source
    backup_path "$HOME/.cache/ambxst/wallpapers.json" ambxst-wallpapers.json
    backup_path "$HOME/.config/desktop-switcher" desktop-switcher
    backup_path "$PROFILE_ROOT" desktop-profiles
    backup_path "$HOME/.local/bin/desktop-switch" desktop-switch
    backup_path "$HOME/.local/bin/recover-caelestia" recover-caelestia

    log "Installing canonical Foot + fish terminal configuration"
    install -Dm644 "$REPO/foot/.config/foot/foot.ini" "$HOME/.config/foot/foot.ini"
    install -Dm644 "$REPO/fish/.config/fish/config.fish" "$HOME/.config/fish/config.fish"
    install -Dm644 "$REPO/fish/.config/fish/functions/fish_greeting.fish" "$HOME/.config/fish/functions/fish_greeting.fish"
    install -Dm644 "$REPO/fish/.config/fish/functions/foot_cmd_start.fish" "$HOME/.config/fish/functions/foot_cmd_start.fish"
    install -Dm644 "$REPO/fish/.config/fish/functions/foot_cmd_end.fish" "$HOME/.config/fish/functions/foot_cmd_end.fish"
    install -Dm644 "$REPO/fish/.config/fish/conf.d/99-huz-fastfetch.fish" "$HOME/.config/fish/conf.d/99-huz-fastfetch.fish"
    install -Dm644 "$REPO/fish/.config/fish/conf.d/foot-command-markers.fish" "$HOME/.config/fish/conf.d/foot-command-markers.fish"
    install -Dm644 "$REPO/fish/.local/share/huz-terminal/fastfetch.jsonc" "$HOME/.local/share/huz-terminal/fastfetch.jsonc"

    log "Restoring Caelestia, end4-pC, Ambxst, DMS, Serpantinum and Noctalia profiles"
    for profile in caelestia end4 ambxst dms serpantinum noctalia sayconlun; do
        mkdir -p "$PROFILE_ROOT/$profile/hypr"
        rsync -a --delete "$src/profiles/$profile/hypr/" "$PROFILE_ROOT/$profile/hypr/"
    done

    log "Restoring Lumina runtime support"
    mkdir -p "$PROFILE_ROOT/sayconlun/support"
    rsync -a --delete "$src/profiles/sayconlun/support/" "$PROFILE_ROOT/sayconlun/support/"

    while IFS= read -r json; do
        rewrite_home_paths_json "$json"
    done < <(find "$PROFILE_ROOT/sayconlun/support" -type f -name '*.json' -print)

    mkdir -p "$HOME/.config/quickshell"
    rm -f "$HOME/.config/quickshell/lumina"
    ln -s "$PROFILE_ROOT/sayconlun/support/quickshell/lumina" "$HOME/.config/quickshell/lumina"

    log "Restoring three Niri profiles and runtime support"
    for profile in jaqc clavis nixri; do
        [[ -d "$src/profiles/$profile/support" ]] || die "Bundled $profile runtime support is missing"

        mkdir -p "$PROFILE_ROOT/$profile/niri" "$PROFILE_ROOT/$profile/support"
        rsync -a --delete "$src/profiles/$profile/niri/" "$PROFILE_ROOT/$profile/niri/"
        rsync -a --delete "$src/profiles/$profile/support/" "$PROFILE_ROOT/$profile/support/"

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
    if [[ -d "$src/dms/config" ]] && find "$src/dms/config" -mindepth 1 -print -quit | grep -q .; then
        mkdir -p "$HOME/.config/DankMaterialShell"
        rsync -a --delete "$src/dms/config/" "$HOME/.config/DankMaterialShell/"
        while IFS= read -r json; do rewrite_home_paths_json "$json"; done < <(find "$HOME/.config/DankMaterialShell" -type f -name '*.json' -print)
    fi
    if [[ -d "$src/noctalia" ]]; then
        log "Restoring Noctalia v5 configuration"
        mkdir -p "$HOME/.config/noctalia" "$HOME/.local/state/noctalia"
        [[ -f "$src/noctalia/config.toml" ]] && cp -a "$src/noctalia/config.toml" "$HOME/.config/noctalia/config.toml"
        [[ -f "$src/noctalia/settings.toml" ]] && cp -a "$src/noctalia/settings.toml" "$HOME/.local/state/noctalia/settings.toml"
        [[ -f "$src/noctalia/.setup-complete" ]] && cp -a "$src/noctalia/.setup-complete" "$HOME/.local/state/noctalia/.setup-complete"
    fi

    log "Installing Huzaifah Multi-Rice v5 runtime"

    mkdir -p \
        "$HOME/.local/bin" \
        "$HOME/.local/share/desktop-switcher" \
        "$HOME/.config/quickshell/multi-rice-switcher" \
        "$HOME/.config/environment.d"

    rsync -a --delete \
        "$src/quickshell/multi-rice-switcher/" \
        "$HOME/.config/quickshell/multi-rice-switcher/"

    install -m 0755 \
        "$src/bin/multi-rice-control" \
        "$HOME/.local/bin/multi-rice-control"

    install -m 0644 \
        "$src/lib/profile-metadata.sh" \
        "$HOME/.local/share/desktop-switcher/profile-metadata.sh"

    install -m 0644 \
        "$src/environment.d/20-multi-rice-icons.conf" \
        "$HOME/.config/environment.d/20-multi-rice-icons.conf"

    if [[ -f "$src/bin/recover-caelestia" ]]; then
        install -m 0755 \
            "$src/bin/recover-caelestia" \
            "$HOME/.local/bin/recover-caelestia"
    fi

    sudo install -m 0755 \
        "$src/bin/multi-rice-session" \
        /usr/local/bin/multi-rice-session

    sudo install -d -m 0755 /usr/share/wayland-sessions

    sudo install -m 0644 \
        "$src/wayland-sessions/huzaifah-multi-rice.desktop" \
        /usr/share/wayland-sessions/huzaifah-multi-rice.desktop

    rm -f "$HOME/.local/bin/desktop-switch"

    if [[ -f "$src/bin/end4-media-backend" ]]; then
        rm -rf "$HOME/.local/bin/end4-media-backend"
        install -m 0755 "$src/bin/end4-media-backend" "$HOME/.local/bin/end4-media-backend"
    fi

    if [[ -f "$src/systemd/user/end4-media-backend.service" ]]; then
        rm -rf "$HOME/.config/systemd/user/end4-media-backend.service"
        install -Dm644             "$src/systemd/user/end4-media-backend.service"             "$HOME/.config/systemd/user/end4-media-backend.service"
    fi
}

restore_bundled_sources() {
    log "Installing bundled end4-pC, end4-dots, Ambxst and Serpantinum source snapshots"
    mkdir -p "$HOME/.config/quickshell" "$HOME/.local/src" "$HOME/.local/bin"
    rm -rf "$HOME/.local/src/end4-dots" "$HOME/.config/quickshell/end4-pC" "$HOME/.local/src/ambxst" "$HOME/.config/quickshell/ii"
    cp -a "$SOURCE_DIR/end4-dots" "$HOME/.local/src/end4-dots"
    [[ -d "$HOME/.local/src/end4-dots/dots/.config/quickshell/ii" ]] || die "Bundled end4-dots source lacks quickshell/ii"
    cp -a "$HOME/.local/src/end4-dots/dots/.config/quickshell/ii" "$HOME/.config/quickshell/ii"
    cp -a "$SOURCE_DIR/end4-pC" "$HOME/.config/quickshell/end4-pC"
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

    log "Installing bundled Serpantinum 2.1.6 runtime"

    rm -rf         "$HOME/.local/share/serpantinum"         "$HOME/.local/bin/serpantinum"         "$HOME/.local/bin/serpantinumd"

    mkdir -p         "$HOME/.local/share/serpantinum"         "$HOME/.config/serpantinum"         "$HOME/.local/state/serpantinum"

    cp -a "$SOURCE_DIR/serpantinum/bin" "$HOME/.local/share/serpantinum/bin"
    cp -a "$SOURCE_DIR/serpantinum/src" "$HOME/.local/share/serpantinum/src"
    cp -a "$SOURCE_DIR/serpantinum/version.txt" "$HOME/.local/share/serpantinum/version.txt"

    # Our bundled layout puts version.txt one directory above src.
    ln -sfn ../version.txt "$HOME/.local/share/serpantinum/src/version.txt"

    # Reinstall/upgrade must not reset user-selected scale or other preferences.
    if [[ -f "$HOME/.config/serpantinum/settings.json" ]]; then
        log "Preserving existing Serpantinum settings"
    else
        install -m 0644 \
            "$SOURCE_DIR/serpantinum/config/serpantinum/settings.json" \
            "$HOME/.config/serpantinum/settings.json"

        # Aurora canonical default for the built-in laptop panel.
        # Existing installations are never overwritten above.
        local tmp_settings
        tmp_settings="$(mktemp)"
        jq '
            .display = (.display // {}) |
            .display.monitors = (.display.monitors // {}) |
            .display.monitors["eDP-1"] =
                ((.display.monitors["eDP-1"] // {}) + {"scale": 1.25})
        ' "$HOME/.config/serpantinum/settings.json" > "$tmp_settings"
        mv "$tmp_settings" "$HOME/.config/serpantinum/settings.json"
    fi

    chmod 0755 \
        "$HOME/.local/share/serpantinum/bin/serpantinum" \
        "$HOME/.local/share/serpantinum/bin/serpantinumd"

    ln -sfn \
        "$HOME/.local/share/serpantinum/bin/serpantinum" \
        "$HOME/.local/bin/serpantinum"

    ln -sfn \
        "$HOME/.local/share/serpantinum/bin/serpantinumd" \
        "$HOME/.local/bin/serpantinumd"

    local serp_version serp_commit version_state
    serp_version="$(tr -d "[:space:]" < "$SOURCE_DIR/serpantinum/version.txt")"
    serp_commit="$(tr -d "[:space:]" < "$REPO/dual-rice/versions/serpantinum.commit")"
    version_state="$HOME/.local/state/serpantinum/version"

    touch "$version_state"

    if grep -q "^SERPANTINUM_VERSION=" "$version_state"; then
        sed -i "s|^SERPANTINUM_VERSION=.*|SERPANTINUM_VERSION=\"$serp_version\"|" "$version_state"
    else
        printf 'SERPANTINUM_VERSION="%s"\n' "$serp_version" >> "$version_state"
    fi

    if grep -q "^SERPANTINUM_COMMIT=" "$version_state"; then
        sed -i "s|^SERPANTINUM_COMMIT=.*|SERPANTINUM_COMMIT=\"$serp_commit\"|" "$version_state"
    else
        printf 'SERPANTINUM_COMMIT="%s"\n' "$serp_commit" >> "$version_state"
    fi

    command -v fish >/dev/null 2>&1 && fish -c "fish_add_path ~/.local/bin" >/dev/null 2>&1 || true
}

configure_end4_search_only() {
    local config="$HOME/.config/illogical-impulse/config.json" tmp
    mkdir -p "$(dirname "$config")"
    [[ -f "$config" ]] || printf '{}\n' > "$config"
    jq empty "$config" >/dev/null 2>&1 || return 0
    tmp="$(mktemp)"
    jq '.overview = (.overview // {}) | .overview.enable = false' "$config" > "$tmp"
    mv "$tmp" "$config"
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

    # Change only Session= inside SDDM's [Last] section.  A Session=
    # key in another section must never be treated as the previous session.
    awk -v session="$session" '
        BEGIN {
            in_last = 0
            saw_last = 0
            wrote_session = 0
        }

        function write_session() {
            if (in_last && !wrote_session) {
                print "Session=" session
                wrote_session = 1
            }
        }

        /^[[:space:]]*\[[^]]+\][[:space:]]*$/ {
            if (in_last)
                write_session()

            if ($0 ~ /^[[:space:]]*\[Last\][[:space:]]*$/) {
                in_last = 1
                saw_last = 1
                wrote_session = 0
                print
                next
            }

            in_last = 0
        }

        {
            if (in_last && $0 ~ /^[[:space:]]*Session[[:space:]]*=/) {
                if (!wrote_session) {
                    print "Session=" session
                    wrote_session = 1
                }
                next
            }

            print
        }

        END {
            if (in_last)
                write_session()

            if (!saw_last) {
                print ""
                print "[Last]"
                print "Session=" session
            }
        }
    ' "$tmp" > "$out"

    sudo install -o root -g root -m 0644 "$out" "$state"

    rm -f "$tmp" "$out"

    ok "SDDM will remember Huzaifah Multi-Rice for the next login"
}


activate_sddm_for_next_boot() {
    local sddm_unit="/usr/lib/systemd/system/sddm.service"
    local dm_link="/etc/systemd/system/display-manager.service"

    [[ -f "$sddm_unit" ]] || die "sddm.service is missing after package installation"

    log "Selecting SDDM as the display manager for the next boot"

    sudo ln -sfn "$sddm_unit" "$dm_link"
    sudo systemctl daemon-reload
    sudo systemctl enable --force sddm.service >/dev/null 2>&1 || true
    sudo systemctl set-default graphical.target >/dev/null

    ok "SDDM selected for next boot; current graphical session was left running"
}

has_grub() {
    [[ -f /etc/default/grub ]] || return 1
    [[ -f /boot/grub/grub.cfg || -f /boot/grub2/grub.cfg ]]
}

install_evangelion_manager() {
    local eva_src="$SOURCE_DIR/evangelion"

    if ! has_grub; then
        log "GRUB not detected; leaving bootloader configuration untouched."
        return 0
    fi

    [[ -x "$eva_src/install.sh" ]] ||
        die "Bundled Evangelion installer is missing"

    log "Installing pinned silent Evangelion manager/catalog"

    (
        cd "$eva_src"
        sudo ./install.sh --no-apply
    )

    mkdir -p "$HOME/.local/bin"

    install -m 0755         "$REPO/dual-rice/bin/grub-themes"         "$HOME/.local/bin/grub-themes"

    ln -sfn         "$HOME/.local/bin/grub-themes"         "$HOME/.local/bin/Grub-themes"

    ok "Evangelion manager installed; current GRUB appearance remains unchanged"
}


ensure_silent_grub_defaults() {
    local defaults="/etc/default/grub"

    [[ -f "$defaults" ]] || die "GRUB defaults file is missing: $defaults"
    command -v python3 >/dev/null 2>&1 ||
        die "python3 is required to update GRUB arguments safely"

    log "Ensuring quiet Linux boot arguments for Evangelion"

    sudo python3 - "$defaults" <<'PY'
from pathlib import Path
import os
import re
import sys
import tempfile

path = Path(sys.argv[1])
text = path.read_text()
lines = text.splitlines(keepends=True)

key = "GRUB_CMDLINE_LINUX_DEFAULT"
found = False
changed = False
out = []

for line in lines:
    stripped = line.lstrip()
    if stripped.startswith(key + "="):
        found = True

        # Preserve the original RHS byte-for-byte except for inserting one
        # literal " quiet" before its closing quote (or at the end if unquoted).
        newline = "\n" if line.endswith("\n") else ""
        body = line[:-1] if newline else line
        lhs, rhs = body.split("=", 1)

        # Test the value lexically so existing "quiet" is not duplicated.
        # This intentionally avoids evaluating /etc/default/grub as shell code.
        value_for_test = rhs.strip()
        if len(value_for_test) >= 2 and value_for_test[0] == value_for_test[-1] and value_for_test[0] in ("'", '"'):
            value_for_test = value_for_test[1:-1]

        if not re.search(r'(^|\s)quiet(\s|$)', value_for_test):
            trimmed = rhs.rstrip()
            trailing_ws = rhs[len(trimmed):]

            if trimmed.endswith('"') or trimmed.endswith("'"):
                rhs = trimmed[:-1] + " quiet" + trimmed[-1] + trailing_ws
            elif trimmed:
                rhs = trimmed + " quiet" + trailing_ws
            else:
                rhs = '"quiet"' + trailing_ws

            changed = True

        out.append(lhs + "=" + rhs + newline)
    else:
        out.append(line)

if not found:
    if out and not out[-1].endswith("\n"):
        out[-1] += "\n"
    out.append(f'{key}="quiet"\n')
    changed = True

if changed:
    st = path.stat()
    fd, tmp_name = tempfile.mkstemp(prefix=".grub.huz.", dir=str(path.parent))
    try:
        with os.fdopen(fd, "w") as f:
            f.writelines(out)
        os.chmod(tmp_name, st.st_mode & 0o7777)
        try:
            os.chown(tmp_name, st.st_uid, st.st_gid)
        except PermissionError:
            pass
        os.replace(tmp_name, path)
    finally:
        if os.path.exists(tmp_name):
            os.unlink(tmp_name)
PY

    sudo python3 - "$defaults" <<'PY'
from pathlib import Path
import re
import sys

for line in Path(sys.argv[1]).read_text().splitlines():
    if not line.startswith("GRUB_CMDLINE_LINUX_DEFAULT="):
        continue
    rhs = line.split("=", 1)[1].strip()
    if len(rhs) >= 2 and rhs[0] == rhs[-1] and rhs[0] in ("'", '"'):
        rhs = rhs[1:-1]
    if re.search(r'(^|\s)quiet(\s|$)', rhs):
        raise SystemExit(0)
raise SystemExit(1)
PY

    ok "Quiet kernel boot argument is present; Evangelion menu/theme remains visible"
}

configure_evangelion_grub() {
    verify_payload

    if ! has_grub; then
        warn "GRUB was not detected. No bootloader files were changed."
        return 2
    fi

    install_evangelion_manager
    ensure_silent_grub_defaults

    printf "\nLaunching the silent Evangelion GRUB chooser...\n\n"
    sudo eva
}

install_frieren_theme() {
    local theme_src="$REPO/machine/sddm/themes/sddm-frieren-theme"
    local theme_dst="/usr/share/sddm/themes/sddm-frieren-theme"
    local root_backup="/var/backups/huzaifah-multi-rice/sddm-$STAMP"
    sudo mkdir -p "$root_backup" /etc/sddm.conf.d /usr/share/sddm/themes
    sudo test -d "$theme_dst" && sudo cp -a "$theme_dst" "$root_backup/" || true
    sudo test -f /etc/sddm.conf.d/90-huzaifah-theme.conf && sudo cp -a /etc/sddm.conf.d/90-huzaifah-theme.conf "$root_backup/" || true
    sudo rm -rf "$theme_dst"
    sudo cp -a "$theme_src" "$theme_dst"
    printf '[Theme]\nCurrent=sddm-frieren-theme\n' | sudo tee /etc/sddm.conf.d/90-huzaifah-theme.conf >/dev/null
    ok "Frieren SDDM login theme installed"
}

activate_saved_profile() {
    local active=caelestia
    local hypr_active=caelestia
    local niri_active=jaqc

    [[ -f "$REPO/dual-rice/state/active" ]] &&
        active="$(tr -d "[:space:]" < "$REPO/dual-rice/state/active")"

    case "$active" in
        jaqc|clavis|nixri)
            niri_active="$active"
            ;;
        caelestia|end4|ambxst|dms|serpantinum|noctalia|sayconlun)
            hypr_active="$active"
            ;;
        *)
            active=caelestia
            hypr_active=caelestia
            ;;
    esac

    rm -rf "$HOME/.config/hypr" "$HOME/.config/niri"

    ln -s \
        "$PROFILE_ROOT/$hypr_active/hypr" \
        "$HOME/.config/hypr"

    ln -s \
        "$PROFILE_ROOT/$niri_active/niri" \
        "$HOME/.config/niri"

    mkdir -p "$HOME/.config/desktop-profile"
    printf "%s\n" "$active" > "$HOME/.config/desktop-profile/active"

    systemctl --user daemon-reload >/dev/null 2>&1 || true
    systemctl --user stop end4-media-backend.service >/dev/null 2>&1 || true

    if command -v serpantinumd >/dev/null 2>&1; then
        serpantinumd stop >/dev/null 2>&1 || true
    fi

    case "$active" in
        end4)
            systemctl --user start end4-media-backend.service >/dev/null 2>&1 || true
            ;;
        serpantinum)
            command -v serpantinumd >/dev/null 2>&1 &&
                serpantinumd start >/dev/null 2>&1 || true
            ;;
    esac
}

install_background_music() {
    local src="$REPO/dual-rice"
    local playlist="$HOME/Music/Favorites.m3u8"

    log "Installing background music service and controls"

    mkdir -p \
        "$HOME/.local/bin" \
        "$HOME/.config/systemd/user" \
        "$HOME/.local/lib/huzaifah/mpv-mpris" \
        "$HOME/Music"

    install -m 0755 \
        "$src/bin/background-music" \
        "$HOME/.local/bin/background-music"

    install -m 0755 \
        "$BIN_DIR/mpv-mpris-huzaifah.so" \
        "$HOME/.local/lib/huzaifah/mpv-mpris/mpris.so"

    install -m 0644 \
        "$src/systemd/user/background-music.service" \
        "$HOME/.config/systemd/user/background-music.service"

    # v4.1 replaces the old separate stop helper with:
    # background-music quit
    rm -f "$HOME/.local/bin/background-music-stop"

    # Preserve an existing personal playlist. Use the bundled one only
    # when no playlist exists yet.
    if [[ ! -s "$playlist" ]]; then
        cp -a "$src/music/Favorites.m3u8" "$playlist"
    fi

    # Make old /home/<username>/Music paths portable across reinstalls.
    if [[ -f "$playlist" ]]; then
        sed -Ei "s#^/home/[^/]+/Music/#$HOME/Music/#" "$playlist"
    fi

    systemctl --user daemon-reload
    systemctl --user enable background-music.service >/dev/null 2>&1 || true

    if "$HOME/.local/bin/background-music" restart >/dev/null 2>&1; then
        ok "Background music service installed and running"
    else
        warn "Background music was installed and enabled, but no playable local music was available to start it now"
    fi
}

install_night_light() {
    local src="$REPO/dual-rice"
    local shared="$HOME/.config/huzaifah/hyprsunset.conf"

    log "Installing shared night-light controls"

    command -v hyprsunset >/dev/null 2>&1 ||
        die "hyprsunset is missing after offline package installation"

    mkdir -p         "$HOME/.local/bin"         "$HOME/.config/huzaifah"

    install -m 0755         "$src/bin/toggle-night-light"         "$HOME/.local/bin/toggle-night-light"

    # Preserve an existing shared state when reinstalling v4.1.
    # On first migration, preserve the previous active rice state.
    if [[ ! -s "$shared" ]]; then
        if [[ -s "$BACKUP/hyprsunset-shared-config" ]]; then
            cp -a "$BACKUP/hyprsunset-shared-config" "$shared"
        elif [[ -s "$BACKUP/hyprsunset-active-config" ]]; then
            cp -a "$BACKUP/hyprsunset-active-config" "$shared"
        else
            printf "profile {
    time = 00:00
    identity = true
}
" > "$shared"
        fi
    fi

    # This also creates/repairs the shared hyprsunset.conf symlink
    # inside every installed rice.
    "$HOME/.local/bin/toggle-night-light" status >/dev/null

    systemctl --user daemon-reload
    systemctl --user enable hyprsunset.service >/dev/null 2>&1 || true

    if systemctl --user restart hyprsunset.service >/dev/null 2>&1; then
        ok "Shared night-light configuration installed"
    else
        warn "Night-light configuration installed, but hyprsunset could not start in the current session"
    fi
}

install_refresh_switcher() {
    install_named_local jq fuzzel upower
    bash "$REPO/scripts/install-refresh-switcher.sh" --auto
}

install_multi_rice() {
    verify_payload
    create_install_snapshot
    install_all_local_packages
    systemctl --user disable --now dms.service >/dev/null 2>&1 || true
    restore_profiles_and_configs
    install_night_light
    install_background_music
    restore_bundled_sources
    configure_end4_search_only
    activate_saved_profile
    install_refresh_switcher
    install_frieren_theme
    activate_sddm_for_next_boot
    configure_sddm_multi_rice
    finalize_install_snapshot
    ok "Fully offline Multi-Rice v5.0.0 installation completed"
    printf "Transactional rollback snapshot: %s
" "$HUZ_INSTALL_STATE"
    printf "No internet connection was required.
"
}

run_system_setup() {
    local cmd="$1"; shift || true
    [[ -x "$REPO/system-setup.sh" ]] || die "Bundled system-setup.sh is missing"
    bash "$REPO/system-setup.sh" "$cmd" "$@"
}

uninstall_multi_rice_packages() {
    local state pkg
    local -a candidates=()
    local -a installed=()

    state="$(latest_install_snapshot || true)"

    if [[ -n "$state" && -d "$state" && ! -f "$state/restored-at" ]]; then
        warn "Restore the previous desktop first before removing Multi-Rice-added packages."
        return 2
    fi

    if [[ -n "$state" && -f "$state/packages-cleaned-at" ]]; then
        printf "\nThe Multi-Rice-added package cleanup has already been completed.\n"
        printf "Nothing was removed.\n"
        return 0
    fi

    if [[ -z "$state" || ! -f "$state/packages-added.txt" ]]; then
        printf "\nNo v5.0.0 package-addition manifest was found.\n"
        printf "Nothing was removed.\n"
        return 0
    fi

    while IFS= read -r pkg; do
        [[ -n "$pkg" ]] || continue
        candidates+=("$pkg")
        pacman -Q "$pkg" >/dev/null 2>&1 && installed+=("$pkg")
    done < "$state/packages-added.txt"

    if ((${#installed[@]} == 0)); then
        printf "\nNo packages originally added by Multi-Rice remain installed.\n"
        return 0
    fi

    printf "\nPackages recorded as added by this v5.0.0 installation:\n\n"
    printf "  %s\n" "${installed[@]}"

    printf "\nOnly packages absent before installation are candidates.\n"
    printf "Pacman will still perform dependency checks before removal.\n\n"

    prompt_yes_no "Remove these Multi-Rice-added packages with pacman -Rns?" n || {
        log "Package cleanup cancelled"
        return 0
    }

    sudo pacman -Rns -- "${installed[@]}"
    printf "%s\n" "$(date --iso-8601=seconds)" > "$state/packages-cleaned-at"
}

status_report() {
    printf '\nHuzaifah Multi-Rice OFFLINE Status\n'
    printf '==================================\n'
    printf 'Machine:       %s / %s\n' "$(current_vendor)" "$(current_product)"
    printf 'G16 detected:  %s\n' "$(is_g16 && echo yes || echo no)"
    [[ -f "$PAYLOAD/manifest.txt" ]] && { printf '\nPayload manifest:\n'; cat "$PAYLOAD/manifest.txt"; }
    printf '\nSystem setup status:\n'
    run_system_setup status || true
}

usage() {
    cat <<'EOF'
Usage: install-offline.sh ACTION

Actions:
  preflight     Verify payload and target-machine readiness without changing it
  install       Install all 10 rices + switchers + Frieren SDDM theme
  uninstall     Restore the exact pre-install desktop snapshot
  uninstall-packages
                Remove packages recorded as added by the v5.0.0 installation
  refresh       Install/reconfigure SUPER+SHIFT+R refresh switcher
  sddm          Install Frieren SDDM theme only
  grub          Open optional silent Evangelion GRUB chooser
  asus          Install generic ASUS support (asusctl/ROG Control Center)
  g16           Install guarded Zephyrus G16 extras
  hibernate     Configure guarded Btrfs hibernation storage
  status        Show machine/offline-payload status
EOF
}

main() {
    local action="${1:-install}"
    is_arch_family || die "This offline installer supports Arch/CachyOS-family systems only"
    [[ "$(uname -m)" == x86_64 ]] || die "This offline build targets x86_64 only"
    case "$action" in
        preflight) preflight_report ;;
        install) install_multi_rice ;;
        uninstall) uninstall_multi_rice ;;
        uninstall-packages) uninstall_multi_rice_packages ;;
        refresh) verify_payload; install_refresh_switcher ;;
        sddm) verify_payload; install_named_local sddm rsync; install_frieren_theme ;;
        grub) configure_evangelion_grub ;;
        asus) verify_payload; install_named_local asusctl rog-control-center power-profiles-daemon; run_system_setup asus ;;
        g16) verify_payload; install_named_local asusctl rog-control-center power-profiles-daemon supergfxctl; run_system_setup g16 ;;
        hibernate) verify_payload; install_named_local btrfs-progs; run_system_setup hibernate ;;
        status) status_report ;;
        help|-h|--help) usage ;;
        *) die "Unknown action: $action" ;;
    esac
}

main "$@"
