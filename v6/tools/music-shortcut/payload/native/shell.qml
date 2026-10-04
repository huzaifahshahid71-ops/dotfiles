import QtQuick
import QtCore
import Quickshell
import Quickshell.Io

// One Quickshell configuration, one active player window and one mpv backend.
ShellRoot {
    id: themeRoot
    property bool switching: false
    readonly property string currentTheme: ["glass", "nexus", "material"].indexOf(themeSettings.selectedTheme) >= 0
                                           ? themeSettings.selectedTheme : "nexus"

    Settings {
        id: themeSettings
        location: "file://" + Quickshell.env("HOME") + "/.config/quickshell/lumina-music-theme.ini"
        category: "Appearance"
        property string selectedTheme: "nexus"
    }

    function setTheme(theme) {
        if (["glass", "nexus", "material"].indexOf(theme) < 0 || theme === currentTheme)
            return
        switching = true
        themeSettings.selectedTheme = theme
        themeSettings.sync()
    }

    IpcHandler {
        target: "luminaMusic"
        function show(): void {
            if (playerLoader.item) {
                playerLoader.item.visible = true
                if ("minimized" in playerLoader.item) playerLoader.item.minimized = false
            }
        }
    }

    LazyLoader {
        id: playerLoader
        active: true
        source: themeRoot.currentTheme === "glass" ? "GlassPlayer.qml"
              : themeRoot.currentTheme === "material" ? "MaterialPlayer.qml" : "NexusPlayer.qml"
        onItemChanged: {
            if (item) item.themeController = themeRoot
            if (item) themeRoot.switching = false
        }
    }
}
