// Settings hub: the bar's gear (or Super+,) drops a panel down under the bar
// listing every settings panel there is - the rice's own and the system's.
//
// Picking an entry closes the hub and opens that panel. Entries that are a
// switch rather than a panel (visualiser, power profile) change in place and
// keep the hub open, showing their new state.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    property bool open: false
    property int sel: 0
    property var targetScreen: null
    property string powerProfile: ""

    // Wired up by shell.qml.
    property var visualiser: null
    property var clock: null
    property var lyrics: null
    property var controlCenter: null
    property var notifications: null
    property var dashboard: null
    property var captureMenu: null
    property var walls: null
    property var binds: null

    readonly property string bin: Quickshell.env("HOME") + "/.local/share/desktop-profiles/sayconlun/support/bin/"

    // run: argv started detached · call: a function · keep: stay open (switches)
    readonly property var entries: [
        { section: "Rice", icon: "󰕮", label: "Dashboard", hint: "media, weather, system, tasks",
          call: () => root.dashboard.show() },
        { section: "Rice", icon: "󰄀", label: "Screenshot & record", hint: "screen, window or area",
          call: () => root.captureMenu.show() },
        { section: "Rice", icon: "󰉼", label: "Look", hint: "gaps, borders, rounding, blur",
          run: [bin + "rice-settings", "look"] },
        { section: "Rice", icon: "󰍹", label: "Displays", hint: "resolution, scale, refresh, VRR",
          run: [bin + "rice-settings", "displays"] },
        { section: "Rice", icon: "󰌌", label: "Keybinds", hint: "cheatsheet and rebinding",
          call: () => root.binds.show() },
        { section: "Rice", icon: "󰸉", label: "Wallpaper", hint: "carousel with live preview",
          call: () => root.walls.show() },
        { section: "Rice", icon: "󰖟", label: "Wallhaven", hint: "search and download wallpapers",
          run: [bin + "rice-wallhaven"] },
        { section: "Rice", icon: "󰝚", label: "Desktop visualiser", keep: true,
          value: root.visualiser && root.visualiser.enabled ? "On" : "Off",
          call: () => root.visualiser.toggle() },
        { section: "Rice", icon: "󰥔", label: "Desktop clock", keep: true,
          value: root.clock && root.clock.enabled ? "On" : "Off",
          call: () => root.clock.toggle() },
        { section: "Rice", icon: "󰎈", label: "Desktop lyrics", keep: true,
          value: root.lyrics && root.lyrics.enabled ? "On" : "Off",
          call: () => root.lyrics.toggle() },

        { section: "Bar & shell", icon: "󰍜", label: "Show / hide the bar",
          run: ["pkill", "-USR1", "-x", "waybar"] },
        { section: "Bar & shell", icon: "󰑓", label: "Reload the bar", hint: "re-read waybar's config and style",
          run: ["pkill", "-USR2", "-x", "waybar"] },
        { section: "Bar & shell", icon: "󰑓", label: "Reload Quickshell", hint: "after editing its QML",
          call: () => Quickshell.reload(true) },

        { section: "System", icon: "󰙵", label: "Control centre", hint: "Wi-Fi, Bluetooth, theme, night light",
          call: () => root.controlCenter.show() },
        { section: "System", icon: "󰕾", label: "Sound", hint: "outputs, inputs, per-app volume",
          run: ["pavucontrol"] },
        { section: "System", icon: "󰖩", label: "Wi-Fi",
          run: [bin + "rice-wifi"] },
        { section: "System", icon: "󰈀", label: "Network connections", hint: "wired, VPN, advanced",
          run: ["nm-connection-editor"] },
        { section: "System", icon: "󰾅", label: "Power profile", keep: true,
          value: root.pretty(root.powerProfile),
          call: () => root.cyclePower() },
        { section: "System", icon: "󰂚", label: "Notifications", hint: "history, do not disturb",
          call: () => root.notifications.show() },
        { section: "System", icon: "󰏘", label: "GTK appearance", hint: "theme, icons, cursor, fonts",
          run: ["nwg-look"] },
        { section: "System", icon: "󰏘", label: "Qt appearance", hint: "Qt apps such as Kate",
          run: ["qt6ct"] },
        { section: "System", icon: "󰄨", label: "Task manager",
          run: ["kitty", "--class", "taskmgr", "-e", "btop"] },
        { section: "System", icon: "󰐥", label: "Session", hint: "lock, log out, reboot, power off",
          run: [bin + "rice-power"] },

        { section: "CachyOS", icon: "󰋼", label: "CachyOS Hello",
          run: ["cachyos-hello"] },
        { section: "CachyOS", icon: "󰏗", label: "Package installer",
          run: ["cachyos-pi"] },
        { section: "CachyOS", icon: "󰍛", label: "Kernel manager",
          run: ["cachyos-kernel-manager"] },
        { section: "CachyOS", icon: "󰘚", label: "CPU scheduler", hint: "sched-ext",
          run: ["scx-manager"] },
        { section: "CachyOS", icon: "󰁯", label: "Snapshots", hint: "btrfs / snapper",
          run: ["btrfs-assistant-launcher"] }
    ]

    function show() {
        if (open)
            return
        targetScreen = focusedScreen()
        sel = 0
        powerGet.running = true
        open = true
    }

    function close() {
        open = false
    }

    function toggle() {
        open ? close() : show()
    }

    function activate(e) {
        if (!e)
            return
        if (!e.keep)
            close()
        if (e.run)
            Quickshell.execDetached(e.run)
        else if (e.call)
            e.call()
    }

    function pretty(profile) {
        return profile ? profile.split("-").map(w => w[0].toUpperCase() + w.slice(1)).join(" ") : "…"
    }

    function cyclePower() {
        const order = ["power-saver", "balanced", "performance"]
        const next = order[(order.indexOf(powerProfile) + 1) % order.length]
        powerProfile = next
        powerSet.command = ["powerprofilesctl", "set", next]
        powerSet.running = true
    }

    function focusedScreen() {
        const name = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
        const screens = Quickshell.screens
        for (let i = 0; i < screens.length; i++)
            if (screens[i].name === name)
                return screens[i]
        return screens[0]
    }

    Process {
        id: powerGet
        command: ["powerprofilesctl", "get"]
        stdout: StdioCollector {
            onStreamFinished: root.powerProfile = text.trim()
        }
    }

    Process {
        id: powerSet
        onExited: powerGet.running = true     // show what it really is now
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
            // Below the bar, so the panel hangs from it.
            exclusionMode: ExclusionMode.Normal
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "rice-settings"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            // Anywhere outside the panel closes it.
            MouseArea {
                anchors.fill: parent
                onClicked: root.close()
            }

            Rectangle {
                id: panel
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 8
                anchors.rightMargin: 10
                width: 400
                height: Math.min(content.implicitHeight + 24, parent.height - 20)
                radius: 22
                color: Theme.alpha(Theme.surface_container, 0.96)
                border.width: 1
                border.color: Theme.alpha(Theme.outline_variant, 0.7)

                transformOrigin: Item.TopRight
                opacity: 0
                scale: 0.96
                Component.onCompleted: {
                    opacity = 1
                    scale = 1
                    keys.forceActiveFocus()
                }
                Behavior on opacity {
                    NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                }
                Behavior on scale {
                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                }

                MouseArea {
                    anchors.fill: parent       // clicks inside do not close
                }

                Item {
                    id: keys
                    focus: true
                    Keys.onPressed: event => {
                        const n = root.entries.length
                        switch (event.key) {
                        case Qt.Key_Down: case Qt.Key_J: case Qt.Key_Tab:
                            root.sel = (root.sel + 1) % n; break
                        case Qt.Key_Up: case Qt.Key_K: case Qt.Key_Backtab:
                            root.sel = (root.sel - 1 + n) % n; break
                        case Qt.Key_Return: case Qt.Key_Enter: case Qt.Key_Space:
                            root.activate(root.entries[root.sel]); break
                        case Qt.Key_Escape:
                            root.close(); break
                        default:
                            return
                        }
                        event.accepted = true
                    }
                }

                Flickable {
                    id: flick
                    anchors.fill: parent
                    anchors.margins: 12
                    contentHeight: content.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    function ensureVisible(item) {
                        const p = item.mapToItem(content, 0, 0)
                        if (p.y < contentY)
                            contentY = Math.max(0, p.y - 30)
                        else if (p.y + item.height > contentY + height)
                            contentY = Math.min(contentHeight - height, p.y + item.height - height)
                    }

                    ColumnLayout {
                        id: content
                        width: flick.width
                        spacing: 2

                        Repeater {
                            model: root.entries

                            ColumnLayout {
                                id: entry
                                required property var modelData
                                required property int index
                                readonly property bool firstOfSection: index === 0
                                    || root.entries[index - 1].section !== modelData.section
                                readonly property bool selected: index === root.sel

                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    visible: entry.firstOfSection
                                    Layout.topMargin: entry.index === 0 ? 4 : 12
                                    Layout.bottomMargin: 2
                                    Layout.leftMargin: 12
                                    text: entry.modelData.section
                                    color: Theme.primary
                                    font.family: Theme.font
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                    font.capitalization: Font.AllUppercase
                                    font.letterSpacing: 1.2
                                }

                                Rectangle {
                                    id: row
                                    Layout.fillWidth: true
                                    implicitHeight: 38
                                    radius: 12
                                    color: entry.selected ? Theme.alpha(Theme.primary, 0.16) : "transparent"
                                    border.width: entry.selected ? 1 : 0
                                    border.color: Theme.alpha(Theme.primary, 0.5)

                                    Connections {
                                        target: entry
                                        function onSelectedChanged() {
                                            if (entry.selected)
                                                flick.ensureVisible(row)
                                        }
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 10
                                        spacing: 12

                                        Text {
                                            Layout.preferredWidth: 22
                                            horizontalAlignment: Text.AlignHCenter
                                            text: entry.modelData.icon
                                            color: Theme.primary
                                            font.family: Theme.mono
                                            font.pixelSize: 18
                                        }

                                        Text {
                                            text: entry.modelData.label
                                            color: Theme.on_surface
                                            font.family: Theme.font
                                            font.pixelSize: 14
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                            text: entry.modelData.hint || ""
                                            color: Theme.on_surface_variant
                                            font.family: Theme.font
                                            font.pixelSize: 12
                                        }

                                        Rectangle {
                                            visible: entry.modelData.value !== undefined
                                            implicitWidth: valueText.implicitWidth + 18
                                            implicitHeight: 24
                                            radius: 12
                                            color: entry.modelData.value === "Off"
                                                ? Theme.surface_container_highest
                                                : Theme.alpha(Theme.primary, 0.22)

                                            Text {
                                                id: valueText
                                                anchors.centerIn: parent
                                                text: entry.modelData.value || ""
                                                color: entry.modelData.value === "Off" ? Theme.on_surface_variant : Theme.primary
                                                font.family: Theme.font
                                                font.pixelSize: 12
                                                font.weight: Font.DemiBold
                                            }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: root.sel = entry.index
                                        onClicked: root.activate(entry.modelData)
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
