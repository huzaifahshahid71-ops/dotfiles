// Config created by Keyitdev https://github.com/Keyitdev/sddm-astronaut-theme
import QtQuick 2.15
import QtQuick.Controls 2.15

Column {
    id: clock
    width: parent.width / 2
    spacing: 4

    Image {
        id: headerLogo
        anchors.horizontalCenter: parent.horizontalCenter
        source: "../Backgrounds/frieren-logo.png"
        fillMode: Image.PreserveAspectFit
        width: Math.min(parent.width * 0.95, 520)
    }

    Label {
        id: timeLabel
        anchors.horizontalCenter: parent.horizontalCenter
        font.pointSize: root.font.pointSize * 7
        font.family: "Cinzel"
        font.weight: Font.DemiBold
        font.letterSpacing: 4
        opacity: 0.65
        color: config.TimeTextColor
        renderType: Text.QtRendering
        function updateTime() {
            text = new Date().toLocaleTimeString(Qt.locale(config.Locale), config.HourFormat == "long" ? Locale.LongFormat : config.HourFormat !== "" ? config.HourFormat : Locale.ShortFormat)
        }
    }

    Label {
        id: dateLabel
        anchors.horizontalCenter: parent.horizontalCenter
        color: config.DateTextColor
        font.pointSize: root.font.pointSize * 1.7
        font.family: "Cinzel"
        font.letterSpacing: 2
        opacity: 0.85
        renderType: Text.QtRendering
        function updateTime() {
            text = new Date().toLocaleDateString(Qt.locale(config.Locale), config.DateFormat == "short" ? Locale.ShortFormat : config.DateFormat !== "" ? config.DateFormat : Locale.LongFormat)
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            dateLabel.updateTime()
            timeLabel.updateTime()
        }
    }

    Component.onCompleted: {
        dateLabel.updateTime()
        timeLabel.updateTime()
    }
}
