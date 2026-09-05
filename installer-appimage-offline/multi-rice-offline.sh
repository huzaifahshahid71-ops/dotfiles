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

secure_boot_enabled() {
    [[ -d /sys/firmware/efi/efivars ]] || return 1
    local var
    var="$(find /sys/firmware/efi/efivars -maxdepth 1 -name 'SecureBoot-*' -print -quit 2>/dev/null || true)"
    [[ -n "$var" ]] || return 1
    od -An -t u1 -j 4 -N 1 "$var" 2>/dev/null | grep -Eq '[[:space:]]1[[:space:]]*$'
}

setup_mode_enabled() {
    [[ -d /sys/firmware/efi/efivars ]] || return 1
    local var
    var="$(find /sys/firmware/efi/efivars -maxdepth 1 -name 'SetupMode-*' -print -quit 2>/dev/null || true)"
    [[ -n "$var" ]] || return 1
    od -An -t u1 -j 4 -N 1 "$var" 2>/dev/null | grep -Eq '[[:space:]]1[[:space:]]*$'
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
# v3.0.0 records the machine state BEFORE any Multi-Rice mutation.
# The snapshot preserves files/directories/symlinks exactly with tar.

managed_user_paths() {
    printf "%s\n" \
        ".config/hypr" \
        ".config/caelestia" \
        ".config/illogical-impulse" \
        ".config/ambxst" \
        ".config/DankMaterialShell" \
        ".config/noctalia" \
        ".config/desktop-switcher" \
        ".config/desktop-profile" \
        ".config/quickshell/ii" \
        ".config/quickshell/end4-pC" \
        ".config/systemd/user/background-music.service" \
        ".config/systemd/user/dms.service" \
        ".local/share/desktop-profiles" \
        ".local/share/ambxst" \
        ".local/state/noctalia" \
        ".local/src/ambxst" \
        ".local/src/end4-dots" \
        ".local/bin/desktop-switch" \
        ".local/bin/recover-caelestia" \
        ".local/bin/ambxst" \
        ".local/bin/refresh-switch" \
        ".cache/ambxst/wallpapers.json"
}

managed_system_paths() {
    printf "%s\n" \
        "usr/local/bin/axctl" \
        "usr/local/bin/ambxst" \
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

    log "Creating transactional v3.0.0 rollback snapshot BEFORE installation"
    mkdir -p "$state/packages"
    sudo mkdir -p "$system_state"

    {
        printf "version=3.0.0\n"
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
        printf "\nThis v3.0.0 rollback snapshot has already been restored.\n"
        printf "Nothing was changed.\n"
        return 0
    fi

    printf "\nHuzaifah Multi-Rice v3.0.0 rollback\n"
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
    [[ -d "$REPO/dual-rice" ]] || die "Offline payload is missing the dotfiles snapshot"
    [[ -d "$PKG_DIR" ]] || die "Offline payload is missing package archives"
    [[ -f "$PKG_DIR/huzaifah-offline.db" || -f "$PKG_DIR/huzaifah-offline.db.tar.gz" ]] || die "Offline pacman repository database is missing"
    [[ -s "$TARGETS_FILE" ]] || die "Offline target package list is missing"
    for profile in caelestia end4 ambxst dms noctalia; do
        [[ -f "$REPO/dual-rice/profiles/$profile/hypr/hyprland.lua" ]] || die "Missing $profile profile in offline payload"
    done
    [[ -f "$REPO/dual-rice/noctalia/config.toml" ]] || die "Missing Noctalia config in offline payload"
    [[ -f "$REPO/dual-rice/noctalia/settings.toml" ]] || die "Missing Noctalia settings in offline payload"
    [[ -d "$SOURCE_DIR/end4-dots" ]] || die "Bundled end4-dots source is missing"
    [[ -d "$SOURCE_DIR/end4-pC" ]] || die "Bundled end4-pC source is missing"
    [[ -d "$SOURCE_DIR/ambxst" ]] || die "Bundled Ambxst source is missing"
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

[huzaifah-offline]
SigLevel = Never
Server = file://$PKG_DIR
EOF
}

local_repo_has() {
    local pkg="$1" conf
    conf="$(mktemp --suffix=.conf)"
    make_pacman_conf "$conf"
    pacman --config "$conf" -Sl huzaifah-offline 2>/dev/null | awk '{print $2}' | grep -Fxq "$pkg"
    local rc=$?
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
    printf 'Secure Boot:   %s\n' "$(secure_boot_enabled && echo enabled || echo disabled)"
    printf 'Setup Mode:    %s\n' "$(setup_mode_enabled && echo enabled || echo disabled)"
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
    backup_path "$HOME/.config/caelestia" caelestia
    backup_path "$HOME/.config/illogical-impulse" illogical-impulse
    backup_path "$HOME/.config/ambxst" ambxst-config
    backup_path "$HOME/.config/DankMaterialShell" dms-config
    backup_path "$HOME/.config/noctalia" noctalia-config
    backup_path "$HOME/.local/state/noctalia" noctalia-state
    backup_path "$HOME/.local/share/ambxst" ambxst-share
    backup_path "$HOME/.local/src/ambxst" ambxst-source
    backup_path "$HOME/.cache/ambxst/wallpapers.json" ambxst-wallpapers.json
    backup_path "$HOME/.config/desktop-switcher" desktop-switcher
    backup_path "$PROFILE_ROOT" desktop-profiles
    backup_path "$HOME/.local/bin/desktop-switch" desktop-switch
    backup_path "$HOME/.local/bin/recover-caelestia" recover-caelestia

    log "Restoring Caelestia, end4-pC, Ambxst, DMS and Noctalia profiles"
    for profile in caelestia end4 ambxst dms noctalia; do
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

    if [[ -d "$src/desktop-switcher" ]]; then
        mkdir -p "$HOME/.config/desktop-switcher"
        rsync -a --delete "$src/desktop-switcher/" "$HOME/.config/desktop-switcher/"
    fi

    mkdir -p "$HOME/.local/bin"
    for bin in desktop-switch recover-caelestia; do
        [[ -f "$src/bin/$bin" ]] && install -m 0755 "$src/bin/$bin" "$HOME/.local/bin/$bin"
    done
}

restore_bundled_sources() {
    log "Installing bundled end4-pC, end4-dots and Ambxst source snapshots"
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
    command -v fish >/dev/null 2>&1 && fish -c 'fish_add_path ~/.local/bin' >/dev/null 2>&1 || true
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
    ok "Frieren SDDM login theme installed; display-manager/autologin state unchanged"
}

activate_saved_profile() {
    local active=caelestia
    [[ -f "$REPO/dual-rice/state/active" ]] && active="$(tr -d '[:space:]' < "$REPO/dual-rice/state/active")"
    case "$active" in caelestia|end4|ambxst|dms|noctalia) ;; *) active=caelestia ;; esac
    rm -rf "$HOME/.config/hypr"
    ln -s "$PROFILE_ROOT/$active/hypr" "$HOME/.config/hypr"
    mkdir -p "$HOME/.config/desktop-profile"
    printf '%s\n' "$active" > "$HOME/.config/desktop-profile/active"
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
    restore_bundled_sources
    configure_end4_search_only
    activate_saved_profile
    install_refresh_switcher
    install_frieren_theme
    finalize_install_snapshot
    ok "Fully offline Multi-Rice v3.0.0 installation completed"
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

find_refind_binary() {
    local esp p
    for esp in /boot/efi /efi /boot; do
        for p in "$esp/EFI/refind/refind_x64.efi" "$esp/EFI/REFIND/refind_x64.efi"; do
            [[ -f "$p" ]] && { printf '%s\n' "$p"; return 0; }
        done
    done
    return 1
}

sign_known_secure_boot_files() {
    local refind kernel
    refind="$(find_refind_binary || true)"
    [[ -n "$refind" ]] || die "rEFInd EFI binary was not found. Configure rEFInd first, then rerun Secure Boot setup."

    log "Registering/signing rEFInd with sbctl"
    sudo sbctl sign -s "$refind"

    local found=0
    for kernel in /boot/vmlinuz-*; do
        [[ -f "$kernel" ]] || continue
        found=1
        log "Registering/signing $(basename "$kernel")"
        sudo sbctl sign -s "$kernel"
    done
    (( found )) || warn "No /boot/vmlinuz-* kernel images were found; verify your UKI/kernel signing separately."
}

secure_boot_setup() {
    [[ -d /sys/firmware/efi ]] || die "System was not booted in UEFI mode"
    verify_payload
    install_named_local sbctl

    printf '\nCurrent Secure Boot status:\n'
    sudo sbctl status || true

    if secure_boot_enabled; then
        ok "Secure Boot is already enabled in firmware"
        printf '\nVerification only; no firmware keys will be changed.\n'
        sudo sbctl verify || true
        return 0
    fi

    if ! setup_mode_enabled; then
        warn "Firmware is not in Secure Boot Setup Mode."
        printf '\nBefore key enrollment, reboot into firmware settings and:\n'
        printf '  1. Disable Secure Boot.\n'
        printf '  2. Clear/delete the existing Secure Boot keys or select Custom/Setup Mode.\n'
        printf '  3. Boot Linux again and rerun this Secure Boot option.\n'
        printf '\nNo firmware keys were changed.\n'
        return 2
    fi

    [[ -n "$(find_refind_binary || true)" ]] || die "Configure rEFInd first. Secure Boot setup will not enroll keys without a known rEFInd binary to sign."

    warn "SECURE BOOT KEY ENROLLMENT CHANGES UEFI FIRMWARE VARIABLES."
    warn "This guided flow enrolls your sbctl keys together with Microsoft's keys (-m), preserving normal Windows/Microsoft trust."
    warn "Firmware implementations vary; incorrect key enrollment can make some pre-boot devices unavailable."
    printf '\nType ENROLL to continue, or anything else to cancel: '
    local ans
    read -r ans < /dev/tty || true
    [[ "$ans" == ENROLL ]] || { log "Secure Boot enrollment cancelled"; return 0; }

    if ! sudo test -d /var/lib/sbctl/keys; then
        sudo sbctl create-keys
    else
        log "Existing sbctl key directory detected; keeping the existing keys"
    fi

    sudo sbctl enroll-keys -m
    sign_known_secure_boot_files

    printf '\nPost-enrollment verification:\n'
    sudo sbctl status || true
    sudo sbctl verify || true

    ok "Keys enrolled and known Linux/rEFInd boot files registered with sbctl"
    printf '\nNext step is MANUAL: reboot into firmware and enable Secure Boot.\n'
    printf 'Do not delete Microsoft keys; this flow intentionally enrolled them alongside your keys.\n'
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
        printf "\nNo v3.0.0 package-addition manifest was found.\n"
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

    printf "\nPackages recorded as added by this v3.0.0 installation:\n\n"
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
    printf 'Secure Boot:   %s\n' "$(secure_boot_enabled && echo enabled || echo disabled)"
    printf 'Setup Mode:    %s\n' "$(setup_mode_enabled && echo enabled || echo disabled)"
    [[ -f "$PAYLOAD/manifest.txt" ]] && { printf '\nPayload manifest:\n'; cat "$PAYLOAD/manifest.txt"; }
    printf '\nSystem setup status:\n'
    run_system_setup status || true
}

usage() {
    cat <<'EOF'
Usage: install-offline.sh ACTION

Actions:
  preflight     Verify payload and target-machine readiness without changing it
  install       Install all five rices + switchers + Frieren SDDM theme
  uninstall     Restore the exact pre-install desktop snapshot
  uninstall-packages
                Remove packages recorded as added by the v3.0.0 installation
  refresh       Install/reconfigure SUPER+SHIFT+R refresh switcher
  sddm          Install Frieren SDDM theme only
  asus          Install generic ASUS support (asusctl/ROG Control Center)
  g16           Install guarded Zephyrus G16 extras
  refind        Configure rEFInd safely using the bundled theme
  secureboot    Guided sbctl Secure Boot setup with explicit enrollment gate
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
        asus) verify_payload; install_named_local asusctl rog-control-center power-profiles-daemon; run_system_setup asus ;;
        g16) verify_payload; install_named_local asusctl rog-control-center power-profiles-daemon supergfxctl; run_system_setup g16 ;;
        refind) verify_payload; install_named_local refind efibootmgr; run_system_setup refind ;;
        secureboot) secure_boot_setup ;;
        hibernate) verify_payload; install_named_local btrfs-progs; run_system_setup hibernate ;;
        status) status_report ;;
        help|-h|--help) usage ;;
        *) die "Unknown action: $action" ;;
    esac
}

main "$@"
