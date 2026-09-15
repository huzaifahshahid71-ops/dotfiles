// Keybind cheatsheet + editor (Super+/). Every bind in binds.lua, grouped by
// its section and searchable; Enter (or a second click) on one captures a new
// combo and hands it to rice-binds-ctl.py, which applies it live and saves it
// to conf.d/30-binds.lua. A clash is shown first and can be swapped.
//
// While capturing, Hyprland sits in the `rice-capture` submap, which binds
// nothing but Escape - otherwise Super+Q would close a window instead of
// reaching this menu. Escape leaves that submap from Hyprland's side, so it
// gets you out even if this shell has died.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    property bool open: false
    property var binds: []
    property string query: ""
    property int sel: 0
    property string mode: "browse"       // browse | capture | saving | conflict
    property var target: null            // the bind being changed
    property var pending: null           // {mods, key} captured, maybe awaiting a swap
    property var pendingKeys: []
    property var held: []
    property string message: ""
    property var targetScreen: null

    readonly property string ctl: Quickshell.env("HOME") + "/.local/share/desktop-profiles/sayconlun/support/bin/rice-binds-ctl.py"
    readonly property var shown: filtered(binds, query)
    readonly property var current: shown.length ? shown[Math.min(sel, shown.length - 1)] : null

    function show() {
        if (open)
            return
        targetScreen = focusedScreen()
        query = ""
        sel = 0
        mode = "browse"
        message = ""
        open = true
        lister.running = true
    }

    function close() {
        if (mode === "capture")
            Hyprland.dispatch('hl.dsp.submap("reset")')
        mode = "browse"
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

    function filtered(list, q) {
        const words = q.toLowerCase().split(/\s+/).filter(w => w)
        if (!words.length)
            return list
        return list.filter(b => {
            const hay = `${b.label} ${b.category} ${b.keys.join(" ")} ${b.action}`.toLowerCase()
            return words.every(w => hay.includes(w))
        })
    }

    // Sections dealt into n columns, each to the currently shortest one.
    function layout(list, n) {
        const groups = []
        list.forEach((b, i) => {
            if (!groups.length || groups[groups.length - 1].name !== b.category)
                groups.push({ name: b.category, items: [] })
            groups[groups.length - 1].items.push({ bind: b, flat: i })
        })
        const cols = [], heights = []
        for (let i = 0; i < n; i++) {
            cols.push([])
            heights.push(0)
        }
        groups.forEach(g => {
            const k = heights.indexOf(Math.min(...heights))
            cols[k].push(g)
            heights[k] += g.items.length + 2
        })
        return cols
    }

    // ------------------------------------------------------------ capture --
    // Digits and punctuation by physical key (xkb keycode = evdev + 8): with
    // Shift held Qt reports "!" for the 1 key, but Hyprland binds SHIFT, 1.
    readonly property var scanNames: ({
        10: "1", 11: "2", 12: "3", 13: "4", 14: "5", 15: "6", 16: "7", 17: "8", 18: "9", 19: "0",
        20: "minus", 21: "equal", 34: "bracketleft", 35: "bracketright", 47: "semicolon",
        48: "apostrophe", 49: "grave", 51: "backslash", 59: "comma", 60: "period", 61: "slash"
    })

    readonly property var namedKeys: ({
        [Qt.Key_Return]: "RETURN", [Qt.Key_Enter]: "KP_Enter", [Qt.Key_Space]: "SPACE",
        [Qt.Key_Tab]: "TAB", [Qt.Key_Backtab]: "TAB", [Qt.Key_Backspace]: "BackSpace",
        [Qt.Key_Delete]: "Delete", [Qt.Key_Insert]: "Insert", [Qt.Key_Home]: "Home",
        [Qt.Key_End]: "End", [Qt.Key_PageUp]: "Prior", [Qt.Key_PageDown]: "Next",
        [Qt.Key_Left]: "left", [Qt.Key_Right]: "right", [Qt.Key_Up]: "up", [Qt.Key_Down]: "down",
        [Qt.Key_Print]: "Print", [Qt.Key_Pause]: "Pause", [Qt.Key_ScrollLock]: "Scroll_Lock",
        [Qt.Key_VolumeUp]: "XF86AudioRaiseVolume", [Qt.Key_VolumeDown]: "XF86AudioLowerVolume",
        [Qt.Key_VolumeMute]: "XF86AudioMute", [Qt.Key_MicMute]: "XF86AudioMicMute",
        [Qt.Key_MediaPlay]: "XF86AudioPlay", [Qt.Key_MediaTogglePlayPause]: "XF86AudioPlay",
        [Qt.Key_MediaNext]: "XF86AudioNext", [Qt.Key_MediaPrevious]: "XF86AudioPrev",
        [Qt.Key_MonBrightnessUp]: "XF86MonBrightnessUp",
        [Qt.Key_MonBrightnessDown]: "XF86MonBrightnessDown"
    })

    readonly property var modifierKeys: [Qt.Key_Shift, Qt.Key_Control, Qt.Key_Alt, Qt.Key_AltGr,
        Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R, Qt.Key_Hyper_L, Qt.Key_Hyper_R]

    function keyName(e) {
        if (scanNames[e.nativeScanCode] !== undefined)
            return scanNames[e.nativeScanCode]
        const k = e.key
        if (k >= Qt.Key_A && k <= Qt.Key_Z)
            return String.fromCharCode(k)
        if (k >= Qt.Key_F1 && k <= Qt.Key_F35)
            return "F" + (k - Qt.Key_F1 + 1)
        if (namedKeys[k] !== undefined)
            return namedKeys[k]
        return e.nativeScanCode ? "code:" + e.nativeScanCode : ""
    }

    function modsOf(e) {
        const m = e.modifiers, k = e.key, out = []
        if ((m & Qt.MetaModifier) || k === Qt.Key_Meta || k === Qt.Key_Super_L || k === Qt.Key_Super_R)
            out.push("SUPER")
        if ((m & Qt.ControlModifier) || k === Qt.Key_Control)
            out.push("CTRL")
        if ((m & Qt.AltModifier) || k === Qt.Key_Alt)
            out.push("ALT")
        if ((m & Qt.ShiftModifier) || k === Qt.Key_Shift)
            out.push("SHIFT")
        return out
    }

    function pretty(mods) {
        const names = { SUPER: "Super", CTRL: "Ctrl", ALT: "Alt", SHIFT: "Shift" }
        return mods.map(m => names[m] || m)
    }

    function beginCapture(b) {
        if (!b)
            return
        if (!b.editable) {
            message = "Mouse and scroll binds can only be changed in binds.lua"
            return
        }
        target = b
        held = []
        pending = null
        message = ""
        mode = "capture"
        Hyprland.dispatch('hl.dsp.submap("rice-capture")')
    }

    function captureKey(e) {
        if (modifierKeys.includes(e.key)) {
            held = pretty(modsOf(e))
            return
        }
        const key = keyName(e)
        if (!key)
            return
        const mods = modsOf(e)
        pending = { mods: mods.join(" "), key: key }
        pendingKeys = pretty(mods).concat([key.length === 1 ? key : key.replace(/^XF86/, "")])
        mode = "saving"
        Hyprland.dispatch('hl.dsp.submap("reset")')
        runCtl(["set", target.id, pending.mods, pending.key])
    }

    function reset(b) {
        if (!b)
            return
        if (!b.overridden) {
            message = `${b.label} is already as binds.lua has it`
            return
        }
        target = b
        mode = "saving"
        runCtl(["reset", b.id])
    }

    function runCtl(args) {
        if (setter.running)
            return
        setter.command = [ctl].concat(args)
        setter.running = true
    }

    function handle(text) {
        let r
        try {
            r = JSON.parse(text)
        } catch (e) {
            r = { ok: false, error: text.trim() || "rice-binds-ctl.py failed" }
        }
        if (r.ok) {
            mode = "browse"
            message = r.message + (r.warnings && r.warnings.length ? `  (hyprctl: ${r.warnings[0]})` : "")
            pending = null
            lister.running = true
        } else if (r.conflict) {
            pendingKeys = r.conflict.keys
            message = `Already used by “${r.conflict.label}”`
            mode = "conflict"
        } else {
            mode = "browse"
            message = r.error
        }
    }

    function onKey(e, input) {
        if (mode === "capture") {
            captureKey(e)
            e.accepted = true
            return
        }
        if (mode === "saving") {
            e.accepted = true
            return
        }
        if (mode === "conflict") {
            if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                mode = "saving"
                runCtl(["set", target.id, pending.mods, pending.key, "--swap"])
            } else if (e.key === Qt.Key_Escape) {
                mode = "browse"
                message = ""
            }
            e.accepted = true
            return
        }
        switch (e.key) {
        case Qt.Key_Down:
            sel = Math.min(sel + 1, shown.length - 1); break
        case Qt.Key_Up:
            sel = Math.max(sel - 1, 0); break
        case Qt.Key_PageDown:
            sel = Math.min(sel + 10, shown.length - 1); break
        case Qt.Key_PageUp:
            sel = Math.max(sel - 10, 0); break
        case Qt.Key_Return: case Qt.Key_Enter:
            beginCapture(current); break
        case Qt.Key_Escape:
            if (input.text)
                input.text = ""
            else
                close()
            break
        case Qt.Key_R:
            if (!(e.modifiers & Qt.ControlModifier))
                return
            reset(current)
            break
        default:
            return
        }
        e.accepted = true
    }

    // Escape inside rice-capture resets the submap from Hyprland's side.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "submap" && event.data === "" && root.mode === "capture") {
                root.mode = "browse"
                root.message = "Cancelled"
            }
        }
    }

    Process {
        id: lister
        command: [root.ctl, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text)
                    if (r.ok)
                        root.binds = r.binds
                    else
                        root.message = r.error
                } catch (e) {
                    root.message = "Could not read the binds"
                }
            }
        }
    }

    Process {
        id: setter
        stdout: StdioCollector {
            onStreamFinished: root.handle(text)
        }
    }

    component Keycap: Rectangle {
        property string label
        property bool big: false

        implicitWidth: Math.max(big ? 44 : 26, capText.implicitWidth + (big ? 26 : 14))
        implicitHeight: big ? 48 : 24
        radius: big ? 12 : 7
        color: Theme.surface_container_highest
        border.width: 1
        border.color: Theme.alpha(Theme.outline_variant, 0.9)

        Text {
            id: capText
            anchors.centerIn: parent
            text: parent.label
            color: Theme.on_surface
            font.family: Theme.mono
            font.pixelSize: parent.big ? 20 : 12
        }
    }

    LazyLoader {
        active: root.open

        PanelWindow {
            screen: root.targetScreen
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "rice-binds"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.5)
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.close()
                }
            }

            Rectangle {
                id: card
                readonly property int columnCount: width > 1500 ? 4 : width > 1000 ? 3 : 2

                anchors.centerIn: parent
                width: Math.min(parent.width - 100, 1760)
                height: Math.min(parent.height - 100, 1000)
                radius: 26
                color: Theme.alpha(Theme.surface_container, 0.96)
                border.width: 1
                border.color: Theme.alpha(Theme.outline_variant, 0.7)

                MouseArea {
                    anchors.fill: parent        // keep clicks on the card from closing it
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 28
                    spacing: 20

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 16

                        Text {
                            text: "󰌌"
                            color: Theme.primary
                            font.family: Theme.mono
                            font.pixelSize: 30
                        }

                        Text {
                            text: "Keybinds"
                            color: Theme.on_surface
                            font.family: Theme.font
                            font.pixelSize: 26
                            font.weight: Font.Bold
                        }

                        Rectangle {
                            Layout.preferredWidth: 420
                            Layout.preferredHeight: 42
                            Layout.leftMargin: 10
                            radius: 21
                            color: Theme.surface_container_high
                            border.width: 1
                            border.color: search.activeFocus ? Theme.primary : Theme.outline_variant

                            Text {
                                anchors.fill: parent
                                anchors.leftMargin: 18
                                verticalAlignment: Text.AlignVCenter
                                visible: !search.text
                                text: "Search binds…"
                                color: Theme.on_surface_variant
                                font.family: Theme.font
                                font.pixelSize: 16
                            }

                            TextInput {
                                id: search
                                anchors.fill: parent
                                anchors.leftMargin: 18
                                anchors.rightMargin: 18
                                verticalAlignment: TextInput.AlignVCenter
                                clip: true
                                focus: true
                                color: Theme.on_surface
                                selectionColor: Theme.primary_container
                                font.family: Theme.font
                                font.pixelSize: 16
                                onTextChanged: {
                                    root.query = text
                                    root.sel = 0
                                }
                                Component.onCompleted: forceActiveFocus()
                                Keys.onPressed: event => root.onKey(event, search)
                                Keys.onReleased: event => {
                                    if (root.mode === "capture" && root.modifierKeys.includes(event.key))
                                        root.held = root.pretty(root.modsOf(event).filter(m => {
                                            const k = event.key
                                            return !((m === "SUPER" && (k === Qt.Key_Meta || k === Qt.Key_Super_L || k === Qt.Key_Super_R))
                                                  || (m === "CTRL" && k === Qt.Key_Control)
                                                  || (m === "ALT" && k === Qt.Key_Alt)
                                                  || (m === "SHIFT" && k === Qt.Key_Shift))
                                        }))
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: root.mode === "browse" ? root.message : ""
                            color: Theme.tertiary
                            font.family: Theme.font
                            font.pixelSize: 15
                        }

                        Text {
                            text: "↑↓  select     Enter  rebind     Ctrl+R  reset     Esc  close"
                            color: Theme.on_surface_variant
                            font.family: Theme.font
                            font.pixelSize: 14
                        }
                    }

                    Flickable {
                        id: flick
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentHeight: columns.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        function ensureVisible(item) {
                            const p = item.mapToItem(columns, 0, 0)
                            if (p.y < contentY)
                                contentY = Math.max(0, p.y - 40)
                            else if (p.y + item.height > contentY + height)
                                contentY = Math.min(contentHeight - height, p.y + item.height - height + 16)
                        }

                        RowLayout {
                            id: columns
                            width: flick.width
                            spacing: 30

                            Repeater {
                                model: root.layout(root.shown, card.columnCount)

                                ColumnLayout {
                                    id: column
                                    required property var modelData

                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 100      // equal shares
                                    Layout.alignment: Qt.AlignTop
                                    spacing: 22

                                    Repeater {
                                        model: column.modelData

                                        ColumnLayout {
                                            id: group
                                            required property var modelData

                                            Layout.fillWidth: true
                                            spacing: 3

                                            Text {
                                                Layout.bottomMargin: 5
                                                Layout.leftMargin: 12
                                                text: group.modelData.name
                                                color: Theme.primary
                                                font.family: Theme.font
                                                font.pixelSize: 13
                                                font.weight: Font.Bold
                                                font.capitalization: Font.AllUppercase
                                                font.letterSpacing: 1.2
                                            }

                                            Repeater {
                                                model: group.modelData.items

                                                Rectangle {
                                                    id: row
                                                    required property var modelData
                                                    readonly property var bind: modelData.bind
                                                    readonly property bool selected: modelData.flat === root.sel

                                                    Layout.fillWidth: true
                                                    implicitHeight: 34
                                                    radius: 10
                                                    color: selected ? Theme.alpha(Theme.primary, 0.16)
                                                         : hover.hovered ? Theme.alpha(Theme.on_surface, 0.05)
                                                         : "transparent"
                                                    border.width: selected ? 1 : 0
                                                    border.color: Theme.alpha(Theme.primary, 0.6)
                                                    onSelectedChanged: if (selected) flick.ensureVisible(row)

                                                    HoverHandler { id: hover }

                                                    RowLayout {
                                                        anchors.fill: parent
                                                        anchors.leftMargin: 12
                                                        anchors.rightMargin: 6
                                                        spacing: 5

                                                        Rectangle {
                                                            visible: row.bind.overridden
                                                            implicitWidth: 6
                                                            implicitHeight: 6
                                                            radius: 3
                                                            color: Theme.tertiary
                                                        }

                                                        Text {
                                                            Layout.fillWidth: true
                                                            elide: Text.ElideRight
                                                            text: row.bind.label
                                                            color: Theme.on_surface
                                                            opacity: row.bind.editable ? 1 : 0.65
                                                            font.family: Theme.font
                                                            font.pixelSize: 14
                                                        }

                                                        Repeater {
                                                            model: row.bind.keys
                                                            Keycap {
                                                                required property string modelData
                                                                label: modelData
                                                            }
                                                        }
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                                        onClicked: mouse => {
                                                            if (root.mode !== "browse")
                                                                return
                                                            if (mouse.button === Qt.RightButton) {
                                                                root.sel = row.modelData.flat
                                                                root.reset(row.bind)
                                                            } else if (row.selected) {
                                                                root.beginCapture(row.bind)
                                                            } else {
                                                                root.sel = row.modelData.flat
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
                    }
                }

                // Capture / conflict panel, over the whole card.
                Rectangle {
                    anchors.fill: parent
                    radius: card.radius
                    visible: root.mode !== "browse"
                    color: Theme.alpha(Theme.surface_container_lowest, 0.93)

                    MouseArea {
                        anchors.fill: parent
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 20

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.mode === "conflict" ? "That shortcut is taken"
                                : root.mode === "saving" ? "Saving…"
                                : "Press the new shortcut for"
                            color: root.mode === "conflict" ? Theme.error : Theme.on_surface_variant
                            font.family: Theme.font
                            font.pixelSize: 18
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.target ? root.target.label : ""
                            color: Theme.on_surface
                            font.family: Theme.font
                            font.pixelSize: 34
                            font.weight: Font.Bold
                        }

                        Row {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 10
                            spacing: 10

                            Repeater {
                                model: root.mode === "capture"
                                    ? (root.held.length ? root.held : ["…"])
                                    : root.pendingKeys
                                Keycap {
                                    required property string modelData
                                    label: modelData
                                    big: true
                                }
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 10
                            text: root.mode === "conflict"
                                ? `${root.message}.   Enter  swaps the two     Esc  keeps things as they are`
                                : root.mode === "capture"
                                ? `Now: ${root.target ? root.target.keys.join(" + ") : ""}     Esc  cancels`
                                : ""
                            color: Theme.on_surface_variant
                            font.family: Theme.font
                            font.pixelSize: 15
                        }
                    }
                }
            }
        }
    }
}
