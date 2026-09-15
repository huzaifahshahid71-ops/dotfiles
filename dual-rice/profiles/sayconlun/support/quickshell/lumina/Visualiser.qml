// Desktop visualiser: cava across the middle of every monitor, on the BOTTOM
// layer - above the wallpaper, under every window - on every workspace.
//
// cava only does the maths here. It runs once, in raw mode, printing one line
// of bar levels per frame; the bars are drawn by Qt, which is what allows
// rounded, slightly see-through bars at exact pixel spacing. (The kitty panel
// this replaced could do none of that: terminal cells have no alpha, and cava
// spaces bars in whole columns.)
//
// Bars grow up and down from a centre line; in silence all that is left is a
// dashed line. Colours follow the palette, so wallpaper previews recolour it.
// cava's pulse input follows the default output, headphones included.
//
//   qs -c lumina ipc call visualiser toggle      (Super+Shift+V)
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    property bool enabled: true

    readonly property int bandHeight: 360      // logical px, centred on each monitor
    readonly property int barWidth: 9
    readonly property int barGap: 4
    readonly property real barOpacity: 0.8
    readonly property int minBar: 2            // the centre line in silence

    // One cava feeds every monitor, so the bar count comes from the widest.
    readonly property int count: {
        let widest = 0
        for (const s of Quickshell.screens)
            widest = Math.max(widest, s.width)
        const n = Math.floor((widest + barGap) / (barWidth + barGap))
        return Math.max(2, n - n % 2)          // even: stereo splits it in half
    }

    property var levels: []

    readonly property string configPath: Quickshell.env("HOME") + "/.local/share/desktop-profiles/sayconlun/support/state/cache/cava-visualiser.conf"

    function toggle() {
        enabled = !enabled
    }

    // Written before each start, because the bar count depends on the monitors.
    function writeConfig() {
        cavaConf.setText(`# Written by Visualiser.qml - regenerated on every start.
[general]
framerate = 60
autosens = 1
bars = ${count}

[input]
method = pulse
source = auto

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 1000
bar_delimiter = 59
frame_delimiter = 10
channels = stereo
mono_option = average

[smoothing]
noise_reduction = 60
`)
    }

    function start() {
        if (!enabled || cava.running)
            return
        writeConfig()
        cava.running = true
    }

    onEnabledChanged: {
        if (enabled) {
            start()
        } else {
            restart.stop()
            cava.running = false
            levels = []
        }
    }
    onCountChanged: if (cava.running) cava.running = false   // restarts with the new count
    Component.onCompleted: start()

    FileView {
        id: cavaConf
        path: root.configPath
        preload: false
        atomicWrites: false
    }

    Process {
        id: cava
        command: ["cava", "-p", root.configPath]
        stdout: SplitParser {
            onRead: data => {
                const parts = data.split(";")
                const out = new Array(root.count)
                for (let i = 0; i < root.count; i++)
                    out[i] = (parseInt(parts[i]) || 0) / 1000
                root.levels = out
            }
        }
        onExited: {
            root.levels = []
            if (root.enabled)
                restart.start()                // cava died or the count changed
        }
    }

    Timer {
        id: restart
        interval: 1500
        onTriggered: root.start()
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel
            required property var modelData

            screen: modelData
            visible: root.enabled
            // Left + right only: layer-shell centres the band vertically.
            anchors {
                left: true
                right: true
            }
            implicitHeight: root.bandHeight
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            mask: Region {}                    // never takes a click from the desktop
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "rice-visualiser"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Item {
                id: bars
                readonly property real total: root.count * (root.barWidth + root.barGap) - root.barGap

                anchors.fill: parent
                opacity: root.barOpacity

                Repeater {
                    model: root.count

                    Rectangle {
                        required property int index
                        readonly property real level: root.levels[index] || 0

                        x: (bars.width - bars.total) / 2 + index * (root.barWidth + root.barGap)
                        width: root.barWidth
                        height: Math.max(root.minBar, level * bars.height)
                        y: (bars.height - height) / 2
                        radius: root.barWidth / 2
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Theme.primary_fixed }
                            GradientStop { position: 0.5; color: Theme.primary_container }
                            GradientStop { position: 1.0; color: Theme.primary_fixed }
                        }
                    }
                }
            }
        }
    }
}
