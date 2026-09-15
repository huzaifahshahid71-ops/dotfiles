// Control centre · Ethernet: link details, automatic connect, and
// connect/disconnect when a cable is in.
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: page

    property var cc
    readonly property var device: cc.wiredDevice

    spacing: 12

    CcPageHeader {
        Layout.fillWidth: true
        title: "Ethernet"
        onBack: page.cc.page = "main"
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: info.implicitHeight + 28
        radius: 20
        color: Theme.alpha(Theme.surface_container_high, 0.85)
        border.width: 1
        border.color: Theme.alpha(Theme.outline_variant, 0.45)

        GridLayout {
            id: info
            anchors.fill: parent
            anchors.margins: 16
            columns: 2
            columnSpacing: 16
            rowSpacing: 10

            Repeater {
                model: [
                    ["Status", !page.device ? "Not available"
                        : !page.device.hasLink ? "Cable unplugged"
                        : page.device.connected ? "Connected" : "Disconnected"],
                    ["Interface", page.device ? page.device.name : "-"],
                    ["MAC address", page.device ? page.device.address : "-"],
                    ["Speed", page.device && page.device.hasLink && page.device.linkSpeed ? page.device.linkSpeed + " Mb/s" : "-"]
                ]

                delegate: RowLayout {
                    required property var modelData
                    Layout.columnSpan: 2
                    Layout.fillWidth: true

                    Text {
                        Layout.fillWidth: true
                        text: modelData[0]
                        color: Theme.on_surface_variant
                        font.family: Theme.font
                        font.pixelSize: 13
                    }

                    Text {
                        text: modelData[1]
                        color: Theme.on_surface
                        font.family: Theme.font
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                }
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        visible: page.device !== null
        implicitHeight: actions.implicitHeight + 28
        radius: 20
        color: Theme.alpha(Theme.surface_container_high, 0.85)
        border.width: 1
        border.color: Theme.alpha(Theme.outline_variant, 0.45)

        ColumnLayout {
            id: actions
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    text: "Connect automatically"
                    color: Theme.on_surface
                    font.family: Theme.font
                    font.pixelSize: 14
                }

                CcSwitch {
                    checked: page.device ? page.device.autoconnect : false
                    onToggled: page.device.autoconnect = !page.device.autoconnect
                }
            }

            Rectangle {
                Layout.fillWidth: true
                visible: page.device && page.device.hasLink
                implicitHeight: 42
                radius: 14
                color: connectArea.containsMouse ? Theme.primary : Theme.alpha(Theme.primary, 0.16)

                Text {
                    anchors.centerIn: parent
                    text: page.device && page.device.connected ? "Disconnect" : "Connect"
                    color: connectArea.containsMouse ? Theme.on_primary : Theme.primary
                    font.family: Theme.font
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }

                MouseArea {
                    id: connectArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (page.device.connected)
                            page.device.disconnect()
                        else if (page.device.network)
                            page.device.network.connect()
                    }
                }
            }
        }
    }
}
