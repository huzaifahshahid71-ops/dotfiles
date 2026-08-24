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

Backs up the currently working Caelestia + end4-pC dual-rice setup into
this dotfiles repository. With --push, the script also commits and pushes
only the dual-rice snapshot and this backup script's generated manifests.
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
[[ -d "$PROFILE_ROOT/caelestia/hypr" ]] || die "Caelestia profile not found"
[[ -d "$PROFILE_ROOT/end4/hypr" ]] || die "end4 profile not found"
[[ -f "$PROFILE_ROOT/caelestia/hypr/hyprland.lua" ]] || die "Caelestia hyprland.lua missing"
[[ -f "$PROFILE_ROOT/end4/hypr/hyprland.lua" ]] || die "end4 hyprland.lua missing"

log "Preparing dual-rice snapshot"
mkdir -p \
    "$DEST/profiles/caelestia/hypr" \
    "$DEST/profiles/end4/hypr" \
    "$DEST/caelestia" \
    "$DEST/desktop-switcher" \
    "$DEST/bin" \
    "$DEST/systemd/user" \
    "$DEST/music" \
    "$DEST/packages" \
    "$DEST/versions" \
    "$DEST/state"

# Common exclusions for anything copied from user configuration.
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

log "Backing up Caelestia Hyprland profile"
rsync -a --delete "${RSYNC_EXCLUDES[@]}" \
    "$PROFILE_ROOT/caelestia/hypr/" \
    "$DEST/profiles/caelestia/hypr/"

log "Backing up end4 Hyprland profile"
rsync -a --delete "${RSYNC_EXCLUDES[@]}" \
    "$PROFILE_ROOT/end4/hypr/" \
    "$DEST/profiles/end4/hypr/"

if [[ -d "$HOME/.config/caelestia" ]]; then
    log "Backing up Caelestia user configuration"
    rsync -a --delete "${RSYNC_EXCLUDES[@]}" \
        "$HOME/.config/caelestia/" \
        "$DEST/caelestia/"
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

if [[ -f "$HOME/.config/desktop-profile/active" ]]; then
    cp -a "$HOME/.config/desktop-profile/active" "$DEST/state/active"
elif [[ -L "$HOME/.config/hypr" ]]; then
    case "$(readlink -f "$HOME/.config/hypr")" in
        "$PROFILE_ROOT/caelestia/hypr") printf '%s\n' caelestia > "$DEST/state/active" ;;
        "$PROFILE_ROOT/end4/hypr") printf '%s\n' end4 > "$DEST/state/active" ;;
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

# Remove empty local patches so they don't create noise.
find "$DEST/versions" -type f -name '*-local.patch' -empty -delete

# Refuse to auto-push obvious credentials if they accidentally landed in the snapshot.
secret_hits="$(grep -RIlE \
    '(^|[^[:alnum:]_])(password|passwd|api[_-]?key|access[_-]?token|refresh[_-]?token)[[:space:]]*[:=]' \
    "$DEST" 2>/dev/null || true)"
if [[ -n "$secret_hits" ]]; then
    warn "Possible credential-like assignments found. Review before pushing:"
    printf '%s\n' "$secret_hits" >&2
    [[ "$PUSH" -eq 0 ]] || die "Refusing --push until the flagged files are reviewed"
fi

ok "Dual-rice snapshot updated at $DEST"
printf '\nSnapshot size:\n'
du -sh "$DEST"
printf '\nGit changes:\n'
git -C "$REPO_ROOT" status --short -- dual-rice scripts/backup-dual-rice.sh scripts/restore-dual-rice.sh

if (( PUSH )); then
    log "Committing dual-rice snapshot"
    git -C "$REPO_ROOT" add -- \
        dual-rice \
        scripts/backup-dual-rice.sh \
        scripts/restore-dual-rice.sh

    if git -C "$REPO_ROOT" diff --cached --quiet; then
        ok "Nothing changed; repository is already current"
        exit 0
    fi

    git -C "$REPO_ROOT" commit -m "Backup working Caelestia and end4 dual-rice setup"
    git -C "$REPO_ROOT" push
    ok "Dual-rice backup pushed to GitHub"
else
    printf '\nReview the changes, then run:\n'
    printf '  %s --push\n' "$0"
fi
