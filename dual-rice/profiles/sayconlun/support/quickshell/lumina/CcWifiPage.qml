// Control centre · Wi-Fi: on/off, networks (connected first, then by
// signal), connect with an inline password field, disconnect, errors.
//
// A wrong password leaves NetworkManager holding a profile that will never
// work, so on NoSecrets the network is forgotten again (as Nisfere does).
import QtQuick
import QtQuick.Layouts
import Quickshell.Networking

ColumnLayout {
    id: page

    property var cc
    property string prompt: ""            // network whose password field is open
    property string errorFor: ""
    property string error: ""

    readonly property var networks: cc.wifiNetworks
        .filter(n => n.name)
        .sort((a, b) => (b.connected - a.connected) || (b.signalStrength - a.signalStrength))

    function connect(net, psk) {
        errorFor = ""
        prompt = ""
        cc.refocus()
        if (psk)
            net.connectWithPsk(psk)
        else
            net.connect()
    }

    function failText(reason) {
        switch (reason) {
        case ConnectionFailReason.NoSecrets: return "Wrong password"
        case ConnectionFailReason.WifiAuthTimeout: return "Timed out while authenticating"
        case ConnectionFailReason.WifiNetworkLost: return "Network lost"
        default: return "Could not connect"
        }
    }

    spacing: 12

    CcPageHeader {
        Layout.fillWidth: true
        title: "Wi-Fi"
        onBack: page.cc.page = "main"

        CcSwitch {
            checked: Networking.wifiEnabled
            onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
        }
    }

    Text {
        Layout.leftMargin: 4
        text: Networking.wifiEnabled ? "Available networks" : "Wi-Fi is turned off"
        color: Theme.on_surface_variant
        font.family: Theme.font
        font.pixelSize: 13
        font.weight: Font.DemiBold
    }

    Flickable {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(list.implicitHeight, 440)
        visible: Networking.wifiEnabled
        contentHeight: list.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: list
            width: parent.width
            spacing: 6

            Text {
                visible: page.networks.length === 0
                Layout.leftMargin: 4
                text: "Scanning…"
                color: Theme.on_surface_variant
                font.family: Theme.font
                font.pixelSize: 13
            }

            Repeater {
                model: page.networks

                ColumnLayout {
                    id: entry
                    required property var modelData
                    readonly property bool secured: modelData.security !== WifiSecurityType.Open
                    readonly property bool prompting: page.prompt === modelData.name

                    Layout.fillWidth: true
                    spacing: 4

                    Connections {
                        target: entry.modelData
                        function onConnectionFailed(reason) {
                            page.errorFor = entry.modelData.name
                            page.error = page.failText(reason)
                            if (reason === ConnectionFailReason.NoSecrets)
                                entry.modelData.forget()
                        }
                        function onConnectedChanged() {
                            if (entry.modelData.connected && page.errorFor === entry.modelData.name)
                                page.errorFor = ""
                        }
                    }

                    CcRow {
                        Layout.fillWidth: true
                        icon: page.cc.wifiIcon(entry.modelData.signalStrength)
                        title: entry.modelData.name
                        highlighted: entry.modelData.connected
                        busy: entry.modelData.stateChanging
                        subtitle: entry.modelData.stateChanging
                                ? (entry.modelData.state === ConnectionState.Disconnecting ? "Disconnecting…" : "Connecting…")
                            : entry.modelData.connected ? "Connected"
                            : entry.modelData.known ? "Saved"
                            : entry.secured ? "Secured" : "Open"
                        actionIcon: entry.prompting || entry.modelData.connected ? "x" : "check"
                        onActionClicked: {
                            if (entry.prompting) {
                                page.prompt = ""
                                page.cc.refocus()
                            } else if (entry.modelData.connected) {
                                entry.modelData.disconnect()
                            } else if (entry.modelData.known || !entry.secured) {
                                page.connect(entry.modelData, "")
                            } else {
                                page.prompt = entry.modelData.name
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        visible: entry.prompting
                        implicitHeight: 46
                        radius: 14
                        color: Theme.surface_container_lowest
                        border.width: 1
                        border.color: password.activeFocus ? Theme.primary : Theme.outline_variant

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 6
                            spacing: 8

                            LucideIcon {
                                icon: "lock"
                                size: 16
                                color: Theme.on_surface_variant
                            }

                            TextInput {
                                id: password
                                Layout.fillWidth: true
                                echoMode: TextInput.Password
                                color: Theme.on_surface
                                font.family: Theme.font
                                font.pixelSize: 14
                                clip: true
                                onVisibleChanged: if (visible) forceActiveFocus()
                                Keys.onReturnPressed: page.connect(entry.modelData, text)
                                Keys.onEnterPressed: page.connect(entry.modelData, text)
                                Keys.onEscapePressed: {
                                    page.prompt = ""
                                    page.cc.refocus()
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: !password.text
                                    text: "Password"
                                    color: Theme.on_surface_variant
                                    font: password.font
                                }
                            }

                            Rectangle {
                                implicitWidth: 34
                                implicitHeight: 34
                                radius: 12
                                color: Theme.primary

                                LucideIcon {
                                    anchors.centerIn: parent
                                    icon: "check"
                                    size: 17
                                    color: Theme.on_primary
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: page.connect(entry.modelData, password.text)
                                }
                            }
                        }
                    }

                    Text {
                        Layout.leftMargin: 14
                        visible: page.errorFor === entry.modelData.name
                        text: page.error
                        color: Theme.error
                        font.family: Theme.font
                        font.pixelSize: 12
                    }
                }
            }
        }
    }
}
