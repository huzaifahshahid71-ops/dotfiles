// On-screen display, modelled on Nisfere's OSD: a small card in the
// bottom-right corner of the focused monitor for volume, mic, media and
// keyboard layout. It replaced swayosd.
//
// It watches the sources itself - PipeWire, every MPRIS player, Hyprland's
// layout events - so the keys only change a value (wpctl, playerctl) and
// never have to ask for an OSD. The price is that ANY change shows it, a
// volume slider dragged in pavucontrol included, which is the point.
//
// Quiet for the first seconds: PipeWire and the players report their
// initial values as changes, which would flash it at every login.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris

Scope {
    id: root

    property bool shown: false
    property bool armed: false
    property string kind: "volume"         // volume | mic | media | keyboard
    property string title: ""
    property string subtitle: ""
    property real value: 0
    property bool muted: false
    property var targetScreen: null
    property string lastLayout: ""

    readonly property bool showBar: kind === "volume" || kind === "mic"
    readonly property string icon: {
        switch (kind) {
        case "volume":
            return muted ? "volume-x" : value > 0.66 ? "volume-2" : value > 0.33 ? "volume-1" : "volume"
        case "mic":
            return muted ? "mic-off" : "mic"
        case "media":
            return muted ? "pause" : "play"
        default:
            return "keyboard"
        }
    }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    PwObjectTracker {
        objects: [root.sink, root.source].filter(o => o)
    }

    function nodeName(node) {
        return node ? (node.description || node.nickname || node.name) : ""
    }

    function focusedScreen() {
        const name = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
        const screens = Quickshell.screens
        for (let i = 0; i < screens.length; i++)
            if (screens[i].name === name)
                return screens[i]
        return screens[0]
    }

    function show(k, t, v, m, sub) {
        if (!armed)
            return
        kind = k
        title = t
        value = Math.max(0, Math.min(1, v))
        muted = m
        subtitle = sub || ""
        if (!shown)
            targetScreen = focusedScreen()
        shown = true
        hideTimer.restart()
    }

    onShownChanged: if (!shown) outro.restart()

    Timer {
        interval: 3000
        running: true
        onTriggered: root.armed = true
    }

    Timer {
        id: hideTimer
        interval: 1800
        onTriggered: root.shown = false
    }

    Timer {
        id: outro                              // keeps the window for the fade-out
        interval: 260
    }

    // ------------------------------------------------------------ sources --
    Connections {
        target: root.sink ? root.sink.audio : null
        function onVolumeChanged() { root.show("volume", "Volume", root.sink.audio.volume, root.sink.audio.muted, root.nodeName(root.sink)) }
        function onMutedChanged() { root.show("volume", "Volume", root.sink.audio.volume, root.sink.audio.muted, root.nodeName(root.sink)) }
    }

    Connections {
        target: root.source ? root.source.audio : null
        function onVolumeChanged() { root.show("mic", "Microphone", root.source.audio.volume, root.source.audio.muted, root.nodeName(root.source)) }
        function onMutedChanged() { root.show("mic", "Microphone", root.source.audio.volume, root.source.audio.muted, root.nodeName(root.source)) }
    }

    // One watcher per player, so the OSD reports the player that changed -
    // not whichever one a "current player" guess happened to pick.
    Instantiator {
        model: Mpris.players

        delegate: Connections {
            required property var modelData
            target: modelData

            function report() {
                if (modelData.trackTitle)
                    root.show("media", modelData.trackTitle, 0, !modelData.isPlaying,
                              modelData.trackArtist || modelData.identity)
            }
            function onIsPlayingChanged() { report() }
            function onTrackTitleChanged() { report() }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "activelayout")
                return
            const layout = event.data.split(",").slice(1).join(",")
            if (layout && root.lastLayout && layout !== root.lastLayout)
                root.show("keyboard", "Keyboard layout", 0, false, layout)
            if (layout)
                root.lastLayout = layout
        }
    }

    // ------------------------------------------------------------- window --
    LazyLoader {
        active: root.shown || outro.running

        PanelWindow {
            screen: root.targetScreen
            anchors {
                bottom: true
                right: true
            }
            // Above a notification popup, when one is showing.
            margins {
                bottom: 24 + (NotifService.popupHeight > 0 ? NotifService.popupHeight + 12 : 0)
                right: 24
            }
            implicitWidth: 320
            implicitHeight: card.implicitHeight + 24     // room to slide in
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            mask: Region {}
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "rice-osd"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Rectangle {
                id: card
                property bool live: false
                readonly property bool visibleNow: root.shown && live
                Component.onCompleted: live = true

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                implicitHeight: row.implicitHeight + 30
                radius: 22
                color: Theme.alpha(Theme.surface_container, 0.96)
                border.width: 1
                border.color: Theme.alpha(Theme.outline_variant, 0.7)

                opacity: visibleNow ? 1 : 0
                scale: visibleNow ? 1 : 0.94
                transform: Translate {
                    y: card.visibleNow ? 0 : 22
                    Behavior on y {
                        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                    }
                }
                Behavior on opacity {
                    NumberAnimation { duration: 180 }
                }
                Behavior on scale {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }

                RowLayout {
                    id: row
                    anchors.fill: parent
                    anchors.margins: 15
                    spacing: 14

                    Rectangle {
                        implicitWidth: 44
                        implicitHeight: 44
                        radius: 22
                        color: Theme.surface_container_highest
                        border.width: 1
                        border.color: Theme.alpha(Theme.outline_variant, 0.8)

                        LucideIcon {
                            anchors.centerIn: parent
                            icon: root.icon
                            size: 20
                            color: root.muted && root.kind !== "media" ? Theme.on_surface : Theme.primary
                            opacity: root.muted && root.kind !== "media" ? 0.5 : 1
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 5

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                Layout.fillWidth: true
                                text: root.title
                                elide: Text.ElideRight
                                color: Theme.on_surface
                                font.family: Theme.font
                                font.pixelSize: 14
                                font.weight: Font.Bold
                            }

                            Text {
                                visible: root.showBar
                                text: root.muted ? "Muted" : Math.round(root.value * 100) + "%"
                                color: Theme.on_surface
                                opacity: 0.65
                                font.family: Theme.font
                                font.pixelSize: 13
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 6
                            visible: root.showBar

                            Rectangle {
                                anchors.fill: parent
                                radius: 3
                                color: Theme.on_surface
                                opacity: 0.12
                            }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                radius: 3
                                width: Math.max(height, parent.width * (root.muted ? 0 : root.value))
                                color: root.muted ? Theme.on_surface : Theme.primary
                                opacity: root.muted ? 0.35 : 1
                                Behavior on width {
                                    NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: root.subtitle !== ""
                            text: root.subtitle
                            elide: Text.ElideRight
                            color: Theme.on_surface_variant
                            font.family: Theme.font
                            font.pixelSize: 12
                        }
                    }
                }
            }
        }
    }
}
