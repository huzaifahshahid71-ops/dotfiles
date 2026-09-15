// Icon (tap to mute) · pill slider · value. Ported from Nisfere's SliderRow
// and ControlSlider: a fat rounded track, and a handle that only appears
// while hovered or dragged.
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

RowLayout {
    id: root

    property string icon: "volume-2"
    property string mutedIcon: "volume-x"
    property bool muted: false
    property real value: 0

    signal muteToggled
    signal moved(real value)

    spacing: 12

    Rectangle {
        implicitWidth: 38
        implicitHeight: 38
        radius: 19
        color: root.muted ? Theme.surface_container_highest : "transparent"
        border.width: root.muted ? 1 : 0
        border.color: Theme.alpha(Theme.outline_variant, 0.8)

        LucideIcon {
            anchors.centerIn: parent
            icon: root.muted ? root.mutedIcon : root.icon
            size: 19
            color: root.muted ? Theme.on_surface : Theme.primary
            opacity: root.muted ? 0.55 : 1
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.muteToggled()
        }
    }

    Slider {
        id: slider
        Layout.fillWidth: true
        implicitHeight: 34
        from: 0
        to: 1
        hoverEnabled: true
        onMoved: root.moved(value)

        // Follow the real value, except while the user is dragging.
        Binding {
            target: slider
            property: "value"
            value: root.value
            when: !slider.pressed
            restoreMode: Binding.RestoreNone
        }

        background: Rectangle {
            x: slider.leftPadding
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: slider.availableWidth
            height: 24
            radius: 12
            color: Theme.surface_container_lowest

            Rectangle {
                width: slider.visualPosition * parent.width
                height: parent.height
                radius: parent.radius
                color: root.muted ? Theme.outline_variant : Theme.primary
            }
        }

        handle: Rectangle {
            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            implicitWidth: 14
            implicitHeight: 32
            radius: 7
            color: slider.pressed ? Theme.on_surface : Theme.primary
            border.width: 2
            border.color: Theme.surface_container
            opacity: slider.hovered || slider.pressed ? 1 : 0
            scale: slider.hovered || slider.pressed ? 1 : 0.5
            Behavior on opacity {
                NumberAnimation { duration: 120 }
            }
            Behavior on scale {
                NumberAnimation { duration: 120 }
            }
        }
    }

    Text {
        Layout.preferredWidth: 42
        horizontalAlignment: Text.AlignRight
        text: root.muted ? "Mute" : Math.round(slider.value * 100) + "%"
        color: Theme.on_surface
        opacity: 0.75
        font.family: Theme.font
        font.pixelSize: 13
    }
}
