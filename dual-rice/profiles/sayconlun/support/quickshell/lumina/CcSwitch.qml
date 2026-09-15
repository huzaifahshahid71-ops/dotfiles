// A small on/off switch for control-centre page headers.
import QtQuick

Rectangle {
    id: root

    property bool checked: false
    signal toggled

    implicitWidth: 48
    implicitHeight: 28
    radius: 14
    color: checked ? Theme.primary : Theme.surface_container_highest
    border.width: checked ? 0 : 1
    border.color: Theme.outline_variant
    Behavior on color {
        ColorAnimation { duration: 150 }
    }

    Rectangle {
        y: 4
        x: root.checked ? root.width - width - 4 : 4
        width: 20
        height: 20
        radius: 10
        color: root.checked ? Theme.on_primary : Theme.on_surface_variant
        Behavior on x {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
