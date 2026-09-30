#!/usr/bin/env bash
# Install only the v6 Multi-Rice switcher theme-selector update.
# No sudo, no compositor reload, no rice/profile changes.
set -euo pipefail

MODE="${1:-}"
case "$MODE" in
  --check|--install|--rollback) ;;
  *) printf 'Usage: %s --check|--install|--rollback\n' "$0" >&2; exit 2 ;;
esac

RAW="https://raw.githubusercontent.com/huzaifahshahid71-ops/dotfiles/v6.0-tahoe-dev"
QML_TARGET="$HOME/.config/quickshell/multi-rice-switcher/shell.qml"
BACKEND_TARGET="$HOME/.local/bin/multi-rice-control"
STATE_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/zephyrus-v6/switcher-theme-backups"

tmp=""
cleanup() { [[ -n "$tmp" ]] && rm -rf -- "$tmp"; }
trap cleanup EXIT

log() { printf '\n==> %s\n' "$*"; }
ok() { printf 'PASS: %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

[[ "${EUID:-$(id -u)}" -ne 0 ]] || die "Run as your normal user, not root."

fetch_sources() {
  command -v curl >/dev/null 2>&1 || die "curl is required"
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/z6-switcher-themes.XXXXXXXX")"

  curl -fsSLo "$tmp/shell.qml"     "$RAW/dual-rice/quickshell/multi-rice-switcher/shell.qml"
  curl -fsSLo "$tmp/multi-rice-control"     "$RAW/dual-rice/bin/multi-rice-control"
}

preflight() {
  log "Checking current Multi-Rice switcher"
  [[ -r "$QML_TARGET" ]] || die "Missing installed switcher QML: $QML_TARGET"
  [[ -x "$BACKEND_TARGET" ]] || die "Missing executable switcher backend: $BACKEND_TARGET"
  command -v qs >/dev/null 2>&1 || die "Quickshell 'qs' is unavailable"

  fetch_sources

  bash -n "$tmp/multi-rice-control"
  grep -Fq 'set-theme)' "$tmp/multi-rice-control" ||
    die "Downloaded backend is missing theme support"
  grep -Fq 'id: themesButton' "$tmp/shell.qml" ||
    die "Downloaded QML is missing the top-right Themes control"
  grep -Fq 'text: "HUZAIFAH"' "$tmp/shell.qml" ||
    die "Downloaded QML is missing Huzaifah branding"
  grep -Fq 'id: compositorPage' "$tmp/shell.qml" ||
    die "Downloaded QML is missing the compositor home screen"
  grep -Fq 'Midnight Cyan' "$tmp/shell.qml" ||
    die "Downloaded QML is missing the Midnight Cyan theme entry"

  if command -v qmlformat >/dev/null 2>&1; then
    cp "$tmp/shell.qml" "$tmp/qml-check.qml"
    qmlformat -i "$tmp/qml-check.qml"
  elif [[ -x /usr/lib/qt6/bin/qmlformat ]]; then
    cp "$tmp/shell.qml" "$tmp/qml-check.qml"
    /usr/lib/qt6/bin/qmlformat -i "$tmp/qml-check.qml"
  fi

  ok "Theme-selector sources validate"
  printf 'Will update only:\n  %s\n  %s\n' "$QML_TARGET" "$BACKEND_TARGET"
  printf '%s\n' "Theme choice will live at ~/.config/desktop-switcher/theme."
  printf '%s\n' "No rice, Hyprland, Niri, SDDM, systemd or keybind files are modified."
}

install_update() {
  preflight

  printf '\nType exactly INSTALL SWITCHER THEMES to continue: '
  IFS= read -r answer
  [[ "$answer" == "INSTALL SWITCHER THEMES" ]] || die "Installation cancelled"

  local stamp backup
  stamp="$(date +%Y%m%d-%H%M%S)"
  backup="$STATE_ROOT/$stamp"
  mkdir -p "$backup"

  cp -a -- "$QML_TARGET" "$backup/shell.qml"
  cp -a -- "$BACKEND_TARGET" "$backup/multi-rice-control"
  printf '%s\n' "$backup" > "$STATE_ROOT/latest"

  install -d -m 0755 "$(dirname "$QML_TARGET")" "$(dirname "$BACKEND_TARGET")"
  install -m 0644 "$tmp/shell.qml" "$QML_TARGET"
  install -m 0755 "$tmp/multi-rice-control" "$BACKEND_TARGET"

  ok "Rices / Themes switcher update installed"
  printf 'Rollback snapshot: %s\n' "$backup"
  printf '%s\n' "Launch now with: qs -c multi-rice-switcher"
}

rollback_update() {
  local latest="$STATE_ROOT/latest"
  [[ -r "$latest" ]] || die "No switcher-theme rollback snapshot is recorded"

  local backup
  backup="$(cat "$latest")"
  [[ -r "$backup/shell.qml" ]] || die "Backup QML missing: $backup"
  [[ -r "$backup/multi-rice-control" ]] || die "Backup backend missing: $backup"

  printf 'Restore switcher snapshot %s? Type exactly ROLLBACK SWITCHER THEMES: ' "$backup"
  IFS= read -r answer
  [[ "$answer" == "ROLLBACK SWITCHER THEMES" ]] || die "Rollback cancelled"

  install -m 0644 "$backup/shell.qml" "$QML_TARGET"
  install -m 0755 "$backup/multi-rice-control" "$BACKEND_TARGET"
  ok "Previous Multi-Rice switcher restored"
}

case "$MODE" in
  --check) preflight ;;
  --install) install_update ;;
  --rollback) rollback_update ;;
esac
