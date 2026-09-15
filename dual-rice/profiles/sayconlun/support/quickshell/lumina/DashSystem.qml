// Dashboard · System: CPU, memory, GPU and VRAM gauges, temperatures,
// storage and the machine's details (SystemStats.qml).
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: page

    property var dash

    spacing: 12

    function tempColour(t, hot) {
        return t >= hot ? Theme.error : Theme.primary
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        DashCard {
            Layout.fillWidth: true
            Layout.preferredHeight: 220

            DashGauge {
                anchors.centerIn: parent
                width: 170
                height: 170
                value: SystemStats.cpu
                label: "CPU"
                sub: SystemStats.cpuTemp ? Math.round(SystemStats.cpuTemp) + "°C" : ""
            }
        }

        DashCard {
            Layout.fillWidth: true
            Layout.preferredHeight: 220

            DashGauge {
                anchors.centerIn: parent
                width: 170
                height: 170
                value: SystemStats.mem
                label: "Memory"
                sub: SystemStats.memTotal ? `${SystemStats.memUsed.toFixed(1)} / ${Math.round(SystemStats.memTotal)} GiB` : ""
            }
        }

        DashCard {
            Layout.fillWidth: true
            Layout.preferredHeight: 220

            DashGauge {
                anchors.centerIn: parent
                width: 170
                height: 170
                value: SystemStats.gpu
                label: "GPU"
                sub: SystemStats.gpuAsleep ? "asleep" : SystemStats.gpuTemp ? Math.round(SystemStats.gpuTemp) + "°C" : ""
            }
        }

        DashCard {
            Layout.fillWidth: true
            Layout.preferredHeight: 220

            DashGauge {
                anchors.centerIn: parent
                width: 170
                height: 170
                value: SystemStats.vramTotal ? SystemStats.vramUsed / SystemStats.vramTotal : 0
                label: "VRAM"
                sub: SystemStats.vramTotal ? `${SystemStats.vramUsed.toFixed(1)} / ${Math.round(SystemStats.vramTotal)} GiB` : ""
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        DashCard {
            Layout.fillWidth: true
            Layout.preferredHeight: 190

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 12

                Text {
                    text: "Temperatures"
                    color: Theme.on_surface_variant
                    font.family: Theme.font
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }

                Repeater {
                    model: [
                        { label: "CPU", value: SystemStats.cpuTemp, hot: 85 },
                        { label: "GPU edge", value: SystemStats.gpuTemp, hot: 90 },
                        { label: "GPU junction", value: SystemStats.gpuJunction, hot: 100 }
                    ]

                    RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 12

                        LucideIcon {
                            icon: "thermometer"
                            size: 16
                            color: page.tempColour(modelData.value, modelData.hot)
                        }

                        Text {
                            Layout.preferredWidth: 110
                            text: modelData.label
                            color: Theme.on_surface
                            font.family: Theme.font
                            font.pixelSize: 13
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 6
                            radius: 3
                            color: Theme.alpha(Theme.on_surface, 0.1)

                            Rectangle {
                                width: parent.width * Math.min(1, modelData.value / 110)
                                height: parent.height
                                radius: 3
                                color: page.tempColour(modelData.value, modelData.hot)
                                Behavior on width {
                                    NumberAnimation { duration: 400 }
                                }
                            }
                        }

                        Text {
                            Layout.preferredWidth: 46
                            horizontalAlignment: Text.AlignRight
                            text: modelData.value ? Math.round(modelData.value) + "°C" : "--"
                            color: Theme.on_surface
                            font.family: Theme.font
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }
        }

        DashCard {
            Layout.fillWidth: true
            Layout.preferredHeight: 190

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 12

                Text {
                    text: "Storage"
                    color: Theme.on_surface_variant
                    font.family: Theme.font
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }

                Repeater {
                    model: SystemStats.disks

                    ColumnLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true

                            LucideIcon {
                                icon: "hard-drive"
                                size: 16
                                color: Theme.primary
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.mount
                                color: Theme.on_surface
                                font.family: Theme.font
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                            }

                            Text {
                                text: `${SystemStats.gib(modelData.used)} of ${SystemStats.gib(modelData.size)}`
                                color: Theme.on_surface_variant
                                font.family: Theme.font
                                font.pixelSize: 12
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 8
                            radius: 4
                            color: Theme.alpha(Theme.on_surface, 0.1)

                            Rectangle {
                                width: parent.width * (modelData.size ? modelData.used / modelData.size : 0)
                                height: parent.height
                                radius: 4
                                color: modelData.used / modelData.size > 0.9 ? Theme.error : Theme.primary
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }
    }

    DashCard {
        Layout.fillWidth: true
        Layout.preferredHeight: 64

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            spacing: 26

            Repeater {
                model: [
                    { icon: "cpu", value: SystemStats.cpuName },
                    { icon: "monitor", value: SystemStats.os },
                    { icon: "layout-dashboard", value: SystemStats.kernel },
                    { icon: "clock", value: "up " + SystemStats.uptimeText }
                ]

                RowLayout {
                    required property var modelData
                    spacing: 8

                    LucideIcon {
                        icon: modelData.icon
                        size: 16
                        color: Theme.primary
                    }

                    Text {
                        text: modelData.value
                        color: Theme.on_surface
                        font.family: Theme.font
                        font.pixelSize: 13
                    }
                }
            }

            Item { Layout.fillWidth: true }
        }
    }
}
