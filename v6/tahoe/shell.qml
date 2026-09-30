//@ pragma UseQApplication
// ZEPHYRUS v6.0 Tahoe — visual + launcher preview, NOT final Liquid Glass.
// Single-display alpha: intentionally avoids Variants + PanelWindow Qt 6.11.2 regression.
// Run with v6/tahoe/preview.sh; it does not replace the active rice.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets

ShellRoot {
    id: tahoe

    // Per-session only. No global icon/cursor/GTK themes are modified.
    property color ink: "#202536"
    property color softInk: "#52647a"
    property color accent: "#539cf1"
    property var launchers: [
        { label: "Files", icon: "system-file-manager", desktop: "org.gnome.Nautilus",
          fallback: ["sh", "-c", "xdg-open \"$HOME\""] },
        { label: "Terminal", icon: "utilities-terminal", desktop: "foot",
          fallback: ["foot"] },
        { label: "Browser", icon: "internet-web-browser", desktop: "firefox",
          fallback: ["xdg-open", "https://example.org"] },
        { label: "Apps", icon: "view-app-grid", desktop: "",
          fallback: ["sh", "-c", "if command -v fuzzel >/dev/null; then exec fuzzel; elif command -v rofi >/dev/null; then exec rofi -show drun; else exec foot; fi"] }
    ]

    function openLauncher(entry) {
        if (entry.desktop) {
            let desktop = DesktopEntries.heuristicLookup(entry.desktop);
            if (desktop !== null) {
                desktop.execute();
                return;
            }
        }
        Quickshell.execDetached(entry.fallback);
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // Preview top menu bar: content follows the focused Wayland application.
    PanelWindow {
        id: menuBar
        anchors { top: true; left: true; right: true }
        implicitHeight: 43
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "zephyrus-tahoe-alpha-bar"
        WlrLayershell.layer: WlrLayer.Top

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#edf6fdff" }
                GradientStop { position: 1.0; color: "#bcdde8f7" }
            }
            border.color: "#f6ffffff"
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 19
                anchors.rightMargin: 19
                spacing: 16

                Rectangle {
                    implicitWidth: 27
                    implicitHeight: 27
                    radius: 9
                    color: "#315f7896"
                    Text {
                        anchors.centerIn: parent
                        text: "⌘"
                        color: "white"
                        font.pixelSize: 19
                        font.bold: true
                    }
                }

                Text {
                    text: {
                        const app = Hyprland.activeToplevel;
                        return app && app.appId ? app.appId.split(".").pop() : "Finder";
                    }
                    color: tahoe.ink
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    Layout.maximumWidth: 180
                    elide: Text.ElideRight
                }

                Text {
                    text: "File"
                    color: tahoe.softInk
                    font.pixelSize: 12
                    // Decorative until native application menus can be bridged.
                    opacity: 0.5
                }

                Text {
                    text: "Edit"
                    color: tahoe.softInk
                    font.pixelSize: 12
                    opacity: 0.5
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "TAHOE • PREVIEW"
                    color: "#60778ea5"
                    font.pixelSize: 10
                    font.letterSpacing: 2
                    font.bold: true
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: Qt.formatDateTime(clock.date, "ddd MMM d  hh:mm AP")
                    color: tahoe.ink
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }

                Rectangle {
                    implicitWidth: 22
                    implicitHeight: 22
                    radius: 11
                    color: quitArea.containsMouse ? "#ea6874" : "#6b91a2b3"
                    Behavior on color { ColorAnimation { duration: 140 } }
                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        color: "white"
                        font.pixelSize: 16
                    }
                    MouseArea {
                        id: quitArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: Qt.quit() // Exit ONLY this preview, not Hyprland.
                    }
                }
            }
        }
    }

    // One small bottom layer-shell window instead of a full-screen invisible
    // capture region. Avoid blocking clicks outside the Dock during preview.
    PanelWindow {
        id: dock
        anchors { bottom: true }
        margins { bottom: 16 }
        implicitWidth: Math.max(360, dockContent.implicitWidth + 36)
        implicitHeight: 83
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "zephyrus-tahoe-alpha-dock"
        WlrLayershell.layer: WlrLayer.Top

        Rectangle {
            anchors.fill: parent
            radius: 27
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#d9f6fbff" }
                GradientStop { position: 0.54; color: "#b7eaf1fb" }
                GradientStop { position: 1.0; color: "#a0d0dbe8" }
            }
            border.color: "#f5ffffff"
            border.width: 1

            Rectangle {
                x: 18
                y: 2
                width: parent.width - 36
                height: 2
                radius: 1
                color: "#aaffffff"
            }

            Row {
                id: dockContent
                anchors.centerIn: parent
                spacing: 7

                Repeater {
                    model: tahoe.launchers
                    delegate: Item {
                        id: pinnedCell
                        required property var modelData
                        width: 58
                        height: 65
                        property bool over: pinnedHover.hovered
                        scale: over ? 1.14 : 1.0
                        transformOrigin: Item.Bottom
                        Behavior on scale {
                            NumberAnimation { duration: 165; easing.type: Easing.OutCubic }
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            width: 47
                            height: 47
                            radius: 14
                            gradient: Gradient {
                                GradientStop { position: 0; color: "#a6ffffff" }
                                GradientStop { position: 1; color: "#60e7f1fa" }
                            }
                            border.color: "#d9ffffff"

                            IconImage {
                                anchors.centerIn: parent
                                implicitSize: 34
                                source: Quickshell.iconPath(pinnedCell.modelData.icon, "application-x-executable")
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            text: pinnedCell.over ? pinnedCell.modelData.label : "·"
                            color: pinnedCell.over ? tahoe.ink : "#52718da1"
                            font.pixelSize: pinnedCell.over ? 10 : 15
                            font.weight: Font.Medium
                        }

                        HoverHandler { id: pinnedHover }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: tahoe.openLauncher(pinnedCell.modelData)
                        }
                    }
                }

                Rectangle {
                    width: 1
                    height: 45
                    color: "#7292a8bc"
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Real running windows, one entry per toplevel for this alpha.
                // v6's real Dock will group them by app ID and implement the
                // address-specific minimize/restore state machine separately.
                Repeater {
                    model: Hyprland.toplevels
                    delegate: Item {
                        id: runningCell
                        required property var modelData
                        width: 54
                        height: 65
                        property bool over: runningHover.hovered
                        scale: over ? 1.13 : 1.0
                        transformOrigin: Item.Bottom
                        Behavior on scale {
                            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            width: 43
                            height: 43
                            radius: 13
                            color: "#78ffffff"
                            border.color: runningCell.modelData.activated
                                ? tahoe.accent : "#b8ffffff"
                            border.width: runningCell.modelData.activated ? 2 : 1

                            IconImage {
                                anchors.centerIn: parent
                                implicitSize: 33
                                source: Quickshell.iconPath(
                                    runningCell.modelData.appId || "application-x-executable",
                                    "application-x-executable"
                                )
                            }
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            width: 5
                            height: 5
                            radius: 3
                            color: runningCell.modelData.activated ? tahoe.accent : tahoe.softInk
                        }

                        HoverHandler { id: runningHover }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: runningCell.modelData.activate()
                        }
                    }
                }
            }
        }
    }
}
