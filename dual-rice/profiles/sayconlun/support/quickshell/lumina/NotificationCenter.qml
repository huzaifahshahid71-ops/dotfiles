// Notification centre (Super+N, or the bar's bell): the history, Do Not
// Disturb and clear-all, hanging from the bar like the control centre.
// The history lives here until the dashboard exists.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    property bool open: false
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

    LazyLoader {
        active: root.open

        PanelWindow {
            id: win
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
            WlrLayershell.namespace: "rice-notifcenter"
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
                width: 460
                height: Math.min(content.implicitHeight + 36, parent.height - 20)
                radius: 28
                color: Theme.alpha(Theme.surface_container, 0.97)
                border.width: 1
                border.color: Theme.alpha(Theme.outline_variant, 0.7)
                clip: true

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
                Behavior on height {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
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

                        Item {
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            visible: NotifService.count > 0
                            implicitWidth: clearRow.implicitWidth + 24
                            implicitHeight: 34
                            radius: 12
                            color: clearArea.containsMouse ? Theme.alpha(Theme.error, 0.2) : Theme.surface_container_high

                            RowLayout {
                                id: clearRow
                                anchors.centerIn: parent
                                spacing: 6

                                LucideIcon {
                                    icon: "trash-2"
                                    size: 15
                                    color: clearArea.containsMouse ? Theme.error : Theme.on_surface
                                }

                                Text {
                                    text: "Clear all"
                                    color: Theme.on_surface
                                    font.family: Theme.font
                                    font.pixelSize: 13
                                }
                            }

                            MouseArea {
                                id: clearArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: NotifService.clear()
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 52
                        radius: 18
                        color: Theme.alpha(Theme.surface_container_high, 0.85)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 14
                            spacing: 12

                            LucideIcon {
                                icon: NotifService.dnd ? "bell-off" : "bell"
                                size: 19
                                color: NotifService.dnd ? Theme.primary : Theme.on_surface
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "Do not disturb"
                                color: Theme.on_surface
                                font.family: Theme.font
                                font.pixelSize: 14
                            }

                            CcSwitch {
                                checked: NotifService.dnd
                                onToggled: NotifService.dnd = !NotifService.dnd
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 18
                        Layout.bottomMargin: 18
                        visible: NotifService.count === 0
                        spacing: 8

                        LucideIcon {
                            Layout.alignment: Qt.AlignHCenter
                            icon: "bell"
                            size: 34
                            color: Theme.on_surface_variant
                            opacity: 0.6
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "You're all caught up"
                            color: Theme.on_surface_variant
                            font.family: Theme.font
                            font.pixelSize: 14
                        }
                    }

                    Flickable {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(list.implicitHeight, win.height - 200)
                        visible: NotifService.count > 0
                        contentHeight: list.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        ColumnLayout {
                            id: list
                            width: parent.width
                            spacing: 8

                            Repeater {
                                model: NotifService.list

                                NotifCard {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    entry: modelData
                                    compact: true
                                    color: Theme.alpha(Theme.surface_container_high, 0.85)
                                    onDismissed: NotifService.dismiss(modelData)
                                    onActionInvoked: {
                                        NotifService.dismiss(modelData)
                                        root.close()
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
