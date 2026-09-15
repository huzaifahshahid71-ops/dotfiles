// Capture menu (Super+Shift+S, or the bar's screenshot button): screenshot
// or record the screen, a window or an area. While recording it becomes a
// timer with a Stop button. The work itself is in Capture.qml.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    property bool open: false
    property var capture: null
    property var targetScreen: null

    function show() {
        if (open)
            return
        targetScreen = focusedScreen()
        open = true
    }

    function close() {
        open = false
    }

    function toggle() {
        open ? close() : show()
    }

    function focusedScreen() {
        const name = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
        const screens = Quickshell.screens
        for (let i = 0; i < screens.length; i++)
            if (screens[i].name === name)
                return screens[i]
        return screens[0]
    }

    component Tile: Rectangle {
        id: tile
        property string icon: ""
        property string label: ""
        signal clicked

        Layout.fillWidth: true
        implicitHeight: 88
        radius: 18
        color: tileArea.containsMouse ? Theme.alpha(Theme.primary, 0.16) : Theme.alpha(Theme.surface_container_high, 0.85)
        border.width: 1
        border.color: tileArea.containsMouse ? Theme.alpha(Theme.primary, 0.6) : Theme.alpha(Theme.outline_variant, 0.45)

        Column {
            anchors.centerIn: parent
            spacing: 8

            LucideIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                icon: tile.icon
                size: 24
                color: Theme.primary
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: tile.label
                color: Theme.on_surface
                font.family: Theme.font
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }
        }

        MouseArea {
            id: tileArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.clicked()
        }
    }

    component SectionLabel: Text {
        Layout.leftMargin: 4
        Layout.topMargin: 4
        color: Theme.on_surface_variant
        font.family: Theme.font
        font.pixelSize: 12
        font.weight: Font.Bold
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 1
    }

    LazyLoader {
        active: root.open

        PanelWindow {
            screen: root.targetScreen
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Normal
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "rice-capture"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            MouseArea {
                anchors.fill: parent
                onClicked: root.close()
            }

            Rectangle {
                id: panel
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 8
                anchors.rightMargin: 10
                width: 420
                height: content.implicitHeight + 36
                radius: 26
                color: Theme.alpha(Theme.surface_container, 0.97)
                border.width: 1
                border.color: Theme.alpha(Theme.outline_variant, 0.7)

                transformOrigin: Item.TopRight
                opacity: 0
                scale: 0.96
                Component.onCompleted: {
                    opacity = 1
                    scale = 1
                    keys.forceActiveFocus()
                }
                Behavior on opacity {
                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                }
                Behavior on scale {
                    NumberAnimation { duration: 170; easing.type: Easing.OutCubic }
                }

                MouseArea {
                    anchors.fill: parent
                }

                Item {
                    id: keys
                    focus: true
                    Keys.onEscapePressed: root.close()
                }

                ColumnLayout {
                    id: content
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 18
                    spacing: 10

                    Text {
                        Layout.leftMargin: 4
                        text: "Capture"
                        color: Theme.on_surface
                        font.family: Theme.font
                        font.pixelSize: 22
                        font.weight: Font.Bold
                    }

                    // ------------------------------------------ while recording --
                    Rectangle {
                        Layout.fillWidth: true
                        visible: root.capture && root.capture.recording
                        implicitHeight: 76
                        radius: 20
                        color: Theme.alpha(Theme.error, 0.12)
                        border.width: 1
                        border.color: Theme.alpha(Theme.error, 0.5)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 20
                            anchors.rightMargin: 14
                            spacing: 14

                            Rectangle {
                                implicitWidth: 14
                                implicitHeight: 14
                                radius: 7
                                color: Theme.error

                                SequentialAnimation on opacity {
                                    running: root.capture && root.capture.recording
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 0.25; duration: 650 }
                                    NumberAnimation { to: 1; duration: 650 }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                Text {
                                    text: "Recording"
                                    color: Theme.on_surface
                                    font.family: Theme.font
                                    font.pixelSize: 15
                                    font.weight: Font.Bold
                                }

                                Text {
                                    text: root.capture ? root.capture.elapsedText : ""
                                    color: Theme.on_surface_variant
                                    font.family: Theme.mono
                                    font.pixelSize: 13
                                }
                            }

                            Rectangle {
                                implicitWidth: stopRow.implicitWidth + 28
                                implicitHeight: 42
                                radius: 21
                                color: stopArea.containsMouse ? Qt.lighter(Theme.error, 1.1) : Theme.error

                                RowLayout {
                                    id: stopRow
                                    anchors.centerIn: parent
                                    spacing: 8

                                    LucideIcon {
                                        icon: "square"
                                        size: 15
                                        color: Theme.on_error
                                    }

                                    Text {
                                        text: "Stop"
                                        color: Theme.on_error
                                        font.family: Theme.font
                                        font.pixelSize: 14
                                        font.weight: Font.Bold
                                    }
                                }

                                MouseArea {
                                    id: stopArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.capture.stop()
                                        root.close()
                                    }
                                }
                            }
                        }
                    }

                    // --------------------------------------------- screenshot --
                    SectionLabel {
                        visible: !(root.capture && root.capture.recording)
                        text: "Screenshot"
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: !(root.capture && root.capture.recording)
                        spacing: 8

                        Tile {
                            icon: "monitor"
                            label: "Screen"
                            onClicked: {
                                root.close()
                                root.capture.screenshot("screen")
                            }
                        }

                        Tile {
                            icon: "app-window"
                            label: "Window"
                            onClicked: {
                                root.close()
                                root.capture.screenshot("window")
                            }
                        }

                        Tile {
                            icon: "crop"
                            label: "Area"
                            onClicked: {
                                root.close()
                                root.capture.screenshot("area")
                            }
                        }
                    }

                    // ------------------------------------------------- record --
                    SectionLabel {
                        visible: !(root.capture && root.capture.recording)
                        text: "Record"
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: !(root.capture && root.capture.recording)
                        spacing: 8

                        Tile {
                            icon: "video"
                            label: "Screen"
                            onClicked: {
                                root.close()
                                root.capture.record("screen")
                            }
                        }

                        Tile {
                            icon: "crop"
                            label: "Area"
                            onClicked: {
                                root.close()
                                root.capture.record("area")
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        visible: !(root.capture && root.capture.recording)
                        implicitHeight: audio.implicitHeight + 20
                        radius: 18
                        color: Theme.alpha(Theme.surface_container_high, 0.85)

                        ColumnLayout {
                            id: audio
                            anchors.fill: parent
                            anchors.margins: 10
                            anchors.leftMargin: 16
                            spacing: 6

                            Repeater {
                                model: [
                                    { icon: "volume-2", label: "Desktop audio", key: "desktopAudio" },
                                    { icon: "mic", label: "Microphone", key: "micAudio" }
                                ]

                                RowLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: 12

                                    LucideIcon {
                                        icon: modelData.icon
                                        size: 17
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.label
                                        color: Theme.on_surface
                                        font.family: Theme.font
                                        font.pixelSize: 14
                                    }

                                    CcSwitch {
                                        checked: root.capture ? root.capture[modelData.key] : false
                                        onToggled: root.capture[modelData.key] = !root.capture[modelData.key]
                                    }
                                }
                            }
                        }
                    }

                    // ------------------------------------------------ folders --
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 2
                        spacing: 8

                        Repeater {
                            model: [
                                { icon: "image", label: "Screenshots", dir: root.capture ? root.capture.shotDir : "" },
                                { icon: "film", label: "Recordings", dir: root.capture ? root.capture.videoDir : "" }
                            ]

                            Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                implicitHeight: 40
                                radius: 14
                                color: folderArea.containsMouse ? Theme.alpha(Theme.on_surface, 0.08) : "transparent"

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 8

                                    LucideIcon {
                                        icon: modelData.icon
                                        size: 16
                                        color: Theme.on_surface_variant
                                    }

                                    Text {
                                        text: modelData.label
                                        color: Theme.on_surface_variant
                                        font.family: Theme.font
                                        font.pixelSize: 13
                                    }
                                }

                                MouseArea {
                                    id: folderArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.close()
                                        Quickshell.execDetached(["bash", "-c", 'mkdir -p "$1" && exec thunar "$1"', "_", modelData.dir])
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
