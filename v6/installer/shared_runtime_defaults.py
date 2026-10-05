"""Reviewed music launcher repair and explicit shared-helper inclusion."""
import hashlib
from pathlib import Path

MUSIC = '.local/bin/background-music'
REFRESH = '.local/bin/refresh-rate-ctl'
KNOWN_MUSIC = {
    '0ef29572637ffb3e809864784d67fd2eee087f9a4980e71715b3adfe10498dcc',
    'e20ee0692c368c11db7afadf3006648f1c1fb7322ce2ad6cf1a099d07c16333d',
}
OLD = 'PLAYLIST="${BACKGROUND_MUSIC_PLAYLIST:-$MUSIC_DIR/Favorites.m3u8}"'
NEW = '''STATE_DIR="$HOME/.local/state/background-music"
ACTIVE_PLAYLIST_FILE="$STATE_DIR/active-playlist"
DEFAULT_PLAYLIST="$MUSIC_DIR/Favorites.m3u8"

if [[ -n "${BACKGROUND_MUSIC_PLAYLIST:-}" ]]; then
    PLAYLIST="$BACKGROUND_MUSIC_PLAYLIST"
elif [[ -s "$ACTIVE_PLAYLIST_FILE" ]]; then
    PLAYLIST="$(head -n1 "$ACTIVE_PLAYLIST_FILE")"
else
    PLAYLIST="$DEFAULT_PLAYLIST"
fi'''

def sha(data):
    return hashlib.sha256(data).hexdigest()

def music_defaults(data):
    if b'--terminal=yes' in data and NEW.encode() in data:
        return data
    if sha(data) not in KNOWN_MUSIC:
        raise ValueError('Music launcher differs from the captured sources; retained unchanged.')
    text = data.decode()
    if OLD in text:
        text = text.replace(OLD, NEW, 1)
    text = text.replace('--terminal=no', '--terminal=yes \\\n        --input-terminal=no \\\n        --msg-level=all=warn', 1)
    return text.encode()

def reviewed_shared_defaults(payload, rows, asset):
    """Replace atomically to preserve the retained, hard-linked candidate."""
    def generated(relative, data, mode):
        destination = payload / 'home' / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        temporary = destination.with_name(destination.name + '.shared-new')
        if temporary.exists() or temporary.is_symlink():
            raise ValueError('Unexpected shared-runtime temporary file')
        temporary.write_bytes(data)
        temporary.chmod(mode)
        temporary.replace(destination)
        rows[relative] = dict(rows.get(relative, {}), path=relative, source='home/' + relative,
                              sha256=sha(data), bytes=len(data), mode=mode,
                              template=b'@MULTI_RICE_HOME@' in data)
    if MUSIC not in rows:
        raise ValueError('Candidate is missing the shared music launcher')
    data = (payload / rows[MUSIC]['source']).read_bytes()
    fixed = music_defaults(data)
    if fixed != data:
        generated(MUSIC, fixed, rows[MUSIC].get('mode', 0o755))
    if REFRESH not in rows:
        generated(REFRESH, Path(asset).read_bytes(), 0o755)
