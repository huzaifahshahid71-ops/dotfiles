// Dashboard · Overview: clock and month calendar on the left; weather,
// the playing track and a few system facts on the right.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

RowLayout {
    id: page

    property var dash
    property date now: new Date()
    property int viewMonth: now.getMonth()
    property int viewYear: now.getFullYear()

    spacing: 12

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: page.now = new Date()
    }

    function shiftMonth(d) {
        let m = viewMonth + d, y = viewYear
        if (m < 0) { m = 11; y-- }
        if (m > 11) { m = 0; y++ }
        viewMonth = m
        viewYear = y
    }

    // ------------------------------------------------------ clock + calendar --
    DashCard {
        Layout.preferredWidth: 400
        Layout.preferredHeight: 470

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 22
            spacing: 6

            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8

                Text {
                    id: bigTime
                    text: Qt.formatTime(page.now, "h:mm")
                    color: Theme.primary
                    font.family: Theme.font
                    font.pixelSize: 64
                    font.weight: Font.Bold
                    font.features: { "tnum": 1 }
                }

                Text {
                    anchors.baseline: bigTime.baseline
                    text: Qt.formatTime(page.now, "AP")
                    color: Theme.primary
                    opacity: 0.7
                    font.family: Theme.font
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatDate(page.now, "dddd, d MMMM")
                color: Theme.on_surface
                opacity: 0.65
                font.family: Theme.font
                font.pixelSize: 16
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 8
                Layout.bottomMargin: 4
                implicitHeight: 1
                color: Theme.alpha(Theme.on_surface, 0.1)
            }

            RowLayout {
                Layout.fillWidth: true

                DashButton {
                    icon: "chevron-left"
                    size: 30
                    iconSize: 16
                    onClicked: page.shiftMonth(-1)
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.locale().standaloneMonthName(page.viewMonth) + " " + page.viewYear
                    color: Theme.on_surface
                    font.family: Theme.font
                    font.pixelSize: 15
                    font.weight: Font.Bold
                }

                DashButton {
                    icon: "chevron-right"
                    size: 30
                    iconSize: 16
                    onClicked: page.shiftMonth(1)
                }
            }

            DayOfWeekRow {
                Layout.fillWidth: true
                locale: grid.locale

                delegate: Text {
                    required property string shortName
                    text: shortName
                    horizontalAlignment: Text.AlignHCenter
                    color: Theme.on_surface
                    opacity: 0.45
                    font.family: Theme.font
                    font.pixelSize: 12
                    font.weight: Font.Bold
                }
            }

            MonthGrid {
                id: grid
                Layout.fillWidth: true
                Layout.fillHeight: true
                month: page.viewMonth
                year: page.viewYear
                locale: Qt.locale("en_GB")           // weeks start on Monday

                delegate: Item {
                    required property var model

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height) * 0.82
                        height: width
                        radius: width / 2
                        color: model.today ? Theme.primary : "transparent"
                    }

                    Text {
                        anchors.centerIn: parent
                        text: model.day
                        color: model.today ? Theme.on_primary : Theme.on_surface
                        opacity: model.month === grid.month ? 1 : 0.3
                        font.family: Theme.font
                        font.pixelSize: 13
                        font.weight: model.today ? Font.Bold : Font.Normal
                    }
                }
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 470
        spacing: 12

        // ------------------------------------------------------------ weather --
        DashCard {
            Layout.fillWidth: true
            Layout.preferredHeight: 116

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: page.dash.tab = 2
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 22
                anchors.rightMargin: 22
                spacing: 18

                LucideIcon {
                    icon: WeatherService.icon(WeatherService.code, WeatherService.isDay)
                    size: 48
                    color: Theme.primary
                }

                ColumnLayout {
                    spacing: 0

                    Text {
                        text: WeatherService.ready ? Math.round(WeatherService.temperature) + "°C" : "--°C"
                        color: Theme.on_surface
                        font.family: Theme.font
                        font.pixelSize: 30
                        font.weight: Font.Bold
                    }

                    Text {
                        text: WeatherService.ready ? WeatherService.describe(WeatherService.code)
                            : WeatherService.error || "Fetching weather…"
                        color: Theme.on_surface_variant
                        font.family: Theme.font
                        font.pixelSize: 14
                    }
                }

                Item { Layout.fillWidth: true }

                ColumnLayout {
                    spacing: 2

                    Text {
                        Layout.alignment: Qt.AlignRight
                        text: WeatherService.city
                        color: Theme.on_surface
                        font.family: Theme.font
                        font.pixelSize: 15
                        font.weight: Font.Bold
                    }

                    Text {
                        Layout.alignment: Qt.AlignRight
                        visible: WeatherService.daily.length > 0
                        text: WeatherService.daily.length
                            ? `H ${Math.round(WeatherService.daily[0].max)}° · L ${Math.round(WeatherService.daily[0].min)}°` : ""
                        color: Theme.on_surface_variant
                        font.family: Theme.font
                        font.pixelSize: 13
                    }
                }
            }
        }

        // -------------------------------------------------------------- media --
        DashCard {
            Layout.fillWidth: true
            Layout.fillHeight: true

            RowLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 18

                ClippingRectangle {
                    implicitWidth: 120
                    implicitHeight: 120
                    radius: 18
                    color: Theme.surface_container_highest

                    Image {
                        id: miniArt
                        anchors.fill: parent
                        source: MediaState.art
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: status === Image.Ready
                    }

                    LucideIcon {
                        anchors.centerIn: parent
                        visible: miniArt.status !== Image.Ready
                        icon: "music"
                        size: 38
                        color: Theme.on_surface_variant
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        Layout.fillWidth: true
                        text: MediaState.title
                        elide: Text.ElideRight
                        color: Theme.on_surface
                        font.family: Theme.font
                        font.pixelSize: 17
                        font.weight: Font.Bold
                    }

                    Text {
                        Layout.fillWidth: true
                        text: MediaState.artist
                        elide: Text.ElideRight
                        color: Theme.on_surface_variant
                        font.family: Theme.font
                        font.pixelSize: 13
                    }

                    DashSeek {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 14

                        DashButton {
                            icon: "skip-back"
                            active: MediaState.player !== null
                            onClicked: MediaState.previous()
                        }

                        DashButton {
                            icon: MediaState.playing ? "pause" : "play"
                            accent: true
                            size: 48
                            iconSize: 20
                            active: MediaState.player !== null
                            onClicked: MediaState.toggle()
                        }

                        DashButton {
                            icon: "skip-forward"
                            active: MediaState.player !== null
                            onClicked: MediaState.next()
                        }
                    }
                }
            }
        }

        // ------------------------------------------------------------- system --
        DashCard {
            Layout.fillWidth: true
            Layout.preferredHeight: 116

            GridLayout {
                anchors.fill: parent
                anchors.margins: 18
                columns: 2
                columnSpacing: 18
                rowSpacing: 10

                Repeater {
                    model: [
                        { icon: "user", label: "User", value: Quickshell.env("USER") || "" },
                        { icon: "monitor", label: "OS", value: SystemStats.os },
                        { icon: "layout-dashboard", label: "WM", value: "Hyprland" },
                        { icon: "clock", label: "Uptime", value: SystemStats.uptimeText }
                    ]

                    RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 10

                        LucideIcon {
                            icon: modelData.icon
                            size: 17
                            color: Theme.primary
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                text: modelData.label
                                color: Theme.on_surface_variant
                                font.family: Theme.font
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                font.capitalization: Font.AllUppercase
                                font.letterSpacing: 1
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.value
                                elide: Text.ElideRight
                                color: Theme.on_surface
                                font.family: Theme.font
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                            }
                        }
                    }
                }
            }
        }
    }
}
