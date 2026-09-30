#!/usr/bin/env bash
# Tahoe v6 — pinned Hyprliquid build, not activation.
# No sudo, pacman, hyprpm, plugin load/unload, compositor reload or config edits.
set -euo pipefail

readonly REQUIRED_HYPR_SHA="efb50993780079460b0cbed1363e2166a2de1d9f"
# The 2026-09-30 hyprpm.toml mainline pin for Hyprland v0.56.2.
# This pinned revision includes an upstream unload-crash repair.
readonly HYPRLIQUID_SHA="c5442379542dc5e5c91cc385e3168172dd9d5ff9"
readonly UPSTREAM="https://github.com/zaregototsukai/hyprliquid.git"
readonly ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/zephyrus-v6"
readonly SOURCE="$ROOT/src/hyprliquid"
readonly BUILD="$ROOT/build/hyprliquid-v0562"
readonly OUTPUT="$ROOT/plugins/hyprliquid-v0562/libhyprliquid.so"

say() { printf '\n==> %s\n' "$*"; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

usage() {
    printf 'Usage: bash %s --check|--build\n' "$0" >&2
    exit 2
}

[[ "$#" -eq 1 ]] || usage
case "$1" in --check|--build) ;; *) usage ;; esac
[[ "${EUID:-$(id -u)}" != 0 ]] || fail "Do not run as root."

say "Verifying exact G16 Hyprland build"
command -v Hyprland >/dev/null 2>&1 || fail "Hyprland command not found."
version="$(Hyprland --version 2>&1 || true)"
printf '%s\n' "$version" | head -n 2
printf '%s\n' "$version" | grep -Fq "$REQUIRED_HYPR_SHA" ||
    fail "Different Hyprland commit. No plugin will be built for this ABI."

say "Checking compiler and system headers (no packages will be installed)"
missing=()
for tool in git cmake ninja pkg-config c++; do
    command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
done
if [[ "${#missing[@]}" -gt 0 ]]; then
    fail "Missing commands: ${missing[*]}. Install only after reviewing package dependencies."
fi
if ! pkg-config --exists hyprland; then
    fail "Hyprland pkg-config headers are missing. Check pkg-config --modversion hyprland; do not update Hyprland blindly."
fi
if ! pkg-config --modversion hyprland | grep -Eq '^0[.]56[.]2([.-]|$)'; then
    fail "The hyprland development metadata isn't 0.56.2. Do not mix plugin headers with the compositor."
fi
if [[ ! -r /usr/include/stb/stb_image.h && ! -r /usr/local/include/stb/stb_image.h &&
      ! -r /usr/include/stb_image.h ]]; then
    fail "stb_image.h is missing (Arch package: stb). No build attempted."
fi

printf 'Hyprland pkg-config: %s\n' "$(pkg-config --modversion hyprland)"
printf 'Build source commit: %s\n' "$HYPRLIQUID_SHA"
printf 'Destination: %s\n' "$OUTPUT"
if [[ "$1" == "--check" ]]; then
    say "PASS: preflight only; no downloads or build requested"
    exit 0
fi

say "Fetching pinned upstream source (user directory only)"
mkdir -p "$ROOT/src" "$ROOT/build" "$(dirname "$OUTPUT")"
if [[ -d "$SOURCE/.git" ]]; then
    existing_remote="$(git -C "$SOURCE" remote get-url origin 2>/dev/null || true)"
    [[ "$existing_remote" == "$UPSTREAM" ]] ||
        fail "Existing checkout has unexpected origin '$existing_remote'; refusing to overwrite."
else
    [[ ! -e "$SOURCE" ]] || fail "Source directory exists but isn't a Git checkout."
    git clone --quiet "$UPSTREAM" "$SOURCE"
fi

# Do not modify tracked files in an existing checkout.
[[ -z "$(git -C "$SOURCE" status --porcelain --untracked-files=no)" ]] ||
    fail "Source checkout has local changes; refusing to overwrite."
git -C "$SOURCE" fetch --quiet origin "$HYPRLIQUID_SHA" ||
    git -C "$SOURCE" fetch --quiet origin
git -C "$SOURCE" cat-file -e "$HYPRLIQUID_SHA^{commit}" ||
    fail "Pinned revision could not be retrieved; no fallback to 'latest'."
git -C "$SOURCE" checkout --quiet --detach "$HYPRLIQUID_SHA"
[[ "$(git -C "$SOURCE" rev-parse HEAD)" == "$HYPRLIQUID_SHA" ]] ||
    fail "Unexpected Git revision."

say "Compiling locally (limited to 3 concurrent jobs)"
# NO_SYSTEMD limits unrelated integration requirements; the glass shader
# and basic material rendering do not need portal color-scheme tracking.
cmake -S "$SOURCE" -B "$BUILD" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DNO_SYSTEMD=ON
cmake --build "$BUILD" --parallel 3

lib="$BUILD/libhyprliquid.so"
[[ -s "$lib" ]] || fail "Build finished without libhyprliquid.so."
install -m644 "$lib" "$OUTPUT"

say "BUILD COMPLETE — NO PLUGIN LOADED"
ls -lh -- "$OUTPUT"
sha256sum -- "$OUTPUT"
printf 'Verified source: %s\n' "$(git -C "$SOURCE" rev-parse HEAD)"
printf '%s\n' "No system files, Hyprland profiles, session plugins or autostart entries were changed."
printf '%s\n' "Do NOT run hyprctl plugin load yet. Next: isolated test session and recovery plan."
