pragma Singleton

// Focus timer, modelled on Nisfere's FocusService: focus and break sessions
// that count down, switch to the other mode when done (without starting it)
// and say so with a notification. Kept in memory only.
import QtQuick
import Quickshell

Singleton {
    id: root

    property string mode: "focus"            // focus | break
    property int focusMinutes: 25
    property int breakMinutes: 5
    property int remaining: 25 * 60
    property bool running: false

    readonly property int minutes: mode === "focus" ? focusMinutes : breakMinutes
    readonly property int total: minutes * 60
    readonly property real progress: total > 0 ? remaining / total : 0
    readonly property string clock: Math.floor(remaining / 60) + ":" + (remaining % 60 < 10 ? "0" : "") + remaining % 60

    function toggle() {
        running = !running
    }

    function reset() {
        running = false
        remaining = total
    }

    function setMode(m) {
        if (mode === m)
            return
        mode = m
        reset()
    }

    // Focus moves in 5-minute steps (5-120), breaks in 1-minute steps (1-30).
    function adjust(direction) {
        if (running)
            return
        if (mode === "focus")
            focusMinutes = Math.max(5, Math.min(120, focusMinutes + 5 * direction))
        else
            breakMinutes = Math.max(1, Math.min(30, breakMinutes + direction))
        remaining = total
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.running
        onTriggered: {
            if (root.remaining > 1) {
                root.remaining--
                return
            }
            const wasFocus = root.mode === "focus"
            root.running = false
            Quickshell.execDetached(["notify-send", "-a", "Focus",
                wasFocus ? "Focus session complete" : "Break's over",
                wasFocus ? "Time for a break." : "Ready to focus again?"])
            root.mode = wasFocus ? "break" : "focus"
            root.remaining = root.total
        }
    }
}
