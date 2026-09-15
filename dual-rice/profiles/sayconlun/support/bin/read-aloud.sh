#!/usr/bin/env bash
# Read prose aloud with piper, for listening back while editing.
#
#   read-aloud.sh <file.md>     read a manuscript file
#   read-aloud.sh --selection   read the highlighted text (else the clipboard)
#   read-aloud.sh --toggle      pause / resume
#   read-aloud.sh --back        back 10s        --forward  skip 10s
#   read-aloud.sh --prev        previous sentence  --next  next sentence
#   read-aloud.sh --faster / --slower
#   read-aloud.sh --stop
#   read-aloud.sh --no-tile <file>   play without the on-screen tile
#
# Renders ONE WAV PER SENTENCE and appends each to mpv's playlist as it
# lands, so audio starts in a few seconds even on an 89k-word manuscript.
# Pre-rendering a whole book first means minutes of silence - don't go back
# to that.
#
# Sentence granularity is also what makes the subtitle tile exact: mpv's
# playlist-pos is the sentence index, so tts-tile.py needs no timing model
# and cannot drift. Rendering is still BATCHED (many sentences per piper
# invocation via --json-input) because piper reloads the 61MB voice model on
# every invocation - one process per sentence would be far slower than the
# old whole-chunk rendering, not faster.
#
# NOTE: /usr/bin/piper here is the Logitech mouse configurator, NOT the TTS.
# The real engine is under ~/.local/share/piper-tts.
set -uo pipefail

PIPER="$HOME/.local/share/piper-tts/piper/piper"
VOICE="${PIPER_VOICE:-$HOME/.local/share/piper-tts/voices/en_GB-jenny_dioco-medium.onnx}"
TILE="$HOME/.local/share/desktop-profiles/sayconlun/support/bin/tts-tile.py"
RUN="${XDG_RUNTIME_DIR:-/tmp}"
SOCK="$RUN/read-aloud.sock"
DIR="$RUN/read-aloud.d"
PIDF="$RUN/read-aloud.render.pid"
TILEPIDF="$RUN/read-aloud.tile.pid"
REAPPIDF="$RUN/read-aloud.reap.pid"
# First batch is small so playback starts quickly; later batches are large so
# the model load is amortised across many sentences.
HEAD_BATCH="${TTS_HEAD_BATCH:-6}"
BATCH="${TTS_BATCH:-40}"

ipc() {
    # mpv leaves its socket file behind when it exits, so an -S test alone
    # passes on a dead socket and the command vanishes silently. Treat a
    # failed connect as "not playing" and clear the stale file.
    [[ -S "$SOCK" ]] || { echo "nothing is playing" >&2; exit 1; }
    if ! printf '%s\n' "$1" | socat -t0.2 - "$SOCK" >/dev/null 2>&1; then
        rm -f "$SOCK"
        echo "nothing is playing" >&2
        exit 1
    fi
}

# pkill -f matches ANY process whose command line contains the pattern -
# including the shell that invoked this script, if that command line happens
# to mention the script or the tile. That self-match killed the caller. Kill
# by recorded PID where possible, and never kill ourselves or our parent.
kill_matching() {
    local pid
    for pid in $(pgrep -f "$1" 2>/dev/null); do
        [[ "$pid" == "$$" || "$pid" == "$PPID" ]] && continue
        kill "$pid" 2>/dev/null
    done
}

stop_all() {
    [[ -f "$PIDF" ]] && kill "$(cat "$PIDF")" 2>/dev/null
    [[ -f "$TILEPIDF" ]] && kill "$(cat "$TILEPIDF")" 2>/dev/null
    [[ -f "$REAPPIDF" ]] && kill "$(cat "$REAPPIDF")" 2>/dev/null
    kill_matching "read-aloud.sh --render-rest"
    kill_matching "read-aloud.sh --reap"
    kill_matching "input-ipc-server=$SOCK"
    kill_matching "piper-tts/piper/piper"
    rm -rf "$DIR" "$SOCK" "$PIDF" "$TILEPIDF" "$REAPPIDF"
}

render_batch() {
    # One piper process per batch: one model load, one WAV per input line.
    "$PIPER" -m "$VOICE" --json-input -q < "$1" >/dev/null 2>&1
}

