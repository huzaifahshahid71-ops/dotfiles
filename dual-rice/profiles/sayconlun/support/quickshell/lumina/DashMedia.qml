// Dashboard · Media: round album art that pulses with the bass (from the
// desktop visualiser's levels), a player switcher, the track, seek bar and
// transport. Modelled on Nisfere's Media tab.
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets

RowLayout {
    id: page

    property var dash
    property bool pickingPlayer: false

    // cava's stereo layout puts the lowest frequencies in the middle bars.
    readonly property real bass: {
        const v = dash && dash.visualiser ? dash.visualiser.levels : []
        if (!v || !v.length)
            return 0
        const mid = Math.floor(v.length / 2)
        let sum = 0, n = 0
        for (let i = mid - 6; i < mid + 6; i++) {
            if (i >= 0 && i < v.length) {
                sum += v[i]
                n++
            }
        }
        return n ? sum / n : 0
    }

    spacing: 44
    implicitHeight: 360

    Item {
        Layout.preferredWidth: 320
        Layout.preferredHeight: 320
        Layout.leftMargin: 20
        Layout.alignment: Qt.AlignVCenter

        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.86
            height: width
            radius: width / 2
            color: Theme.primary
            opacity: MediaState.playing ? 0.1 + page.bass * 0.4 : 0.06
            scale: 1 + (MediaState.playing ? page.bass * 0.22 : 0)
            Behavior on opacity {
                NumberAnimation { duration: 90 }
            }
            Behavior on scale {
                NumberAnimation { duration: 90 }
            }
        }

        ClippingRectangle {
            anchors.centerIn: parent
            width: parent.width * 0.7
            height: width
            radius: width / 2
            color: Theme.surface_container_highest
            border.width: 3
            border.color: Theme.primary

            Image {
                id: art
                anchors.fill: parent
                source: MediaState.art
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }

            LucideIcon {
                anchors.centerIn: parent
                visible: art.status !== Image.Ready
                icon: "music"
                size: 64
                color: Theme.on_surface_variant
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.rightMargin: 20
        Layout.alignment: Qt.AlignVCenter
        spacing: 10

        // Player switcher
        Rectangle {
            visible: MediaState.players.length > 0
            implicitWidth: switcherRow.implicitWidth + 26
            implicitHeight: 32
            radius: 16
            color: switcherArea.containsMouse ? Theme.alpha(Theme.primary, 0.18) : Theme.alpha(Theme.surface_container_high, 0.85)

            RowLayout {
                id: switcherRow
                anchors.centerIn: parent
                spacing: 8

                LucideIcon {
                    icon: "disc"
                    size: 15
                    color: Theme.primary
                }

                Text {
                    text: MediaState.player ? MediaState.player.identity.toUpperCase() : ""
                    color: Theme.on_surface
                    font.family: Theme.font
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    font.letterSpacing: 1.2
                }

                LucideIcon {
                    visible: MediaState.players.length > 1
                    icon: "chevron-right"
                    rotation: page.pickingPlayer ? 270 : 90
                    size: 14
                }
            }

            MouseArea {
                id: switcherArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: MediaState.players.length > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: if (MediaState.players.length > 1) page.pickingPlayer = !page.pickingPlayer
            }
        }

        Column {
            visible: page.pickingPlayer
            spacing: 4

            Repeater {
                model: MediaState.players

                Rectangle {
                    required property var modelData
                    width: 300
                    height: 36
                    radius: 12
                    color: modelData === MediaState.player ? Theme.alpha(Theme.primary, 0.16)
                         : pickArea.containsMouse ? Theme.alpha(Theme.on_surface, 0.07) : "transparent"

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        text: modelData.identity + (modelData.isPlaying ? "  ·  playing" : "")
                        color: Theme.on_surface
                        font.family: Theme.font
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: pickArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            MediaState.pick(modelData)
                            page.pickingPlayer = false
                        }
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 6
            text: MediaState.title
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            color: Theme.on_surface
            font.family: Theme.font
            font.pixelSize: 34
            font.weight: Font.Bold
        }

        Text {
            Layout.fillWidth: true
            text: MediaState.artist
            elide: Text.ElideRight
            color: Theme.on_surface_variant
            font.family: Theme.font
            font.pixelSize: 20
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 10

            Text {
                text: MediaState.time(MediaState.position)
                color: Theme.on_surface_variant
                font.family: Theme.mono
                font.pixelSize: 12
            }

            Item { Layout.fillWidth: true }

            Text {
                text: MediaState.length ? MediaState.time(MediaState.length) : "--:--"
                color: Theme.on_surface_variant
                font.family: Theme.mono
                font.pixelSize: 12
            }
        }

        DashSeek {
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 6
            spacing: 22

            DashButton {
                icon: "skip-back"
                size: 50
                iconSize: 22
                active: MediaState.player !== null
                onClicked: MediaState.previous()
            }

            DashButton {
                icon: MediaState.playing ? "pause" : "play"
                accent: true
                size: 66
                iconSize: 28
                active: MediaState.player !== null
                onClicked: MediaState.toggle()
            }

            DashButton {
                icon: "skip-forward"
                size: 50
                iconSize: 22
                active: MediaState.player !== null
                onClicked: MediaState.next()
            }
        }
    }
}
