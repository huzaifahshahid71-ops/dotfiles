#!/usr/bin/env bash
# ZEPHYRUS v6 Tahoe — guarded SDDM session installer.
# Development branch only. --check is read-only apart from temporary files.
set -euo pipefail

MODE="${1:-}"
case "$MODE" in
  --check|--install|--rollback) ;;
  *) printf 'Usage: %s --check|--install|--rollback\n' "$0" >&2; exit 2 ;;
esac

REPO="huzaifahshahid71-ops/dotfiles"
BRANCH="v6.0-tahoe-dev"
RAW="https://raw.githubusercontent.com/$REPO/$BRANCH/v6/tahoe/session"
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

USER_DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
USER_STATE="${XDG_STATE_HOME:-$HOME/.local/state}"
CONFIG_DIR="$USER_DATA/zephyrus-v6/tahoe-session"
CONFIG_TARGET="$CONFIG_DIR/hyprland.lua"
LAUNCHER_TARGET="/usr/local/bin/zephyrus-tahoe-session"
DESKTOP_TARGET="/usr/share/wayland-sessions/zephyrus-tahoe.desktop"
BACKUP_ROOT="$USER_STATE/zephyrus-v6/session-backups"

tmp=""
cleanup() { [[ -n "$tmp" ]] && rm -rf -- "$tmp"; }
trap cleanup EXIT

