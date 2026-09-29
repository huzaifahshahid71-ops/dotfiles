#!/usr/bin/env bash
set -euo pipefail

QS_ROOT="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
SRC_ROOT="$HOME/.local/src"
QML_ROOT="$HOME/.local/lib/qt6/qml"
STATE_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/revo-v5.1"

RYOKU_URL="${RYOKU_URL:-https://github.com/Ryoku-dev/ryoku.git}"
RYOKU_REF="${RYOKU_REF:-98a0368253d9628be72b853985878a5db90e1547}"
RYOKU_SRC="$SRC_ROOT/ryoku-arch"

PERSONA_CAVA_URL="${PERSONA_CAVA_URL:-https://github.com/Yujonpradhananga/Qt6-Cava-plugin.git}"
PERSONA_CAVA_REF="${PERSONA_CAVA_REF:-23b108a7919da59d4eaaced5f0bf4cbe21867093}"
PERSONA_CAVA_SRC="$SRC_ROOT/persona-cava-v5.1"

VAST_URL="${VAST_URL:-https://github.com/myamusashi/vast-shell.git}"
VAST_REF="${VAST_REF:-e6b7474239a0f4b648e49db21cb0f1bab7aa922f}"
VAST_SRC="$SRC_ROOT/vast-shell-v5.1"

M3_URL="${M3_URL:-https://github.com/soramanew/m3shapes.git}"
M3_REF="${M3_REF:-8a6fe8961749887d677700b6508e0c9249968b7e}"
M3_SRC="$SRC_ROOT/m3shapes-v5.1"

RIPPLE_URL="${RIPPLE_URL:-https://github.com/myamusashi/Another-Ripple.git}"
RIPPLE_REF="${RIPPLE_REF:-d8b2a3b95d0515bc52e2143b786a87931841c840}"
RIPPLE_SRC="$SRC_ROOT/another-ripple-v5.1"

mkdir -p "$SRC_ROOT" "$QML_ROOT" "$STATE_ROOT"

