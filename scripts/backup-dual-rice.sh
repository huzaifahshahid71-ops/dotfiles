#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$REPO_ROOT/dual-rice"
PROFILE_ROOT="$HOME/.local/share/desktop-profiles"
PUSH=0

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARNING:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
    cat <<'EOF'
Usage: ./scripts/backup-dual-rice.sh [--push]

Backs up the currently working Caelestia + end4-pC + Ambxst + DankMaterialShell
Multi-Rice setup into this dotfiles repository. The historical dual-rice path
and script names are kept for compatibility.

With --push, the script also commits and pushes the generated snapshot.
Caches, SSH keys, .env files and obvious credential files are excluded.
EOF
}

for arg in "$@"; do
    case "$arg" in
        --push) PUSH=1 ;;
        --help|-h) usage; exit 0 ;;
        *) die "Unknown option: $arg" ;;
    esac
done

command -v git >/dev/null 2>&1 || die "git is required"
command -v rsync >/dev/null 2>&1 || die "rsync is required"
[[ -d "$REPO_ROOT/.git" ]] || die "$REPO_ROOT is not a Git repository"

for profile in caelestia end4 ambxst dms; do
    [[ -d "$PROFILE_ROOT/$profile/hypr" ]] || die "$profile profile not found"
    [[ -f "$PROFILE_ROOT/$profile/hypr/hyprland.lua" ]] || die "$profile hyprland.lua missing"
done

log "Preparing Multi-Rice snapshot"
mkdir -p \
    "$DEST/profiles/caelestia/hypr" \
    "$DEST/profiles/end4/hypr" \
    "$DEST/profiles/ambxst/hypr" \
    "$DEST/profiles/dms/hypr" \
    "$DEST/caelestia" \
    "$DEST/end4" \
    "$DEST/ambxst/config" \
    "$DEST/dms/config" \
    "$DEST/desktop-switcher" \
    "$DEST/bin" \
    "$DEST/systemd/user" \
    "$DEST/music" \
    "$DEST/packages" \
    "$DEST/versions" \
    "$DEST/state"

RSYNC_EXCLUDES=(
    --exclude='.git/'
    --exclude='.cache/'
    --exclude='cache/'
    --exclude='Cache/'
    --exclude='*.log'
    --exclude='*.bak'
    --exclude='*.backup'
    --exclude='*.old'
    --exclude='.env'
    --exclude='.env.*'
    --exclude='*.pem'
    --exclude='*.key'
    --exclude='id_rsa*'
    --exclude='id_ed25519*'
    --exclude='*token*'
    --exclude='*secret*'
)

for profile in caelestia end4 ambxst dms; do
    log "Backing up $profile Hyprland profile"
    rsync -a --delete "${RSYNC_EXCLUDES[@]}" \
        "$PROFILE_ROOT/$profile/hypr/" \
        "$DEST/profiles/$profile/hypr/"
done

if [[ -d "$HOME/.config/caelestia" ]]; then
    log "Backing up Caelestia user configuration"
    rsync -a --delete "${RSYNC_EXCLUDES[@]}" \
        "$HOME/.config/caelestia/" \
        "$DEST/caelestia/"
fi

if [[ -f "$HOME/.config/illogical-impulse/config.json" ]]; then
    log "Backing up end4 widget/bar layout"
    cp -a "$HOME/.config/illogical-impulse/config.json" \
        "$DEST/end4/config.json"
fi

if [[ -d "$HOME/.config/ambxst" ]]; then
    log "Backing up Ambxst user configuration"
    rsync -a --delete "${RSYNC_EXCLUDES[@]}" \
        "$HOME/.config/ambxst/" \
        "$DEST/ambxst/config/"
fi

# Ambxst keeps the selected wallpaper directory in its cache tree. Preserve
# only this small portable state file, not thumbnails or other caches.
if [[ -f "$HOME/.cache/ambxst/wallpapers.json" ]]; then
    log "Backing up Ambxst wallpaper directory state"
    cp -a "$HOME/.cache/ambxst/wallpapers.json" \
        "$DEST/ambxst/wallpapers.json"
fi

if [[ -d "$HOME/.config/DankMaterialShell" ]]; then
    log "Backing up DMS user configuration"
    rsync -a --delete "${RSYNC_EXCLUDES[@]}" \
        "$HOME/.config/DankMaterialShell/" \
        "$DEST/dms/config/"
fi

if [[ -d "$HOME/.config/desktop-switcher" ]]; then
    log "Backing up desktop-switcher theme"
    rsync -a --delete "${RSYNC_EXCLUDES[@]}" \
        "$HOME/.config/desktop-switcher/" \
        "$DEST/desktop-switcher/"
fi

for bin in desktop-switch recover-caelestia; do
    if [[ -f "$HOME/.local/bin/$bin" ]]; then
        install -m 0755 "$HOME/.local/bin/$bin" "$DEST/bin/$bin"
    fi
done

