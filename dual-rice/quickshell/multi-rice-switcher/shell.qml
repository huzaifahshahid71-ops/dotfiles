import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

ShellRoot {
    PanelWindow {
        id: window

        visible: true
        implicitWidth: 820
        implicitHeight: 540
        color: "transparent"
        surfaceFormat.opaque: false
        focusable: true
        aboveWindows: true
        exclusionMode: ExclusionMode.Ignore

        onClosed: Qt.quit()

        Rectangle {
            id: root
            anchors.fill: parent
            radius: 24
            antialiasing: true
            clip: true
            color: "#101016"
            border.width: 2
            border.color: "#8b5cf6"

            focus: true

            property int page: 0
            property int compositorIndex: 0
            property int riceIndex: 0

            property string activeProfile: "unknown"
            property string activeCompositor: "unknown"
            property int hyprInstalled: 0
            property int niriInstalled: 0
            property var installedProfiles: ({})

            property var hyprRices: []
            property var niriRices: []

            property var visibleRices:
                compositorIndex === 0 ? hyprRices : niriRices

            property var visibleNativeRices:
                visibleRices.filter(item => item.kind !== "revo-shell")

            property var visibleRevoRices:
                visibleRices.filter(item => item.kind === "revo-shell")

            function profileInstalled(id) {
                return installedProfiles[id] === true
            }

            function indexForProfile(id) {
                for (let i = 0; i < visibleRices.length; ++i) {
                    if (visibleRices[i].id === id)
                        return i
                }
                return -1
            }

            function selectLocalProfile(section, localIndex) {
                const list = section === 0
                    ? visibleNativeRices
                    : visibleRevoRices

                if (list.length === 0)
                    return

                const safeIndex = Math.max(
                    0,
                    Math.min(list.length - 1, localIndex)
                )
                const globalIndex =
                    indexForProfile(list[safeIndex].id)

                if (globalIndex >= 0)
                    riceIndex = globalIndex
            }

            function moveRice(horizontal, vertical) {
                if (visibleRices.length === 0)
                    return

                const current = visibleRices[riceIndex]
                if (!current)
                    return

                const section =
                    current.kind === "revo-shell" ? 1 : 0
                const list = section === 0
                    ? visibleNativeRices
                    : visibleRevoRices

                let localIndex = -1
                for (let i = 0; i < list.length; ++i) {
                    if (list[i].id === current.id) {
                        localIndex = i
                        break
                    }
                }

                if (localIndex < 0)
                    return

                const columns = 4
                const column = localIndex % columns

                if (horizontal !== 0) {
                    const candidate = localIndex + horizontal
                    if (candidate >= 0 &&
                        candidate < list.length &&
                        Math.floor(candidate / columns) ===
                        Math.floor(localIndex / columns)) {
                        selectLocalProfile(section, candidate)
                    }
                    return
                }

                if (vertical > 0) {
                    const candidate = localIndex + columns

                    if (candidate < list.length) {
                        selectLocalProfile(section, candidate)
                    } else if (section === 0 &&
                               visibleRevoRices.length > 0) {
                        selectLocalProfile(
                            1,
                            Math.min(
                                column,
                                visibleRevoRices.length - 1
                            )
                        )
                    }
                    return
                }

                if (vertical < 0) {
                    const candidate = localIndex - columns

                    if (candidate >= 0) {
                        selectLocalProfile(section, candidate)
                    } else if (section === 1 &&
                               visibleNativeRices.length > 0) {
                        const lastRow =
                            Math.floor(
                                (visibleNativeRices.length - 1) /
                                columns
                            )
                        let target =
                            lastRow * columns + column

                        while (target >=
                               visibleNativeRices.length &&
                               target >= columns) {
                            target -= columns
                        }

                        selectLocalProfile(0, target)
                    }
                }
            }

            function revealCard(card) {
                if (!card || root.page !== 1)
                    return

                const point = card.mapToItem(
                    riceScroll.contentItem,
                    0,
                    0
                )
                const top = point.y - 10
                const bottom =
                    point.y + card.height + 10

                if (top < riceScroll.contentY)
                    riceScroll.contentY = Math.max(0, top)
                else if (bottom >
                         riceScroll.contentY +
                         riceScroll.height)
                    riceScroll.contentY = Math.min(
                        riceScroll.contentHeight -
                            riceScroll.height,
                        bottom - riceScroll.height
                    )
            }

            function applyStatus(text) {
                const values = {}
                const lines = text.trim().split("\n")

                for (let i = 0; i < lines.length; ++i) {
                    const pos = lines[i].indexOf("=")
                    if (pos <= 0)
                        continue

                    values[lines[i].slice(0, pos)] =
                        lines[i].slice(pos + 1)
                }

                activeCompositor =
                    values.compositor || "unknown"

                activeProfile =
                    values.profile || "unknown"

                hyprInstalled =
                    parseInt(values.hyprland_installed || "0")

                niriInstalled =
                    parseInt(values.niri_installed || "0")

                if (activeCompositor === "niri")
                    compositorIndex = 1
                else if (activeCompositor === "hyprland")
                    compositorIndex = 0
            }

            function applyList(text) {
                const next = {}
                const hypr = []
                const niri = []
                const lines = text.trim().split("\n")

                for (let i = 0; i < lines.length; ++i) {
                    if (lines[i].length === 0)
                        continue

                    const parts = lines[i].split("|")
                    if (parts.length < 6)
                        continue

                    const item = {
                        id: parts[0],
                        name: parts[1],
                        icon: parts[2],
                        compositor: parts[3],
                        kind: parts.length > 6 ? parts[6] : "desktop",
                        shell: parts.length > 7 ? parts[7] : ""
                    }

                    next[item.id] = parts[4] === "true"

                    if (item.compositor === "hyprland")
                        hypr.push(item)
                    else if (item.compositor === "niri")
                        niri.push(item)
                }

                installedProfiles = next
                hyprRices = hypr
                niriRices = niri

                if (riceIndex >= visibleRices.length)
                    riceIndex = Math.max(0, visibleRices.length - 1)
            }

            function openCompositor() {
                page = 1
                riceIndex = 0
            }

            function goBack() {
                if (page === 1) {
                    page = 0
                    riceIndex = 0
                } else {
                    Qt.quit()
                }
            }

            property string actionMessage: ""

            function activateSelection() {
                if (page === 0) {
                    openCompositor()
                    return
                }

                if (visibleRices.length === 0) {
                    actionMessage = "No profiles are available"
                    return
                }

                const profile = visibleRices[riceIndex]
                if (!profile) {
                    actionMessage = "Profile list is still loading"
                    return
                }

                if (!profileInstalled(profile.id)) {
                    actionMessage =
                        profile.name + " is not installed yet"
                    return
                }

                if (profile.id === activeProfile) {
                    actionMessage =
                        profile.name + " is already active"
                    return
                }

                actionMessage =
                    "Switching to " + profile.name + "…"

                switchProc.command = [
                    Quickshell.env("HOME") +
                        "/.local/bin/multi-rice-control",
                    "switch",
                    profile.id
                ]

                switchProc.running = true
            }

            Process {
                id: switchProc

                stdout: StdioCollector {
                    onStreamFinished: {
                        if (text.trim().length > 0)
                            console.log(text.trim())
                    }
                }

                stderr: StdioCollector {
                    onStreamFinished: {
                        if (text.trim().length > 0)
                            root.actionMessage = text.trim()
                    }
                }

                onExited: (exitCode, exitStatus) => {
                    if (exitCode !== 0 &&
                        root.actionMessage.length === 0) {
                        root.actionMessage =
                            "Switch failed • exit " + exitCode
                    }
                }
            }

            Process {
                id: statusProc
                running: true
                command: [
                    Quickshell.env("HOME") +
                        "/.local/bin/multi-rice-control",
                    "status"
                ]

                stdout: StdioCollector {
                    onStreamFinished:
                        root.applyStatus(text)
                }
            }

            Process {
                id: listProc
                running: true
                command: [
                    Quickshell.env("HOME") +
                        "/.local/bin/multi-rice-control",
                    "list"
                ]

                stdout: StdioCollector {
                    onStreamFinished:
                        root.applyList(text)
                }
            }

            Keys.onPressed: event => {
                if (page === 0) {
                    if (event.key === Qt.Key_Left) {
                        compositorIndex = 0
                        event.accepted = true
                    } else if (event.key === Qt.Key_Right) {
                        compositorIndex = 1
                        event.accepted = true
                    } else if (
                        event.key === Qt.Key_Return ||
                        event.key === Qt.Key_Enter
                    ) {
                        openCompositor()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Escape) {
                        Qt.quit()
                        event.accepted = true
                    }
                } else {
                    if (event.key === Qt.Key_Left &&
                        visibleRices.length > 0) {
                        moveRice(-1, 0)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Right &&
                               visibleRices.length > 0) {
                        moveRice(1, 0)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Up &&
                               visibleRices.length > 0) {
                        moveRice(0, -1)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Down &&
                               visibleRices.length > 0) {
                        moveRice(0, 1)
                        event.accepted = true
                    } else if (
                        event.key === Qt.Key_Return ||
                        event.key === Qt.Key_Enter
                    ) {
                        activateSelection()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Escape) {
                        goBack()
                        event.accepted = true
                    }
                }
            }

            Component.onCompleted: forceActiveFocus()

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 30
                spacing: 18

                RowLayout {
                    Layout.fillWidth: true

                    ColumnLayout {
                        spacing: 3

                        Text {
                            text: "HUZAIFAH"
                            color: "#a78bfa"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 14
                            font.bold: true
                        }

                        Text {
                            text: root.page === 0
                                ? "Multi-Rice"
                                : root.compositorIndex === 0
                                    ? "Hyprland Rices"
                                    : "Niri Rices"

                            color: "#f4f4f5"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 29
                            font.bold: true
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        width: 150
                        height: 38
                        radius: 19
                        color: "#1d1d28"

                        Text {
                            anchors.centerIn: parent
                            text: root.page === 0
                                ? "SELECT ENGINE"
                                : root.compositorIndex === 0
                                    ? "HYPRLAND"
                                    : "NIRI"
                            color: "#a1a1aa"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Row {
                        id: compositorPage
                        anchors.centerIn: parent
                        spacing: 28
                        visible: root.page === 0

                        Repeater {
                            model: [
                                {
                                    name: "HYPRLAND",
                                    subtitle: "28 RICES",
                                    detail: "Currently Active"
                                },
                                {
                                    name: "NIRI",
                                    subtitle: "3 RICES",
                                    detail: "Switch Session"
                                }
                            ]

                            delegate: Rectangle {
                                required property int index
                                required property var modelData

                                width: 330
                                height: 250
                                radius: 20
                                antialiasing: true

                                property bool selected:
                                    root.compositorIndex === index

                                color: selected
                                    ? "#202033"
                                    : "#17171f"

                                border.width: selected ? 3 : 1
                                border.color: selected
                                    ? "#a78bfa"
                                    : "#34343f"

                                scale: selected ? 1.035 : 1.0

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: 130
                                    }
                                }

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 14

                                    Text {
                                        anchors.horizontalCenter:
                                            parent.horizontalCenter
                                        text: index === 0 ? "H" : "N"
                                        color: selected
                                            ? "#c4b5fd"
                                            : "#71717a"
                                        font.family:
                                            "JetBrainsMono Nerd Font"
                                        font.pixelSize: 46
                                        font.bold: true
                                    }

                                    Text {
                                        anchors.horizontalCenter:
                                            parent.horizontalCenter
                                        text: modelData.name
                                        color: "#fafafa"
                                        font.family:
                                            "JetBrainsMono Nerd Font"
                                        font.pixelSize: 24
                                        font.bold: true
                                    }

                                    Text {
                                        anchors.horizontalCenter:
                                            parent.horizontalCenter
                                        text: index === 0
                                            ? root.hyprInstalled + " / " + root.hyprRices.length + " INSTALLED"
                                            : root.niriInstalled + " / " + root.niriRices.length + " INSTALLED"
                                        color: "#a78bfa"
                                        font.family:
                                            "JetBrainsMono Nerd Font"
                                        font.pixelSize: 13
                                    }

                                    Text {
                                        anchors.horizontalCenter:
                                            parent.horizontalCenter
                                        text:
                                            root.activeCompositor ===
                                            (index === 0
                                                ? "hyprland"
                                                : "niri")
                                            ? "Currently Active"
                                            : "Switch Session"
                                        color: "#71717a"
                                        font.family:
                                            "JetBrainsMono Nerd Font"
                                        font.pixelSize: 12
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: {
                                        root.compositorIndex = index
                                        root.openCompositor()
                                    }
                                }
                            }
                        }
                    }

                    Flickable {
                        id: riceScroll
                        anchors.fill: parent
                        visible: root.page === 1
                        clip: true
                        contentWidth: width
                        contentHeight: riceContent.height
                        boundsBehavior: Flickable.StopAtBounds

                        Column {
                            id: riceContent
                            width: riceScroll.width
                            spacing: 18

                            GridLayout {
                                width: parent.width
                                columns: 4
                                columnSpacing: 12
                                rowSpacing: 12

                                Repeater {
                                    model: root.visibleNativeRices

                                    delegate: Rectangle {
                                        id: nativeCard

                                        required property int index
                                        required property var modelData

                                        Layout.preferredWidth:
                                            (riceContent.width - 36) / 4
                                        Layout.preferredHeight: 96

                                        radius: 18
                                        antialiasing: true

                                        property int globalIndex:
                                            root.indexForProfile(
                                                modelData.id
                                            )

                                        property bool selected:
                                            root.riceIndex ===
                                            globalIndex

                                        property bool active:
                                            modelData.id ===
                                            root.activeProfile

                                        opacity:
                                            root.profileInstalled(
                                                modelData.id
                                            ) ? 1.0 : 0.38

                                        color: nativeCard.selected
                                            ? "#202033"
                                            : "#17171f"

                                        border.width:
                                            nativeCard.selected ||
                                            nativeCard.active
                                            ? 2 : 1

                                        border.color:
                                            nativeCard.selected
                                            ? "#a78bfa"
                                            : nativeCard.active
                                                ? "#6d5bd0"
                                                : "#34343f"

                                        scale:
                                            nativeCard.selected
                                            ? 1.025 : 1.0

                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: 110
                                            }
                                        }

                                        onSelectedChanged: {
                                            if (nativeCard.selected)
                                                Qt.callLater(
                                                    () =>
                                                    root.revealCard(
                                                        nativeCard
                                                    )
                                                )
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            width: parent.width - 20
                                            horizontalAlignment:
                                                Text.AlignHCenter
                                            text: modelData.name
                                            elide: Text.ElideRight
                                            color: "#fafafa"
                                            font.family:
                                                "JetBrainsMono Nerd Font"
                                            font.pixelSize: 15
                                            font.bold:
                                                nativeCard.selected ||
                                                nativeCard.active
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape:
                                                Qt.PointingHandCursor

                                            onClicked: {
                                                root.riceIndex =
                                                    nativeCard.globalIndex
                                                root.activateSelection()
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height:
                                    root.visibleNativeRices.length > 0 &&
                                    root.visibleRevoRices.length > 0
                                    ? 1 : 0
                                visible: height > 0
                                color: "#2d2d38"
                            }

                            GridLayout {
                                width: parent.width
                                columns: 4
                                columnSpacing: 12
                                rowSpacing: 12
                                visible:
                                    root.visibleRevoRices.length > 0

                                Repeater {
                                    model: root.visibleRevoRices

                                    delegate: Rectangle {
                                        id: revoCard

                                        required property int index
                                        required property var modelData

                                        Layout.preferredWidth:
                                            (riceContent.width - 36) / 4
                                        Layout.preferredHeight: 96

                                        radius: 18
                                        antialiasing: true

                                        property int globalIndex:
                                            root.indexForProfile(
                                                modelData.id
                                            )

                                        property bool selected:
                                            root.riceIndex ===
                                            globalIndex

                                        property bool active:
                                            modelData.id ===
                                            root.activeProfile

                                        opacity:
                                            root.profileInstalled(
                                                modelData.id
                                            ) ? 1.0 : 0.38

                                        color: revoCard.selected
                                            ? "#202033"
                                            : "#17171f"

                                        border.width:
                                            revoCard.selected ||
                                            revoCard.active
                                            ? 2 : 1

                                        border.color:
                                            revoCard.selected
                                            ? "#a78bfa"
                                            : revoCard.active
                                                ? "#6d5bd0"
                                                : "#34343f"

                                        scale:
                                            revoCard.selected
                                            ? 1.025 : 1.0

                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: 110
                                            }
                                        }

                                        onSelectedChanged: {
                                            if (revoCard.selected)
                                                Qt.callLater(
                                                    () =>
                                                    root.revealCard(
                                                        revoCard
                                                    )
                                                )
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            width: parent.width - 20
                                            horizontalAlignment:
                                                Text.AlignHCenter
                                            text: modelData.name
                                            elide: Text.ElideRight
                                            color: "#fafafa"
                                            font.family:
                                                "JetBrainsMono Nerd Font"
                                            font.pixelSize: 15
                                            font.bold:
                                                revoCard.selected ||
                                                revoCard.active
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape:
                                                Qt.PointingHandCursor

                                            onClicked: {
                                                root.riceIndex =
                                                    revoCard.globalIndex
                                                root.activateSelection()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#2d2d38"
                }

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: root.actionMessage.length > 0
                            ? root.actionMessage
                            : root.page === 0
                                ? "← →  Select compositor"
                                : "← ↑ ↓ →  Select rice"
                        color: "#71717a"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Text {
                        text: root.page === 0
                            ? "ENTER  Open     ESC  Close"
                            : "ENTER  Select     ESC  Back"
                        color: "#71717a"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                    }
                }
            }
        }
    }
}
