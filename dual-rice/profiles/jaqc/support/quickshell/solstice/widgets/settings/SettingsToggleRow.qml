import QtQuick
import "../../components/common"
import "../../components/theme"

Item {
    id: root

    required property string title
    required property string detail
    required property bool checked
    property bool showSeparator: false

    signal toggleRequested

    height: 96

    Column {
        anchors {
            left: parent.left
            right: toggle.left
            verticalCenter: parent.verticalCenter
            leftMargin: 20
            rightMargin: 20
        }
        spacing: 3

        Text {
            width: parent.width
            text: root.title
            color: Theme.primaryTextColor
            font.family: Typography.bodyFontFamily
            font.pixelSize: 16
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: root.detail
            color: Theme.mutedTextColor
            font.family: Typography.bodyFontFamily
            font.pixelSize: 12
            elide: Text.ElideRight
        }
    }

    UtilitySwitch {
        id: toggle

        anchors {
            right: parent.right
            rightMargin: 20
            verticalCenter: parent.verticalCenter
        }
        checked: root.checked
        scale: 1.05
        onToggled: root.toggleRequested()
    }

    Rectangle {
        visible: root.showSeparator
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            leftMargin: 20
            rightMargin: 20
        }
        height: 1
        color: Theme.surfaceBorderColor
        opacity: 0.65
    }
}
