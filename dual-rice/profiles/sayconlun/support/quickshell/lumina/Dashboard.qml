// Dashboard (Super+D, or click the bar's clock), modelled on Nisfere's: a
// panel hanging from the top centre of the bar with tabs for Overview,
// Media, Weather, Alerts, System, Productivity and GitHub.
//
//   qs -c lumina ipc call dashboard toggle
//   qs -c lumina ipc call dashboard tab weather     open on a tab
//
// Keys: 1-6 switch tabs (unless typing a task), Esc closes. The last tab
// is remembered between openings.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    property bool open: false
    property int tab: 0
    property var targetScreen: null
    property var visualiser: null             // Media tab's art pulses with its bass

    readonly property var tabs: [
        { name: "Overview", icon: "layout-dashboard" },
        { name: "Media", icon: "music" },
        { name: "Weather", icon: "cloud-sun" },
        { name: "Alerts", icon: "bell" },
        { name: "System", icon: "activity" },
        { name: "Productivity", icon: "list-checks" },
        { name: "GitHub", icon: "git-branch" }
    ]

    // The GitHub tab's data is fetched on demand, at most once a minute.
    onTabChanged: refreshGitHub()
    onOpenChanged: refreshGitHub()

    function refreshGitHub() {
        if (open && tab === 6 && Date.now() - GitHubService.refreshedAt > 60000)
            GitHubService.refresh()
    }

    function show() {
        if (open)
            return
        targetScreen = focusedScreen()
        open = true
    }

    function close() {
        open = false
    }

    function toggle() {
        open ? close() : show()
    }

    function showTab(name) {
        const i = tabs.findIndex(t => t.name.toLowerCase() === String(name).toLowerCase())
        if (i >= 0)
            tab = i
        show()
    }

    function focusedScreen() {
        const name = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
        const screens = Quickshell.screens
        for (let i = 0; i < screens.length; i++)
            if (screens[i].name === name)
                return screens[i]
        return screens[0]
    }

    // Start the forecast before the first opening, so it is there already.
    Component.onCompleted: WeatherService.ready

    Binding {
        target: MediaState
        property: "watched"
        value: root.open && (root.tab === 0 || root.tab === 1)
    }

    Binding {
        target: SystemStats
        property: "watched"
        value: root.open && (root.tab === 0 || root.tab === 4)
    }

    LazyLoader {
        active: root.open

        PanelWindow {
            id: win
            screen: root.targetScreen
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Normal
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "rice-dashboard"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            MouseArea {
                anchors.fill: parent
                onClicked: root.close()
            }

            Rectangle {
                id: panel
                anchors.top: parent.top
                anchors.topMargin: 8
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width - 40, 1080)
                height: Math.min(content.implicitHeight + 40, parent.height - 20)
                radius: 30
                color: Theme.alpha(Theme.surface_container, 0.97)
                border.width: 1
                border.color: Theme.alpha(Theme.outline_variant, 0.7)
                clip: true

                Behavior on height {
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }

                transformOrigin: Item.Top
                opacity: 0
                scale: 0.97
                Component.onCompleted: {
                    opacity = 1
                    scale = 1
                    keys.forceActiveFocus()
                }
                Behavior on opacity {
                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                }
                Behavior on scale {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: keys.forceActiveFocus()     // typing ends when clicking elsewhere
                }

                Item {
                    id: keys
                    focus: true
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            root.close()
                        } else if (event.key >= Qt.Key_1 && event.key < Qt.Key_1 + root.tabs.length) {
                            root.tab = event.key - Qt.Key_1
                        } else {
                            return
                        }
                        event.accepted = true
                    }
                }

                ColumnLayout {
                    id: content
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 20
                    spacing: 18

                    // Tab bar
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: tabRow.implicitWidth + 12
                        implicitHeight: 46
                        radius: 23
                        color: Theme.alpha(Theme.surface_container_high, 0.85)

                        RowLayout {
                            id: tabRow
                            anchors.centerIn: parent
                            spacing: 4

                            Repeater {
                                model: root.tabs

                                Rectangle {
                                    required property var modelData
                                    required property int index
                                    readonly property bool selected: root.tab === index

                                    implicitWidth: tabLabel.implicitWidth + 50
                                    implicitHeight: 36
                                    radius: 18
                                    color: selected ? Theme.primary
                                         : tabArea.containsMouse ? Theme.alpha(Theme.on_surface, 0.07) : "transparent"
                                    Behavior on color {
                                        ColorAnimation { duration: 150 }
                                    }

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 7

                                        LucideIcon {
                                            anchors.verticalCenter: parent.verticalCenter
                                            icon: modelData.icon
                                            size: 16
                                            color: selected ? Theme.on_primary : Theme.on_surface
                                        }

                                        Text {
                                            id: tabLabel
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.name
                                            color: selected ? Theme.on_primary : Theme.on_surface
                                            font.family: Theme.font
                                            font.pixelSize: 13
                                            font.weight: selected ? Font.Bold : Font.Medium
                                        }
                                    }

                                    MouseArea {
                                        id: tabArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.tab = index
                                            keys.forceActiveFocus()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Loader {
                        id: page
                        Layout.fillWidth: true
                        sourceComponent: [overview, media, weather, alerts, system, productivity, github][root.tab]
                        onLoaded: {
                            item.opacity = 0
                            fade.restart()
                        }

                        NumberAnimation {
                            id: fade
                            target: page.item
                            property: "opacity"
                            to: 1
                            duration: 180
                        }
                    }
                }
            }
        }
    }

    Component {
        id: overview
        DashOverview { dash: root }
    }

    Component {
        id: media
        DashMedia { dash: root }
    }

    Component {
        id: weather
        DashWeather { dash: root }
    }

    Component {
        id: alerts
        DashAlerts { dash: root }
    }

    Component {
        id: system
        DashSystem { dash: root }
    }

    Component {
        id: productivity
        DashProductivity { dash: root }
    }

    Component {
        id: github
        DashGitHub { dash: root }
    }
}
