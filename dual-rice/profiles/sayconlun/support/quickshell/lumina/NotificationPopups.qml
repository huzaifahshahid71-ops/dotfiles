// Notification popup, modelled on Nisfere's: the newest notification as a
// card in the bottom-right corner of the focused monitor, with a countdown
// bar. Hovering pauses the countdown; critical ones stay until dismissed.
// Everything also lands in the notification centre.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    property var current: null
    property real progress: 1
    property bool hovered: false
    property var targetScreen: null
    readonly property int timeout: 5000

    function focusedScreen() {
        const name = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
        const screens = Quickshell.screens
        for (let i = 0; i < screens.length; i++)
            if (screens[i].name === name)
                return screens[i]
        return screens[0]
    }

    function hide() {
        countdown.stop()
        current = null
    }

    onCurrentChanged: if (!current) outro.restart()

    Connections {
        target: NotifService

        function onPopup(entry) {
            if (!root.current)
                root.targetScreen = root.focusedScreen()
            root.current = entry
            root.progress = 1
            if (entry.critical)
                countdown.stop()
            else
                countdown.restart()
        }

        // Dismissed from the centre, or closed by its sender, while showing.
        function onListChanged() {
            const c = root.current
            if (c && !NotifService.list.some(e => e.id === c.id && e.app === c.app))
                root.hide()
        }
    }

    NumberAnimation {
        id: countdown
        target: root
        property: "progress"
        from: 1
        to: 0
        duration: root.timeout
        paused: running && root.hovered
        onFinished: root.current = null
    }

    Timer {
        id: outro                                  // keeps the window for the fade-out
        interval: 300
    }

    LazyLoader {
        active: root.current !== null || outro.running

        PanelWindow {
            screen: root.targetScreen
            anchors {
                bottom: true
                right: true
            }
            margins {
                bottom: 24
                right: 24
            }
            implicitWidth: 420
            implicitHeight: card.implicitHeight + 24
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            mask: Region { item: card }
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "rice-notifications"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            NotifCard {
                id: card
                property bool live: false
                property var lastEntry: null           // keeps the text during the fade-out
                readonly property bool visibleNow: root.current !== null && live

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                entry: root.current || lastEntry
                progress: root.current && !root.current.critical ? root.progress : -1
                Component.onCompleted: live = true

                opacity: visibleNow ? 1 : 0
                scale: visibleNow ? 1 : 0.96
                transform: Translate {
                    y: card.visibleNow ? 0 : 26
                    Behavior on y {
                        NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                    }
                }
                Behavior on opacity {
                    NumberAnimation { duration: 200 }
                }
                Behavior on scale {
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }

                HoverHandler {
                    onHoveredChanged: root.hovered = hovered
                }

                onDismissed: {
                    NotifService.dismiss(entry)
                    root.hide()
                }
                onActionInvoked: {
                    NotifService.dismiss(entry)
                    root.hide()
                }

                Binding {
                    target: NotifService
                    property: "popupHeight"
                    value: card.visibleNow ? card.implicitHeight : 0
                }

                Connections {
                    target: root
                    function onCurrentChanged() {
                        if (root.current)
                            card.lastEntry = root.current
                    }
                }
            }
        }
    }
}
