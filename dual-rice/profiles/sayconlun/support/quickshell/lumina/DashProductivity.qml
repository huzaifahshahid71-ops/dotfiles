// Dashboard · Productivity: a task list and a focus timer, picked from a side
// menu. Modelled on Nisfere's Productivity tab (TasksService, FocusService).
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: page

    property var dash
    property string section: "tasks"
    property string filter: "active"

    spacing: 16

    ColumnLayout {
        Layout.preferredWidth: 180
        Layout.alignment: Qt.AlignTop
        spacing: 6

        Repeater {
            model: [
                { id: "tasks", label: "Tasks", icon: "list-checks" },
                { id: "focus", label: "Focus", icon: "timer" }
            ]

            Rectangle {
                required property var modelData
                readonly property bool selected: page.section === modelData.id

                Layout.fillWidth: true
                implicitHeight: 46
                radius: 15
                color: selected ? Theme.alpha(Theme.primary, 0.16)
                     : menuArea.containsMouse ? Theme.alpha(Theme.on_surface, 0.06) : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    spacing: 12

                    LucideIcon {
                        icon: modelData.icon
                        size: 18
                        color: selected ? Theme.primary : Theme.on_surface
                    }

                    Text {
                        Layout.fillWidth: true
                        text: modelData.label
                        color: Theme.on_surface
                        font.family: Theme.font
                        font.pixelSize: 14
                        font.weight: selected ? Font.Bold : Font.Medium
                    }
                }

                MouseArea {
                    id: menuArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: page.section = modelData.id
                }
            }
        }
    }

    Rectangle {
        Layout.fillHeight: true
        implicitWidth: 1
        color: Theme.alpha(Theme.on_surface, 0.1)
    }

    Loader {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        sourceComponent: page.section === "tasks" ? tasksView : focusView
    }

    // -------------------------------------------------------------- tasks --
    Component {
        id: tasksView

        ColumnLayout {
            spacing: 12

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 50
                radius: 16
                color: Theme.surface_container_lowest
                border.width: 1
                border.color: input.activeFocus ? Theme.primary : Theme.outline_variant

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 8
                    spacing: 8

                    TextInput {
                        id: input
                        Layout.fillWidth: true
                        color: Theme.on_surface
                        font.family: Theme.font
                        font.pixelSize: 15
                        clip: true
                        Keys.onReturnPressed: add()
                        Keys.onEnterPressed: add()

                        function add() {
                            TasksService.add(text)
                            text = ""
                            page.filter = "active"
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !input.text
                            text: "Add a task…"
                            color: Theme.on_surface_variant
                            font: input.font
                        }
                    }

                    DashButton {
                        icon: "arrow-up"
                        accent: true
                        size: 36
                        iconSize: 17
                        active: input.text.trim() !== ""
                        onClicked: input.add()
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: [
                        { id: "active", label: `Active (${TasksService.activeCount})` },
                        { id: "done", label: `Completed (${TasksService.doneCount})` }
                    ]

                    Rectangle {
                        required property var modelData
                        readonly property bool selected: page.filter === modelData.id

                        implicitWidth: filterText.implicitWidth + 28
                        implicitHeight: 32
                        radius: 16
                        color: selected ? Theme.primary
                             : filterArea.containsMouse ? Theme.alpha(Theme.on_surface, 0.07) : Theme.surface_container_high

                        Text {
                            id: filterText
                            anchors.centerIn: parent
                            text: modelData.label
                            color: selected ? Theme.on_primary : Theme.on_surface
                            font.family: Theme.font
                            font.pixelSize: 13
                            font.weight: selected ? Font.Bold : Font.Normal
                        }

                        MouseArea {
                            id: filterArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.filter = modelData.id
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                DashButton {
                    visible: page.filter === "done" && TasksService.doneCount > 0
                    icon: "trash-2"
                    size: 34
                    iconSize: 16
                    onClicked: TasksService.clearDone()
                }
            }

            Text {
                Layout.topMargin: 24
                Layout.bottomMargin: 24
                Layout.alignment: Qt.AlignHCenter
                visible: shown.length === 0
                text: page.filter === "active" ? "Nothing to do - add a task above" : "No completed tasks yet"
                color: Theme.on_surface_variant
                font.family: Theme.font
                font.pixelSize: 14

                readonly property var shown: TasksService.tasks.filter(t => page.filter === "done" ? t.done : !t.done)
            }

            Flickable {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(taskList.implicitHeight, 380)
                contentHeight: taskList.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: taskList
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: TasksService.tasks.filter(t => page.filter === "done" ? t.done : !t.done)

                        Rectangle {
                            required property var modelData

                            Layout.fillWidth: true
                            implicitHeight: 48
                            radius: 14
                            color: rowArea.containsMouse ? Theme.alpha(Theme.on_surface, 0.06) : Theme.alpha(Theme.surface_container_high, 0.7)

                            MouseArea {
                                id: rowArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: TasksService.toggle(modelData.id)
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 8
                                spacing: 12

                                Rectangle {
                                    implicitWidth: 22
                                    implicitHeight: 22
                                    radius: 7
                                    color: modelData.done ? Theme.primary : "transparent"
                                    border.width: 2
                                    border.color: Theme.primary

                                    LucideIcon {
                                        anchors.centerIn: parent
                                        visible: modelData.done
                                        icon: "check"
                                        size: 14
                                        color: Theme.on_primary
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.text
                                    elide: Text.ElideRight
                                    color: Theme.on_surface
                                    opacity: modelData.done ? 0.45 : 1
                                    font.family: Theme.font
                                    font.pixelSize: 14
                                    font.strikeout: modelData.done
                                }

                                DashButton {
                                    icon: "x"
                                    size: 30
                                    iconSize: 14
                                    onClicked: TasksService.remove(modelData.id)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // -------------------------------------------------------------- focus --
    Component {
        id: focusView

        ColumnLayout {
            spacing: 14

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8

                Repeater {
                    model: [
                        { id: "focus", label: "Focus", icon: "brain" },
                        { id: "break", label: "Break", icon: "coffee" }
                    ]

                    Rectangle {
                        required property var modelData
                        readonly property bool selected: FocusService.mode === modelData.id

                        implicitWidth: modeRow.implicitWidth + 30
                        implicitHeight: 38
                        radius: 19
                        color: selected ? Theme.primary
                             : modeArea.containsMouse ? Theme.alpha(Theme.on_surface, 0.07) : Theme.surface_container_high

                        Row {
                            id: modeRow
                            anchors.centerIn: parent
                            spacing: 8

                            LucideIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                icon: modelData.icon
                                size: 16
                                color: selected ? Theme.on_primary : Theme.on_surface
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.label
                                color: selected ? Theme.on_primary : Theme.on_surface
                                font.family: Theme.font
                                font.pixelSize: 14
                                font.weight: selected ? Font.Bold : Font.Medium
                            }
                        }

                        MouseArea {
                            id: modeArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: FocusService.setMode(modelData.id)
                        }
                    }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 28

                DashButton {
                    icon: "minus"
                    size: 44
                    active: !FocusService.running
                    onClicked: FocusService.adjust(-1)
                }

                DashGauge {
                    implicitWidth: 240
                    implicitHeight: 240
                    thickness: 14
                    valueSize: 44
                    value: FocusService.progress
                    valueText: FocusService.clock
                    label: FocusService.mode === "focus" ? "Focus" : "Break"
                    accent: FocusService.mode === "focus" ? Theme.primary : Theme.tertiary
                }

                DashButton {
                    icon: "plus"
                    size: 44
                    active: !FocusService.running
                    onClicked: FocusService.adjust(1)
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: FocusService.minutes + " min session"
                color: Theme.on_surface_variant
                font.family: Theme.font
                font.pixelSize: 13
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: 6
                spacing: 18

                DashButton {
                    icon: "rotate-ccw"
                    size: 46
                    onClicked: FocusService.reset()
                }

                DashButton {
                    icon: FocusService.running ? "pause" : "play"
                    accent: true
                    size: 64
                    iconSize: 26
                    onClicked: FocusService.toggle()
                }
            }
        }
    }
}
