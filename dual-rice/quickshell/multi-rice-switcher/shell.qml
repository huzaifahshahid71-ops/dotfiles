import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

ShellRoot {
    PanelWindow {
        id: window

        // Resolve the saved theme before mapping the classic window.
        visible: root.themeResolved &&
                 (root.forceThemePicker || root.activeTheme !== "sumi-deck")
        implicitWidth: 860
        implicitHeight: 560
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
            color: root.bg
            border.width: 2
            border.color: root.accent

            focus: true

            // 0 = compositor picker, 2 = rice picker, 3 = theme picker.
            // Page 1 is intentionally unused to preserve a small diff from
            // the previous switcher implementation.
            property int page: 0
            property int hubIndex: 0
            property int compositorIndex: 0
            property int riceIndex: 0
            property int themeIndex: 0

            property string activeProfile: "unknown"
            property string activeCompositor: "unknown"
            property int hyprInstalled: 0
            property int niriInstalled: 0
            property var installedProfiles: ({})

            property string activeTheme: "original"
            property bool themeResolved: false
            property string pendingTheme: ""
            property string actionMessage: ""
            property bool forceThemePicker:
                Quickshell.env("HUZAIFAH_SWITCHER_FORCE_PICKER") === "1"

            property var hyprRices: [
                { id: "caelestia",   icon: "✦", name: "Aether" },
                { id: "end4",        icon: "◈", name: "Obsidian" },
                { id: "ambxst",      icon: "◆", name: "Crimson" },
                { id: "dms",         icon: "●", name: "Materia" },
                { id: "serpantinum", icon: "◇", name: "Aurora" },
                { id: "noctalia",    icon: "◉", name: "Nocturne" },
                { id: "sayconlun",   icon: "⬡", name: "Lumina" }
            ]

            property var niriRices: [
                { id: "jaqc",   icon: "☀", name: "Solstice" },
                { id: "clavis", icon: "❖", name: "Cipher" },
                { id: "nixri",  icon: "✧", name: "Astra" }
            ]

            property var themes: [
                {
                    id: "original",
                    name: "Original",
                    subtitle: "CLASSIC",
                    description: "Purple Multi-Rice interface",
                    accent: "#8b5cf6"
                },
                {
                    id: "midnight",
                    name: "Midnight Cyan",
                    subtitle: "DARK CYAN",
                    description: "Huzaifah layout with a dark cyan skin",
                    accent: "#38bdf8"
                },
                {
                    id: "sumi-deck",
                    name: "Sumi Deck",
                    subtitle: "CARD CAROUSEL",
                    description: "Full-screen fanned profile cards",
                    accent: "#b4d088"
                }
            ]

            property var visibleRices:
                compositorIndex === 0 ? hyprRices : niriRices

            // Theme palette. This changes only this switcher.
            property bool midnight: activeTheme === "midnight"
            property color bg: midnight ? "#090c12" : "#101016"
            property color panel: midnight ? "#111722" : "#17171f"
            property color panelSelected: midnight ? "#162433" : "#202033"
            property color rowSelected: midnight ? "#132838" : "#26263a"
            property color accent: midnight ? "#38bdf8" : "#8b5cf6"
            property color accentText: midnight ? "#7dd3fc" : "#c4b5fd"
            property color titleText: midnight ? "#f8fafc" : "#f4f4f5"
            property color bodyText: midnight ? "#d6e2ef" : "#d4d4d8"
            property color mutedText: midnight ? "#718398" : "#71717a"
            property color borderIdle: midnight ? "#243244" : "#34343f"
            property color chip: midnight ? "#0d1520" : "#1d1d28"
            property color separator: midnight ? "#1f2d3b" : "#2d2d38"

            function profileInstalled(id) {
                return installedProfiles[id] === true
            }

            function applyStatus(text) {
                const values = {}
                const lines = text.trim().split("\n")

                for (let i = 0; i < lines.length; ++i) {
                    const pos = lines[i].indexOf("=")
                    if (pos <= 0)
                        continue
                    values[lines[i].slice(0, pos)] = lines[i].slice(pos + 1)
                }

                activeCompositor = values.compositor || "unknown"
                activeProfile = values.profile || "unknown"
                hyprInstalled = parseInt(values.hyprland_installed || "0")
                niriInstalled = parseInt(values.niri_installed || "0")

                let savedTheme = values.switcher_theme || "original"
                if (savedTheme === "revo")
                    savedTheme = "midnight"

                if (savedTheme === "sumi-deck")
                    activeTheme = "sumi-deck"
                else if (savedTheme === "midnight")
                    activeTheme = "midnight"
                else
                    activeTheme = "original"

                if (activeCompositor === "niri")
                    compositorIndex = 1
                else if (activeCompositor === "hyprland")
                    compositorIndex = 0

                for (let i = 0; i < themes.length; ++i) {
                    if (themes[i].id === activeTheme) {
                        themeIndex = i
                        break
                    }
                }
                themeResolved = true
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
                        compositor: parts[3]
                    }

                    next[item.id] = parts[4] === "true"

                    if (item.compositor === "hyprland")
                        hypr.push(item)
                    else if (item.compositor === "niri")
                        niri.push(item)
                }

                installedProfiles = next

                if (hypr.length > 0)
                    hyprRices = hypr
                if (niri.length > 0)
                    niriRices = niri

                if (riceIndex >= visibleRices.length)
                    riceIndex = Math.max(0, visibleRices.length - 1)
            }

            function openHubSelection() {
                actionMessage = ""
                if (hubIndex === 0) {
                    page = 1
                } else {
                    page = 3
                    for (let i = 0; i < themes.length; ++i) {
                        if (themes[i].id === activeTheme) {
                            themeIndex = i
                            break
                        }
                    }
                }
            }

            function openRiceList() {
                page = 2
                riceIndex = 0
                actionMessage = ""
            }

            function goBack() {
                actionMessage = ""

                if (page === 2 || page === 3) {
                    page = 0
                    return
                }

                Qt.quit()
            }

            function activateRice() {
                const profile = visibleRices[riceIndex]

                if (!profileInstalled(profile.id)) {
                    actionMessage = profile.name + " is not installed yet"
                    return
                }

                if (profile.id === activeProfile) {
                    actionMessage = profile.name + " is already active"
                    return
                }

                actionMessage = "Switching to " + profile.name + "…"
                switchProc.command = [
                    Quickshell.env("HOME") + "/.local/bin/multi-rice-control",
                    "switch",
                    profile.id
                ]
                switchProc.running = true
            }

            function openSumiDeck() {
                if (forceThemePicker)
                    return

                const home = Quickshell.env("HOME")
                const deckPath =
                    home +
                    "/.local/share/desktop-switcher/themes/sumi-deck/DotsBrowser.qml"
                const logDir =
                    home + "/.local/state/huzaifah-switcher"
                const logPath =
                    logDir + "/sumi-deck.log"

                Quickshell.execDetached([
                    "bash",
                    "-c",
                    "mkdir -p -- \"$2\"; " +
                        "if test -r \"$1\"; then " +
                        "exec quickshell -p \"$1\" >>\"$3\" 2>&1; " +
                        "else notify-send 'Huzaifah Switcher' " +
                        "'Sumi Deck is missing; reinstall switcher themes.' " +
                        "2>/dev/null || true; exit 1; fi",
                    "huzaifah-sumi-deck", deckPath, logDir, logPath
                ])

                Qt.callLater(Qt.quit)
            }

            function activateTheme() {
                const theme = themes[themeIndex]

                if (theme.id === activeTheme) {
                    actionMessage = theme.name + " is already active"
                    return
                }

                pendingTheme = theme.id
                actionMessage = "Applying " + theme.name + "…"
                themeProc.command = [
                    Quickshell.env("HOME") + "/.local/bin/multi-rice-control",
                    "set-theme",
                    theme.id
                ]
                themeProc.running = true
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
                    if (exitCode !== 0 && root.actionMessage.length === 0)
                        root.actionMessage = "Switch failed • exit " + exitCode
                }
            }

            Process {
                id: themeProc

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
                    if (exitCode === 0 && root.pendingTheme.length > 0) {
                        root.activeTheme = root.pendingTheme
                        root.actionMessage = "Switcher theme • " +
                            root.themes[root.themeIndex].name

                        if (root.pendingTheme === "sumi-deck")
                            Qt.callLater(root.openSumiDeck)
                    } else if (exitCode !== 0 && root.actionMessage.length === 0) {
                        root.actionMessage = "Theme change failed • exit " + exitCode
                    }
                    root.pendingTheme = ""
                }
            }

            Process {
                id: statusProc
                running: true
                command: [
                    Quickshell.env("HOME") + "/.local/bin/multi-rice-control",
                    "status"
                ]

                stdout: StdioCollector {
                    onStreamFinished: {
                        root.applyStatus(text)

                        if (root.forceThemePicker) {
                            root.page = 3
                            root.forceActiveFocus()
                        } else if (root.activeTheme === "sumi-deck") {
                            Qt.callLater(root.openSumiDeck)
                        }
                    }
                }

                onExited: (exitCode, exitStatus) => {
                    if (exitCode !== 0) {
                        root.activeTheme = "original"
                        root.themeResolved = true
                        root.actionMessage = "Unable to read switcher status • exit " + exitCode
                    }
                }
            }

            Process {
                id: listProc
                running: true
                command: [
                    Quickshell.env("HOME") + "/.local/bin/multi-rice-control",
                    "list"
                ]

                stdout: StdioCollector {
                    onStreamFinished: root.applyList(text)
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
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        openRiceList()
                        event.accepted = true
                    } else if (event.key === Qt.Key_T) {
                        for (let i = 0; i < themes.length; ++i) {
                            if (themes[i].id === activeTheme) {
                                themeIndex = i
                                break
                            }
                        }
                        page = 3
                        event.accepted = true
                    } else if (event.key === Qt.Key_Escape) {
                        Qt.quit()
                        event.accepted = true
                    }
                } else if (page === 2) {
                    if (event.key === Qt.Key_Up) {
                        riceIndex = (riceIndex - 1 + visibleRices.length) % visibleRices.length
                        event.accepted = true
                    } else if (event.key === Qt.Key_Down) {
                        riceIndex = (riceIndex + 1) % visibleRices.length
                        event.accepted = true
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        activateRice()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Left) {
                        goBack()
                        event.accepted = true
                    }
                } else if (page === 3) {
                    if (event.key === Qt.Key_Up || event.key === Qt.Key_Left) {
                        themeIndex = (themeIndex - 1 + themes.length) % themes.length
                        event.accepted = true
                    } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Right) {
                        themeIndex = (themeIndex + 1) % themes.length
                        event.accepted = true
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        activateTheme()
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
                            color: root.accentText
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: root.midnight ? 12 : 14
                            font.bold: true
                            font.letterSpacing: root.midnight ? 1.2 : 0
                        }

                        Text {
                            text: root.page === 0
                                ? "Multi-Rice"
                                : root.page === 2
                                    ? (root.compositorIndex === 0 ? "Hyprland Rices" : "Niri Rices")
                                    : "Switcher Themes"
                            color: root.titleText
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: root.midnight ? 27 : 29
                            font.bold: true
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        id: themesButton
                        width: 150
                        height: 38
                        radius: root.midnight ? 8 : 19
                        color: themesMouse.containsMouse
                            ? root.panelSelected
                            : root.chip
                        border.width: root.midnight ? 1 : 0
                        border.color: root.page === 3
                            ? root.accent
                            : root.borderIdle

                        Text {
                            anchors.centerIn: parent
                            text: root.page === 3 ? "←  BACK" : "THEMES  ◐"
                            color: root.page === 3
                                ? root.accentText
                                : root.mutedText
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            font.bold: true
                        }

                        MouseArea {
                            id: themesMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                root.actionMessage = ""
                                if (root.page === 3) {
                                    root.page = 0
                                } else {
                                    for (let i = 0; i < root.themes.length; ++i) {
                                        if (root.themes[i].id === root.activeTheme) {
                                            root.themeIndex = i
                                            break
                                        }
                                    }
                                    root.page = 3
                                }
                                root.forceActiveFocus()
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    // Hub: Rices / Themes
                    Row {
                        id: hubPage
                        anchors.centerIn: parent
                        spacing: 28
                        visible: false

                        Repeater {
                            model: [
                                {
                                    glyph: "◫",
                                    name: "RICES",
                                    subtitle: "Switch desktop profile",
                                    detail: "Hyprland + Niri"
                                },
                                {
                                    glyph: "◐",
                                    name: "THEMES",
                                    subtitle: "Switcher appearance",
                                    detail: "Does not change your rice"
                                }
                            ]

                            delegate: Rectangle {
                                required property int index
                                required property var modelData

                                width: 350
                                height: 250
                                radius: root.midnight ? 14 : 20
                                antialiasing: true

                                property bool selected: root.hubIndex === index

                                color: selected ? root.panelSelected : root.panel
                                border.width: selected ? 2 : 1
                                border.color: selected ? root.accent : root.borderIdle
                                scale: selected ? 1.025 : 1.0

                                Behavior on scale {
                                    NumberAnimation { duration: 120 }
                                }

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 14

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.glyph
                                        color: selected ? root.accentText : root.mutedText
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 48
                                        font.bold: true
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.name
                                        color: root.titleText
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 24
                                        font.bold: true
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.subtitle
                                        color: root.bodyText
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 13
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.detail
                                        color: root.mutedText
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.hubIndex = index
                                        root.openHubSelection()
                                    }
                                }
                            }
                        }
                    }

                    // Rices -> compositor selection
                    Row {
                        id: compositorPage
                        anchors.centerIn: parent
                        spacing: 28
                        visible: root.page === 0

                        Repeater {
                            model: [
                                { name: "HYPRLAND", glyph: "H" },
                                { name: "NIRI", glyph: "N" }
                            ]

                            delegate: Rectangle {
                                required property int index
                                required property var modelData

                                width: 330
                                height: 250
                                radius: root.midnight ? 14 : 20
                                antialiasing: true

                                property bool selected: root.compositorIndex === index

                                color: selected ? root.panelSelected : root.panel
                                border.width: selected ? 2 : 1
                                border.color: selected ? root.accent : root.borderIdle
                                scale: selected ? 1.025 : 1.0

                                Behavior on scale {
                                    NumberAnimation { duration: 120 }
                                }

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 14

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.glyph
                                        color: selected ? root.accentText : root.mutedText
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 46
                                        font.bold: true
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.name
                                        color: root.titleText
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 24
                                        font.bold: true
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: index === 0
                                            ? root.hyprInstalled + " / " + root.hyprRices.length + " INSTALLED"
                                            : root.niriInstalled + " / " + root.niriRices.length + " INSTALLED"
                                        color: root.accentText
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 13
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: root.activeCompositor === (index === 0 ? "hyprland" : "niri")
                                            ? "Currently Active"
                                            : "Switch Session"
                                        color: root.mutedText
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 12
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.compositorIndex = index
                                        root.openRiceList()
                                    }
                                }
                            }
                        }
                    }

                    // Rice list
                    Column {
                        id: ricePage
                        anchors.fill: parent
                        spacing: 6
                        visible: root.page === 2

                        Repeater {
                            model: root.visibleRices

                            delegate: Rectangle {
                                required property int index
                                required property var modelData

                                width: ricePage.width
                                height: 38
                                radius: root.midnight ? 8 : 12
                                antialiasing: true

                                property bool selected: root.riceIndex === index

                                opacity: root.profileInstalled(modelData.id) ? 1.0 : 0.38
                                color: selected ? root.rowSelected : "transparent"
                                border.width: selected ? 1 : 0
                                border.color: root.accent

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 18
                                    anchors.rightMargin: 18

                                    Text {
                                        text: modelData.icon
                                        color: selected ? root.accentText : root.mutedText
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 18
                                    }

                                    Text {
                                        text: modelData.name
                                        color: selected ? root.titleText : root.bodyText
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 16
                                        font.bold: selected
                                    }

                                    Item { Layout.fillWidth: true }

                                    Text {
                                        visible: modelData.id === root.activeProfile ||
                                            !root.profileInstalled(modelData.id)
                                        text: modelData.id === root.activeProfile
                                            ? "ACTIVE"
                                            : "NOT INSTALLED"
                                        color: modelData.id === root.activeProfile
                                            ? root.accentText
                                            : root.mutedText
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                        font.bold: true
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.riceIndex = index
                                        root.activateRice()
                                    }
                                }
                            }
                        }
                    }

                    // Theme picker. This never invokes profile switching.
                    Row {
                        id: themePage
                        anchors.centerIn: parent
                        spacing: 18
                        visible: root.page === 3

                        Repeater {
                            model: root.themes

                            delegate: Rectangle {
                                id: themeCard
                                required property int index
                                required property var modelData

                                width: 242
                                height: 255
                                radius: root.midnight ? 14 : 20
                                color: root.themeIndex === index
                                    ? root.panelSelected
                                    : root.panel
                                border.width: root.themeIndex === index ? 2 : 1
                                border.color: root.themeIndex === index
                                    ? modelData.accent
                                    : root.borderIdle

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 18
                                    spacing: 12

                                    Row {
                                        width: parent.width
                                        spacing: 10

                                        Rectangle {
                                            width: 12
                                            height: 12
                                            radius: 6
                                            anchors.verticalCenter: parent.verticalCenter
                                            color: modelData.accent
                                        }

                                        Text {
                                            text: modelData.subtitle
                                            color: root.mutedText
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 10
                                            font.bold: true
                                            font.letterSpacing: 1
                                        }
                                    }

                                    Text {
                                        text: modelData.name
                                        color: root.titleText
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 20
                                        font.bold: true
                                    }

                                    Text {
                                        width: parent.width
                                        text: modelData.description
                                        wrapMode: Text.WordWrap
                                        color: root.bodyText
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 12
                                    }

                                    Item { width: 1; height: 5 }

                                    // Tiny visual preview of the selected skin.
                                    Rectangle {
                                        width: parent.width
                                        height: 66
                                        radius: modelData.id === "midnight" ? 8 : 14
                                        color: modelData.id === "midnight" ? "#090c12" : "#101016"
                                        border.width: 1
                                        border.color: modelData.accent

                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.top: parent.top
                                            height: 18
                                            radius: parent.radius
                                            color: modelData.id === "midnight" ? "#111722" : "#1d1d28"
                                        }

                                        Row {
                                            anchors.centerIn: parent
                                            spacing: 8

                                            Repeater {
                                                model: 4

                                                delegate: Rectangle {
                                                    required property int index
                                                    width: index === 1 ? 58 : 36
                                                    height: 26
                                                    radius: themeCard.modelData.id === "midnight" ? 5 : 9
                                                    color: index === 1
                                                        ? modelData.accent
                                                        : (themeCard.modelData.id === "midnight" ? "#162433" : "#26263a")
                                                    opacity: index === 1 ? 0.85 : 1
                                                }
                                            }
                                        }
                                    }

                                    Item { Layout.fillHeight: true; height: 1 }

                                    Text {
                                        text: modelData.id === root.activeTheme ? "ACTIVE THEME" : "ENTER TO APPLY"
                                        color: modelData.id === root.activeTheme
                                            ? modelData.accent
                                            : root.mutedText
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                        font.bold: true
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.themeIndex = index
                                        root.activateTheme()
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: root.separator
                }

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: root.actionMessage.length > 0
                            ? root.actionMessage
                            : root.page === 0
                                ? "← →  Select compositor     T  Themes"
                                : root.page === 2
                                        ? "↑ ↓  Select rice"
                                        : "← →  Select switcher theme"
                        color: root.mutedText
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: root.page === 0
                            ? "ENTER  Open     ESC  Close"
                            : root.page === 2
                                    ? "ENTER  Select     ESC  Back"
                                    : "ENTER  Apply     ESC  Back"
                        color: root.mutedText
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                    }
                }
            }
        }
    }
}
