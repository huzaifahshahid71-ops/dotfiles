// Dashboard · Alerts: the notification history with Do Not Disturb and
// clear-all - the same list as the notification centre (Super+N).
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: page

    property var dash

    spacing: 12

    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Text {
            Layout.leftMargin: 4
            text: "Notifications"
            color: Theme.on_surface
            font.family: Theme.font
            font.pixelSize: 22
            font.weight: Font.Bold
        }

        Rectangle {
            visible: NotifService.count > 0
            implicitWidth: countText.implicitWidth + 16
            implicitHeight: 24
            radius: 12
            color: Theme.alpha(Theme.primary, 0.2)

            Text {
                id: countText
                anchors.centerIn: parent
                text: NotifService.count
                color: Theme.primary
                font.family: Theme.font
                font.pixelSize: 12
                font.weight: Font.Bold
            }
        }

        Item { Layout.fillWidth: true }

        LucideIcon {
            icon: NotifService.dnd ? "bell-off" : "bell"
            size: 17
            color: NotifService.dnd ? Theme.primary : Theme.on_surface_variant
        }

        Text {
            text: "Do not disturb"
            color: Theme.on_surface_variant
            font.family: Theme.font
            font.pixelSize: 13
        }

        CcSwitch {
            checked: NotifService.dnd
            onToggled: NotifService.dnd = !NotifService.dnd
        }

        DashButton {
            Layout.leftMargin: 6
            visible: NotifService.count > 0
            icon: "trash-2"
            size: 36
            iconSize: 16
            onClicked: NotifService.clear()
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: 40
        Layout.bottomMargin: 40
        visible: NotifService.count === 0
        spacing: 10

        LucideIcon {
            Layout.alignment: Qt.AlignHCenter
            icon: NotifService.dnd ? "bell-off" : "bell"
            size: 44
            color: Theme.on_surface_variant
            opacity: 0.6
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: NotifService.dnd ? "Do Not Disturb is on" : "You're all caught up"
            color: Theme.on_surface_variant
            font.family: Theme.font
            font.pixelSize: 15
        }
    }

    Flickable {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(list.implicitHeight, 480)
        visible: NotifService.count > 0
        contentHeight: list.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        GridLayout {
            id: list
            width: parent.width
            columns: 2
            columnSpacing: 10
            rowSpacing: 10
            uniformCellWidths: true

            Repeater {
                model: NotifService.list

                NotifCard {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    entry: modelData
                    compact: true
                    color: Theme.alpha(Theme.surface_container_high, 0.85)
                    onDismissed: NotifService.dismiss(modelData)
                    onActionInvoked: {
                        NotifService.dismiss(modelData)
                        page.dash.close()
                    }
                }
            }
        }
    }
}