if [[ -f "$HOME/.config/systemd/user/background-music.service" ]]; then
    cp -a "$HOME/.config/systemd/user/background-music.service" \
        "$DEST/systemd/user/background-music.service"
fi

# The playlist itself is portable text; music files are intentionally not copied.
for playlist in "$HOME/Music/Favorites.m3u8" "$HOME/Music/favorites.m3u8"; do
    if [[ -f "$playlist" ]]; then
        cp -a "$playlist" "$DEST/music/$(basename "$playlist")"
        break
    fi
done

log "Recording package and version manifests"
pacman -Qqe | sort > "$DEST/packages/pacman-explicit.txt"
pacman -Qqm | sort > "$DEST/packages/aur-foreign.txt"

hyprctl version > "$DEST/versions/hyprland.txt" 2>&1 || true
qs --version > "$DEST/versions/quickshell.txt" 2>&1 || true
caelestia --version > "$DEST/versions/caelestia.txt" 2>&1 || true
ambxst version > "$DEST/versions/ambxst.txt" 2>&1 || true
axctl --version > "$DEST/versions/axctl.txt" 2>&1 || true
dms version > "$DEST/versions/dms.txt" 2>&1 || true

if [[ -d "$HOME/.config/quickshell/end4-pC/.git" ]]; then
    git -C "$HOME/.config/quickshell/end4-pC" rev-parse HEAD \
        > "$DEST/versions/end4-pC.commit"
    git -C "$HOME/.config/quickshell/end4-pC" diff --binary \
        > "$DEST/versions/end4-pC-local.patch"
fi

if [[ -d "$HOME/.local/src/end4-dots/.git" ]]; then
    git -C "$HOME/.local/src/end4-dots" rev-parse HEAD \
        > "$DEST/versions/end4-dots.commit"
    git -C "$HOME/.local/src/end4-dots" diff --binary \
        > "$DEST/versions/end4-dots-local.patch"
fi

if [[ -d "$HOME/.local/src/ambxst/.git" ]]; then
    git -C "$HOME/.local/src/ambxst" rev-parse HEAD \
        > "$DEST/versions/ambxst.commit"
    git -C "$HOME/.local/src/ambxst" diff --binary \
        > "$DEST/versions/ambxst-local.patch"
fi

if [[ -f "$HOME/.config/desktop-profile/active" ]]; then
    cp -a "$HOME/.config/desktop-profile/active" "$DEST/state/active"
elif [[ -L "$HOME/.config/hypr" ]]; then
    case "$(readlink -f "$HOME/.config/hypr")" in
        "$PROFILE_ROOT/caelestia/hypr") printf '%s\n' caelestia > "$DEST/state/active" ;;
        "$PROFILE_ROOT/end4/hypr") printf '%s\n' end4 > "$DEST/state/active" ;;
        "$PROFILE_ROOT/ambxst/hypr") printf '%s\n' ambxst > "$DEST/state/active" ;;
        "$PROFILE_ROOT/dms/hypr") printf '%s\n' dms > "$DEST/state/active" ;;
        *) printf '%s\n' caelestia > "$DEST/state/active" ;;
    esac
else
    printf '%s\n' caelestia > "$DEST/state/active"
fi

cat > "$DEST/versions/snapshot.txt" <<EOF
Captured: $(date --iso-8601=seconds)
Host: $(hostname)
Kernel: $(uname -sr)
EOF

find "$DEST/versions" -type f -name '*-local.patch' -empty -delete

# Refuse to auto-push obvious credentials if they accidentally land in the snapshot.
secret_hits="$(grep -RIlE \
    '(^|[^[:alnum:]_])(password|passwd|api[_-]?key|access[_-]?token|refresh[_-]?token)[[:space:]]*[:=]' \
    "$DEST" 2>/dev/null || true)"
if [[ -n "$secret_hits" ]]; then
    warn "Possible credential-like assignments found. Review before pushing:"
    printf '%s\n' "$secret_hits" >&2
    [[ "$PUSH" -eq 0 ]] || die "Refusing --push until the flagged files are reviewed"
fi

ok "Multi-Rice snapshot updated at $DEST"
printf '\nSnapshot size:\n'
du -sh "$DEST"
printf '\nGit changes:\n'
git -C "$REPO_ROOT" status --short -- dual-rice scripts/backup-dual-rice.sh scripts/restore-dual-rice.sh

if (( PUSH )); then
    log "Committing Multi-Rice snapshot"
    git -C "$REPO_ROOT" add -- \
        dual-rice \
        scripts/backup-dual-rice.sh \
        scripts/restore-dual-rice.sh

    if git -C "$REPO_ROOT" diff --cached --quiet; then
        ok "Nothing changed; repository is already current"
        exit 0
    fi

    git -C "$REPO_ROOT" commit -m "Backup working Caelestia end4 Ambxst and DMS Multi-Rice setup"
    git -C "$REPO_ROOT" push
    ok "Multi-Rice backup pushed to GitHub"
else
    printf '\nReview the changes, then run:\n'
    printf '  %s --push\n' "$0"
fi