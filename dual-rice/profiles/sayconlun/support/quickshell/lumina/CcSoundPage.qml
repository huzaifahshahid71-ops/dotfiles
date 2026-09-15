// Control centre · Sound: pick the output and input device. Not in Nisfere -
// added because the default output decides where the visualiser listens and
// what the bar's volume shows, and that went wrong once already.
//
// Setting Pipewire.preferredDefault* makes WirePlumber switch the default and
// move the running streams, cava's included.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire

ColumnLayout {
    id: page

    property var cc

    readonly property var nodes: Array.from(Pipewire.nodes.values).filter(n => n.audio && !n.isStream)
    readonly property var outputs: nodes.filter(n => n.isSink)
    readonly property var inputs: nodes.filter(n => !n.isSink)

    spacing: 12

    CcPageHeader {
        Layout.fillWidth: true
        title: "Sound"
        onBack: page.cc.page = "main"
    }

    Repeater {
        model: [
            { label: "Output", list: page.outputs, sink: true },
            { label: "Input", list: page.inputs, sink: false }
        ]

        ColumnLayout {
            id: section
            required property var modelData

            Layout.fillWidth: true
            spacing: 6

            Text {
                Layout.leftMargin: 4
                Layout.topMargin: 2
                text: section.modelData.label
                color: Theme.on_surface_variant
                font.family: Theme.font
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }

            Repeater {
                model: section.modelData.list

                CcRow {
                    required property var modelData
                    readonly property bool isDefault: modelData === (section.modelData.sink ? Pipewire.defaultAudioSink : Pipewire.defaultAudioSource)
                    readonly property string label: page.cc.nodeName(modelData)

                    Layout.fillWidth: true
                    icon: !section.modelData.sink ? "mic"
                        : /usb|headset|headphone/i.test(label + modelData.name) ? "headphones"
                        : /hdmi|displayport/i.test(label + modelData.name) ? "speaker"
                        : "volume-2"
                    title: label
                    subtitle: isDefault ? "In use" : ""
                    highlighted: isDefault
                    actionIcon: isDefault ? "" : "check"
                    onClicked: pick()
                    onActionClicked: pick()

                    function pick() {
                        if (section.modelData.sink)
                            Pipewire.preferredDefaultAudioSink = modelData
                        else
                            Pipewire.preferredDefaultAudioSource = modelData
                    }
                }
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 40
        radius: 14
        color: moreArea.containsMouse ? Theme.alpha(Theme.on_surface, 0.08) : Theme.surface_container_high

        Text {
            anchors.centerIn: parent
            text: "More sound settings"
            color: Theme.on_surface
            font.family: Theme.font
            font.pixelSize: 13
        }

        MouseArea {
            id: moreArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                page.cc.close()
                Quickshell.execDetached(["pavucontrol"])
            }
        }
    }
}
