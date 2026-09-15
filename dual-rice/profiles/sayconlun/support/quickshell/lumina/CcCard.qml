// A control-centre tile: icon disc, title, subtitle and an optional chevron
// that opens a detail page. Ported from Nisfere's ControlButton + GlassCard.
//
// The body and the chevron are separate click targets - tapping the body is
// the quick action (e.g. Wi-Fi on/off), the chevron opens the page.
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool active: false
    property bool hasMore: false

    signal clicked
    signal moreClicked

    implicitHeight: 78

    // Glass: a translucent fill with a faint wash toward the accent.
    Rectangle {
        anchors.fill: parent
        radius: 20
        color: Theme.alpha(Theme.surface_container_high, 0.85)
        border.width: 1
        border.color: Theme.alpha(Theme.outline_variant, 0.45)
    }

    Rectangle {
        anchors.fill: parent
        radius: 20
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.alpha(Theme.on_surface, 0.04) }
            GradientStop { position: 0.55; color: "transparent" }
            GradientStop { position: 1.0; color: Theme.alpha(Theme.primary, 0.08) }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 20
        color: root.active ? Theme.alpha(Theme.primary, 0.08)
             : body.containsMouse ? Theme.alpha(Theme.on_surface, 0.05)
             : "transparent"
        Behavior on color {
            ColorAnimation { duration: 150 }
        }
    }

    MouseArea {
        id: body
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 10
        spacing: 12

        Rectangle {
            implicitWidth: 44
            implicitHeight: 44
            radius: 22
            color: root.active ? Theme.primary : Theme.surface_container_highest
            border.width: root.active ? 0 : 1
            border.color: Theme.alpha(Theme.outline_variant, 0.8)
            Behavior on color {
                ColorAnimation { duration: 150 }
            }

            LucideIcon {
                anchors.centerIn: parent
                icon: root.icon
                size: 20
                color: root.active ? Theme.on_primary : Theme.on_surface
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: root.title
                elide: Text.ElideRight
                color: Theme.on_surface
                font.family: Theme.font
                font.pixelSize: 15
                font.weight: Font.Bold
            }

            Text {
                Layout.fillWidth: true
                text: root.subtitle
                elide: Text.ElideRight
                color: root.active ? Theme.primary : Theme.on_surface_variant
                opacity: root.active ? 0.95 : 0.75
                font.family: Theme.font
                font.pixelSize: 12
            }
        }

        Rectangle {
            visible: root.hasMore
            implicitWidth: 32
            implicitHeight: 32
            radius: 10
            color: more.containsMouse ? Theme.alpha(Theme.primary, 0.18) : "transparent"

            LucideIcon {
                anchors.centerIn: parent
                icon: "chevron-right"
                size: 18
                opacity: 0.8
            }

            MouseArea {
                id: more
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.moreClicked()
            }
        }
    }
}
