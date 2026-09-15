pragma Singleton

// The dashboard's task list, modelled on Nisfere's TasksService:
// [{id, text, done}] in ~/.local/share/desktop-profiles/sayconlun/support/state/data/tasks.json - not ~/.cache,
// because these are yours and should survive a cache clean.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var tasks: []
    property bool loaded: false

    readonly property string dir: Quickshell.env("HOME") + "/.local/share/desktop-profiles/sayconlun/support/state/data"
    readonly property int activeCount: tasks.filter(t => !t.done).length
    readonly property int doneCount: tasks.length - activeCount

    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", dir])

    function add(text) {
        const t = (text || "").trim()
        if (!t)
            return
        tasks = tasks.concat([{ id: Date.now().toString(), text: t, done: false }])
        save()
    }

    function toggle(id) {
        tasks = tasks.map(t => t.id === id ? { id: t.id, text: t.text, done: !t.done } : t)
        save()
    }

    function remove(id) {
        tasks = tasks.filter(t => t.id !== id)
        save()
    }

    function clearDone() {
        tasks = tasks.filter(t => !t.done)
        save()
    }

    function save() {
        if (loaded)
            store.setText(JSON.stringify({ tasks: tasks }, null, 2) + "\n")
    }

    FileView {
        id: store
        path: root.dir + "/tasks.json"
        printErrors: false
        onLoaded: {
            try {
                root.tasks = JSON.parse(text()).tasks || []
            } catch (e) {
                console.warn("TasksService: unreadable tasks.json:", e)
            }
            root.loaded = true
        }
        onLoadFailed: root.loaded = true
    }
}
