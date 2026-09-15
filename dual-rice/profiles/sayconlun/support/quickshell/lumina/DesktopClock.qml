// Desktop clock: big time, an accent line, the date - centred in the upper
// part of every monitor, on the BOTTOM layer (on the wallpaper, under windows),
// so it shows whenever the desktop does. Takes no clicks.
//
//   qs -c lumina ipc call clock toggle      (or the settings hub)
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

Scope {
    id: root

    property bool enabled: true

    readonly property bool use24h: false       // the bar shows 12-hour, so this does too
    readonly property real topFraction: 0.12   // band top, as a share of screen height
    readonly property int timeSize: 120
    readonly property int dateSize: 24

    property date now: new Date()

    function toggle() {
        enabled = !enabled
    }

    // Ticks on the second, so the minute turns over on time; drawing only
    // changes once a minute because the text only does.
    Timer {
        running: root.enabled
        repeat: true
        interval: 1000
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData

            screen: modelData
            visible: root.enabled
            anchors {
                top: true
                left: true
                right: true
            }
            margins.top: Math.round(modelData.height * root.topFraction)
            implicitHeight: root.timeSize + root.dateSize + 90
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            mask: Region {}
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "rice-clock"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Item {
                anchors.fill: parent

                // A soft shadow keeps it readable on bright wallpapers.
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Qt.rgba(0, 0, 0, 0.55)
                    shadowBlur: 0.9
                    shadowVerticalOffset: 3
                }

                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 10
                    spacing: 10

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 10

                        // The accent colour, so the clock follows the wallpaper's palette.
                        Text {
                            id: time
                            text: Qt.formatDateTime(root.now, root.use24h ? "HH:mm" : "h:mm")
                            color: Theme.primary
                            Behavior on color {
                                ColorAnimation { duration: 400 }
                            }
                            font.family: Theme.font
                            font.pixelSize: root.timeSize
                            font.weight: Font.Bold
                            font.features: { "tnum": 1 }    // digits keep their width
                        }

                        Text {
                            visible: !root.use24h
                            anchors.baseline: time.baseline
                            text: Qt.formatDateTime(root.now, "AP")
                            color: Theme.primary
                            Behavior on color {
                                ColorAnimation { duration: 400 }
                            }
                            opacity: 0.75
                            font.family: Theme.font
                            font.pixelSize: Math.round(root.timeSize * 0.24)
                            font.weight: Font.DemiBold
                        }
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 44
                        height: 4
                        radius: 2
                        color: Theme.primary
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(root.now, "dddd, d MMMM")
                        color: Theme.on_surface
                        opacity: 0.85
                        font.family: Theme.font
                        font.pixelSize: root.dateSize
                    }
                }
            }
        }
    }
}
