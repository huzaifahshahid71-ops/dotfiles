// A list row for control-centre pages: icon, title, subtitle, and an
// optional round action button that spins while `busy`.
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool highlighted: false
    property string actionIcon: ""       // empty: no button
    property bool busy: false

    signal clicked
    signal actionClicked

    Layout.fillWidth: true
    implicitHeight: 58
    radius: 16
    color: highlighted ? Theme.alpha(Theme.primary, 0.12)
         : rowArea.containsMouse ? Theme.alpha(Theme.on_surface, 0.06)
         : Theme.alpha(Theme.surface_container_high, 0.7)

    MouseArea {
        id: rowArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 10
        spacing: 12

        LucideIcon {
            icon: root.icon
            size: 19
            color: root.highlighted ? Theme.primary : Theme.on_surface
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Text {
                Layout.fillWidth: true
                text: root.title
                elide: Text.ElideRight
                color: Theme.on_surface
                font.family: Theme.font
                font.pixelSize: 14
                font.weight: root.highlighted ? Font.Bold : Font.Medium
            }

            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.subtitle
                elide: Text.ElideRight
                color: root.highlighted ? Theme.primary : Theme.on_surface_variant
                font.family: Theme.font
                font.pixelSize: 11
            }
        }

        Rectangle {
            visible: root.actionIcon !== ""
            implicitWidth: 34
            implicitHeight: 34
            radius: 12
            color: action.containsMouse && !root.busy ? Theme.primary : Theme.alpha(Theme.primary, 0.14)

            LucideIcon {
                id: actionGlyph
                anchors.centerIn: parent
                icon: root.busy ? "loader-circle" : root.actionIcon
                size: 17
                color: action.containsMouse && !root.busy ? Theme.on_primary : Theme.primary

                NumberAnimation on rotation {
                    running: root.busy
                    from: 0
                    to: 360
                    duration: 900
                    loops: Animation.Infinite
                    onRunningChanged: if (!running) actionGlyph.rotation = 0
                }
            }

            MouseArea {
                id: action
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (!root.busy) root.actionClicked()
            }
        }
    }
}
