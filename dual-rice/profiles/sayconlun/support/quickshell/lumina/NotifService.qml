pragma Singleton

// The rice's notification daemon (org.freedesktop.Notifications), modelled on
// Nisfere's NotificationService. It replaced swaync.
//
//   history   newest first, capped at 100, saved to ~/.local/share/desktop-profiles/sayconlun/support/state/cache/notifications.json.
//             Images are not saved: an image:// handle dies with the
//             sender's notification, so a restored entry shows its app icon.
//   DND       saved too, so it survives a restart. Critical notifications
//             still pop up.
//   bar       {count, dnd} goes to ~/.local/share/desktop-profiles/sayconlun/support/state/cache/notifications-state.json,
//             and waybar gets SIGRTMIN+8 to re-read it.
//   popups    the `popup` signal, handled by NotificationPopups.qml.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Singleton {
    id: root

    property bool dnd: false
    property var list: []            // {id, app, appIcon, summary, body, image, time, critical, actions, raw}
    property real popupHeight: 0     // the popup on screen, so the OSD can sit above it
    property bool loaded: false

    readonly property int count: list.length
    readonly property int maxHistory: 100
    readonly property string cacheDir: Quickshell.env("HOME") + "/.local/share/desktop-profiles/sayconlun/support/state/cache"

    signal popup(var entry)

    onDndChanged: save()

    NotificationServer {
        keepOnReload: true
        persistenceSupported: true
        actionsSupported: true
        imageSupported: true
        bodyMarkupSupported: false          // senders strip markup; bodies are shown as plain text

        onNotification: n => {
            n.tracked = true
            const entry = root.entryFor(n)
            const i = root.list.findIndex(e => e.id === n.id && e.app === entry.app)
            const next = root.list.slice()
            if (i >= 0) {
                entry.time = next[i].time
                next[i] = entry
            } else {
                next.unshift(entry)
            }
            root.list = next.slice(0, root.maxHistory)
            n.closed.connect(() => root.forget(n))
            root.save()
            if (!n.lastGeneration && (!root.dnd || entry.critical))
                root.popup(entry)
        }
    }

    function entryFor(n) {
        return {
            id: n.id,
            app: n.appName || "System",
            appIcon: n.appIcon || "",
            summary: n.summary || "",
            body: n.body || "",
            image: n.image || "",
            time: Date.now(),
            critical: n.urgency === NotificationUrgency.Critical,
            actions: n.actions ? Array.from(n.actions) : [],
            raw: n
        }
    }

    // Picture if there is one, else the app icon (a path or a theme name).
    function iconSource(e) {
        const src = e.image || e.appIcon || ""
        if (!src)
            return ""
        if (src.startsWith("/"))
            return "file://" + src
        if (src.includes("://"))
            return src
        return Quickshell.iconPath(src, true)
    }

    function dismiss(entry) {
        if (!entry)
            return
        if (entry.raw) {
            try {
                entry.raw.dismiss()
            } catch (e) {
                // already closed by its sender
            }
        }
        list = list.filter(e => !(e.id === entry.id && e.app === entry.app))
        save()
    }

    function clear() {
        for (const e of list) {
            if (e.raw) {
                try {
                    e.raw.dismiss()
                } catch (err) {}
            }
        }
        list = []
        save()
    }

    // The sender closed it (or it was dismissed): drop it from the history.
    function forget(n) {
        const next = list.filter(e => e.raw !== n)
        if (next.length !== list.length) {
            list = next
            save()
        }
    }

    function save() {
        if (!loaded)
            return
        store.setText(JSON.stringify({
            dnd: dnd,
            notifications: list.map(e => ({
                id: e.id, app: e.app, appIcon: e.appIcon, summary: e.summary,
                body: e.body, time: e.time, critical: e.critical
            }))
        }))
        publish()
    }

    function publish() {
        stateFile.setText(JSON.stringify({ count: list.length, dnd: dnd }))
        Quickshell.execDetached(["pkill", "-RTMIN+8", "-x", "waybar"])
    }

    FileView {
        id: store
        path: root.cacheDir + "/notifications.json"
        printErrors: false

        onLoaded: {
            try {
                const saved = JSON.parse(text())
                root.dnd = !!saved.dnd
                // Live notifications that arrived before this finished loading win.
                const restored = (saved.notifications || [])
                    .filter(s => !root.list.some(e => e.id === s.id && e.app === s.app))
                    .map(s => Object.assign(s, { image: "", actions: [], raw: null }))
                root.list = root.list.concat(restored).slice(0, root.maxHistory)
            } catch (e) {
                console.warn("NotifService: unreadable history:", e)
            }
            root.loaded = true
            root.publish()
        }
        onLoadFailed: {
            root.loaded = true
            root.publish()
        }
    }

    FileView {
        id: stateFile
        path: root.cacheDir + "/notifications-state.json"
        preload: false
        blockWrites: true                  // written before waybar is signalled
    }
}
