#!/usr/bin/env bash
# The terminal greeting: system info beside a logo that fits the window.
#
# Three things it does that plain `fastfetch` does not:
#
#  1. Picks the logo size from the CURRENT terminal width, so a narrow window
#     gets a small logo (or none) instead of wrapping the info text into
#     nonsense. fastfetch prints once and cannot reflow afterwards, which is
#     why a window resized smaller stays broken - re-run this (`fetch`) and
#     it redraws at the new size.
#
#  2. Animates, when there is a GIF at $LOGO_GIF and the terminal is kitty.
#     fastfetch cannot do this: its kitty/kitty-direct logo sends a single
#     still. `kitten icat` transmits every frame and kitty then plays them
#     ITSELF - verified: icat exits and the image keeps moving - so this
#     costs no background process and does not hold up the prompt.
#
#  3. Falls back cleanly: static PNG in kitty without a GIF, text art
#     anywhere else (sixel would need ImageMagick, which is not installed).
set -uo pipefail

CFG="$HOME/.local/share/desktop-profiles/sayconlun/support/runtime/fastfetch"
LOGO_GIF="${LOGO_GIF:-$CFG/logo.gif}"
LOGO_PNG="${LOGO_PNG:-$CFG/logo.png}"

# side  - logo beside the info, the classic fetch look.
# stack - logo above it. Uglier, but it is the only one that survives the
#         window being made NARROWER: a side-by-side block carries the
#         logo's width as indent on every line, so shrinking wraps all of
#         them, doubles the block's height and scrolls it out of view.
LAYOUT="${RICE_FETCH_LAYOUT:-side}"

cols=$(tput cols 2>/dev/null || echo 80)
rows=$(tput lines 2>/dev/null || echo 24)

# Width tiers, derived from a MEASURED number rather than guessed: the info
# column of this fastfetch config is 59 columns at its widest (the CPU line),
# and the logo block costs pad_left + W + pad_right on top of that. So the
# logo only gets whatever is left after the text has what it needs, and below
# that it is dropped entirely - a logo that forces the info to wrap is worse
# than no logo.
# 55, measured by simulating the escapes rather than counting characters:
# fastfetch positions each value with an ESC[<n>G absolute-column jump, so a
# naive strip-and-count reads those four bytes as text and overstates the
# width. An earlier 60 came from exactly that mistake.
INFO_W=${INFO_W:-55}
CHROME=5                      # logo padding: 2 left + 3 right, from config.jsonc

if   (( cols >= INFO_W + CHROME + 44 )); then W=44; H=22; ART="$CFG/logo-large.txt"
elif (( cols >= INFO_W + CHROME + 30 )); then W=30; H=15; ART="$CFG/logo-small.txt"
elif (( cols >= INFO_W + CHROME + 20 )); then W=20; H=10; ART=""
else                                          W=0;  H=0;  ART=""
fi

# Below INFO_W the info column simply does not fit and the last few
# characters wrap. Nothing to be done: --key-width counts the icon glyph in
# the key, so any value low enough to save columns CLIPS the label ("screen"
# -> "scr") instead of tightening the gutter. A wrapped tail reads better
# than a truncated key.

# Never let the logo take more than the window is tall, either.
if (( H > rows - 6 )); then
    H=$(( rows - 6 )); W=$(( H * 2 ))
fi
(( H < 6 )) && { W=0; H=0; ART=""; }

pad_left=2
gap=3

# Pixel dimensions straight out of the file header - no PIL, no ImageMagick,
# and cheap enough to run on every new shell. GIF keeps w,h as little-endian
# uint16 at byte 6; PNG keeps them as big-endian uint32 at byte 16.
image_dims() {
    local f="$1"
    case "${f,,}" in
        *.gif) od -An -tu2 -j6  -N4 -- "$f" 2>/dev/null | tr -s ' ' ;;
        *.png) od -An -tu4 -j16 -N8 --endian=big -- "$f" 2>/dev/null | tr -s ' ' ;;
        *)     echo "" ;;
    esac
}

# Height in CELLS that keeps the image's aspect inside a W-cell-wide box.
# A terminal cell is about twice as tall as it is wide, so a 16:9 image in a
# 44x22 box would letterbox badly - it wants about 44x12. icat preserves
# aspect regardless, so getting this wrong only costs dead space, never
# distortion.
fit_height() {
    local w_cells="$1" iw="$2" ih="$3"
    [[ -z "$iw" || -z "$ih" || "$ih" -eq 0 ]] && { echo "$4"; return; }
    awk -v w="$w_cells" -v iw="$iw" -v ih="$ih" -v cap="$4" 'BEGIN{
        h = int(w * ih / iw / 2 + 0.5);
        if (h > cap) h = cap;
        if (h < 4)   h = 4;
        print h;
    }'
}

plain_fetch() {           # no logo at all - narrow windows
    fastfetch --logo-type none
}

art_fetch() {             # text art - non-kitty terminals
    if [[ -n "$ART" && -r "$ART" ]]; then
        fastfetch --logo-type file-raw --logo "$ART"
    elif (( W >= 44 )); then
        fastfetch                 # no art of your own: the distro logo
    else
        plain_fetch
    fi
}

cursor_row() {            # 0-based row of the cursor, via ESC[6n
    local pos row
    exec < /dev/tty
    old=$(stty -g); stty raw -echo min 0 time 3
    printf '\033[6n' > /dev/tty
    IFS=';' read -r -d R -a pos
    stty "$old"
    row="${pos[0]#*\[}"
    echo $(( row - 1 ))
}

