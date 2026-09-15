// Lock screen, modelled on Nisfere's Locker: the wallpaper blurred and dimmed,
// a big clock, your name, a password field, what's playing, and suspend /
// restart / power off.
//
// A broken lock screen can lock you out of your own session, so:
//   - It uses ext-session-lock (WlSessionLock). Hyprland keeps the session
//     locked even if Quickshell dies, and hyprland.lua sets
//     misc:allow_session_lock_restore so another locker can take over - from
//     a TTY: `hyprctl --instance 0 dispatch 'hl.dsp.exec_cmd("hyprlock")'`.
//   - hypridle falls back to hyprlock whenever Quickshell is not running.
//   - Passwords go through PAM with hyprlock's own config (/etc/pam.d/hyprlock),
//     so the rules - faillock included - are the ones hyprlock used.
//   - `qs -c lumina ipc call lock preview` shows the same screen as an ordinary
//     window: try the password there first. Nothing is locked.
//   - There is deliberately no IPC to unlock.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pam

Scope {
    id: root

    property bool locked: false
    property bool previewing: false
    property bool busy: false
    property string error: ""
    property string pending: ""
    property var previewScreen: null

    signal failed

    function lock() {
        if (locked)
            return
        previewing = false
        stopPam()
        error = ""
        locked = true
    }

    function preview() {
        if (locked)
            return
        error = ""
        const name = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
        previewScreen = Quickshell.screens.find(s => s.name === name) || Quickshell.screens[0]
        previewing = true
    }

    function endPreview() {
        previewing = false
        stopPam()
    }

    function submit(password) {
        if (!password || busy)
            return
        busy = true
        error = ""
        if (pam.responseRequired) {
            pam.respond(password)
        } else {
            pending = password
            if (!pam.active)
                pam.start()
        }
    }

    function stopPam() {
        pending = ""
        busy = false
        if (pam.active)
            pam.abort()
    }

    function succeed() {
        busy = false
        error = ""
        if (previewing) {
            previewing = false
            Quickshell.execDetached(["notify-send", "-a", "Lock screen", "Password accepted",
                "The real lock screen unlocks the same way."])
        }
        locked = false
    }

    PamContext {
        id: pam
        config: "hyprlock"

        onResponseRequiredChanged: {
            if (responseRequired && root.pending !== "") {
                const p = root.pending
                root.pending = ""
                respond(p)
            }
        }

        onCompleted: result => {
            root.busy = false
            root.pending = ""
            if (result === PamResult.Success) {
                root.succeed()
                return
            }
            root.error = result === PamResult.MaxTries ? "Too many attempts - wait a moment and try again"
                       : result === PamResult.Failed ? "Wrong password"
                       : "Could not check the password"
            root.failed()
        }

        onError: err => {
            root.busy = false
            root.pending = ""
            root.error = "Could not check the password"
            root.failed()
        }

        onPamMessage: {
            if (messageIsError && message)
                root.error = message
        }
    }

    WlSessionLock {
        locked: root.locked

        WlSessionLockSurface {
            color: "black"

            LockSurface {
                anchors.fill: parent
                lock: root
            }
        }
    }

    LazyLoader {
        active: root.previewing

        PanelWindow {
            screen: root.previewScreen
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: "black"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "rice-lock-preview"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            LockSurface {
                anchors.fill: parent
                lock: root
                preview: true
            }
        }
    }
}
