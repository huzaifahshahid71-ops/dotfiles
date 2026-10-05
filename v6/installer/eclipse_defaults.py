"""Portable Eclipse appearance defaults verified against the host comparison."""
import copy
import json

ECLIPSE_CONFIGS = {".local/share/desktop-profiles/inir/home/.config/inir/config.json",
                   ".local/share/desktop-profiles/inir/home/.config/illogical-impulse/config.json"}
PANELS = ['irisBar', 'irisBackground', 'irisPalette', 'irisControlCenter', 'irisNotificationPopup', 'irisOnScreenDisplay', 'irisSessionScreen', 'irisLock', 'irisPolkit', 'iiBar', 'iiBackground', 'iiBackdrop', 'iiBootGreeting', 'iiCheatsheet', 'iiControlPanel', 'iiDock', 'iiLock', 'iiMediaControls', 'iiNotificationPopup', 'iiOnScreenDisplay', 'iiOnScreenKeyboard', 'iiOverlay', 'iiOverview', 'iiPolkit', 'iiRegionSelector', 'iiScreenCorners', 'iiSessionScreen', 'iiSidebarLeft', 'iiSidebarRight', 'iiTilingOverlay', 'iiVerticalBar', 'iiWallpaperSelector', 'iiWallpaperLauncher', 'iiCoverflowSelector', 'iiClipboard', 'iiShellUpdate', 'iiRecordingOsd', 'iiDashboard', 'iiMascotCompanion', 'wBar', 'wBackground', 'wBackdrop', 'wStartMenu', 'wActionCenter', 'wNotificationCenter', 'wNotificationPopup', 'wOnScreenDisplay', 'wWidgets', 'wTaskView', 'wLock', 'wPolkit', 'wSessionScreen']

def apply_defaults(config):
    if not isinstance(config, dict):
        raise ValueError("Eclipse settings must be a JSON object")
    config = copy.deepcopy(config)
    config["panelFamily"] = "waffle"
    previous = config.get("enabledPanels", [])
    if not isinstance(previous, list) or not all(isinstance(x,str) for x in previous):
        raise ValueError("Eclipse enabledPanels must be an array of names")
    config["enabledPanels"] = PANELS + [x for x in previous if x not in PANELS]
    for keys, value in ((["appearance", "typography", "syncWithSystem"], False),
                        (["bar", "modules", "resources"], True),
                        (["bar", "modules", "utilButtons"], True)):
        node = config
        for key in keys[:-1]:
            child = node.setdefault(key, {})
            if not isinstance(child, dict):
                raise ValueError("Invalid Eclipse settings section: "+key)
            node = child
        node[keys[-1]] = value
    return config

def render_defaults(data):
    return (json.dumps(apply_defaults(json.loads(data)),indent=2,ensure_ascii=False)+"\n").encode()
