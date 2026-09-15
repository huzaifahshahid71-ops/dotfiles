// Control centre, modelled on Nisfere's: a panel hanging from the bar with a
// grid of glass toggle cards, volume and mic sliders, and detail pages for
// Wi-Fi, Bluetooth, Ethernet and sound devices.
//
//   qs -c lumina ipc call controlcenter toggle      (the bar's network/volume pill)
//
// Where each card gets its state:
//   Wi-Fi, Ethernet   Quickshell.Networking (NetworkManager)
//   Bluetooth         Quickshell.Bluetooth (BlueZ)
//   volume, mic       Quickshell.Services.Pipewire - needs a PwObjectTracker,
//                     or the nodes' audio properties never go live
//   Energy            Quickshell.Services.UPower power profiles
//   theme             `rice-wallpaper mode`, state in ~/.local/share/desktop-profiles/sayconlun/support/state/cache/mode
//   Do Not Disturb    NotifService (Quickshell is the notification daemon)
//   Night Light       hyprsunset, running or not
//   keyboard          hyprctl; shown only with more than one layout, and
//                     the visualiser switch takes its place otherwise
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

Scope {
    id: root

    property bool open: false
    property string page: "main"          // main | wifi | bluetooth | ethernet | sound
    property var targetScreen: null
    property var visualiser: null          // wired up by shell.qml

    signal refocus                         // pages hand keyboard focus back

    readonly property string home: Quickshell.env("HOME")
    readonly property string bin: home + "/.local/share/desktop-profiles/sayconlun/support/bin/"

    function show() {
        if (open)
            return
        targetScreen = focusedScreen()
        page = "main"
        nightGet.running = true
        keyboardGet.running = true
        open = true
    }

    function close() {
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

    // ------------------------------------------------------------ network --
    readonly property var wifiDevice: firstDevice(DeviceType.Wifi)
    readonly property var wiredDevice: firstDevice(DeviceType.Wired)
    readonly property var wifiNetworks: wifiDevice ? Array.from(wifiDevice.networks.values) : []
    readonly property var wifiCurrent: {
        for (const n of wifiNetworks)
            if (n.connected)
                return n
        return null
    }

    function firstDevice(type) {
        const ds = Networking.devices.values
        for (let i = 0; i < ds.length; i++)
            if (ds[i].type === type)
                return ds[i]
        return null
    }

    function wifiIcon(strength) {
        const s = strength > 1 ? strength / 100 : strength
        return s >= 0.75 ? "wifi" : s >= 0.5 ? "wifi-high" : s >= 0.25 ? "wifi-low" : "wifi-zero"
    }

    // Scan only while the panel is open.
    Binding {
        target: root.wifiDevice
        property: "scannerEnabled"
        value: root.open
        when: root.wifiDevice !== null
    }

    // ---------------------------------------------------------- bluetooth --
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property var btConnected: Array.from(Bluetooth.devices.values).filter(d => d.connected)

    // -------------------------------------------------------------- audio --
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    PwObjectTracker {
        objects: [root.sink, root.source].filter(o => o)
    }

    function setVolume(node, v) {
        if (!node || !node.audio)
            return
        node.audio.muted = false
        node.audio.volume = Math.max(0, Math.min(1, v))
    }

    function volumeIcon(node) {
        const a = node && node.audio
        if (!a || a.muted)
            return "volume-x"
        return a.volume > 0.6 ? "volume-2" : a.volume > 0.2 ? "volume-1" : "volume"
    }

    function nodeName(node) {
        return node ? (node.description || node.nickname || node.name) : "No device"
    }

    // ------------------------------------------------------------- energy --
    readonly property var profileNames: ["Power saver", "Balanced", "Performance"]

    function cyclePower() {
        const order = [PowerProfile.PowerSaver, PowerProfile.Balanced]
        if (PowerProfiles.hasPerformanceProfile)
            order.push(PowerProfile.Performance)
        const i = order.indexOf(PowerProfiles.profile)
        PowerProfiles.profile = order[(i + 1) % order.length]
    }

    // -------------------------------------------------------------- theme --
    property string mode: "dark"

    FileView {
        path: root.home + "/.local/share/desktop-profiles/sayconlun/support/state/cache/mode"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.mode = text().trim() === "light" ? "light" : "dark"
    }

    function toggleMode() {
        mode = mode === "dark" ? "light" : "dark"    // the file confirms it
        Quickshell.execDetached([bin + "rice-wallpaper", "mode", mode])
    }

    // ---------------------------------------------------- do not disturb --
    readonly property bool dnd: NotifService.dnd === true   // undefined while the service is starting

    function toggleDnd() {
        NotifService.dnd = !NotifService.dnd
    }

    // -------------------------------------------------------- night light --
    property bool nightLight: false
    readonly property int nightTemperature: 4000

    Process {
        id: nightGet
        command: ["pgrep", "-x", "hyprsunset"]
        onExited: code => root.nightLight = code === 0
    }

    Timer {
        id: nightRecheck
        interval: 800
        onTriggered: nightGet.running = true
    }

    function toggleNightLight() {
        if (nightLight)
            Quickshell.execDetached(["pkill", "-x", "hyprsunset"])
        else
            Quickshell.execDetached(["hyprsunset", "-t", String(nightTemperature)])
        nightLight = !nightLight
        nightRecheck.restart()
    }

    // ----------------------------------------------------------- keyboard --
    property var layouts: []
    property string keymap: ""

    Process {
        id: keyboardGet
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const kb = JSON.parse(text).keyboards
                    const main = kb.find(k => k.main) || kb[0]
                    root.layouts = main ? main.layout.split(",").filter(l => l) : []
                    root.keymap = main ? main.active_keymap : ""
                } catch (e) {
                    root.layouts = []
                }
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout")
                root.keymap = event.data.split(",").slice(1).join(",")
        }
    }

    function nextLayout() {
        Quickshell.execDetached(["hyprctl", "switchxkblayout", "current", "next"])
    }

    // ------------------------------------------------------------- window --
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
            exclusionMode: ExclusionMode.Normal     // hang from under the bar
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "rice-controlcenter"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

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
                width: 520
                height: Math.min(pages.implicitHeight + 36, parent.height - 20)
                radius: 28
                color: Theme.alpha(Theme.surface_container, 0.97)
                border.width: 1
                border.color: Theme.alpha(Theme.outline_variant, 0.7)
                clip: true

                Behavior on height {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }

                transformOrigin: Item.TopRight
                opacity: 0
                scale: 0.96
                Component.onCompleted: {
                    opacity = 1
                    scale = 1
                    keys.forceActiveFocus()
                }
                Behavior on opacity {
                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                }
                Behavior on scale {
                    NumberAnimation { duration: 170; easing.type: Easing.OutCubic }
                }

                MouseArea {
                    anchors.fill: parent        // clicks inside do not close
                }

                Item {
                    id: keys
                    focus: true
                    Keys.onEscapePressed: root.page === "main" ? root.close() : root.page = "main"
                }

                Connections {
                    target: root
                    function onRefocus() {
                        keys.forceActiveFocus()
                    }
                }

                Loader {
                    id: pages
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 18
                    sourceComponent: root.page === "wifi" ? wifiPage
                                   : root.page === "bluetooth" ? bluetoothPage
                                   : root.page === "ethernet" ? ethernetPage
                                   : root.page === "sound" ? soundPage
                                   : mainPage
                    onLoaded: {
                        item.opacity = 0
                        item.x = root.page === "main" ? -16 : 16
                        fadeIn.restart()
                    }

                    ParallelAnimation {
                        id: fadeIn
                        NumberAnimation { target: pages.item; property: "opacity"; to: 1; duration: 180 }
                        NumberAnimation { target: pages.item; property: "x"; to: 0; duration: 220; easing.type: Easing.OutCubic }
                    }
                }
            }
        }
    }

    // -------------------------------------------------------------- pages --
    Component {
        id: mainPage

        ColumnLayout {
            spacing: 12

            // Title, with the settings and power buttons that used to be on the bar.
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    Layout.leftMargin: 4
                    text: "Control Center"
                    color: Theme.on_surface
                    font.family: Theme.font
                    font.pixelSize: 22
                    font.weight: Font.Bold
                }

                DashButton {
                    icon: "settings"
                    size: 36
                    iconSize: 17
                    onClicked: {
                        root.close()
                        Quickshell.execDetached(["qs", "-c", "lumina", "ipc", "call", "settings", "open"])
                    }
                }

                DashButton {
                    icon: "power"
                    size: 36
                    iconSize: 17
                    onClicked: {
                        root.close()
                        Quickshell.execDetached([root.bin + "rice-power"])
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 10
                rowSpacing: 10
                uniformCellWidths: true

                CcCard {
                    Layout.fillWidth: true
                    visible: root.wiredDevice !== null
                    icon: "ethernet-port"
                    title: "Ethernet"
                    active: root.wiredDevice ? root.wiredDevice.connected : false
                    subtitle: !root.wiredDevice ? ""
                        : root.wiredDevice.connected
                            ? "Connected" + (root.wiredDevice.linkSpeed ? ` (${root.wiredDevice.linkSpeed} Mb/s)` : "")
                        : root.wiredDevice.hasLink ? "Disconnected" : "Cable unplugged"
                    hasMore: true
                    onClicked: root.page = "ethernet"
                    onMoreClicked: root.page = "ethernet"
                }

                CcCard {
                    Layout.fillWidth: true
                    visible: root.wifiDevice !== null
                    icon: !Networking.wifiEnabled ? "wifi-off"
                        : root.wifiCurrent ? root.wifiIcon(root.wifiCurrent.signalStrength) : "wifi"
                    title: "Wi-Fi"
                    active: root.wifiCurrent !== null
                    subtitle: !Networking.wifiEnabled ? "Off"
                        : root.wifiCurrent ? root.wifiCurrent.name : "Not connected"
                    hasMore: true
                    onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
                    onMoreClicked: root.page = "wifi"
                }

                CcCard {
                    Layout.fillWidth: true
                    visible: root.btAdapter !== null
                    icon: !root.btAdapter || !root.btAdapter.enabled ? "bluetooth-off"
                        : root.btConnected.length ? "bluetooth-connected" : "bluetooth"
                    title: "Bluetooth"
                    active: root.btAdapter ? root.btAdapter.enabled : false
                    subtitle: !root.btAdapter || !root.btAdapter.enabled ? "Off"
                        : root.btConnected.length ? root.btConnected.map(d => d.name || d.deviceName).join(", ")
                        : "On"
                    hasMore: true
                    onClicked: if (root.btAdapter) root.btAdapter.enabled = !root.btAdapter.enabled
                    onMoreClicked: root.page = "bluetooth"
                }

                CcCard {
                    Layout.fillWidth: true
                    icon: "palette"
                    title: root.mode === "dark" ? "Dark Theme" : "Light Theme"
                    subtitle: "Appearance"
                    active: root.mode === "dark"
                    onClicked: root.toggleMode()
                }

                CcCard {
                    Layout.fillWidth: true
                    visible: root.layouts.length > 1
                    icon: "keyboard"
                    title: root.keymap || "Keyboard"
                    subtitle: "Layout: " + root.layouts.join(", ").toUpperCase()
                    onClicked: root.nextLayout()
                }

                CcCard {
                    Layout.fillWidth: true
                    visible: root.layouts.length <= 1 && root.visualiser !== null
                    icon: "audio-lines"
                    title: "Visualiser"
                    active: root.visualiser ? root.visualiser.enabled : false
                    subtitle: active ? "On" : "Off"
                    onClicked: root.visualiser.toggle()
                }

                CcCard {
                    Layout.fillWidth: true
                    icon: root.dnd ? "bell-off" : "bell"
                    title: "Do Not Disturb"
                    active: root.dnd
                    subtitle: root.dnd ? "On" : "Off"
                    onClicked: root.toggleDnd()
                }

                CcCard {
                    Layout.fillWidth: true
                    icon: root.nightLight ? "moon-star" : "sun"
                    title: "Night Light"
                    active: root.nightLight
                    subtitle: root.nightLight ? `On · ${root.nightTemperature}K` : "Off"
                    onClicked: root.toggleNightLight()
                }

                CcCard {
                    Layout.fillWidth: true
                    icon: PowerProfiles.profile === PowerProfile.PowerSaver ? "leaf"
                        : PowerProfiles.profile === PowerProfile.Performance ? "zap" : "gauge"
                    title: "Energy"
                    active: PowerProfiles.profile === PowerProfile.Performance
                    subtitle: root.profileNames[PowerProfiles.profile] ?? "Balanced"
                    onClicked: root.cyclePower()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: sliders.implicitHeight + 28
                radius: 20
                color: Theme.alpha(Theme.surface_container_high, 0.85)
                border.width: 1
                border.color: Theme.alpha(Theme.outline_variant, 0.45)

                ColumnLayout {
                    id: sliders
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    CcSlider {
                        Layout.fillWidth: true
                        icon: root.volumeIcon(root.sink)
                        muted: root.sink && root.sink.audio ? root.sink.audio.muted : false
                        value: root.sink && root.sink.audio ? root.sink.audio.volume : 0
                        onMoved: v => root.setVolume(root.sink, v)
                        onMuteToggled: if (root.sink && root.sink.audio) root.sink.audio.muted = !root.sink.audio.muted
                    }

                    CcSlider {
                        Layout.fillWidth: true
                        icon: "mic"
                        mutedIcon: "mic-off"
                        muted: root.source && root.source.audio ? root.source.audio.muted : false
                        value: root.source && root.source.audio ? root.source.audio.volume : 0
                        onMoved: v => root.setVolume(root.source, v)
                        onMuteToggled: if (root.source && root.source.audio) root.source.audio.muted = !root.source.audio.muted
                    }

                    // The output in use, and a way to change it.
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 40
                        radius: 12
                        color: outputArea.containsMouse ? Theme.alpha(Theme.on_surface, 0.06) : "transparent"

                        MouseArea {
                            id: outputArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.page = "sound"
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 6
                            spacing: 10

                            LucideIcon {
                                icon: "headphones"
                                size: 17
                                color: Theme.on_surface_variant
                            }

                            Text {
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                text: root.nodeName(root.sink)
                                color: Theme.on_surface_variant
                                font.family: Theme.font
                                font.pixelSize: 13
                            }

                            LucideIcon {
                                icon: "chevron-right"
                                size: 17
                                opacity: 0.8
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: wifiPage
        CcWifiPage {
            cc: root
        }
    }

    Component {
        id: bluetoothPage
        CcBluetoothPage {
            cc: root
        }
    }

    Component {
        id: ethernetPage
        CcEthernetPage {
            cc: root
        }
    }

    Component {
        id: soundPage
        CcSoundPage {
            cc: root
        }
    }
}
