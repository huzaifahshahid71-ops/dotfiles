// ZEPHYRUS Tahoe preview alpha 0.2 — surface/layout proof.
// NOT yet real refraction. Existing shell and compositor remain untouched.
// Qt 6.11.2 compatibility: one fixed menu bar, dock and optional popup.
// Avoid the QtQuick Variants/PanelWindow multiple-output crash path.

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets

ShellRoot {
    id: tahoe

    property bool appleMenuOpen: false
    property int hoveredDockIndex: -1
    property color ink: "#243047"
    property color muted: "#5e6f87"
    property color accent: "#2477f3"

    property var pinned: [
        {label: "Finder", icon: "system-file-manager", desktop: "org.gnome.Nautilus", fallback: ["xdg-open", "/home"]},
        {label: "Terminal", icon: "utilities-terminal", desktop: "foot", fallback: ["foot"]},
        {label: "Browser", icon: "internet-web-browser", desktop: "firefox", fallback: ["xdg-open", "https://example.org"]},
        {label: "Launchpad", icon: "view-app-grid", desktop: "", fallback: ["sh", "-c", "if command -v fuzzel >/dev/null; then exec fuzzel; elif command -v rofi >/dev/null; then exec rofi -show drun; else exec foot; fi"]},
        {label: "Settings", icon: "preferences-system", desktop: "org.gnome.Settings", fallback: ["sh", "-c", "if command -v gnome-control-center >/dev/null; then exec gnome-control-center; elif command -v pavucontrol >/dev/null; then exec pavucontrol; else exec foot; fi"]}
    ]

    function launch(entry) {
        appleMenuOpen = false;
        if (entry.desktop) {
            const app = DesktopEntries.heuristicLookup(entry.desktop);
            if (app !== null) {
                app.execute();
                return;
            }
        }
        Quickshell.execDetached(entry.fallback);
    }

    function activeName() {
        const t = Hyprland.activeToplevel;
        if (!t || !t.appId)
            return "Finder";
        const parts = t.appId.split(".");
        return parts[parts.length - 1].replace(/[-_]/g, " ");
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    PanelWindow {
        id: bar
        anchors {
            top: true
            left: true
            right: true
        }
        implicitHeight: 38
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "zephyrus-tahoe-alpha-bar"
        WlrLayershell.layer: WlrLayer.Top

        Rectangle {
            anchors.fill: parent
            color: "#d8e9f1ff"

            Rectangle {
                anchors.fill: parent
                color: "#3effffff"
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: "#73909cae"
            }

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 17
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height
                spacing: 23

                Item {
                    width: 30
                    height: parent.height

                    Rectangle {
                        anchors.centerIn: parent
                        width: 26
                        height: 26
                        radius: 9
                        color: appleHit.containsMouse || tahoe.appleMenuOpen ? "#6dffffff" : "transparent"
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "●"
                        color: tahoe.ink
                        font.pixelSize: 19
                        font.weight: Font.Black
                    }

                    MouseArea {
                        id: appleHit
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: tahoe.appleMenuOpen = !tahoe.appleMenuOpen
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: tahoe.activeName()
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: tahoe.ink
                    width: Math.min(190, paintedWidth)
                    elide: Text.ElideRight
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Applications"
                    color: tahoe.ink
                    font.pixelSize: 12
                    MouseArea {
                        anchors.fill: parent
                        onClicked: tahoe.launch(tahoe.pinned[3])
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Files"
                    color: tahoe.ink
                    font.pixelSize: 12
                    MouseArea {
                        anchors.fill: parent
                        onClicked: tahoe.launch(tahoe.pinned[0])
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Terminal"
                    color: tahoe.ink
                    font.pixelSize: 12
                    MouseArea {
                        anchors.fill: parent
                        onClicked: tahoe.launch(tahoe.pinned[1])
                    }
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                spacing: 17

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "ZEPHYRUS"
                    color: "#68829bb6"
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.2
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDateTime(clock.date, "ddd  MMM d   hh:mm AP")
                    color: tahoe.ink
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }
            }
        }
    }

    PanelWindow {
        id: appleMenu
        visible: tahoe.appleMenuOpen
        anchors {
            top: true
            left: true
        }
        margins {
            top: 39
            left: 14
        }
        implicitWidth: 245
        implicitHeight: 233
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "zephyrus-tahoe-alpha-menu"

        Rectangle {
            anchors.fill: parent
            radius: 18
            color: "#edf1f7fd"
            border.color: "#eaffffff"
            border.width: 1

            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 9
                }
                height: 32
                radius: 10
                color: "#e0e8f9ff"

                Text {
                    anchors.centerIn: parent
                    text: "Tahoe • Alpha 0.2"
                    color: tahoe.ink
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
            }

            Column {
                x: 11
                y: 53
                spacing: 2

                Repeater {
                    model: [
                        { title: "About this preview", action: "about" },
                        { title: "Open Applications", action: "applications" },
                        { title: "Open Finder", action: "finder" },
                        { title: "Open Terminal", action: "terminal" },
                        { title: "Quit Tahoe Preview", action: "quit" }
                    ]
                    delegate: Rectangle {
                        id: entry
                        required property var modelData
                        width: 223
                        height: 30
                        radius: 8
                        color: actionArea.containsMouse ? "#317bbff2" : "transparent"

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: entry.modelData.title
                            font.pixelSize: 12
                            color: actionArea.containsMouse ? "#ffffff" : tahoe.ink
                        }

                        MouseArea {
                            id: actionArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                const act = entry.modelData.action;
                                tahoe.appleMenuOpen = false;
                                if (act === "quit") {
                                    Qt.quit();
                                } else if (act === "applications") {
                                    tahoe.launch(tahoe.pinned[3]);
                                } else if (act === "finder") {
                                    tahoe.launch(tahoe.pinned[0]);
                                } else if (act === "terminal") {
                                    tahoe.launch(tahoe.pinned[1]);
                                } else if (act === "about") {
                                    tahoe.aboutOpen = true;
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    property bool aboutOpen: false
    PanelWindow {
        visible: tahoe.aboutOpen
        anchors {
            top: true
            left: true
        }
        margins {
            top: 282
            left: 14
        }
        implicitWidth: 330
        implicitHeight: 94
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "zephyrus-tahoe-alpha-about"

        Rectangle {
            anchors.fill: parent
            radius: 17
            color: "#f0f2f9ff"
            border.color: "#faffffff"
            Text {
                x: 17
                y: 15
                text: "ZEPHYRUS Tahoe — design prototype"
                color: tahoe.ink
                font.pixelSize: 13
                font.bold: true
            }
            Text {
                x: 17
                y: 40
                text: "Glass refraction, Genie, minimize: not installed yet."
                color: tahoe.muted
                font.pixelSize: 11
            }
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 15
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 10
                text: "Close ×"
                color: tahoe.accent
                font.pixelSize: 11
                MouseArea {
                    anchors.fill: parent
                    onClicked: tahoe.aboutOpen = false
                }
            }
        }
    }

    PanelWindow {
        id: dock
        anchors { bottom: true }
        margins { bottom: 20 }
        implicitWidth: dockItems.implicitWidth + 35
        implicitHeight: 112
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "zephyrus-tahoe-alpha-dock"

        Rectangle {
            id: dockMaterial
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }
            height: 91
            radius: 24
            color: "#b4f4f8ff"
            border.color: "#efffffff"
            border.width: 1

            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                }
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                height: 2
                radius: 1
                color: "#9affffff"
            }

            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    bottomMargin: 1
                    leftMargin: 18
                    rightMargin: 18
                }
                height: 1
                color: "#50ffffff"
            }

            Row {
                id: dockItems
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                spacing: 8

                Repeater {
                    model: tahoe.pinned
                    delegate: Item {
                        id: pinnedItem
                        required property var modelData
                        required property int index
                        width: 68
                        height: 72
                        property int gapFromPointer: Math.abs(tahoe.hoveredDockIndex - index)
                        property real zoom: tahoe.hoveredDockIndex < 0
                            ? 1.0 : gapFromPointer === 0 ? 1.25 : gapFromPointer === 1 ? 1.08 : 1.0

                        IconImage {
                            id: icon
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            implicitSize: 59
                            source: Quickshell.iconPath(
                                pinnedItem.modelData.icon,
                                "application-x-executable"
                            )
                            scale: pinnedItem.zoom
                            transformOrigin: Item.Bottom
                            Behavior on scale {
                                NumberAnimation {
                                    duration: 145
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            width: 4
                            height: 4
                            radius: 2
                            color: "#6c8298af"
                            visible: false // will become live app state in stage 2
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.top
                            anchors.bottomMargin: 8
                            width: pinnedLabel.implicitWidth + 17
                            height: 25
                            radius: 9
                            color: "#d9293443"
                            visible: pinnedHover.containsMouse

                            Text {
                                id: pinnedLabel
                                anchors.centerIn: parent
                                text: pinnedItem.modelData.label
                                font.pixelSize: 11
                                color: "white"
                            }
                        }

                        MouseArea {
                            id: pinnedHover
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: tahoe.hoveredDockIndex = pinnedItem.index
                            onExited: {
                                if (tahoe.hoveredDockIndex === pinnedItem.index)
                                    tahoe.hoveredDockIndex = -1;
                            }
                            onClicked: tahoe.launch(pinnedItem.modelData)
                        }
                    }
                }

                Rectangle {
                    width: 1
                    height: 56
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#7896aabf"
                }

                Repeater {
                    model: Hyprland.toplevels
                    delegate: Item {
                        id: running
                        required property var modelData
                        width: 63
                        height: 72
                        property bool focused: modelData.activated

                        IconImage {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            implicitSize: 53
                            source: Quickshell.iconPath(
                                running.modelData.appId || "application-x-executable",
                                "application-x-executable"
                            )
                            scale: runningMouse.containsMouse ? 1.2 : 1.0
                            transformOrigin: Item.Bottom
                            Behavior on scale {
                                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                            }
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            width: 5
                            height: 5
                            radius: 3
                            color: running.focused ? tahoe.accent : tahoe.muted
                        }

                        MouseArea {
                            id: runningMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: running.modelData.activate()
                        }
                    }
                }
            }
        }
    }
}
