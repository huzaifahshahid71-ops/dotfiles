// Back button · title · anything placed inside (e.g. a CcSwitch) on the right.
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root

    property string title: ""
    signal back

    default property alias trailing: trailingRow.data

    spacing: 10

    Rectangle {
        implicitWidth: 34
        implicitHeight: 34
        radius: 12
        color: backArea.containsMouse ? Theme.alpha(Theme.primary, 0.2) : Theme.surface_container_high

        LucideIcon {
            anchors.centerIn: parent
            icon: "chevron-left"
            size: 18
        }

        MouseArea {
            id: backArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.back()
        }
    }

    Text {
        Layout.fillWidth: true
        text: root.title
        elide: Text.ElideRight
        color: Theme.on_surface
        font.family: Theme.font
        font.pixelSize: 20
        font.weight: Font.Bold
    }

    RowLayout {
        id: trailingRow
        spacing: 8
    }
}
