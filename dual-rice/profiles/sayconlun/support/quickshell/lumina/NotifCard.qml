// One notification, shared by the popup and the notification centre. Layout
// from Nisfere's NotificationContent: a picture or app-icon badge, app name
// and time, summary, body, and the sender's action buttons. Clicking the
// card itself runs the sender's "default" action, when it has one.
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets

Rectangle {
    id: root

    property var entry: null
    property bool compact: false          // the centre's list: shorter bodies
    property real progress: -1            // popup countdown; below 0 hides it

    signal dismissed
    signal actionInvoked

    readonly property bool critical: entry ? entry.critical : false
    readonly property bool hasImage: entry ? entry.image !== "" : false
    readonly property var actions: entry && entry.actions ? entry.actions : []
    readonly property var buttons: actions.filter(a => a.identifier !== "default" && a.text)
    readonly property var defaultAction: actions.find(a => a.identifier === "default") || null

    implicitHeight: col.implicitHeight + 28
    radius: 22
    color: Theme.alpha(Theme.surface_container, 0.97)
    border.width: 1
    border.color: critical ? Theme.alpha(Theme.error, 0.7) : Theme.alpha(Theme.outline_variant, 0.7)

    MouseArea {
        anchors.fill: parent
        cursorShape: root.defaultAction ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (root.defaultAction) {
                root.defaultAction.invoke()
                root.actionInvoked()
            }
        }
    }

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14
        spacing: 10

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 3
            visible: root.progress >= 0

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * Math.max(0, root.progress)
                radius: 1.5
                color: Theme.primary
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 13

            ClippingRectangle {
                readonly property int size: root.hasImage ? (root.compact ? 56 : 72) : 40

                Layout.alignment: Qt.AlignTop
                implicitWidth: size
                implicitHeight: size
                radius: 14
                color: Theme.surface_container_highest

                Image {
                    id: badge
                    anchors.fill: parent
                    anchors.margins: root.hasImage ? 0 : 8
                    source: root.entry ? NotifService.iconSource(root.entry) : ""
                    fillMode: root.hasImage ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                    asynchronous: true
                    sourceSize.width: 144
                    sourceSize.height: 144
                    visible: status === Image.Ready
                }

                LucideIcon {
                    anchors.centerIn: parent
                    visible: badge.status !== Image.Ready
                    icon: root.critical ? "triangle-alert" : "bell"
                    size: 20
                    color: root.critical ? Theme.error : Theme.primary
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: 3

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        Layout.fillWidth: true
                        text: root.entry ? root.entry.app.toUpperCase() : ""
                        elide: Text.ElideRight
                        color: root.critical ? Theme.error : Theme.primary
                        font.family: Theme.font
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        font.letterSpacing: 0.8
                    }

                    Text {
                        text: root.entry ? Qt.formatTime(new Date(root.entry.time), "h:mm AP") : ""
                        color: Theme.on_surface_variant
                        font.family: Theme.font
                        font.pixelSize: 11
                    }

                    Rectangle {
                        implicitWidth: 24
                        implicitHeight: 24
                        radius: 12
                        color: closeArea.containsMouse ? Theme.error : "transparent"

                        LucideIcon {
                            anchors.centerIn: parent
                            icon: "x"
                            size: 14
                            color: closeArea.containsMouse ? Theme.on_error : Theme.on_surface
                            opacity: closeArea.containsMouse ? 1 : 0.6
                        }

                        MouseArea {
                            id: closeArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.dismissed()
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: root.entry ? root.entry.summary : ""
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    color: Theme.on_surface
                    font.family: Theme.font
                    font.pixelSize: 15
                    font.weight: Font.Bold
                }

                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.entry ? root.entry.body : ""
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    maximumLineCount: root.compact ? 2 : 4
                    elide: Text.ElideRight
                    color: Theme.on_surface
                    opacity: 0.8
                    font.family: Theme.font
                    font.pixelSize: 13
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: root.buttons.length > 0
            spacing: 8

            Repeater {
                model: root.buttons

                Rectangle {
                    required property var modelData

                    Layout.fillWidth: true
                    implicitHeight: 34
                    radius: 12
                    border.width: 1
                    border.color: Theme.alpha(Theme.outline_variant, 0.9)
                    color: actionArea.containsMouse ? Theme.primary : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: modelData.text
                        color: actionArea.containsMouse ? Theme.on_primary : Theme.on_surface
                        font.family: Theme.font
                        font.pixelSize: 12
                        font.weight: Font.Bold
                    }

                    MouseArea {
                        id: actionArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            modelData.invoke()
                            root.actionInvoked()
                        }
                    }
                }
            }
        }
    }
}
