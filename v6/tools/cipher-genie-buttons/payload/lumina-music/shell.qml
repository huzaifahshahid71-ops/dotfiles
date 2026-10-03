import QtQuick
import QtCore
import Quickshell

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
