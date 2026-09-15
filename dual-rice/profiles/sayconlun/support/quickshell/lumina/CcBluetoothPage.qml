// Control centre · Bluetooth: power, scan, and devices (connected first,
// then paired) with connect/disconnect and battery level.
//
// Connecting follows Nisfere, which is known to work with BlueZ: a paired
// device is trusted then connected; an unpaired one pairs as it connects.
// `pairing` only covers first-time pairing, so each row keeps its own
// pending flag, cleared when `connected` changes or after 15 s.
import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth

ColumnLayout {
    id: page

    property var cc
    readonly property var adapter: cc.btAdapter
    readonly property bool enabled: adapter ? adapter.enabled : false

    readonly property var devices: Array.from(Bluetooth.devices.values)
        .filter(d => d.name || d.deviceName)
        .sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired)
                        || (a.name || a.deviceName).localeCompare(b.name || b.deviceName))

    spacing: 12

    CcPageHeader {
        Layout.fillWidth: true
        title: "Bluetooth"
        onBack: page.cc.page = "main"

        CcSwitch {
            visible: page.adapter !== null
            checked: page.enabled
            onToggled: page.adapter.enabled = !page.adapter.enabled
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        spacing: 8

        Text {
            Layout.fillWidth: true
            text: page.enabled ? "Devices" : "Bluetooth is turned off"
            color: Theme.on_surface_variant
            font.family: Theme.font
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }

        Rectangle {
            visible: page.enabled
            implicitWidth: scanRow.implicitWidth + 24
            implicitHeight: 32
            radius: 12
            color: page.adapter && page.adapter.discovering ? Theme.alpha(Theme.primary, 0.22)
                 : scanArea.containsMouse ? Theme.alpha(Theme.on_surface, 0.08)
                 : Theme.surface_container_high

            RowLayout {
                id: scanRow
                anchors.centerIn: parent
                spacing: 6

                LucideIcon {
                    id: scanIcon
                    icon: "refresh-cw"
                    size: 15
                    color: Theme.primary

                    NumberAnimation on rotation {
                        running: page.adapter ? page.adapter.discovering : false
                        from: 0
                        to: 360
                        duration: 1100
                        loops: Animation.Infinite
                        onRunningChanged: if (!running) scanIcon.rotation = 0
                    }
                }

                Text {
                    text: page.adapter && page.adapter.discovering ? "Scanning" : "Scan"
                    color: Theme.on_surface
                    font.family: Theme.font
                    font.pixelSize: 13
                }
            }

            MouseArea {
                id: scanArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: page.adapter.discovering = !page.adapter.discovering
            }
        }
    }

    Flickable {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(list.implicitHeight, 440)
        visible: page.enabled
        contentHeight: list.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: list
            width: parent.width
            spacing: 6

            Text {
                visible: page.devices.length === 0
                Layout.leftMargin: 4
                text: "No devices yet - put yours in pairing mode and press Scan"
                color: Theme.on_surface_variant
                font.family: Theme.font
                font.pixelSize: 13
            }

            Repeater {
                model: page.devices

                CcRow {
                    id: row
                    required property var modelData
                    property bool pending: false
                    readonly property real batteryPercent: modelData.battery > 1 ? modelData.battery : modelData.battery * 100

                    Layout.fillWidth: true
                    icon: modelData.connected ? "bluetooth-connected" : "bluetooth"
                    title: modelData.name || modelData.deviceName
                    highlighted: modelData.connected
                    busy: pending || modelData.pairing
                    subtitle: modelData.pairing ? "Pairing…"
                        : pending ? (modelData.connected ? "Disconnecting…" : "Connecting…")
                        : modelData.connected
                            ? "Connected" + (modelData.batteryAvailable ? ` · ${Math.round(batteryPercent)}%` : "")
                        : modelData.paired ? "Paired" : "Available"
                    actionIcon: modelData.connected ? "x" : "check"

                    onActionClicked: {
                        pending = true
                        pendingTimeout.restart()
                        if (modelData.connected) {
                            modelData.connected = false
                        } else if (modelData.paired) {
                            modelData.trusted = true
                            modelData.connected = true
                        } else {
                            modelData.connected = true
                        }
                    }

                    Connections {
                        target: row.modelData
                        function onConnectedChanged() {
                            row.pending = false
                        }
                    }

                    Timer {
                        id: pendingTimeout
                        interval: 15000
                        onTriggered: row.pending = false
                    }
                }
            }
        }
    }
}