log() { printf '\n==> %s\n' "$*"; }
ok() { printf 'PASS: %s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

[[ "${EUID:-$(id -u)}" -ne 0 ]] || die "Run as your normal user, not root."

get_sources() {
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/zephyrus-tahoe-install.XXXXXXXX")"
  local names=(hyprland.lua zephyrus-tahoe-session zephyrus-tahoe.desktop)
  local name
  for name in "${names[@]}"; do
    if [[ -r "$SELF_DIR/$name" ]]; then
      cp -- "$SELF_DIR/$name" "$tmp/$name"
    else
      command -v curl >/dev/null 2>&1 || die "curl is required to fetch staged Tahoe sources."
      curl -fsSLo "$tmp/$name" "$RAW/$name" ||
        die "Could not fetch $name from the v6 development branch."
    fi
  done
}

preflight() {
  log "Checking SDDM and existing sessions (no changes)"
  local dm
  dm="$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null || true)"
  [[ "$dm" == "/usr/lib/systemd/system/sddm.service" ]] ||
    die "Expected SDDM, found: ${dm:-none}"

  local required_sessions=(
    /usr/share/wayland-sessions/huzaifah-multi-rice.desktop
    /usr/share/wayland-sessions/hyprland.desktop
    /usr/share/wayland-sessions/hyprland-uwsm.desktop
    /usr/share/wayland-sessions/niri.desktop
  )
  local f
  for f in "${required_sessions[@]}"; do
    [[ -r "$f" ]] || die "Existing recovery session missing: $f"
  done
  ok "SDDM and all four existing Wayland session entries are present"

  [[ "$(command -v start-hyprland || true)" == "/usr/bin/start-hyprland" ]] ||
    die "/usr/bin/start-hyprland is required"
  [[ "$(command -v foot || true)" == "/usr/bin/foot" ]] ||
    die "/usr/bin/foot is required"
  command -v Hyprland >/dev/null 2>&1 || die "Hyprland is unavailable"
  ok "Hyprland watchdog and recovery terminal are available"

  get_sources

  log "Validating staged files"
  bash -n "$tmp/zephyrus-tahoe-session"
  grep -Fq 'exec start-hyprland -- --config "$config"' "$tmp/zephyrus-tahoe-session" ||
    die "Staged launcher does not use the expected watchdog handoff"
  grep -Fq 'Name=ZEPHYRUS Tahoe (Experimental)' "$tmp/zephyrus-tahoe.desktop" ||
    die "Unexpected SDDM entry name"
  grep -Fq 'Exec=/usr/local/bin/zephyrus-tahoe-session' "$tmp/zephyrus-tahoe.desktop" ||
    die "Unexpected SDDM launcher path"

  ! grep -Eq 'hl[.]plugin[.]load|hyprpm|systemctl|sudo|pacman|require[(]|dofile[(]|loadfile[(]' "$tmp/hyprland.lua" ||
    die "Baseline Lua config contains a forbidden plugin/package/import action"
  grep -Fq 'hl.bind("SUPER + RETURN", hl.dsp.exec_cmd("foot"))' "$tmp/hyprland.lua" ||
    die "Recovery terminal binding missing"
  grep -Fq 'hl.bind("SUPER + SHIFT + E", hl.dsp.exit())' "$tmp/hyprland.lua" ||
    die "Session exit binding missing"

  Hyprland --verify-config --config "$tmp/hyprland.lua" >/dev/null ||
    die "Hyprland rejected the staged Tahoe Lua configuration"
  ok "Standalone plugin-free Tahoe config passes Hyprland verification"

  log "Collision check"
  [[ ! -e "$DESKTOP_TARGET" ]] && ok "No existing Tahoe SDDM entry" ||
    warn "$DESKTOP_TARGET already exists; installer will back it up before replacement"
  [[ ! -e "$LAUNCHER_TARGET" ]] && ok "No existing Tahoe launcher" ||
    warn "$LAUNCHER_TARGET already exists; installer will back it up before replacement"
  [[ ! -e "$CONFIG_TARGET" ]] && ok "No existing Tahoe user config" ||
    warn "$CONFIG_TARGET already exists; installer will back it up before replacement"

  printf '\nPlanned files only:\n'
  printf '  %s\n  %s\n  %s\n' "$CONFIG_TARGET" "$LAUNCHER_TARGET" "$DESKTOP_TARGET"
  printf '%s\n' "Existing Multi-Rice/Hyprland/UWSM/Niri entries and SDDM state.conf are not modified."
}

backup_one() {
  local src="$1" label="$2" backup="$3"
  if [[ -e "$src" || -L "$src" ]]; then
    if [[ "$src" == /usr/* ]]; then
      sudo cp -a -- "$src" "$backup/$label"
    else
      cp -a -- "$src" "$backup/$label"
    fi
    printf 'present\n' > "$backup/$label.state"
  else
    printf 'absent\n' > "$backup/$label.state"
  fi
}

install_session() {
  preflight

  printf '\nThis will ADD a fifth SDDM session named "ZEPHYRUS Tahoe (Experimental)".\n'
  printf '%s\n' "It will NOT make Tahoe the default session and will NOT modify SDDM state.conf."
  printf 'Type exactly INSTALL TAHOE to continue: '
  IFS= read -r answer
  [[ "$answer" == "INSTALL TAHOE" ]] || die "Installation cancelled."

  local stamp backup
  stamp="$(date +%Y%m%d-%H%M%S)"
  backup="$BACKUP_ROOT/$stamp"
  mkdir -p -- "$backup"

  log "Backing up only Tahoe-owned target paths"
  backup_one "$CONFIG_TARGET" "hyprland.lua" "$backup"
  backup_one "$LAUNCHER_TARGET" "zephyrus-tahoe-session" "$backup"
  backup_one "$DESKTOP_TARGET" "zephyrus-tahoe.desktop" "$backup"

  printf '%s\n' "$backup" > "$BACKUP_ROOT/latest"

  log "Installing isolated user config"
  install -d -m 0755 "$CONFIG_DIR"
  install -m 0644 "$tmp/hyprland.lua" "$CONFIG_TARGET"

  log "Registering unique SDDM session files"
  sudo install -m 0755 "$tmp/zephyrus-tahoe-session" "$LAUNCHER_TARGET"
  sudo install -m 0644 "$tmp/zephyrus-tahoe.desktop" "$DESKTOP_TARGET"

  ok "Tahoe session installed as an additional SDDM choice"
  printf '%s\n' "Do NOT change SDDM defaults. Log out normally and select ZEPHYRUS Tahoe (Experimental) manually."
  printf '%s\n' "Inside Tahoe: Super+Enter opens Foot; Super+Shift+E exits the compositor."
  printf 'Rollback snapshot: %s\n' "$backup"
}

restore_one() {
  local target="$1" label="$2" backup="$3" privileged="$4"
  local state="$backup/$label.state"
  [[ -r "$state" ]] || die "Backup state missing: $state"
  if grep -qx 'present' "$state"; then
    [[ -e "$backup/$label" || -L "$backup/$label" ]] ||
      die "Backup payload missing: $backup/$label"
    if [[ "$privileged" == 1 ]]; then
      sudo cp -a -- "$backup/$label" "$target"
    else
      mkdir -p -- "$(dirname "$target")"
      cp -a -- "$backup/$label" "$target"
    fi
  else
    if [[ "$privileged" == 1 ]]; then
      sudo rm -f -- "$target"
    else
      rm -f -- "$target"
    fi
  fi
}

rollback_session() {
  local latest="$BACKUP_ROOT/latest"
  [[ -r "$latest" ]] || die "No Tahoe installer rollback snapshot is recorded."
  local backup
  backup="$(cat "$latest")"
  [[ -d "$backup" ]] || die "Recorded backup directory is missing: $backup"

  printf 'Rollback using %s? Type exactly ROLLBACK TAHOE: ' "$backup"
  IFS= read -r answer
  [[ "$answer" == "ROLLBACK TAHOE" ]] || die "Rollback cancelled."

  restore_one "$CONFIG_TARGET" "hyprland.lua" "$backup" 0
  restore_one "$LAUNCHER_TARGET" "zephyrus-tahoe-session" "$backup" 1
  restore_one "$DESKTOP_TARGET" "zephyrus-tahoe.desktop" "$backup" 1
  ok "Restored the three Tahoe-owned paths to their pre-install states"
}

case "$MODE" in
  --check) preflight ;;
  --install) install_session ;;
  --rollback) rollback_session ;;
esac
