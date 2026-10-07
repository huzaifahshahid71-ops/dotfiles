"""Keep accepted desktop launch fixes when collecting a later candidate."""
import re

def desktop_defaults(relative,data):
    prefix='env QT_QPA_PLATFORMTHEME=qt6ct QS_ICON_THEME=Papirus-Dark '
    if relative in {'.local/share/desktop-profiles/caelestia/hypr/hyprland/execs.lua',
                    '.local/share/desktop-profiles/caelestia/hypr/hyprland/keybinds.lua'}:
        text=data.decode()
        def literal(m):
            value=m.group(0)
            if 'caelestia shell -d' not in value:return value
            if ('QT_QPA_PLATFORMTHEME=' in value or 'QS_ICON_THEME=' in value) and prefix not in value:
                raise RuntimeError('Custom Aether launch environment retained')
            return re.sub(r'(?<!QS_ICON_THEME=Papirus-Dark )\bcaelestia shell -d\b',prefix+'caelestia shell -d',value)
        lines=[]
        for line in text.splitlines(keepends=True):
            lines.append(line if line.lstrip().startswith('--') else re.sub(r'"(?:[^"\\]|\\.)*"',literal,line))
        return ''.join(lines).encode()
    if relative=='.local/share/desktop-profiles/clavis/native/niri/config.kdl':
        old='spawn "qs" "-c" "clavis" "ipc" "call" "spotlight" "toggle"'
        new='spawn "/usr/bin/qs" "-p" "@MULTI_RICE_HOME@/.local/share/desktop-profiles/clavis/support/quickshell/clavis" "ipc" "call" "spotlight" "toggle"'
        lines=[]
        for line in data.decode().splitlines(keepends=True):
            if re.match(r'^\s*(?:Mod|Super)\+Space\b',line) and old in line.split('//',1)[0]:line=line.replace(old,new,1)
            lines.append(line)
        return ''.join(lines).encode()
    return data
