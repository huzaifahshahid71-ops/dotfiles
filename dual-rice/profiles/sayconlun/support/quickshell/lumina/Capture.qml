// Screenshots and screen recording, modelled on Nisfere's ScreenshotService,
// ScreenRecordService and AreaPicker - with gpu-screen-recorder, the GPU
// encoder the replay buffer already uses, in place of wf-recorder.
//
//   screenshots  grim -> ~/Pictures/Screenshots, also copied to the clipboard.
//                The notification offers Open, Edit (satty), Show in folder.
//   recordings   gpu-screen-recorder -> ~/Videos/Recordings: mp4, 60 fps,
//                desktop audio and optionally the mic. Stopped with SIGINT,
//                which is what makes it finish the file.
//   area         a drag-to-select overlay on every monitor (Esc cancels)
//   bar          ~/.local/share/desktop-profiles/sayconlun/support/state/cache/recording holds the start time while recording;
//                waybar's recording pill counts from it
//
// Every capture waits a moment first, so the menu or picker that started it
// has faded out of the frame.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    property bool recording: false
    property real startedAt: 0
    property int elapsed: 0
    property bool desktopAudio: true
    property bool micAudio: false
    property bool picking: false
    property var pickCallback: null

    readonly property string home: Quickshell.env("HOME")
    readonly property string shotDir: home + "/Pictures/Screenshots"
    readonly property string videoDir: home + "/Videos/Recordings"
    readonly property string elapsedText: Math.floor(elapsed / 60) + ":" + (elapsed % 60 < 10 ? "0" : "") + elapsed % 60

    function stamp() {
        return Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss")
    }

    function focusedMonitor() {
        return Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
    }

    Timer {
        id: delay
        property var job: null
        interval: 400
        onTriggered: {
            const j = job
            job = null
            if (j)
                j()
        }
    }

    function later(job) {
        delay.job = job
        delay.restart()
    }

    // --------------------------------------------------------- screenshots --
    // screen (the focused monitor) | window (the active one) | area
    function screenshot(mode) {
        if (mode === "area")
            pick(g => shoot(["-g", g.grim]))
        else if (mode === "window")
            later(() => windowGeometry.running = true)
        else
            later(() => shoot(["-o", focusedMonitor()]))
    }

    Process {
        id: windowGeometry
        command: ["hyprctl", "activewindow", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const w = JSON.parse(text)
                    root.shoot(["-g", `${w.at[0]},${w.at[1]} ${w.size[0]}x${w.size[1]}`])
                } catch (e) {
                    root.shoot(["-o", root.focusedMonitor()])     // no window: the monitor
                }
            }
        }
    }

    function shoot(grimArgs) {
        if (shooter.running)
            return
        shooter.file = shotDir + "/Screenshot_" + stamp() + ".png"
        shooter.command = ["bash", "-c",
            'dir="$1"; file="$2"; shift 2; mkdir -p "$dir" && grim "$@" "$file" && wl-copy --type image/png < "$file"',
            "_", shotDir, shooter.file].concat(grimArgs)
        shooter.running = true
    }

    Process {
        id: shooter
        property string file: ""
        onExited: code => {
            if (code === 0)
                root.notifyFile(file, "Screenshot saved", "copied to the clipboard", true)
            else
                Quickshell.execDetached(["notify-send", "-a", "Screenshot", "-u", "critical", "Screenshot failed", "grim exited with " + code])
        }
    }

    // A notification with buttons. notify-send -A waits for the click, so it
    // runs detached and does the action itself.
    function notifyFile(file, title, note, isImage) {
        Quickshell.execDetached(["bash", "-c",
            'file="$1"; title="$2"; note="$3"; image="$4"\n'
            + 'name="$(basename "$file")"\n'
            + 'if [ "$image" = yes ]; then\n'
            + '  act="$(notify-send -a Capture -i "$file" -A open=Open -A edit=Edit -A folder="Show in folder" "$title" "$name · $note")"\n'
            + 'else\n'
            + '  act="$(notify-send -a Capture -i video-x-generic -A open=Open -A folder="Show in folder" "$title" "$name · $note")"\n'
            + 'fi\n'
            + 'case "$act" in\n'
            + '  open) xdg-open "$file" ;;\n'
            + '  edit) satty --filename "$file" ;;\n'
            + '  folder) thunar "$file" ;;\n'
            + 'esac',
            "_", file, title, note, isImage ? "yes" : "no"])
    }

    // ----------------------------------------------------------- recording --
    // screen (the focused monitor) | area
    function record(mode) {
        if (recording)
            return
        if (mode === "area")
            pick(g => startRecording(["-w", "region", "-region", g.gsr]))
        else
            later(() => startRecording(["-w", focusedMonitor()]))
    }

    function toggleRecording() {
        recording ? stop() : record("screen")
    }

    function stop() {
        if (recording && recorder.running)
            recorder.signal(2)
    }

    function startRecording(target) {
        if (recorder.running)
            return
        const audio = [desktopAudio ? "default_output" : "", micAudio ? "default_input" : ""].filter(a => a).join("|")
        recorder.file = videoDir + "/Recording_" + stamp() + ".mp4"
        recorder.command = ["bash", "-c", 'mkdir -p "$1"; shift; exec "$@"', "_", videoDir,
            "gpu-screen-recorder"].concat(target,
            ["-f", "60", "-c", "mp4", "-q", "very_high", "-cursor", "yes"],
            audio ? ["-a", audio] : [],
            ["-o", recorder.file])
        recorder.running = true
        recording = true
        startedAt = Date.now()
        elapsed = 0
        stateFile.setText(Math.floor(startedAt / 1000) + "\n")
    }

    Process {
        id: recorder
        property string file: ""
        stderr: StdioCollector {
            id: recorderErrors
        }
        onExited: code => {
            root.recording = false
            stateFile.setText("\n")
            const seconds = Math.round((Date.now() - root.startedAt) / 1000)
            if (seconds >= 1 && (code === 0 || code === 130 || code === 2)) {
                root.notifyFile(file, "Recording saved",
                    Math.floor(seconds / 60) + "m " + (seconds % 60) + "s", false)
            } else {
                const lines = recorderErrors.text.trim().split("\n")
                Quickshell.execDetached(["notify-send", "-a", "Capture", "-u", "critical", "Recording failed",
                    lines[lines.length - 1] || "gpu-screen-recorder exited with " + code])
            }
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.recording
        onTriggered: root.elapsed = Math.round((Date.now() - root.startedAt) / 1000)
    }

    FileView {
        id: stateFile
        path: root.home + "/.local/share/desktop-profiles/sayconlun/support/state/cache/recording"
        preload: false
        blockWrites: true
    }

    // --------------------------------------------------------- area picker --
    function pick(callback) {
        if (picking)
            return
        pickCallback = callback
        later(() => root.picking = true)
    }

    function finishPick(geometry) {
        picking = false
        const callback = pickCallback
        pickCallback = null
        if (callback && geometry)
            later(() => callback(geometry))
    }

    LazyLoader {
        active: root.picking

        Variants {
            model: Quickshell.screens

            PanelWindow {
                id: picker
                required property var modelData

                property point a
                property point b
                property bool dragging: false
                readonly property rect sel: dragging
                    ? Qt.rect(Math.min(a.x, b.x), Math.min(a.y, b.y), Math.abs(a.x - b.x), Math.abs(a.y - b.y))
                    : Qt.rect(0, 0, 0, 0)

                screen: modelData
                anchors {
                    top: true
                    bottom: true
                    left: true
                    right: true
                }
                exclusionMode: ExclusionMode.Ignore
                color: "transparent"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "rice-areapicker"
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

                // Dim everything outside the selection.
                Rectangle {
                    x: 0; y: 0
                    width: parent.width
                    height: picker.sel.y
                    color: Qt.rgba(0, 0, 0, 0.45)
                }
                Rectangle {
                    x: 0
                    y: picker.sel.y + picker.sel.height
                    width: parent.width
                    height: parent.height - y
                    color: Qt.rgba(0, 0, 0, 0.45)
                }
                Rectangle {
                    x: 0
                    y: picker.sel.y
                    width: picker.sel.x
                    height: picker.sel.height
                    color: Qt.rgba(0, 0, 0, 0.45)
                }
                Rectangle {
                    x: picker.sel.x + picker.sel.width
                    y: picker.sel.y
                    width: parent.width - x
                    height: picker.sel.height
                    color: Qt.rgba(0, 0, 0, 0.45)
                }

                Rectangle {
                    visible: picker.dragging
                    x: picker.sel.x
                    y: picker.sel.y
                    width: picker.sel.width
                    height: picker.sel.height
                    color: "transparent"
                    border.width: 2
                    border.color: Theme.primary
                }

                Rectangle {
                    visible: picker.dragging && picker.sel.width > 0
                    x: picker.sel.x
                    y: Math.max(0, picker.sel.y - height - 6)
                    implicitWidth: sizeText.implicitWidth + 16
                    implicitHeight: 24
                    radius: 8
                    color: Theme.surface_container

                    Text {
                        id: sizeText
                        anchors.centerIn: parent
                        text: Math.round(picker.sel.width) + " × " + Math.round(picker.sel.height)
                        color: Theme.on_surface
                        font.family: Theme.mono
                        font.pixelSize: 12
                    }
                }

                Rectangle {
                    visible: !picker.dragging
                    anchors.centerIn: parent
                    implicitWidth: hint.implicitWidth + 32
                    implicitHeight: 44
                    radius: 22
                    color: Theme.alpha(Theme.surface_container, 0.95)

                    Text {
                        id: hint
                        anchors.centerIn: parent
                        text: "Drag to select an area  ·  Esc to cancel"
                        color: Theme.on_surface
                        font.family: Theme.font
                        font.pixelSize: 14
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.CrossCursor
                    onPressed: mouse => {
                        picker.a = Qt.point(mouse.x, mouse.y)
                        picker.b = picker.a
                        picker.dragging = true
                    }
                    onPositionChanged: mouse => {
                        if (picker.dragging)
                            picker.b = Qt.point(mouse.x, mouse.y)
                    }
                    onReleased: {
                        const r = picker.sel
                        picker.dragging = false
                        if (r.width < 4 || r.height < 4) {
                            root.finishPick(null)
                            return
                        }
                        // Global logical coordinates, as grim -g expects.
                        const x = Math.round(picker.modelData.x + r.x), y = Math.round(picker.modelData.y + r.y)
                        const w = Math.round(r.width), h = Math.round(r.height)
                        root.finishPick({ grim: `${x},${y} ${w}x${h}`, gsr: `${w}x${h}+${x}+${y}` })
                    }
                }

                Item {
                    anchors.fill: parent
                    focus: true
                    Component.onCompleted: forceActiveFocus()
                    Keys.onEscapePressed: root.finishPick(null)
                }
            }
        }
    }
}