case "${1:-}" in
    --stop)    stop_all; echo "stopped"; exit 0 ;;
    --toggle)  ipc '{"command":["cycle","pause"]}';        exit 0 ;;
    --back)    ipc '{"command":["seek",-10]}';             exit 0 ;;
    --forward) ipc '{"command":["seek",10]}';              exit 0 ;;
    --prev)    ipc '{"command":["playlist-prev"]}';        exit 0 ;;
    --next)    ipc '{"command":["playlist-next"]}';        exit 0 ;;
    --faster)  ipc '{"command":["multiply","speed",1.1]}'; exit 0 ;;
    --slower)  ipc '{"command":["multiply","speed",0.9]}'; exit 0 ;;
    --reap)
        # Sentence WAVs live in $XDG_RUNTIME_DIR, which is tmpfs - i.e. RAM.
        # A whole manuscript rendered at ~40MB per 900 words runs to several
        # GB, so drop WAVs the playhead has left well behind. KEEP_BEHIND
        # sentences are retained so --back and --prev still work.
        RDIR="${2:?}"
        keep="${TTS_KEEP_BEHIND:-20}"
        low=0
        for _ in {1..60}; do [[ -S "$SOCK" ]] && break; sleep 0.25; done
        while [[ -S "$SOCK" ]]; do
            # mpv leaves its socket file behind on exit, so -S alone stays
            # true forever and this loop would poll a dead socket for the
            # rest of the session. Treat an unanswered query as the end.
            reply=$(printf '{"command":["get_property","playlist-pos"],"request_id":77}\n' \
                | socat -t0.3 - "$SOCK" 2>/dev/null)
            [[ -n "$reply" ]] || { rm -f "$SOCK"; exit 0; }
            pos=$(printf '%s\n' "$reply" | grep '"request_id":77' \
                | sed -n 's/.*"data":\(-\?[0-9]\+\).*/\1/p' | head -1)
            if [[ "$pos" =~ ^[0-9]+$ ]] && (( pos > keep )); then
                target=$(( pos - keep ))
                while (( low < target )); do
                    rm -f "$(printf '%s/s%05d.wav' "$RDIR" "$low")"
                    low=$(( low + 1 ))
                done
            fi
            sleep 5
        done
        exit 0 ;;
    --render-rest)
        # Runs detached via setsid so it outlives the launching shell. A plain
        # background subshell dies with the parent and you get one batch only.
        RDIR="${2:?}"
        # mpv needs a moment to create its IPC socket. Without this wait the
        # first loop iteration sees no socket, exits 0, and only batch 1 ever
        # renders - which looks exactly like the renderer being killed.
        for _ in {1..60}; do [[ -S "$SOCK" ]] && break; sleep 0.25; done
        [[ -S "$SOCK" ]] || exit 0
        for b in "$RDIR"/batch-*.jsonl; do
            [[ "$b" == "$RDIR/batch-0001.jsonl" ]] && continue
            [[ -S "$SOCK" ]] || exit 0        # playback was stopped
            render_batch "$b"
            while read -r wav; do
                [[ -S "$SOCK" ]] || exit 0
                [[ -s "$wav" ]] || continue
                printf '{"command":["loadfile","%s","append"]}\n' "$wav" \
                    | socat -t0.2 - "$SOCK" >/dev/null 2>&1
            done < "${b%.jsonl}.list"
        done
        # Everything is queued, so let mpv exit at the end of the playlist
        # instead of idling. That EOF is what dismisses the tile.
        [[ -S "$SOCK" ]] && printf '{"command":["set_property","idle","no"]}\n' \
            | socat -t0.2 - "$SOCK" >/dev/null 2>&1
        exit 0 ;;
esac

WANT_TILE=1
if [[ "${1:-}" == "--no-tile" ]]; then WANT_TILE=0; shift; fi

[[ -x "$PIPER" ]] || { echo "piper TTS not found at $PIPER" >&2; exit 1; }
[[ -f "$VOICE" ]] || { echo "voice model not found: $VOICE" >&2; exit 1; }

if [[ "${1:-}" == "--selection" ]]; then
    # Highlighted text lives in the primary selection, not the clipboard -
    # reading only the clipboard ignores a highlight that was never Ctrl+C'd.
    text=$(wl-paste --primary --no-newline 2>/dev/null)
    [[ -n "${text// }" ]] || text=$(wl-paste --no-newline 2>/dev/null)
elif [[ -n "${1:-}" && -f "$1" ]]; then
    text=$(cat "$1")
else
    echo "usage: read-aloud.sh <file.md> | --selection | --toggle | --stop" >&2
    exit 1
fi
[[ -n "${text// }" ]] || { echo "nothing to read" >&2; exit 1; }

stop_all
mkdir -p "$DIR"

# Strip markdown, split into sentences, then group sentences into batches.
printf '%s' "$text" | HEAD_BATCH="$HEAD_BATCH" BATCH="$BATCH" DIR="$DIR" python3 -c '
import json, os, re, sys
t = sys.stdin.read()
t = re.sub(r"^---.*?^---", "", t, flags=re.S | re.M)
t = re.sub(r"```.*?```", "", t, flags=re.S)
t = re.sub(r"!\[[^\]]*\]\([^)]*\)", "", t)
t = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", t)
t = re.sub(r"^\s{0,3}#{1,6}\s*(.+)$", r"\1.", t, flags=re.M)
t = re.sub(r"^\s*[-*+]\s+", "", t, flags=re.M)
t = re.sub(r"^\s*>\s?", "", t, flags=re.M)
t = re.sub(r"[*_]{1,3}([^*_]+)[*_]{1,3}", r"\1", t)
t = re.sub(r"`([^`]*)`", r"\1", t)
t = re.sub(r"^\s*[-*_]{3,}\s*$", "", t, flags=re.M)

