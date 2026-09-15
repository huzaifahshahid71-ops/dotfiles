import QtQuick
import QtQuick.Layouts
import Quickshell

ShellRoot {
    PanelWindow {
        id: window

        visible: true
        implicitWidth: 820
        implicitHeight: 540
        color: "transparent"
        surfaceFormat.opaque: false
        focusable: true
        aboveWindows: true
        exclusionMode: ExclusionMode.Ignore

        onClosed: Qt.quit()

        Rectangle {
            id: root
            anchors.fill: parent
            radius: 24
            antialiasing: true
            clip: true
            color: "#101016"
            border.width: 2
            border.color: "#8b5cf6"

            focus: true

            property int page: 0
            property int compositorIndex: 0
            property int riceIndex: 0

            property var hyprRices: [
                { id: "caelestia",   icon: "✦", name: "Aether" },
                { id: "end4",        icon: "◈", name: "Obsidian" },
                { id: "ambxst",      icon: "◆", name: "Crimson" },
                { id: "dms",         icon: "●", name: "Materia" },
                { id: "serpantinum", icon: "◇", name: "Aurora" },
                { id: "noctalia",    icon: "◉", name: "Nocturne" },
                { id: "sayconlun",   icon: "⬡", name: "Lumina" }
            ]

            property var niriRices: [
                { id: "jaqc",   icon: "☀", name: "Solstice" },
                { id: "clavis", icon: "❖", name: "Cipher" }
            ]

            property var visibleRices:
                compositorIndex === 0 ? hyprRices : niriRices

            function openCompositor() {
                page = 1
                riceIndex = 0
            }

            function goBack() {
                if (page === 1) {
                    page = 0
                    riceIndex = 0
                } else {
                    Qt.quit()
                }
            }

            function activateSelection() {
                if (page === 0) {
                    openCompositor()
                    return
                }

                // Phase 1 GUI prototype only.
                // Backend activation will be wired in Phase 1C.
                console.log(
                    "Selected profile:",
                    visibleRices[riceIndex].id
                )
            }

            Keys.onPressed: event => {
                if (page === 0) {
                    if (event.key === Qt.Key_Left) {
                        compositorIndex = 0
                        event.accepted = true
                    } else if (event.key === Qt.Key_Right) {
                        compositorIndex = 1
                        event.accepted = true
                    } else if (
                        event.key === Qt.Key_Return ||
                        event.key === Qt.Key_Enter
                    ) {
                        openCompositor()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Escape) {
                        Qt.quit()
                        event.accepted = true
                    }
                } else {
                    if (event.key === Qt.Key_Up) {
                        riceIndex =
                            (riceIndex - 1 + visibleRices.length)
                            % visibleRices.length
                        event.accepted = true
                    } else if (event.key === Qt.Key_Down) {
                        riceIndex =
                            (riceIndex + 1)
                            % visibleRices.length
                        event.accepted = true
                    } else if (
                        event.key === Qt.Key_Return ||
                        event.key === Qt.Key_Enter
                    ) {
                        activateSelection()
                        event.accepted = true
                    } else if (
                        event.key === Qt.Key_Escape ||
                        event.key === Qt.Key_Left
                    ) {
                        goBack()
                        event.accepted = true
                    }
                }
            }

            Component.onCompleted: forceActiveFocus()

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 30
                spacing: 18

                RowLayout {
                    Layout.fillWidth: true

                    ColumnLayout {
                        spacing: 3

                        Text {
                            text: "HUZAIFAH"
                            color: "#a78bfa"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 14
                            font.bold: true
                        }

                        Text {
                            text: root.page === 0
                                ? "Multi-Rice"
                                : root.compositorIndex === 0
                                    ? "Hyprland Rices"
                                    : "Niri Rices"

                            color: "#f4f4f5"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 29
                            font.bold: true
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        width: 150
                        height: 38
                        radius: 19
                        color: "#1d1d28"

                        Text {
                            anchors.centerIn: parent
                            text: root.page === 0
                                ? "SELECT ENGINE"
                                : root.compositorIndex === 0
                                    ? "HYPRLAND"
                                    : "NIRI"
                            color: "#a1a1aa"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Row {
                        id: compositorPage
                        anchors.centerIn: parent
                        spacing: 28
                        visible: root.page === 0

                        Repeater {
                            model: [
                                {
                                    name: "HYPRLAND",
                                    subtitle: "7 RICES",
                                    detail: "Currently Active"
                                },
                                {
                                    name: "NIRI",
                                    subtitle: "2 RICES",
                                    detail: "Switch Session"
                                }
                            ]

                            delegate: Rectangle {
                                required property int index
                                required property var modelData

                                width: 330
                                height: 250
                                radius: 20
                                antialiasing: true

                                property bool selected:
                                    root.compositorIndex === index

                                color: selected
                                    ? "#202033"
                                    : "#17171f"

                                border.width: selected ? 3 : 1
                                border.color: selected
                                    ? "#a78bfa"
                                    : "#34343f"

                                scale: selected ? 1.035 : 1.0

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: 130
                                    }
                                }

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 14

                                    Text {
                                        anchors.horizontalCenter:
                                            parent.horizontalCenter
                                        text: index === 0 ? "H" : "N"
                                        color: selected
                                            ? "#c4b5fd"
                                            : "#71717a"
                                        font.family:
                                            "JetBrainsMono Nerd Font"
                                        font.pixelSize: 46
                                        font.bold: true
                                    }

                                    Text {
                                        anchors.horizontalCenter:
                                            parent.horizontalCenter
                                        text: modelData.name
                                        color: "#fafafa"
                                        font.family:
                                            "JetBrainsMono Nerd Font"
                                        font.pixelSize: 24
                                        font.bold: true
                                    }

                                    Text {
                                        anchors.horizontalCenter:
                                            parent.horizontalCenter
                                        text: modelData.subtitle
                                        color: "#a78bfa"
                                        font.family:
                                            "JetBrainsMono Nerd Font"
                                        font.pixelSize: 13
                                    }

                                    Text {
                                        anchors.horizontalCenter:
                                            parent.horizontalCenter
                                        text: modelData.detail
                                        color: "#71717a"
                                        font.family:
                                            "JetBrainsMono Nerd Font"
                                        font.pixelSize: 12
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: {
                                        root.compositorIndex = index
                                        root.openCompositor()
                                    }
                                }
                            }
                        }
                    }

                    Column {
                        id: ricePage
                        anchors.fill: parent
                        spacing: 6
                        visible: root.page === 1

                        Repeater {
                            model: root.visibleRices

                            delegate: Rectangle {
                                required property int index
                                required property var modelData

                                width: ricePage.width
                                height: 38
                                radius: 12

                                antialiasing: true
                                property bool selected:
                                    root.riceIndex === index

                                color: selected
                                    ? "#26263a"
                                    : "transparent"

                                border.width: selected ? 1 : 0
                                border.color: "#8b5cf6"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 18
                                    anchors.rightMargin: 18

                                    Text {
                                        text: modelData.icon
                                        color: selected
                                            ? "#c4b5fd"
                                            : "#a1a1aa"
                                        font.family:
                                            "JetBrainsMono Nerd Font"
                                        font.pixelSize: 18
                                    }

                                    Text {
                                        text: modelData.name
                                        color: selected
                                            ? "#fafafa"
                                            : "#d4d4d8"
                                        font.family:
                                            "JetBrainsMono Nerd Font"
                                        font.pixelSize: 16
                                        font.bold: selected
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        visible:
                                            modelData.id === "caelestia"
                                        text: "ACTIVE"
                                        color: "#a78bfa"
                                        font.family:
                                            "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                        font.bold: true
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: {
                                        root.riceIndex = index
                                        root.activateSelection()
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#2d2d38"
                }

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: root.page === 0
                            ? "← →  Select compositor"
                            : "↑ ↓  Select rice"
                        color: "#71717a"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Text {
                        text: root.page === 0
                            ? "ENTER  Open     ESC  Close"
                            : "ENTER  Select     ESC  Back"
                        color: "#71717a"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                    }
                }
            }
        }
    }
}