log() { printf '==> %s\n' "$*"; }
ok() { printf '✓ %s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }

sync_repo() {
    local url="$1"
    local ref="$2"
    local dest="$3"
    local recursive="${4:-0}"

    if [[ -d "$dest/.git" ]]; then
        git -C "$dest" remote set-url origin "$url" >/dev/null 2>&1 || true
        git -C "$dest" fetch --quiet origin "$ref" || git -C "$dest" fetch --quiet origin
    else
        rm -rf "$dest"
        git clone --quiet "$url" "$dest"
    fi

    git -C "$dest" checkout --quiet --detach "$ref"

    if [[ "$recursive" == "1" ]]; then
        git -C "$dest" submodule update --init --recursive --quiet
    fi
}

is_virtual_machine() {
    command -v systemd-detect-virt >/dev/null 2>&1 &&
        systemd-detect-virt --quiet
}

find_qsb() {
    command -v qsb 2>/dev/null ||
        command -v qsb6 2>/dev/null ||
        find /usr/lib/qt6 /usr/lib/qt /opt/qt6 -name qsb -type f 2>/dev/null | head -n1 ||
        true
}

setup_ryoku() {
    log "Hydrating Ryoku source runtime"
    sync_repo "$RYOKU_URL" "$RYOKU_REF" "$RYOKU_SRC" 1

    if [[ ! -f "$RYOKU_SRC/ryoku/shell/dev-run.sh" ]]; then
        warn "Ryoku checkout is missing ryoku/shell/dev-run.sh"
        return 1
    fi

    if ! command -v go >/dev/null 2>&1; then
        warn "Ryoku source is ready, but 'go' is missing. Install the Arch package 'go'."
        return 1
    fi

    if ! command -v cmake >/dev/null 2>&1 || ! command -v ninja >/dev/null 2>&1; then
        warn "Ryoku source is ready, but cmake/ninja is missing."
        return 1
    fi

    ok "Ryoku source pinned at $RYOKU_REF"
}

disable_persona_cava() {
    local wallpaper="$QS_ROOT/persona-quickshell/Widgets/WallpaperEngine.qml"
    [[ -f "$wallpaper" ]] || return 1

    python - "$wallpaper" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
marker = "// HUZAIFAH_V51_CAVA_FALLBACK"

if marker in text:
    raise SystemExit(0)

block = """        CavaVisualizer {
            id: s1_cava
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                topMargin: 0
            }
            height: 555
        }

"""
if block not in text:
    raise SystemExit("Persona CavaVisualizer block changed; refusing unsafe fallback patch")

text = text.replace(block, "        " + marker + "\n", 1)
path.write_text(text, encoding="utf-8")
PY

    ok "Persona audio visualizer disabled as a compatibility fallback"
}

compile_qsb_compat() {
    local qsb="$1"
    local source="$2"
    local output="$3"
    local tmp="${output}.v51-tmp"

    [[ -f "$source" ]] || return 0
    rm -f "$tmp"

    if "$qsb" --glsl "430,330,300 es" --hlsl 50 --msl 12 \
        -o "$tmp" "$source" >/dev/null 2>&1; then
        mv -f "$tmp" "$output"
        ok "Baked VM-compatible shader: ${output#$QS_ROOT/}"
    else
        rm -f "$tmp"
        warn "Could not bake compatibility shader: $source"
    fi
}

setup_vm_graphics_compat() {
    local qsb=""
    local mac="$QS_ROOT/macos/modules/common"
    local eq="$QS_ROOT/eqsh"
    local src

    is_virtual_machine || return 0

    log "Applying virtual-GPU OpenGL compatibility"
    qsb="$(find_qsb)"

    if [[ -f "$eq/shell.qml" ]]; then
        python - "$eq/shell.qml" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
if "HUZAIFAH_V51_VM_OPENGL" not in text:
    text = text.replace(
        "//@ pragma Env QSG_RHI_BACKEND=vulkan",
        "// HUZAIFAH_V51_VM_OPENGL\n//@ pragma Env QSG_RHI_BACKEND=opengl",
        1,
    )
path.write_text(text, encoding="utf-8")
PY
        ok "EQSH renderer changed from Vulkan to OpenGL for this VM only"
    fi

    if [[ -f "$mac/LiquidGlassShader.qml" ]]; then
        python - "$mac/LiquidGlassShader.qml" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
text = text.replace(
    'fragmentShader: "shaders/glass.frag"',
    'fragmentShader: Qt.resolvedUrl("shaders/glass.frag.qsb")',
)
text = text.replace(
    'vertexShader: "shaders/glass.vert"',
    'vertexShader: Qt.resolvedUrl("shaders/glass.vert.qsb")',
)
path.write_text(text, encoding="utf-8")
PY
    fi

    if [[ -n "$qsb" ]]; then
        compile_qsb_compat "$qsb" "$mac/shaders/glass.frag" "$mac/shaders/glass.frag.qsb"
        compile_qsb_compat "$qsb" "$mac/shaders/glass.vert" "$mac/shaders/glass.vert.qsb"

        # EQSH hard-codes Vulkan upstream. Re-bake every shader whose GLSL
        # source ships with Revo so virgl can consume OpenGL 4.3/3.3 variants.
        if [[ -d "$eq/media/shaders" ]]; then
            while IFS= read -r -d '' src; do
                compile_qsb_compat "$qsb" "$src" "$src.qsb"
            done < <(find "$eq/media/shaders" -maxdepth 1 -type f \
                \( -name '*.frag' -o -name '*.vert' \) -print0)
        fi
    else
        warn "qsb is unavailable; VM renderer was patched but shaders could not be re-baked"
    fi
}

bootstrap_k4_state() {
    local state="${XDG_STATE_HOME:-$HOME/.local/state}/k4"
    local config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
    local hypr_theme="$config_home/hypr/config/k4-theme.lua"

    mkdir -p \
        "$state/plugins/pantallas" \
        "$state/plugins/agentes"

    [[ -s "$state/ajustes.json" ]] || printf '{}\n' > "$state/ajustes.json"
    [[ -s "$state/tokens.json" ]] || printf '{}\n' > "$state/tokens.json"
    [[ -s "$state/plugins.json" ]] || printf '{"habilitados":{}}\n' > "$state/plugins.json"
    [[ -s "$state/hyprtheme.json" ]] || printf '{}\n' > "$state/hyprtheme.json"
    [[ -s "$state/plugins/pantallas/estado.json" ]] || printf '{}\n' > "$state/plugins/pantallas/estado.json"
    [[ -s "$state/plugins/agentes/estado.json" ]] || printf '{}\n' > "$state/plugins/agentes/estado.json"

    if [[ -d "$(dirname "$hypr_theme")" && ! -e "$hypr_theme" ]]; then
        printf '%s\n' '-- Huzaifah v5.1: K4 writes its saved Hyprland theme here.' > "$hypr_theme"
    fi

    ok "K4 first-run state initialized"
}

setup_persona_cava() {
    local marker="$QML_ROOT/CavaMonitor/qmldir"
    local build="$PERSONA_CAVA_SRC/build-v51"

    if [[ -f "$marker" ]]; then
        ok "Persona CavaMonitor QML module already installed"
        return 0
    fi

    log "Building Persona CavaMonitor QML module"
    sync_repo "$PERSONA_CAVA_URL" "$PERSONA_CAVA_REF" "$PERSONA_CAVA_SRC" 0

    if ! command -v cmake >/dev/null 2>&1 ||
       ! command -v ninja >/dev/null 2>&1 ||
       ! command -v pkg-config >/dev/null 2>&1 ||
       ! pkg-config --exists libpipewire-0.3 fftw3; then
        warn "Persona CavaMonitor build dependencies are incomplete; using upstream-supported no-Cava fallback"
        disable_persona_cava
        return 0
    fi

    rm -rf "$build"
    if cmake -S "$PERSONA_CAVA_SRC" -B "$build" -G Ninja         -DCMAKE_BUILD_TYPE=Release         -DCMAKE_INSTALL_PREFIX="$QML_ROOT" &&
       cmake --build "$build" -j"$(nproc)" &&
       cmake --install "$build"; then
        ok "Persona CavaMonitor installed under $QML_ROOT/CavaMonitor"
        return 0
    fi

    warn "Persona CavaMonitor build failed; using upstream-supported no-Cava fallback"
    disable_persona_cava
}

build_m3shapes() {
    local marker="$QML_ROOT/M3Shapes/qmldir"
    local build="$M3_SRC/build-v51"

    [[ -f "$marker" ]] && {
        ok "M3Shapes QML module already installed"
        return 0
    }

    log "Building M3Shapes for Vast"
    sync_repo "$M3_URL" "$M3_REF" "$M3_SRC" 0
    rm -rf "$build"

    cmake -S "$M3_SRC" -B "$build" -G Ninja         -DCMAKE_BUILD_TYPE=Release         -DCMAKE_INSTALL_PREFIX="$HOME/.local"         -DCMAKE_INSTALL_LIBDIR=lib         -DINSTALL_QMLDIR=lib/qt6/qml         -DM3SHAPES_BUILD_EXAMPLES=OFF
    cmake --build "$build" -j"$(nproc)"
    cmake --install "$build"

    [[ -f "$marker" ]] || {
        warn "M3Shapes build completed but QML module marker is missing"
        return 1
    }
    ok "M3Shapes installed"
}

build_another_ripple() {
    local marker="$QML_ROOT/AnotherRipple/qmldir"
    local build="$RIPPLE_SRC/build-v51"

    [[ -f "$marker" ]] && {
        ok "AnotherRipple QML module already installed"
        return 0
    }

    log "Building AnotherRipple for Vast"
    sync_repo "$RIPPLE_URL" "$RIPPLE_REF" "$RIPPLE_SRC" 0
    rm -rf "$build"

    cmake -S "$RIPPLE_SRC/AnotherRipple" -B "$build" -G Ninja         -DCMAKE_BUILD_TYPE=Release         -DCMAKE_INSTALL_PREFIX="$HOME/.local"         -DCMAKE_INSTALL_LIBDIR=lib         -DINSTALL_QMLDIR=lib/qt6/qml
    cmake --build "$build" -j"$(nproc)"
    cmake --install "$build"

    [[ -f "$marker" ]] || {
        warn "AnotherRipple build completed but QML module marker is missing"
        return 1
    }
    ok "AnotherRipple installed"
}

compile_vast_assets() {
    local qsb=""
    local shaders="$VAST_SRC/Assets/shaders"
    local transition
    local name

    qsb="$(find_qsb)"
    [[ -n "$qsb" && -d "$shaders" ]] || return 0

    if [[ -f "$shaders/ImageTransition.vert" ]]; then
        "$qsb" --glsl "450,330,300 es" --hlsl 50 --msl 12             -o "$shaders/ImageTransition.vert.qsb" "$shaders/ImageTransition.vert" || true
    fi

    for name in fade wipeDown hexTile circleExpand dissolve splitHorizontal slideUp pixelate diagonalWipe boxExpand roll; do
        transition="$shaders/transitions/$name.frag"
        [[ -f "$transition" ]] || continue
        "$qsb" --glsl "450,330,300 es" --hlsl 50 --msl 12             -o "$transition.qsb" "$transition" || true
    done

    for name in borderProgress wavy waveForm; do
        [[ -f "$shaders/$name.vert" ]] &&
            "$qsb" --glsl "450,330,300 es" --hlsl 50 --msl 12                 -o "$shaders/$name.vert.qsb" "$shaders/$name.vert" || true
        [[ -f "$shaders/$name.frag" ]] &&
            "$qsb" --glsl "450,330,300 es" --hlsl 50 --msl 12                 -o "$shaders/$name.frag.qsb" "$shaders/$name.frag" || true
    done
}

compile_vast_translations() {
    local lrelease=""

    if [[ -x /usr/lib/qt6/bin/lrelease ]]; then
        lrelease=/usr/lib/qt6/bin/lrelease
    elif command -v lrelease >/dev/null 2>&1; then
        lrelease="$(command -v lrelease)"
    fi

    [[ -n "$lrelease" && -d "$VAST_SRC/translations" ]] || return 0
    "$lrelease" "$VAST_SRC"/translations/*.ts >/dev/null 2>&1 || true
}

setup_vast() {
    local marker="$QML_ROOT/Vast/Translation/qmldir"
    local build="$VAST_SRC/build-v51"

    log "Hydrating Vast source runtime"
    sync_repo "$VAST_URL" "$VAST_REF" "$VAST_SRC" 1

    if ! command -v cmake >/dev/null 2>&1 ||
       ! command -v ninja >/dev/null 2>&1 ||
       ! command -v pkg-config >/dev/null 2>&1; then
        warn "Vast source is ready, but cmake/ninja/pkg-config is missing"
        return 1
    fi

    for pc in libpipewire-0.3 ddcutil wayland-client; do
        if ! pkg-config --exists "$pc"; then
            warn "Vast requires pkg-config module '$pc'"
            return 1
        fi
    done

    build_m3shapes || return 1
    build_another_ripple || return 1

    if [[ ! -f "$marker" ]]; then
        log "Building Vast native QML modules"
        rm -rf "$build"
        cmake -S "$VAST_SRC" -B "$build" -G Ninja             -DCMAKE_BUILD_TYPE=Release             -DCMAKE_INSTALL_PREFIX="$HOME/.local"             -DCMAKE_INSTALL_LIBDIR=lib             -DINSTALL_QMLDIR=lib/qt6/qml
        cmake --build "$build" -j"$(nproc)"
        cmake --install "$build"
    fi

    [[ -f "$marker" ]] || {
        warn "Vast.Translation is still missing after build"
        return 1
    }

    mkdir -p "$HOME/.config/vast-shell"
    if [[ -d "$VAST_SRC/Data" ]]; then
        rsync -a --ignore-existing "$VAST_SRC/Data/" "$HOME/.config/vast-shell/"
    fi

    compile_vast_assets
    compile_vast_translations

    ok "Vast source and native QML modules are ready"
}

case "${1:---all}" in
    --all)
        # Stable release path: keep only support required by selectable shells.
        # K4/EQSH assets are still used by Mac; Ryoku/Vast are deliberately
        # not hydrated because those shells are disabled in the v5.1 catalog.
        bootstrap_k4_state || true
        setup_vm_graphics_compat || true
        setup_persona_cava || true
        ;;
    --persona)
        setup_persona_cava
        ;;
    --ryoku)
        setup_ryoku
        ;;
    --vast)
        setup_vast
        ;;
    --graphics)
        setup_vm_graphics_compat
        ;;
    --k4)
        bootstrap_k4_state
        ;;
    *)
        printf 'usage: %s [--all|--persona|--ryoku|--vast|--graphics|--k4]\n' "$0" >&2
        exit 2
        ;;
esac
