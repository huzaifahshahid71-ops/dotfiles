// Palette for the Quickshell overlays: the same matugen colours as everything
// else, read from the JSON its `quickshell` template writes. Watched, so a
// wallpaper change recolours an open overlay too.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var c: ({})

    readonly property color primary: c.primary ?? "#7dcfff"
    readonly property color on_primary: c.on_primary ?? "#00344a"
    readonly property color primary_container: c.primary_container ?? "#004c69"
    readonly property color on_primary_container: c.on_primary_container ?? "#c3e8ff"
    readonly property color primary_fixed: c.primary_fixed ?? "#c3e8ff"
    readonly property color secondary: c.secondary ?? "#b5c9d7"
    readonly property color tertiary: c.tertiary ?? "#c9c0e9"
    readonly property color error: c.error ?? "#ffb4ab"
    readonly property color on_error: c.on_error ?? "#690005"
    readonly property color surface: c.surface ?? "#0f1417"
    readonly property color surface_container_lowest: c.surface_container_lowest ?? "#0a0f12"
    readonly property color surface_container_low: c.surface_container_low ?? "#171c1f"
    readonly property color surface_container: c.surface_container ?? "#1b2023"
    readonly property color surface_container_high: c.surface_container_high ?? "#252b2e"
    readonly property color surface_container_highest: c.surface_container_highest ?? "#303539"
    readonly property color on_surface: c.on_surface ?? "#dee3e7"
    readonly property color on_surface_variant: c.on_surface_variant ?? "#c0c7cd"
    readonly property color outline: c.outline ?? "#8a9297"
    readonly property color outline_variant: c.outline_variant ?? "#40484c"

    readonly property string font: "Inter Variable"
    readonly property string mono: "JetBrainsMono Nerd Font"

    // A colour (or a "#rrggbb" string) at the given opacity.
    function alpha(col, a) {
        const q = Qt.lighter(col, 1.0)
        return Qt.rgba(q.r, q.g, q.b, a)
    }

    FileView {
        path: Quickshell.env("HOME") + "/.local/share/desktop-profiles/sayconlun/support/state/cache/quickshell-colors.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.c = JSON.parse(text())
            } catch (e) {
                console.warn("Theme: unreadable palette:", e)
            }
        }
    }
}
