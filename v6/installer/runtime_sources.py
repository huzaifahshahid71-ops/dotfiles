"""Identify UI source folders that share names with disposable runtime data."""
from pathlib import PurePosixPath

PREFIX = '.local/share/desktop-profiles/'
CODE = {'.qml', '.js', '.mjs', '.qsb'}
SHADERS = {'.frag', '.vert', '.glsl', '.qsb'}
IMAGES = {'.png', '.jpg', '.jpeg', '.webp', '.svg'}
SPECIAL = {'state', '.state', 'generated', 'wallpapers'}

def ui_tree(relative):
    if not relative.startswith(PREFIX): return False
    tail=relative[len(PREFIX):].split('/')
    return (len(tail)>2 and (tail[1:3]==['support','quickshell'] or
        tail[0]=='inir' and tail[1]=='runtime' or
        tail[0]=='tsugumori' and tail[1:4]==['support','config','quickshell']))

def state_code(relative):
    p=PurePosixPath(relative)
    return bool({'state','.state','generated'} & set(p.parts)) and p.suffix.lower() in CODE

def wallpaper_asset(relative):
    p=PurePosixPath(relative)
    return 'assets' in p.parts and 'wallpapers' in p.parts and p.suffix.lower() in IMAGES

def special_source(relative, directory=False):
    if not ui_tree(relative): return False
    return directory or state_code(relative) or wallpaper_asset(relative)

def command_source(relative):
    if relative=='.local/bin/refresh-rate-ctl':return True
    if not relative.startswith(PREFIX):return False
    tail=relative[len(PREFIX):].split('/')
    return len(tail)>2 and (tail[1:3] in (['support','bin'],['runtime','scripts']) or
                            tail[1]=='bin' or tail[1:4]==['support','waybar','scripts'])

LUMINA_DEFAULT = PREFIX+'sayconlun/support/quickshell/lumina/assets/wallpapers/multi-rice-default.png'

def lumina_wallpaper_defaults(data):
    marker=b'# Multi-Rice bundled Lumina wallpaper fallback\n'
    if marker in data:return data
    setting=b'DIR="${RICE_WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"\n'
    empty=b'[[ -n "$f" ]] || exit 0'
    if data.count(setting)!=1 or data.count(empty)!=1:
        raise ValueError('Lumina wallpaper helper differs from the reviewed source')
    fallback=marker+b'''if [[ -z "${RICE_WALLPAPER_DIR:-}" ]] && ! find -L "$DIR" -maxdepth 1 -type f \\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.gif' \\) -print -quit 2>/dev/null | grep -q .; then
    DIR="$HOME/.local/share/desktop-profiles/sayconlun/support/quickshell/lumina/assets/wallpapers"
fi
'''
    return data.replace(setting,setting+fallback,1).replace(empty,b'[[ -f "$f" ]] || die "no wallpaper found in $DIR"',1)

CIPHER_SHELL = PREFIX+'clavis/native/shell.sh'

def cipher_shell_path(data):
    old=b'exec qs -c clavis -n'
    new=b'exec /usr/bin/qs -p "$ROOT/support/quickshell/clavis" -n'
    lines=data.splitlines(keepends=True)
    if sum(line.rstrip(b'\r\n')==new for line in lines)==1:return data
    if sum(line.rstrip(b'\r\n')==old for line in lines)!=1:
        raise ValueError('Cipher shell launcher differs from the reviewed source')
    return b''.join(line.replace(old,new,1) if line.rstrip(b'\r\n')==old else line for line in lines)

END4_STARTUP=PREFIX+'end4/hypr/hyprland/execs.lua'
SOLSTICE_CONFIG=PREFIX+'jaqc/niri/config.kdl'
ECLIPSE_UPDATES=PREFIX+'inir/runtime/services/ShellUpdates.qml'

def end4_shell_path(data):
    old=b'hl.exec_cmd("qs -c $qsConfig")'
    new=b'hl.exec_cmd("/usr/bin/qs -p $HOME/.config/quickshell/end4-pC")'
    if data.count(new)==1:return data
    if data.count(old)!=1:raise ValueError('Obsidian startup differs from the reviewed source')
    return data.replace(old,new,1)

def solstice_shell_path(data,home):
    import json,re
    path=str(home).rstrip('/')+'/'+PREFIX+'jaqc/support/quickshell/solstice'
    target='"/usr/bin/qs" "-p" '+json.dumps(path)
    text=data.decode()
    startup=re.compile(r'(?m)^([ \t]*spawn-at-startup[ \t]+)"(?:/usr/bin/)?qs"[ \t]+"-c"[ \t]+"solstice"(?=[ \t\r\n;])')
    if len(startup.findall(text))==1:text=startup.sub(lambda m:m.group(1)+target,text,count=1)
    elif len(re.findall(r'(?m)^[ \t]*spawn-at-startup[ \t]+'+re.escape(target),text))!=1:raise ValueError('Solstice startup differs from the reviewed source')
    # Preserve the invoked IPC method and arguments, including the existing lock screen behavior.
    ipc=re.compile(r'\bspawn[ \t]+"(?:/usr/bin/)?qs"[ \t]+"-c"[ \t]+"solstice"(?=[ \t\r\n;])')
    return ipc.sub(lambda m:'spawn '+target,text).encode()

def eclipse_version_path(data):
    old=b'command: ["cat", Directories.shellConfig + "/version.json"]'
    new=b'command: ["/usr/bin/cat", Quickshell.shellPath("version.json")]'
    if data.count(new)==1:return data
    if data.count(old)!=1:raise ValueError('Eclipse updater differs from the reviewed source')
    return data.replace(old,new,1)

def startup_source_defaults(relative,data,home):
    if relative==END4_STARTUP:return end4_shell_path(data)
    if relative==SOLSTICE_CONFIG:return solstice_shell_path(data,home)
    if relative==ECLIPSE_UPDATES:return eclipse_version_path(data)
    return data