d = os.environ["DIR"]

# Sentence split. Scanning for boundaries (rather than re.split) keeps the
# trailing quote attached: "Is that you?" she asked. is ONE subtitle, and
# splitting it would silently drop the closing quote character.
ABBRS = {"mr", "mrs", "ms", "dr", "prof", "st", "vs", "etc", "no", "fig",
         "al", "jr", "sr", "capt", "lt", "sgt", "rev", "hon", "inc", "ltd"}


def split_sentences(para):
    out, start = [], 0
    for m in re.finditer(r"[.!?]+[\"\u0027)\]\u201d\u2019]*\s+", para):
        head = para[start:m.start()]
        last = re.search(r"([A-Za-z.]+)$", head)
        if last and last.group(1).lower().strip(".") in ABBRS:
            continue          # "Mr. Darcy", not two sentences
        nxt = para[m.end():m.end() + 1]
        if nxt and nxt.islower():
            continue          # dialogue plus its attribution stays together
        out.append(para[start:m.end()].strip())
        start = m.end()
    tail = para[start:].strip()
    if tail:
        out.append(tail)
    return out


sentences = []
for para in re.split(r"\n\s*\n", t):
    para = " ".join(para.split())
    if not para:
        continue
    for s in split_sentences(para):
        # A very long sentence would overflow the tile and sit on screen for
        # far too long, so break it at clause boundaries.
        if len(s.split()) > 45:
            parts, cur = [], []
            for piece in re.split(r"(?<=[,;:\u2014])\s+", s):
                cur.append(piece)
                if len(" ".join(cur).split()) >= 25:
                    parts.append(" ".join(cur)); cur = []
            if cur:
                parts.append(" ".join(cur))
            sentences.extend(parts)
        else:
            sentences.append(s)

# Drop fragments with nothing speakable in them (stray punctuation, rules).
sentences = [s for s in sentences if re.search(r"[A-Za-z0-9]", s)]

json.dump(sentences, open(f"{d}/sentences.json", "w"))

head, size = int(os.environ["HEAD_BATCH"]), int(os.environ["BATCH"])
bounds, i, first = [], 0, True
while i < len(sentences):
    n = head if first else size
    bounds.append((i, min(i + n, len(sentences)))); i += n; first = False

for bi, (lo, hi) in enumerate(bounds, 1):
    with open(f"{d}/batch-{bi:04d}.jsonl", "w") as jf, \
         open(f"{d}/batch-{bi:04d}.list", "w") as lf:
        for si in range(lo, hi):
            wav = f"{d}/s{si:05d}.wav"
            jf.write(json.dumps({"text": sentences[si], "output_file": wav}) + "\n")
            lf.write(wav + "\n")

print(len(sentences), len(bounds), sum(len(s.split()) for s in sentences))
' > "$DIR/meta" || { echo "text processing failed" >&2; exit 1; }

read -r nsent nbatch nwords < "$DIR/meta"
(( nsent > 0 )) || { echo "nothing to read after stripping markdown" >&2; exit 1; }
echo "$nwords words in $nsent sentences (~$((nwords / 150)) min)"

# First batch synchronously so playback can start immediately.
render_batch "$DIR/batch-0001.jsonl"
mapfile -t first_wavs < "$DIR/batch-0001.list"
[[ -s "${first_wavs[0]}" ]] || { echo "piper produced no audio" >&2; exit 1; }

playable=()
for w in "${first_wavs[@]}"; do [[ -s "$w" ]] && playable+=("$w"); done

setsid mpv --no-video --really-quiet --idle=yes --keep-open=no \
    --gapless-audio=yes --prefetch-playlist=yes \
    --input-ipc-server="$SOCK" --speed="${TTS_SPEED:-1.0}" \
    "${playable[@]}" >/dev/null 2>&1 &

# Remaining batches render detached and are queued as they land.
setsid "$0" --render-rest "$DIR" >/dev/null 2>&1 &
echo $! > "$PIDF"

setsid "$0" --reap "$DIR" >/dev/null 2>&1 &
echo $! > "$REAPPIDF"

if (( WANT_TILE )) && [[ -x "$TILE" && -n "${WAYLAND_DISPLAY:-}" ]]; then
    setsid "$TILE" "$DIR" "$SOCK" >/dev/null 2>&1 &
    echo $! > "$TILEPIDF"
fi

echo "playing - Super+P pause, Super+[ back 10s, Super+] forward"
