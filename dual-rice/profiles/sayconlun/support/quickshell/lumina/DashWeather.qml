// Dashboard · Weather: now, feels-like / humidity / wind, and the 7-day
// forecast. Modelled on Nisfere's Weather tab. Location and units: see
// WeatherService.qml.
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: page

    property var dash

    spacing: 12

    // Plain anchors, not a RowLayout: nested layouts with fill-height cards
    // collapsed this row and stacked the small cards over the big one.
    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 220

        DashCard {
            anchors.left: parent.left
            anchors.right: details.left
            anchors.rightMargin: 12
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 30
                anchors.rightMargin: 22
                spacing: 26

                LucideIcon {
                    icon: WeatherService.icon(WeatherService.code, WeatherService.isDay)
                    size: 96
                    color: Theme.primary
                }

                ColumnLayout {
                    spacing: 2

                    Text {
                        text: WeatherService.ready ? Math.round(WeatherService.temperature) + "°" : "--°"
                        color: Theme.on_surface
                        font.family: Theme.font
                        font.pixelSize: 64
                        font.weight: Font.Bold
                    }

                    Text {
                        text: WeatherService.ready ? WeatherService.describe(WeatherService.code)
                            : WeatherService.error || "Fetching weather…"
                        color: Theme.on_surface
                        font.family: Theme.font
                        font.pixelSize: 20
                    }

                    RowLayout {
                        spacing: 6
                        visible: WeatherService.city !== ""

                        LucideIcon {
                            icon: "map-pin"
                            size: 14
                            color: Theme.on_surface_variant
                        }

                        Text {
                            text: WeatherService.city
                            color: Theme.on_surface_variant
                            font.family: Theme.font
                            font.pixelSize: 14
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                ColumnLayout {
                    Layout.alignment: Qt.AlignTop
                    Layout.topMargin: 18
                    spacing: 6

                    DashButton {
                        Layout.alignment: Qt.AlignRight
                        icon: "refresh-cw"
                        size: 36
                        iconSize: 16
                        active: !WeatherService.loading
                        onClicked: WeatherService.update()
                    }

                    Text {
                        Layout.alignment: Qt.AlignRight
                        visible: WeatherService.ready
                        text: "Updated " + Qt.formatTime(WeatherService.updated, "h:mm AP")
                        color: Theme.on_surface_variant
                        font.family: Theme.font
                        font.pixelSize: 11
                    }
                }
            }
        }

        Column {
            id: details
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 250
            spacing: 10

            Repeater {
                model: [
                    { icon: "flame", label: "Feels like", value: WeatherService.ready ? Math.round(WeatherService.feelsLike) + "°C" : "--" },
                    { icon: "droplets", label: "Humidity", value: WeatherService.ready ? WeatherService.humidity + "%" : "--" },
                    { icon: "wind", label: "Wind", value: WeatherService.ready ? Math.round(WeatherService.wind) + " mph" : "--" }
                ]

                DashCard {
                    required property var modelData
                    width: details.width
                    height: (details.height - 2 * details.spacing) / 3

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 18
                        anchors.rightMargin: 18
                        spacing: 14

                        LucideIcon {
                            icon: modelData.icon
                            size: 22
                            color: Theme.primary
                        }

                        Text {
                            Layout.fillWidth: true
                            text: modelData.label
                            color: Theme.on_surface_variant
                            font.family: Theme.font
                            font.pixelSize: 13
                        }

                        Text {
                            text: modelData.value
                            color: Theme.on_surface
                            font.family: Theme.font
                            font.pixelSize: 18
                            font.weight: Font.Bold
                        }
                    }
                }
            }
        }
    }

    DashCard {
        Layout.fillWidth: true
        Layout.preferredHeight: 200

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 8

            Text {
                text: "7-day forecast"
                color: Theme.on_surface_variant
                font.family: Theme.font
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }

            // Fixed sevenths, not a RowLayout: fill-width columns bunched up on the left.
            Item {
                id: days
                Layout.fillWidth: true
                Layout.fillHeight: true

                Repeater {
                    model: WeatherService.daily

                    Column {
                        required property var modelData
                        required property int index

                        x: index * days.width / 7
                        width: days.width / 7
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: index === 0 ? "Today" : Qt.formatDate(new Date(modelData.date + "T12:00:00"), "ddd")
                            color: index === 0 ? Theme.primary : Theme.on_surface
                            font.family: Theme.font
                            font.pixelSize: 14
                            font.weight: Font.Bold
                        }

                        LucideIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            icon: WeatherService.icon(modelData.code, true)
                            size: 36
                            color: Theme.primary
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Math.round(modelData.max) + "°"
                            color: Theme.on_surface
                            font.family: Theme.font
                            font.pixelSize: 17
                            font.weight: Font.Bold
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Math.round(modelData.min) + "°"
                            color: Theme.on_surface
                            opacity: 0.55
                            font.family: Theme.font
                            font.pixelSize: 14
                        }
                    }
                }
            }
        }
    }
}
