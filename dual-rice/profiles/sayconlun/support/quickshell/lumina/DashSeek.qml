// Seek bar for the playing track (MediaState). Follows the position except
// while dragged, and seeks on release.
import QtQuick
import QtQuick.Controls.Basic

Slider {
    id: slider

    from: 0
    to: Math.max(1, MediaState.length)
    enabled: MediaState.player !== null && MediaState.player.canSeek && MediaState.length > 0
    implicitHeight: 22
    hoverEnabled: true

    Binding {
        target: slider
        property: "value"
        value: MediaState.position
        when: !slider.pressed
        restoreMode: Binding.RestoreNone
    }

    onPressedChanged: if (!pressed) MediaState.seek(value)

    background: Rectangle {
        x: slider.leftPadding
        y: slider.topPadding + slider.availableHeight / 2 - height / 2
        width: slider.availableWidth
        height: 6
        radius: 3
        color: Theme.alpha(Theme.on_surface, 0.12)

        Rectangle {
            width: slider.visualPosition * parent.width
            height: parent.height
            radius: 3
            color: Theme.primary
        }
    }

    handle: Rectangle {
        x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
        y: slider.topPadding + slider.availableHeight / 2 - height / 2
        implicitWidth: 14
        implicitHeight: 14
        radius: 7
        color: Theme.primary
        opacity: slider.hovered || slider.pressed ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: 120 }
        }
    }
}
