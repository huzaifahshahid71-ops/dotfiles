// Desktop lyrics, modelled on Nisfere's WallpaperLyrics: the previous line,
// the current one (bigger, in the accent colour, with a small pop when it
// advances) and the next, just under the visualiser on every monitor.
// Shown only while a track with synced lyrics is playing (LyricsService).
//
// BOTTOM layer - on the wallpaper, under windows - and takes no clicks.
// Every line has an outline, like subtitles: no single colour stays readable
// on every wallpaper.
//
//   qs -c lumina ipc call lyrics toggle
//   qs -c lumina ipc call lyrics offset 0.5      lines later by half a second
import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
    id: root

    property bool enabled: true
    property var visualiser: null                 // lyrics hang below its band

    readonly property bool active: enabled && LyricsService.playing && LyricsService.hasLyrics
    readonly property int gap: 36
    readonly property int bandHeight: 200

    function toggle() {
        enabled = !enabled
    }

    function lineAt(i) {
        const l = LyricsService.lines
        return i >= 0 && i < l.length ? l[i].text : ""
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
            margins.top: Math.round(modelData.height / 2
                                    + (root.visualiser ? root.visualiser.bandHeight / 2 : 180)
                                    + root.gap)
            implicitHeight: root.bandHeight
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            mask: Region {}
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "rice-lyrics"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                width: Math.min(parent.width * 0.7, 1500)
                spacing: 10

                opacity: root.active ? 1 : 0
                Behavior on opacity {
                    NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: root.lineAt(LyricsService.currentIndex - 1)
                    color: Theme.on_surface
                    opacity: 0.6
                    style: Text.Outline
                    styleColor: Qt.rgba(0, 0, 0, 0.6)
                    font.family: Theme.font
                    font.pixelSize: 18
                }

                Text {
                    id: current
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    text: root.lineAt(LyricsService.currentIndex)
                    color: Theme.primary
                    style: Text.Outline
                    styleColor: Qt.rgba(0, 0, 0, 0.65)
                    font.family: Theme.font
                    font.pixelSize: 32
                    font.weight: Font.Bold

                    transform: Scale {
                        id: pop
                        origin.x: current.width / 2
                        origin.y: current.height / 2
                    }

                    Connections {
                        target: LyricsService
                        function onCurrentIndexChanged() {
                            popAnim.restart()
                        }
                    }

                    SequentialAnimation {
                        id: popAnim
                        NumberAnimation { target: pop; properties: "xScale,yScale"; to: 0.93; duration: 90; easing.type: Easing.OutQuad }
                        NumberAnimation { target: pop; properties: "xScale,yScale"; to: 1.0; duration: 200; easing.type: Easing.OutBack }
                    }
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: root.lineAt(LyricsService.currentIndex + 1)
                    color: Theme.on_surface
                    opacity: 0.6
                    style: Text.Outline
                    styleColor: Qt.rgba(0, 0, 0, 0.6)
                    font.family: Theme.font
                    font.pixelSize: 18
                }
            }
        }
    }
}
