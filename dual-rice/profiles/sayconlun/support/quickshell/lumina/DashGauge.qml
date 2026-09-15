// A 270° arc gauge with a value and label in the middle.
import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property real value: 0                  // 0 - 1
    property string valueText: Math.round(shown * 100) + "%"
    property string label: ""
    property string sub: ""
    property color accent: Theme.primary
    property int thickness: 11
    property int valueSize: 28

    property real shown: Math.max(0, Math.min(1, value))
    Behavior on shown {
        NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
    }

    implicitWidth: 160
    implicitHeight: 160

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: Theme.alpha(Theme.on_surface, 0.1)
            strokeWidth: root.thickness
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: Math.min(root.width, root.height) / 2 - root.thickness
                radiusY: Math.min(root.width, root.height) / 2 - root.thickness
                startAngle: 135
                sweepAngle: 270
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.accent
            strokeWidth: root.thickness
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: Math.min(root.width, root.height) / 2 - root.thickness
                radiusY: Math.min(root.width, root.height) / 2 - root.thickness
                startAngle: 135
                sweepAngle: 270 * root.shown
            }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 2

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.valueText
            color: Theme.on_surface
            font.family: Theme.font
            font.pixelSize: root.valueSize
            font.weight: Font.Bold
            font.features: { "tnum": 1 }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: text !== ""
            text: root.label
            color: Theme.on_surface_variant
            font.family: Theme.font
            font.pixelSize: 12
            font.weight: Font.DemiBold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 1
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: text !== ""
            text: root.sub
            color: Theme.on_surface_variant
            opacity: 0.8
            font.family: Theme.font
            font.pixelSize: 11
        }
    }
}
