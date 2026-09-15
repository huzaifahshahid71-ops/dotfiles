// A round icon button: hover tint, or a solid accent fill for the main action.
import QtQuick

Rectangle {
    id: root

    property string icon: ""
    property int size: 40
    property int iconSize: 18
    property bool accent: false
    property bool active: true

    signal clicked

    implicitWidth: size
    implicitHeight: size
    radius: size / 2
    opacity: active ? 1 : 0.4
    color: accent ? (area.containsMouse ? Qt.lighter(Theme.primary, 1.12) : Theme.primary)
         : area.containsMouse ? Theme.alpha(Theme.primary, 0.18) : "transparent"
    Behavior on color {
        ColorAnimation { duration: 120 }
    }

    LucideIcon {
        anchors.centerIn: parent
        icon: root.icon
        size: root.iconSize
        color: root.accent ? Theme.on_primary : Theme.on_surface
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.active
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
