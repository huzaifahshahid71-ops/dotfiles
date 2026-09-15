// The lock screen's content, shared by the real lock (one per monitor) and
// the preview window. See Lock.qml for the safety notes.
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

Item {
    id: surface

    property var lock
    property bool preview: false
    property date now: new Date()
    property string armed: ""               // restart / poweroff waiting for a second click

    readonly property string home: Quickshell.env("HOME")

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: surface.now = new Date()
    }

    Timer {
        id: disarm
        interval: 3000
        onTriggered: surface.armed = ""
    }

    Connections {
        target: surface.lock
        function onFailed() {
            input.text = ""
            shake.restart()
            input.forceActiveFocus()
        }
    }

    function power(action) {
        if (surface.preview)
            return
        if (action !== "suspend" && armed !== action) {
            armed = action
            disarm.restart()
            return
        }
        armed = ""
        Quickshell.execDetached(["systemctl", action])
    }

    // ------------------------------------------------------------ backdrop --
    Image {
        id: wallpaper
        anchors.fill: parent
        source: "file://" + surface.home + "/.local/share/desktop-profiles/sayconlun/support/state/cache/wallpaper"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        source: wallpaper
        blurEnabled: true
        blur: 1.0
        blurMax: 64
        brightness: -0.2
        saturation: 0.1
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.35)
    }

    MouseArea {
        anchors.fill: parent
        onClicked: input.forceActiveFocus()
    }

    // ------------------------------------------------------------- content --
    ColumnLayout {
        anchors.centerIn: parent
        width: 440
        spacing: 16

        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: 10

            Text {
                id: bigTime
                text: Qt.formatTime(surface.now, "h:mm")
                color: "white"
                font.family: Theme.font
                font.pixelSize: 120
                font.weight: Font.Bold
                font.features: { "tnum": 1 }
            }

            Text {
                anchors.baseline: bigTime.baseline
                text: Qt.formatTime(surface.now, "AP")
                color: "white"
                opacity: 0.75
                font.family: Theme.font
                font.pixelSize: 28
                font.weight: Font.DemiBold
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDate(surface.now, "dddd, d MMMM")
            color: "white"
            opacity: 0.8
            font.family: Theme.font
            font.pixelSize: 22
        }

        Item { Layout.preferredHeight: 26 }

        ClippingRectangle {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 96
            implicitHeight: 96
            radius: 48
            color: Theme.alpha(Theme.surface_container, 0.85)
            border.width: 2
            border.color: Theme.primary

            Image {
                id: face
                anchors.fill: parent
                source: "file://" + surface.home + "/.face"
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }

            LucideIcon {
                anchors.centerIn: parent
                visible: face.status !== Image.Ready
                icon: "user"
                size: 44
                color: "white"
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Quickshell.env("USER") || ""
            color: "white"
            font.family: Theme.font
            font.pixelSize: 22
            font.weight: Font.Bold
        }

        Rectangle {
            id: field
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 360
            implicitHeight: 56
            radius: 28
            color: Theme.alpha(Theme.surface_container, 0.85)
            border.width: 2
            border.color: surface.lock && surface.lock.error ? Theme.error
                        : input.activeFocus ? Theme.primary : Theme.alpha(Theme.outline_variant, 0.8)
            Behavior on border.color {
                ColorAnimation { duration: 150 }
            }

            transform: Translate { id: shakeOffset }

            SequentialAnimation {
                id: shake
                NumberAnimation { target: shakeOffset; property: "x"; to: -14; duration: 50 }
                NumberAnimation { target: shakeOffset; property: "x"; to: 14; duration: 70 }
                NumberAnimation { target: shakeOffset; property: "x"; to: -9; duration: 60 }
                NumberAnimation { target: shakeOffset; property: "x"; to: 9; duration: 60 }
                NumberAnimation { target: shakeOffset; property: "x"; to: 0; duration: 50 }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 22
                anchors.rightMargin: 8
                spacing: 12

                LucideIcon {
                    icon: "lock"
                    size: 18
                    color: "white"
                    opacity: 0.8
                }

                TextInput {
                    id: input
                    Layout.fillWidth: true
                    echoMode: TextInput.Password
                    passwordCharacter: "●"
                    color: "white"
                    font.family: Theme.font
                    font.pixelSize: 18
                    clip: true
                    focus: true
                    enabled: !(surface.lock && surface.lock.busy)
                    Component.onCompleted: forceActiveFocus()
                    onTextChanged: if (text && surface.lock) surface.lock.error = ""
                    Keys.onReturnPressed: surface.lock.submit(text)
                    Keys.onEnterPressed: surface.lock.submit(text)
                    Keys.onEscapePressed: {
                        if (text)
                            text = ""
                        else if (surface.preview)
                            surface.lock.endPreview()
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !input.text
                        text: "Password"
                        color: "white"
                        opacity: 0.45
                        font: input.font
                    }
                }

                Rectangle {
                    implicitWidth: 40
                    implicitHeight: 40
                    radius: 20
                    color: Theme.primary

                    LucideIcon {
                        id: submitIcon
                        anchors.centerIn: parent
                        icon: surface.lock && surface.lock.busy ? "loader-circle" : "arrow-right"
                        size: 18
                        color: Theme.on_primary

                        NumberAnimation on rotation {
                            running: surface.lock && surface.lock.busy
                            from: 0
                            to: 360
                            duration: 900
                            loops: Animation.Infinite
                            onRunningChanged: if (!running) submitIcon.rotation = 0
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: surface.lock.submit(input.text)
                    }
                }
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: 20
            text: surface.lock ? surface.lock.error : ""
            color: Theme.error
            font.family: Theme.font
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            visible: surface.preview
            text: "Preview - nothing is locked. Try your password, or Esc to close."
            color: "white"
            opacity: 0.75
            font.family: Theme.font
            font.pixelSize: 13
        }

        // What's playing
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 10
            visible: MediaState.player !== null
            implicitWidth: Math.min(nowRow.implicitWidth + 30, 440)
            implicitHeight: 48
            radius: 24
            color: Theme.alpha(Theme.surface_container, 0.7)

            RowLayout {
                id: nowRow
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 6
                spacing: 12

                LucideIcon {
                    icon: "music"
                    size: 16
                    color: Theme.primary
                }

                Text {
                    Layout.maximumWidth: 320
                    text: MediaState.title + (MediaState.artist ? "  ·  " + MediaState.artist : "")
                    elide: Text.ElideRight
                    color: "white"
                    font.family: Theme.font
                    font.pixelSize: 14
                }

                DashButton {
                    icon: MediaState.playing ? "pause" : "play"
                    size: 36
                    iconSize: 16
                    accent: true
                    onClicked: MediaState.toggle()
                }
            }
        }
    }

    // ---------------------------------------------------------------- power --
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 50
        spacing: 26
        opacity: surface.preview ? 0.4 : 1

        Repeater {
            model: [
                { action: "suspend", icon: "moon", label: "Suspend" },
                { action: "reboot", icon: "rotate-ccw", label: "Restart" },
                { action: "poweroff", icon: "power", label: "Power off" }
            ]

            Column {
                required property var modelData
                readonly property bool isArmed: surface.armed === modelData.action
                spacing: 8

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 56
                    height: 56
                    radius: 28
                    color: isArmed ? Theme.error
                         : powerArea.containsMouse ? Theme.alpha(Theme.primary, 0.35) : Theme.alpha(Theme.surface_container, 0.7)

                    LucideIcon {
                        anchors.centerIn: parent
                        icon: modelData.icon
                        size: 22
                        color: isArmed ? Theme.on_error : "white"
                    }

                    MouseArea {
                        id: powerArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: surface.preview ? Qt.ArrowCursor : Qt.PointingHandCursor
                        onClicked: surface.power(modelData.action)
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: isArmed ? "Click again" : modelData.label
                    color: "white"
                    opacity: 0.8
                    font.family: Theme.font
                    font.pixelSize: 12
                }
            }
        }
    }
}