stack_fetch() {           # logo above the info; reflows safely
    local src="$1" animate="$2" out n avail dims iw ih h w row
    # Render the text FIRST so its real height is known: stacking spends
    # vertical space the side-by-side layout did not, and an image sized
    # without accounting for it pushes the block past the window, scrolls,
    # and gets its top sheared off.
    out="$(fastfetch --logo-type none)"
    n=$(printf '%s\n' "$out" | wc -l)
    avail=$(( rows - n - 3 ))

    if (( avail < 4 )); then      # no room for a logo at all
        printf '%s\n' "$out"
        return
    fi

    dims=$(image_dims "$src"); read -r iw ih <<< "$dims"
    if [[ -z "$iw" || -z "$ih" || "$ih" -eq 0 ]]; then iw=16; ih=9; fi
    h=$avail
    (( h > 16 )) && h=16          # a taller logo than this just crowds the text
    # cells are ~2:1, so width follows from the height and the aspect
    w=$(awk -v h="$h" -v iw="$iw" -v ih="$ih" 'BEGIN{print int(h*2*iw/ih+0.5)}')
    (( w > cols - 4 )) && { w=$(( cols - 4 )); h=$(fit_height "$w" "$iw" "$ih" "$avail"); }

    row=$(cursor_row) || row=0
    if [[ "$animate" == yes ]]; then
        kitten icat -z -1 --loop=-1 --place="${w}x${h}@${pad_left}x${row}" "$src" 2>/dev/null
    else
        kitten icat -z -1 --place="${w}x${h}@${pad_left}x${row}" "$src" 2>/dev/null
    fi
    # --place parks the cursor at the block's top-left, so step past it.
    tput cud $(( h + 1 )) 2>/dev/null
    printf '%s\n' "$out"
}

image_fetch() {           # kitty: animated gif if present, else still png
    local src="$1" animate="$2" spacer out n r_after top dims

    # Shrink the reserved block to the image's own aspect, so a wide logo
    # does not sit in a tall box with empty rows above and below it.
    dims=$(image_dims "$src")
    if [[ -n "$dims" ]]; then
        read -r iw ih <<< "$dims"
        H=$(fit_height "$W" "$iw" "$ih" "$H")
        # A TALL image is limited by the height cap, not the width, so the
        # reserved block has to be narrowed to match or the info column is
        # indented past a wide box that the image only fills the middle of.
        # Narrowing it also shortens every line, which is what decides how
        # far the window can be shrunk before the block wraps.
        local wfit
        wfit=$(awk -v h="$H" -v iw="$iw" -v ih="$ih" 'BEGIN{print int(h*2*iw/ih+0.5)}')
        (( wfit > 0 && wfit < W )) && W=$wfit
    fi

    # Reserve the logo block with a BLANK text logo and let fastfetch lay the
    # info column out itself. Indenting fastfetch's own output by hand does
    # not work - it emits cursor-positioning escapes for the key/value
    # columns, and a leading pad shears the two columns apart.
    spacer="$(mktemp)"; trap 'rm -f "$spacer"' RETURN
    local i=0
    while (( i < H )); do printf '%*s\n' "$W" '' >> "$spacer"; i=$(( i + 1 )); done

    # --logo-width is REQUIRED, not decoration: config.jsonc declares
    # width 44 for its kitty-direct logo, and fastfetch keeps using that
    # figure for the reserved block even when the logo is replaced by a
    # narrower spacer - padding every line out to 44 columns and pushing the
    # text off the right edge. Passing the real width cuts the block from
    # 102 columns to 78 here.
    out="$(fastfetch --logo-type file-raw --logo "$spacer" \
                     --logo-width "$W" --logo-height "$H" 2>/dev/null)"
    printf '%s\n' "$out"
    n=$(printf '%s\n' "$out" | wc -l)

    # Work the block's position out BACKWARDS from where the cursor ended up,
    # so it stays correct even when the output scrolled the screen.
    r_after=$(cursor_row) || return 0
    top=$(( r_after - n + 1 ))          # +1 for the logo's top padding
    (( top < 0 )) && return 0

    if [[ "$animate" == yes ]]; then
        kitten icat -z -1 --loop=-1 --place="${W}x${H}@${pad_left}x${top}" "$src" 2>/dev/null
    else
        kitten icat -z -1 --place="${W}x${H}@${pad_left}x${top}" "$src" 2>/dev/null
    fi
    # --place parks the cursor at the logo's top-left. Put it back under the
    # block, or the prompt is printed over the top of the logo.
    printf '\033[%d;1H' $(( r_after + 1 ))
}

if (( W == 0 )) && [[ "$LAYOUT" != stack ]]; then
    plain_fetch
elif (( cols < 24 )); then
    plain_fetch
elif [[ -n "${KITTY_WINDOW_ID:-}" ]] && command -v kitten >/dev/null 2>&1; then
    draw=image_fetch
    [[ "$LAYOUT" == stack ]] && draw=stack_fetch
    if [[ -r "$LOGO_GIF" ]]; then
        "$draw" "$LOGO_GIF" yes
    elif [[ -r "$LOGO_PNG" ]]; then
        "$draw" "$LOGO_PNG" no
    else
        art_fetch
    fi
else
    art_fetch
fi
