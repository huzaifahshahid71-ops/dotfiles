import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
        id: window
        visible: true
        implicitWidth: 1280
        implicitHeight: 820
        color: "transparent"
        surfaceFormat.opaque: false
        focusable: true
        aboveWindows: true
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        onClosed: { if (!themeController || !themeController.switching) Qt.quit() }
        property var themeController: null

        property string ctl: Quickshell.env("HOME") + "/.local/bin/lumina-music-ctl"
        property int page: 0
        property int drawerMode: 0
        property bool drawerOpen: false

        property var now: ({
            running: false,
            playing: false,
            paused: true,
            title: "",
            artist: "",
            album: "",
            artUrl: "",
            position: 0,
            duration: 0,
            playlist: "",
            playlistName: "Favorites",
            playlistPos: -1,
            playlistCount: 0,
            path: "",
            shuffle: false,
            repeat: false,
            theme: {
                bg1: "#633852",
                bg2: "#19151c",
                accent: "#f1aecb",
                dominant: "#9a5d7e"
            }
        })

        property var library: []
        property var playlists: []
        property var playlistTracks: []
        property var queueTracks: []
        property var waveform: []
        property var lyricsData: ({ title: "", source: "none", plain: "", synced: [] })

        property string selectedPlaylist: ""
        property string selectedPlaylistName: ""
        property string selectedPlaylistArt: ""
        property var selectedPlaylistTheme: ({ bg1: "#633852", bg2: "#19151c", accent: "#f1aecb", dominant: "#9a5d7e" })
        property bool selectedFavorite: false
        property bool selectedPlaylistCustomArt: false
        property bool playlistDetail: false
        property bool playlistMenuOpen: false
        property bool editPlaylist: false
        property bool createPlaylistOpen: false

        property bool addSheetOpen: false
        property string addTrackPath: ""
        property string addTrackTitle: ""
        property string addSearch: ""
        property bool addNewOpen: false

        property bool artSheetOpen: false
        property string artPath: ""
        property bool renameSheetOpen: false

        property real seekUi: 0
        property bool seekDragging: false
        property real systemVolumeUi: 100
        property bool systemVolumeMuted: false
        property bool volumeDragging: false
        property real playerVolumeUi: 100
        property bool playerVolumeDragging: false
        property double playerVolumeHoldUntil: 0
        property string loadedPath: ""
        property string loadedQueue: ""
        property int loadedQueuePos: -999
        property double volumeHoldUntil: 0
        property string message: ""
        property var sectionTheme: {
            if (page === 2 && playlistDetail)
                return selectedPlaylistTheme || now.theme
            if (page === 2 && playlists.length > 0 && playlists[0].theme)
                return playlists[0].theme
            return now.theme
        }

        function fmt(sec) {
            sec = Math.max(0, Math.floor(Number(sec) || 0))
            const minutes = Math.floor(sec / 60)
            const seconds = sec % 60
            return minutes + ":" + (seconds < 10 ? "0" : "") + seconds
        }

        function action(args, msg) {
            if (actionProc.running)
                return
            message = msg || ""
            actionProc.command = [ctl].concat(args)
            actionProc.running = true
        }

        function refreshStatus() {
            if (!statusProc.running)
                statusProc.running = true
        }

        function refreshPage() {
            if (page === 1 && !libraryProc.running)
                libraryProc.running = true
            if (page === 2 && !playlistsProc.running)
                playlistsProc.running = true
        }

        function filteredQueue() {
            const q = queueSearch ? queueSearch.text.toLowerCase() : ""
            return queueTracks.filter(function(t) {
                return q.length === 0 ||
                       (t.title || "").toLowerCase().indexOf(q) >= 0 ||
                       (t.artist || "").toLowerCase().indexOf(q) >= 0 ||
                       (t.album || "").toLowerCase().indexOf(q) >= 0
            })
        }

        function scrollQueueToCurrent() {
            if (!amberQueue)
                return
            const rows = filteredQueue()
            for (let i = 0; i < rows.length; ++i) {
                if (rows[i].current) {
                    amberQueue.currentIndex = i
                    amberQueue.positionViewAtIndex(i, ListView.Center)
                    return
                }
            }
        }

        function loadQueue(path, force) {
            if (!path || path.length === 0)
                return
            if (!force && loadedQueue === path && queueTracks.length > 0)
                return
            loadedQueue = path
            queueProc.command = [ctl, "queue"]
            queueProc.running = true
        }

        function loadTrackExtras(path) {
            if (!path || path.length === 0)
                return
            waveformProc.command = [ctl, "waveform", path]
            waveformProc.running = true
            if (drawerOpen && drawerMode === 1) {
                lyricsProc.command = [ctl, "lyrics"]
                lyricsProc.running = true
            }
        }

        function lyricsIndex(position) {
            const rows = lyricsData.synced || []
            if (rows.length === 0)
                return -1
            let result = 0
            for (let i = 0; i < rows.length; ++i) {
                if (Number(rows[i].time) <= Number(position))
                    result = i
                else
                    break
            }
            return result
        }

        function toggleDrawer(mode) {
            if (drawerOpen && drawerMode === mode) {
                drawerOpen = false
                return
            }
            drawerMode = mode
            drawerOpen = true
            if (mode === 0)
                loadQueue(now.playlist)
            else if (!lyricsProc.running) {
                lyricsProc.command = [ctl, "lyrics"]
                lyricsProc.running = true
            }
        }

        function openPlaylist(p) {
            selectedPlaylist = p.path
            selectedPlaylistName = p.name
            selectedPlaylistArt = p.artUrl || ""
            selectedPlaylistTheme = p.theme || now.theme
            selectedFavorite = !!p.favorite
            selectedPlaylistCustomArt = !!p.customArt
            playlistDetail = true
            playlistMenuOpen = false
            editPlaylist = false
            playlistTracksProc.command = [ctl, "tracks", p.path]
            playlistTracksProc.running = true
        }

        function openAdd(path, title) {
            addTrackPath = path
            addTrackTitle = title
            addSearch = ""
            addNewOpen = false
            addSheetOpen = true
            if (!playlistsProc.running)
                playlistsProc.running = true
        }

        function closeAdd() {
            addSheetOpen = false
            addTrackPath = ""
            addTrackTitle = ""
            addSearch = ""
            addNewOpen = false
        }

        function syncSelectedPlaylistFromList() {
            if (!selectedPlaylist || selectedPlaylist.length === 0)
                return
            for (let i = 0; i < playlists.length; ++i) {
                const p = playlists[i]
                if (p.path === selectedPlaylist) {
                    selectedPlaylistName = p.name
                    selectedPlaylistArt = p.artUrl || ""
                    selectedPlaylistTheme = p.theme || now.theme
                    selectedFavorite = !!p.favorite
                    selectedPlaylistCustomArt = !!p.customArt
                    return
                }
            }
        }

        Timer {
            interval: 500
            repeat: true
            running: true
            onTriggered: window.refreshStatus()
        }

        Timer {
            interval: 1800
            repeat: true
            running: true
            onTriggered: if (!sysVolumeProc.running) sysVolumeProc.running = true
        }

        Process {
            id: statusProc
            command: [window.ctl, "status"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        const next = JSON.parse(text)
                        const changed = next.path !== window.loadedPath
                        window.now = next
                        if (!window.playerVolumeDragging && Date.now() >= window.playerVolumeHoldUntil)
                            window.playerVolumeUi = Number(next.volume) || 0
                        if (!window.seekDragging)
                            window.seekUi = Number(next.position) || 0
                        if (changed) {
                            window.loadedPath = next.path || ""
                            window.waveform = []
                            window.lyricsData = ({ title: next.title || "", source: "none", plain: "", synced: [] })
                            window.loadTrackExtras(window.loadedPath)
                        }
                        const nextPos = Number(next.playlistPos)
                        if (next.playlist && (next.playlist !== window.loadedQueue || nextPos !== window.loadedQueuePos)) {
                            window.loadedQueuePos = nextPos
                            window.loadQueue(next.playlist, true)
                        }
                    } catch (e) {
                    }
                }
            }
        }

        Process {
            id: sysVolumeProc
            command: [window.ctl, "system-volume-status"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        const data = JSON.parse(text)
                        if (!window.volumeDragging && Date.now() >= window.volumeHoldUntil)
                            window.systemVolumeUi = Number(data.volume) || 0
                        window.systemVolumeMuted = !!data.muted
                        window.volumeHoldUntil = Date.now() + 700
                    } catch (e) {
                    }
                }
            }
        }

        Process {
            id: setVolumeProc
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        const data = JSON.parse(text)
                        window.systemVolumeUi = Number(data.volume) || 0
                        window.systemVolumeMuted = !!data.muted
                    } catch (e) {
                    }
                }
            }
        }

        Process {
            id: waveformProc
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        const data = JSON.parse(text)
                        if (data.path === window.loadedPath)
                            window.waveform = data.values || []
                    } catch (e) {
                        window.waveform = []
                    }
                }
            }
        }

        Process {
            id: lyricsProc
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        window.lyricsData = JSON.parse(text)
                    } catch (e) {
                        window.lyricsData = ({ title: window.now.title || "", source: "none", plain: "", synced: [] })
                    }
                }
            }
        }

        Process {
            id: queueProc
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        window.queueTracks = JSON.parse(text)
                        Qt.callLater(window.scrollQueueToCurrent)
                    } catch (e) {
                        window.queueTracks = []
                    }
                }
            }
        }

        Process {
            id: libraryProc
            command: [window.ctl, "library"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        window.library = JSON.parse(text)
                    } catch (e) {
                        window.library = []
                    }
                }
            }
        }

        Process {
            id: playlistsProc
            command: [window.ctl, "playlists"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        window.playlists = JSON.parse(text)
                        window.syncSelectedPlaylistFromList()
                    } catch (e) {
                        window.playlists = []
                    }
                }
            }
        }

        Process {
            id: playlistTracksProc
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        window.playlistTracks = JSON.parse(text)
                    } catch (e) {
                        window.playlistTracks = []
                    }
                }
            }
        }

        Process {
            id: actionProc
            stdout: StdioCollector {
                onStreamFinished: {
                    window.message = ""
                    window.refreshStatus()
                    if (!playlistsProc.running)
                        playlistsProc.running = true
                    if (window.page === 1 && !libraryProc.running)
                        libraryProc.running = true
                    if (window.playlistDetail && window.selectedPlaylist.length > 0 && !playlistTracksProc.running) {
                        playlistTracksProc.command = [window.ctl, "tracks", window.selectedPlaylist]
                        playlistTracksProc.running = true
                    }
                    if (window.drawerOpen && window.drawerMode === 0 && !queueProc.running) {
                        queueProc.command = [window.ctl, "queue"]
                        queueProc.running = true
                    }
                }
            }
        }

        Process {
            id: browseArtProc
            stdout: StdioCollector {
                onStreamFinished: {
                    window.visible = true
                    try {
                        const data = JSON.parse(text)
                        const chosen = String(data.path || "")
                        if (chosen.length > 0) {
                            window.artPath = chosen
                            window.artSheetOpen = false
                            window.action(["set-art", window.selectedPlaylist, chosen], "")
                        }
                    } catch (e) {
                    }
                    shellFrame.forceActiveFocus()
                }
            }
        }

        component SoftButton: Rectangle {
            id: button
            property string label: ""
            property bool active: false
            property color activeColor: window.sectionTheme.accent || "#f1aecb"
            signal clicked()

            implicitWidth: textItem.implicitWidth + 30
            implicitHeight: 36
            radius: 18
            color: active ? activeColor : "#55282a31"
            border.width: 1
            border.color: active ? Qt.lighter(activeColor, 1.08) : "#6a444750"
            scale: mouse.pressed ? 0.97 : 1.0

            Behavior on color {
                ColorAnimation { duration: 260 }
            }
            Behavior on scale {
                NumberAnimation { duration: 120 }
            }

            Text {
                id: textItem
                anchors.centerIn: parent
                text: button.label
                color: button.active ? "#111217" : "#f4f4f6"
                font.family: "Inter"
                font.pixelSize: 10
                font.weight: Font.DemiBold
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: button.clicked()
            }
        }

        component RoundIcon: Item {
            id: iconButton
            property string icon: "▶"
            property int iconSize: 22
            property color iconColor: "#ffffff"
            property bool active: false
            signal clicked()

            implicitWidth: 44
            implicitHeight: 44

            Rectangle {
                anchors.centerIn: parent
                width: hover.containsMouse ? 40 : 34
                height: width
                radius: width / 2
                color: iconButton.active ? "#44383b44" : hover.containsMouse ? "#32343b" : "transparent"
                Behavior on width {
                    NumberAnimation { duration: 120 }
                }
            }

            Text {
                anchors.centerIn: parent
                text: iconButton.icon
                color: iconButton.iconColor
                font.pixelSize: iconButton.iconSize
                font.weight: Font.DemiBold
                scale: hover.pressed ? 0.92 : hover.containsMouse ? 1.08 : 1.0
                Behavior on scale {
                    NumberAnimation { duration: 120 }
                }
            }

            MouseArea {
                id: hover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: iconButton.clicked()
            }
        }

        component GlowSlider: Slider {
            id: slider
            property color accentColor: window.sectionTheme.accent || "#f1aecb"
            implicitHeight: 34
            leftPadding: 0
            rightPadding: 0
            topPadding: 0
            bottomPadding: 0

            background: Rectangle {
                x: slider.leftPadding
                y: slider.availableHeight / 2 - height / 2
                width: slider.availableWidth
                height: 10
                radius: 5
                color: "#55343840"

                Rectangle {
                    width: slider.visualPosition * parent.width
                    height: parent.height
                    radius: parent.radius
                    color: slider.accentColor
                    Behavior on color {
                        ColorAnimation { duration: 380 }
                    }
                }
            }

            handle: Rectangle {
                x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                y: slider.availableHeight / 2 - height / 2
                width: slider.pressed ? 22 : 18
                height: width
                radius: width / 2
                color: "#ffffff"
                border.width: 2
                border.color: slider.accentColor
                Behavior on width {
                    NumberAnimation { duration: 100 }
                }
            }
        }

        component WaveSeek: Item {
            id: wave
            property real from: 0
            property real to: 1
            property real value: 0
            property var values: []
            property color accentColor: window.now.theme.accent || "#f1aecb"
            property bool pressed: seekMouse.pressed
            signal seekRequested(real value)

            implicitHeight: 72

            function fraction() {
                if (to <= from)
                    return 0
                return Math.max(0, Math.min(1, (value - from) / (to - from)))
            }

            function valueAt(px) {
                const f = Math.max(0, Math.min(1, px / Math.max(1, width)))
                return from + f * (to - from)
            }

            Canvas {
                id: waveCanvas
                anchors.fill: parent
                antialiasing: true

                onPaint: {
                    const ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    const rows = wave.values || []
                    const count = rows.length > 0 ? rows.length : 92
                    const gap = 2
                    const barWidth = Math.max(2, (width - gap * (count - 1)) / count)
                    const progress = wave.fraction()
                    for (let i = 0; i < count; ++i) {
                        const amp = rows.length > 0 ? Number(rows[i]) : 0.25 + 0.16 * Math.sin(i * 0.55)
                        const h = Math.max(6, amp * (height - 12))
                        const x = i * (barWidth + gap)
                        const y = (height - h) / 2
                        const center = (i + 0.5) / count
                        ctx.fillStyle = center <= progress ? wave.accentColor : "#60575b63"
                        ctx.fillRect(x, y, barWidth, h)
                    }
                }
            }

            MouseArea {
                id: seekMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPressed: {
                    wave.value = wave.valueAt(mouse.x)
                    waveCanvas.requestPaint()
                }
                onPositionChanged: {
                    if (pressed) {
                        wave.value = wave.valueAt(mouse.x)
                        waveCanvas.requestPaint()
                    }
                }
                onReleased: wave.seekRequested(wave.value)
            }

            onValueChanged: waveCanvas.requestPaint()
            onValuesChanged: waveCanvas.requestPaint()
            onAccentColorChanged: waveCanvas.requestPaint()
            onWidthChanged: waveCanvas.requestPaint()
            onHeightChanged: waveCanvas.requestPaint()
        }

        Rectangle {
            id: shellFrame
            anchors.fill: parent
            anchors.margins: 14
            radius: 42
            antialiasing: true
            color: "#0d0e12"
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.darker(window.sectionTheme.bg1 || "#633852", 1.85); Behavior on color { ColorAnimation { duration: 520 } } }
                GradientStop { position: 0.34; color: Qt.darker(window.sectionTheme.dominant || "#9a5d7e", 2.05); Behavior on color { ColorAnimation { duration: 520 } } }
                GradientStop { position: 0.70; color: Qt.darker(window.sectionTheme.bg2 || "#19151c", 1.18); Behavior on color { ColorAnimation { duration: 520 } } }
                GradientStop { position: 1.0; color: "#07090d"; Behavior on color { ColorAnimation { duration: 520 } } }
            }
            border.width: 1
            border.color: "#4c404751"
            clip: true
            focus: true

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "#50090c12"
            }

            Keys.onEscapePressed: {
                if (window.addSheetOpen)
                    window.closeAdd()
                else if (window.artSheetOpen)
                    window.artSheetOpen = false
                else if (window.renameSheetOpen)
                    window.renameSheetOpen = false
                else if (window.playlistMenuOpen)
                    window.playlistMenuOpen = false
                else if (window.drawerOpen)
                    window.drawerOpen = false
                else if (window.playlistDetail)
                    window.playlistDetail = false
                else
                    Qt.quit()
            }

            Component.onCompleted: {
                forceActiveFocus()
                window.refreshStatus()
                sysVolumeProc.running = true
                playlistsProc.running = true
            }

            // Keep every full-window paint rounded. Rectangle.clip is rectangular,
            // so painting the gradient on shellFrame itself avoids square corners.
            Rectangle {
                anchors.fill: parent
                radius: shellFrame.radius
                antialiasing: true
                color: "#28000000"
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 18

                RowLayout {
                    id: topBar
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    spacing: 18

                    ColumnLayout {
                        spacing: -2
                        Text {
                            text: "LUMINA"
                            color: "#d9d9df"
                            font.family: "Inter"
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            font.letterSpacing: 2.4
                        }
                        Text {
                            text: "Music"
                            color: "#ffffff"
                            font.family: "Inter"
                            font.pixelSize: 23
                            font.weight: Font.DemiBold
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        Layout.preferredWidth: navRow.implicitWidth + 16
                        Layout.preferredHeight: 42
                        radius: 21
                        color: "#4c202229"
                        border.width: 1
                        border.color: "#5d454850"

                        Row {
                            id: navRow
                            anchors.centerIn: parent
                            spacing: 2

                            Repeater {
                                model: ["NOW PLAYING", "SONGS", "PLAYLISTS", "THEMES"]
                                delegate: Rectangle {
                                    required property int index
                                    required property string modelData
                                    width: index === 0 ? 118 : index === 3 ? 92 : 88
                                    height: 34
                                    radius: 17
                                    color: window.page === index ? "#52464b56" : "transparent"
                                    border.width: window.page === index ? 1 : 0
                                    border.color: window.page === index ? "#6a5c636f" : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData
                                        color: window.page === index ? "#ffffff" : "#a9a9b0"
                                        font.family: "Inter"
                                        font.pixelSize: 9
                                        font.weight: window.page === index ? Font.DemiBold : Font.Medium
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            window.page = index
                                            window.drawerOpen = false
                                            if (index !== 2)
                                                window.playlistDetail = false
                                            window.refreshPage()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: 36
                        height: 36
                        radius: 18
                        color: "#4724262d"
                        border.width: 1
                        border.color: "#5a41444d"
                        Text {
                            anchors.centerIn: parent
                            text: "×"
                            color: "#f5f5f7"
                            font.pixelSize: 18
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Qt.quit()
                        }
                    }
                }

                StackLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: window.page

                    Item {
                        RowLayout {
                            anchors.fill: parent
                            spacing: 18

                            // Amberol-style queue sidebar: always visible on the wide overlay.
                            Rectangle {
                                Layout.preferredWidth: 320
                                Layout.fillHeight: true
                                radius: 30
                                color: "#4212171d"
                                border.width: 1
                                border.color: "#4f454851"
                                clip: true

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 14
                                    spacing: 10

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 10

                                        Text {
                                            text: "⌕"
                                            color: "#e9e9ed"
                                            font.pixelSize: 23
                                            font.weight: Font.Medium
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: -1
                                            Text {
                                                Layout.fillWidth: true
                                                text: "Playlist"
                                                color: "#ffffff"
                                                font.family: "Inter"
                                                font.pixelSize: 18
                                                font.weight: Font.DemiBold
                                                horizontalAlignment: Text.AlignHCenter
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                text: window.queueTracks.length + " songs"
                                                color: "#c1c1c7"
                                                font.family: "Inter"
                                                font.pixelSize: 9
                                                horizontalAlignment: Text.AlignHCenter
                                            }
                                        }

                                        RoundIcon {
                                            implicitWidth: 34
                                            implicitHeight: 34
                                            icon: "✓"
                                            iconSize: 15
                                            iconColor: window.now.theme.accent || "#f1aecb"
                                            onClicked: queueSearch.text = ""
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 36
                                        radius: 18
                                        color: "#4721242b"
                                        border.width: 1
                                        border.color: "#51464a53"

                                        TextField {
                                            id: queueSearch
                                            anchors.fill: parent
                                            anchors.leftMargin: 12
                                            anchors.rightMargin: 12
                                            background: null
                                            color: "#ffffff"
                                            placeholderText: "Search current playlist"
                                            onTextChanged: Qt.callLater(window.scrollQueueToCurrent)
                                            placeholderTextColor: "#85868e"
                                            font.family: "Inter"
                                            font.pixelSize: 10
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 1
                                        color: "#3d393d45"
                                    }

                                    ListView {
                                        id: amberQueue
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        clip: true
                                        spacing: 3
                                        model: window.filteredQueue()

                                        delegate: Rectangle {
                                            required property var modelData
                                            width: ListView.view.width
                                            height: 62
                                            radius: 15
                                            color: modelData.current ? "#52474b55" : queueMouse.containsMouse ? "#32282b32" : "transparent"
                                            border.width: modelData.current ? 1 : 0
                                            border.color: modelData.current ? "#65585e69" : "transparent"

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.margins: 6
                                                spacing: 10

                                                Item {
                                                    Layout.preferredWidth: 48
                                                    Layout.preferredHeight: 48

                                                    Rectangle {
                                                        x: 2
                                                        y: 4
                                                        width: 45
                                                        height: 45
                                                        radius: 13
                                                        color: "#26000000"
                                                    }

                                                    Rectangle {
                                                        width: 45
                                                        height: 45
                                                        radius: 12
                                                        color: "#2b2d34"
                                                        clip: true

                                                        Image {
                                                            id: amberQueueArt
                                                            anchors.fill: parent
                                                            source: modelData.artUrl || ""
                                                            fillMode: Image.PreserveAspectCrop
                                                            asynchronous: true
                                                            visible: source.toString().length > 0
                                                        }

                                                        Text {
                                                            anchors.centerIn: parent
                                                            visible: !amberQueueArt.visible
                                                            text: "♫"
                                                            color: "#7b7d85"
                                                            font.pixelSize: 14
                                                        }
                                                    }
                                                }

                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 1
                                                    Text {
                                                        Layout.fillWidth: true
                                                        text: modelData.title || "Unknown track"
                                                        color: modelData.current ? "#ffffff" : "#eeeeF1"
                                                        font.family: "Inter"
                                                        font.pixelSize: 11
                                                        font.weight: modelData.current ? Font.DemiBold : Font.Medium
                                                        elide: Text.ElideRight
                                                    }
                                                    Text {
                                                        Layout.fillWidth: true
                                                        text: modelData.artist || "Unknown artist"
                                                        color: modelData.current ? (window.now.theme.accent || "#f1aecb") : "#a3a4ab"
                                                        font.family: "Inter"
                                                        font.pixelSize: 9
                                                        elide: Text.ElideRight
                                                        Behavior on color { ColorAnimation { duration: 260 } }
                                                    }
                                                }

                                                Text {
                                                    visible: !!modelData.current
                                                    text: "◖)))"
                                                    color: window.now.theme.accent || "#f1aecb"
                                                    font.pixelSize: 10
                                                }
                                            }

                                            MouseArea {
                                                id: queueMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: window.action(["queue-play", String(modelData.queueIndex)], "")
                                            }
                                        }
                                    }
                                }
                            }

                            // Main playback surface: deliberately close to Amberol's composition,
                            // but driven entirely by the existing MPV-backed Lumina controller.
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 30
                                color: "#35111418"
                                border.width: 1
                                border.color: "#443a3f48"

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    width: Math.min(parent.width - 70, 620)
                                    spacing: 8

                                    Item {
                                        Layout.alignment: Qt.AlignHCenter
                                        Layout.preferredWidth: 278
                                        Layout.preferredHeight: 278

                                        // One restrained depth layer, instead of a large muddy fake shadow.
                                        Rectangle {
                                            anchors.centerIn: parent
                                            anchors.horizontalCenterOffset: 5
                                            anchors.verticalCenterOffset: 8
                                            width: 246
                                            height: 246
                                            radius: 24
                                            color: "#30000000"
                                        }

                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 250
                                            height: 250
                                            radius: 23
                                            color: "#282a31"
                                            border.width: 1
                                            border.color: "#6a59616c"
                                            clip: true

                                            Image {
                                                id: amberHeroArt
                                                anchors.fill: parent
                                                source: window.now.artUrl || ""
                                                fillMode: Image.PreserveAspectCrop
                                                asynchronous: true
                                                visible: source.toString().length > 0
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                visible: !amberHeroArt.visible
                                                text: "♫"
                                                color: "#747680"
                                                font.pixelSize: 72
                                            }
                                        }
                                    }

                                    WaveSeek {
                                        id: amberWaveSeek
                                        Layout.alignment: Qt.AlignHCenter
                                        Layout.preferredWidth: Math.min(410, parent.width)
                                        Layout.preferredHeight: 62
                                        from: 0
                                        to: Math.max(1, Number(window.now.duration) || 1)
                                        value: window.seekUi
                                        values: window.waveform
                                        accentColor: window.now.theme.accent || "#f1aecb"
                                        onPressedChanged: window.seekDragging = pressed
                                        onSeekRequested: function(v) {
                                            window.seekDragging = false
                                            window.seekUi = v
                                            window.action(["seek", String(v)], "")
                                        }
                                    }

                                    RowLayout {
                                        Layout.alignment: Qt.AlignHCenter
                                        Layout.preferredWidth: Math.min(410, parent.width)
                                        Text {
                                            text: window.fmt(window.seekUi)
                                            color: "#d0d0d5"
                                            font.family: "Inter"
                                            font.pixelSize: 9
                                        }
                                        Item { Layout.fillWidth: true }
                                        Text {
                                            text: "-" + window.fmt(Math.max(0, Number(window.now.duration) - window.seekUi))
                                            color: "#d0d0d5"
                                            font.family: "Inter"
                                            font.pixelSize: 9
                                        }
                                    }

                                    Item { Layout.preferredHeight: 2 }

                                    Text {
                                        Layout.fillWidth: true
                                        text: window.now.title || "Nothing Playing"
                                        color: "#ffffff"
                                        font.family: "Inter"
                                        font.pixelSize: 24
                                        font.weight: Font.DemiBold
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: window.now.artist || "Lumina Music"
                                        color: "#f0f0f2"
                                        font.family: "Inter"
                                        font.pixelSize: 14
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: window.now.album || window.now.playlistName || ""
                                        color: window.now.theme.accent || "#f1aecb"
                                        font.family: "Inter"
                                        font.pixelSize: 11
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                        Behavior on color { ColorAnimation { duration: 380 } }
                                    }

                                    Item { Layout.preferredHeight: 5 }

                                    RowLayout {
                                        Layout.alignment: Qt.AlignHCenter
                                        spacing: 18

                                        Rectangle {
                                            width: 43
                                            height: 43
                                            radius: 22
                                            color: previousMouse.containsMouse ? "#62424850" : "#49343840"
                                            Text {
                                                anchors.centerIn: parent
                                                text: "⏮"
                                                color: "#ffffff"
                                                font.pixelSize: 18
                                            }
                                            MouseArea {
                                                id: previousMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: window.action(["previous"], "")
                                            }
                                        }

                                        Rectangle {
                                            width: 54
                                            height: 54
                                            radius: 27
                                            color: playMouse.containsMouse ? Qt.lighter(window.now.theme.accent || "#f1aecb", 1.08) : (window.now.theme.accent || "#f1aecb")
                                            scale: playMouse.pressed ? 0.94 : 1.0
                                            Behavior on color { ColorAnimation { duration: 260 } }
                                            Behavior on scale { NumberAnimation { duration: 100 } }
                                            Text {
                                                anchors.centerIn: parent
                                                anchors.horizontalCenterOffset: window.now.playing ? 0 : 2
                                                text: window.now.playing ? "⏸" : "▶"
                                                color: "#17151a"
                                                font.pixelSize: window.now.playing ? 21 : 23
                                                font.weight: Font.DemiBold
                                            }
                                            MouseArea {
                                                id: playMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: window.action(["toggle"], "")
                                            }
                                        }

                                        Rectangle {
                                            width: 43
                                            height: 43
                                            radius: 22
                                            color: nextMouse.containsMouse ? "#62424850" : "#49343840"
                                            Text {
                                                anchors.centerIn: parent
                                                text: "⏭"
                                                color: "#ffffff"
                                                font.pixelSize: 18
                                            }
                                            MouseArea {
                                                id: nextMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: window.action(["next"], "")
                                            }
                                        }
                                    }

                                    Item { Layout.preferredHeight: 3 }

                                    RowLayout {
                                        Layout.alignment: Qt.AlignHCenter
                                        Layout.preferredWidth: Math.min(360, parent.width)
                                        spacing: 10

                                        Text {
                                            text: "♫"
                                            color: "#f0f0f2"
                                            font.pixelSize: 13
                                        }

                                        GlowSlider {
                                            id: amberMusicVolumeSlider
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 30
                                            from: 0
                                            to: 130
                                            value: window.playerVolumeUi
                                            accentColor: window.sectionTheme.accent || "#f1aecb"
                                            onPressedChanged: {
                                                window.playerVolumeDragging = pressed
                                                window.playerVolumeHoldUntil = Date.now() + 1200
                                                if (!pressed) {
                                                    window.playerVolumeUi = value
                                                    window.action(["volume", String(value)], "")
                                                }
                                            }
                                            onMoved: {
                                                window.playerVolumeUi = value
                                                window.playerVolumeHoldUntil = Date.now() + 1200
                                            }
                                        }

                                        Text {
                                            text: Math.round(window.playerVolumeUi) + "%"
                                            color: "#f0f0f2"
                                            font.pixelSize: 10
                                            font.weight: Font.Medium
                                        }
                                    }

                                    RowLayout {
                                        Layout.alignment: Qt.AlignHCenter
                                        Layout.preferredWidth: Math.min(360, parent.width)
                                        spacing: 10

                                        Text {
                                            text: window.systemVolumeMuted ? "🔇" : "🔈"
                                            color: "#f0f0f2"
                                            font.pixelSize: 13
                                        }

                                        GlowSlider {
                                            id: amberVolumeSlider
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 30
                                            from: 0
                                            to: 100
                                            value: window.systemVolumeUi
                                            accentColor: window.sectionTheme.accent || "#f1aecb"
                                            onPressedChanged: {
                                                window.volumeDragging = pressed
                                                window.volumeHoldUntil = Date.now() + 1200
                                                if (!pressed && !setVolumeProc.running) {
                                                    window.systemVolumeUi = value
                                                    setVolumeProc.command = [window.ctl, "system-volume", String(value)]
                                                    setVolumeProc.running = true
                                                }
                                            }
                                            onMoved: {
                                                window.systemVolumeUi = value
                                                window.volumeHoldUntil = Date.now() + 1200
                                            }
                                        }

                                        Text {
                                            text: "🔊"
                                            color: "#f0f0f2"
                                            font.pixelSize: 13
                                        }
                                    }

                                    RowLayout {
                                        Layout.alignment: Qt.AlignHCenter
                                        spacing: 12

                                        RoundIcon {
                                            implicitWidth: 40
                                            implicitHeight: 40
                                            icon: "▣"
                                            iconSize: 16
                                            active: false
                                            onClicked: queueSearch.forceActiveFocus()
                                        }

                                        RoundIcon {
                                            implicitWidth: 40
                                            implicitHeight: 40
                                            icon: "↝"
                                            iconSize: 17
                                            active: !!window.now.shuffle
                                            iconColor: window.now.shuffle ? (window.now.theme.accent || "#f1aecb") : "#f2f2f4"
                                            onClicked: window.action(["shuffle"], "")
                                        }

                                        RoundIcon {
                                            implicitWidth: 40
                                            implicitHeight: 40
                                            icon: "↻"
                                            iconSize: 17
                                            active: !!window.now.repeat
                                            iconColor: window.now.repeat ? (window.now.theme.accent || "#f1aecb") : "#f2f2f4"
                                            onClicked: window.action(["repeat"], "")
                                        }

                                        SoftButton {
                                            label: "Lyrics"
                                            active: window.drawerOpen && window.drawerMode === 1
                                            onClicked: window.toggleDrawer(1)
                                        }
                                    }
                                }
                            }

                            // Lyrics is the only auxiliary drawer now; the queue itself lives
                            // in the persistent Amberol-style sidebar.
                            Rectangle {
                                id: amberLyricsDrawer
                                property real drawerWidth: window.drawerOpen && window.drawerMode === 1 ? 330 : 0
                                Layout.preferredWidth: drawerWidth
                                Layout.fillHeight: true
                                radius: 30
                                antialiasing: true
                                color: "#00000000"
                                gradient: Gradient {
                                    orientation: Gradient.Vertical
                                    GradientStop { position: 0.0; color: Qt.darker(window.now.theme.bg1 || "#633852", 1.65) }
                                    GradientStop { position: 0.52; color: Qt.darker(window.now.theme.dominant || "#9a5d7e", 1.9) }
                                    GradientStop { position: 1.0; color: Qt.darker(window.now.theme.bg2 || "#19151c", 1.1) }
                                }
                                border.width: drawerWidth > 0 ? 1 : 0
                                border.color: window.now.theme.accent || "#f1aecb"
                                opacity: drawerWidth > 0 ? 1 : 0
                                clip: true

                                Behavior on drawerWidth {
                                    NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
                                }
                                Behavior on opacity { NumberAnimation { duration: 180 } }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: amberLyricsDrawer.radius
                                    color: "#28000000"
                                }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 18
                                    spacing: 10
                                    visible: amberLyricsDrawer.drawerWidth > 0

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text {
                                            text: "Lyrics"
                                            color: "#ffffff"
                                            font.family: "Inter"
                                            font.pixelSize: 20
                                            font.weight: Font.DemiBold
                                        }
                                        Item { Layout.fillWidth: true }
                                        Rectangle {
                                            width: 32
                                            height: 32
                                            radius: 16
                                            color: lyricsCloseMouse.containsMouse ? "#53434a54" : "#392e333b"
                                            Text {
                                                anchors.centerIn: parent
                                                text: "×"
                                                color: "#ffffff"
                                                font.pixelSize: 16
                                            }
                                            MouseArea {
                                                id: lyricsCloseMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: window.drawerOpen = false
                                            }
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: window.lyricsData.source === "none" ? "No lyrics source" : window.lyricsData.source
                                        color: "#9a9ba3"
                                        font.family: "Inter"
                                        font.pixelSize: 9
                                        elide: Text.ElideRight
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 1
                                        color: "#433a3f48"
                                    }

                                    ListView {
                                        id: amberSyncedLyrics
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        visible: (window.lyricsData.synced || []).length > 0
                                        clip: true
                                        spacing: 17
                                        model: window.lyricsData.synced || []
                                        currentIndex: window.lyricsIndex(window.seekUi)

                                        onCurrentIndexChanged: {
                                            if (currentIndex >= 0)
                                                positionViewAtIndex(currentIndex, ListView.Center)
                                        }

                                        delegate: Text {
                                            required property int index
                                            required property var modelData
                                            width: ListView.view.width
                                            text: modelData.text || "♪"
                                            horizontalAlignment: Text.AlignHCenter
                                            color: index === amberSyncedLyrics.currentIndex ? "#ffffff" :
                                                   Math.abs(index - amberSyncedLyrics.currentIndex) === 1 ? "#d7d7dc" : "#a6a7ae"
                                            font.family: "Inter"
                                            font.pixelSize: index === amberSyncedLyrics.currentIndex ? 19 : 13
                                            font.weight: index === amberSyncedLyrics.currentIndex ? Font.Bold : Font.Normal
                                            lineHeight: 1.32
                                            wrapMode: Text.WordWrap
                                            opacity: index === amberSyncedLyrics.currentIndex ? 1.0 :
                                                     Math.abs(index - amberSyncedLyrics.currentIndex) === 1 ? 0.72 : 0.42
                                            scale: index === amberSyncedLyrics.currentIndex ? 1.0 : 0.96
                                            Behavior on color { ColorAnimation { duration: 220 } }
                                            Behavior on opacity { NumberAnimation { duration: 220 } }
                                            Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                                        }
                                    }

                                    Flickable {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        visible: (window.lyricsData.synced || []).length === 0
                                        clip: true
                                        contentWidth: width
                                        contentHeight: amberPlainLyrics.implicitHeight

                                        Text {
                                            id: amberPlainLyrics
                                            width: parent.width
                                            text: window.lyricsData.plain || "No lyrics found for this track."
                                            color: "#d0d0d5"
                                            font.family: "Inter"
                                            font.pixelSize: 13
                                            lineHeight: 1.5
                                            wrapMode: Text.WordWrap
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 14

                            RowLayout {
                                Layout.fillWidth: true
                                ColumnLayout {
                                    spacing: 0
                                    Text {
                                        text: "Songs"
                                        color: "#ffffff"
                                        font.family: "Inter"
                                        font.pixelSize: 27
                                        font.weight: Font.DemiBold
                                    }
                                    Text {
                                        text: window.library.length + " tracks"
                                        color: "#cfd6dd"
                                        font.pixelSize: 9
                                    }
                                }
                                Item {
                                    Layout.fillWidth: true
                                }
                                Rectangle {
                                    Layout.preferredWidth: 310
                                    Layout.preferredHeight: 40
                                    radius: 20
                                    color: "#33232a34"
                                    border.width: 1
                                    border.color: "#4c5a6672"
                                    TextField {
                                        id: songSearch
                                        anchors.fill: parent
                                        anchors.leftMargin: 14
                                        anchors.rightMargin: 14
                                        background: null
                                        color: "#ffffff"
                                        placeholderText: "Search songs"
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 30
                                color: "#4f12161d"
                                border.width: 1
                                border.color: "#60566070"
                                clip: true

                                ListView {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    clip: true
                                    spacing: 2
                                    model: window.library.filter(function(t) {
                                        const query = songSearch.text.toLowerCase()
                                        return query.length === 0 ||
                                               t.title.toLowerCase().indexOf(query) >= 0 ||
                                               (t.artist || "").toLowerCase().indexOf(query) >= 0 ||
                                               (t.album || "").toLowerCase().indexOf(query) >= 0
                                    })

                                    delegate: Rectangle {
                                        required property var modelData
                                        width: ListView.view.width
                                        height: 68
                                        radius: 16
                                        color: songMouse.containsMouse ? "#2affffff" : "transparent"

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 7
                                            spacing: 12

                                            Item {
                                                Layout.preferredWidth: 54
                                                Layout.preferredHeight: 54

                                                Rectangle {
                                                    width: 48
                                                    height: 48
                                                    radius: 13
                                                    color: "#2b2d34"
                                                    clip: true
                                                    Image {
                                                        id: songArt
                                                        anchors.fill: parent
                                                        source: modelData.artUrl || ""
                                                        fillMode: Image.PreserveAspectCrop
                                                        asynchronous: true
                                                        visible: source.toString().length > 0
                                                    }
                                                    Text {
                                                        anchors.centerIn: parent
                                                        visible: !songArt.visible
                                                        text: "♫"
                                                        color: "#777982"
                                                        font.pixelSize: 15
                                                    }
                                                }
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 1
                                                Text {
                                                    Layout.fillWidth: true
                                                    text: modelData.title
                                                    color: modelData.path === window.now.path ? "#ffffff" : "#f8fafb"
                                                    font.pixelSize: 11
                                                    font.weight: modelData.path === window.now.path ? Font.Bold : Font.DemiBold
                                                    elide: Text.ElideRight
                                                }
                                                Text {
                                                    Layout.fillWidth: true
                                                    text: (modelData.artist || "Unknown Artist") + (modelData.album ? "  •  " + modelData.album : "")
                                                    color: "#d9e0e4"
                                                    font.pixelSize: 8
                                                    font.weight: Font.Medium
                                                    elide: Text.ElideRight
                                                }
                                            }

                                            Text {
                                                text: window.fmt(modelData.duration || 0)
                                                color: "#eef2f4"
                                                font.pixelSize: 8
                                                font.weight: Font.Medium
                                            }

                                            Rectangle {
                                                width: 36
                                                height: 36
                                                radius: 18
                                                color: addMouse.containsMouse ? (window.now.theme.accent || "#f1aecb") : "#3c292c33"
                                                border.width: 1
                                                border.color: addMouse.containsMouse ? "#ffffff" : "#5b41454e"
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "+"
                                                    color: addMouse.containsMouse ? "#111217" : "#ffffff"
                                                    font.pixelSize: 20
                                                    anchors.verticalCenterOffset: -1
                                                }
                                                MouseArea {
                                                    id: addMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: window.openAdd(modelData.path, modelData.title)
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: songMouse
                                            anchors.left: parent.left
                                            anchors.top: parent.top
                                            anchors.bottom: parent.bottom
                                            anchors.right: parent.right
                                            anchors.rightMargin: 48
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onDoubleClicked: window.action(["play-track", modelData.path], "")
                                        }
                                    }
                                }
                            }


                        }
                    }

                    Item {
                        Item {
                            anchors.fill: parent

                            ColumnLayout {
                                anchors.fill: parent
                                visible: !window.playlistDetail
                                spacing: 14

                                RowLayout {
                                    Layout.fillWidth: true
                                    ColumnLayout {
                                        spacing: 0
                                        Text {
                                            text: "Playlists"
                                            color: "#ffffff"
                                            font.pixelSize: 27
                                            font.weight: Font.DemiBold
                                        }
                                        Text {
                                            text: "Your .m3u / .m3u8 collection"
                                            color: "#8f9098"
                                            font.pixelSize: 9
                                        }
                                    }
                                    Item {
                                        Layout.fillWidth: true
                                    }
                                    SoftButton {
                                        label: "+  New Playlist"
                                        active: true
                                        onClicked: {
                                            window.createPlaylistOpen = true
                                            newPlaylistField.forceActiveFocus()
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: window.createPlaylistOpen ? 48 : 0
                                    visible: window.createPlaylistOpen
                                    radius: 20
                                    color: "#4d22252c"
                                    border.width: 1
                                    border.color: "#5a424650"
                                    TextField {
                                        id: newPlaylistField
                                        anchors.fill: parent
                                        anchors.leftMargin: 14
                                        anchors.rightMargin: 14
                                        background: null
                                        color: "#ffffff"
                                        placeholderText: "New playlist name"
                                        onAccepted: {
                                            if (text.trim().length > 0) {
                                                window.action(["create", text.trim()], "Creating playlist…")
                                                text = ""
                                                window.createPlaylistOpen = false
                                            }
                                        }
                                    }
                                }

                                GridView {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    cellWidth: 188
                                    cellHeight: 226
                                    clip: true
                                    model: window.playlists

                                    delegate: Item {
                                        required property var modelData
                                        width: 174
                                        height: 214

                                        Column {
                                            anchors.fill: parent
                                            spacing: 9

                                            Item {
                                                width: 174
                                                height: 174

                                                Rectangle {
                                                    width: 164
                                                    height: 164
                                                    radius: 24
                                                    color: "#292b32"
                                                    border.width: 1
                                                    border.color: "#56404750"
                                                    clip: true

                                                    Image {
                                                        id: playlistGridArt
                                                        anchors.fill: parent
                                                        source: modelData.artUrl || ""
                                                        fillMode: Image.PreserveAspectCrop
                                                        asynchronous: true
                                                        visible: source.toString().length > 0
                                                    }

                                                    Text {
                                                        anchors.centerIn: parent
                                                        visible: !playlistGridArt.visible
                                                        text: modelData.favorite ? "★" : "♫"
                                                        color: modelData.favorite ? "#ff7890" : "#7e8088"
                                                        font.pixelSize: 44
                                                    }
                                                }
                                            }

                                            Text {
                                                width: parent.width
                                                text: modelData.name
                                                color: "#ffffff"
                                                font.pixelSize: 11
                                                font.weight: Font.DemiBold
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                width: parent.width
                                                text: modelData.count + " songs"
                                                color: "#dbe3e8"
                                                font.pixelSize: 8
                                                font.weight: Font.Medium
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: window.openPlaylist(modelData)
                                        }
                                    }
                                }
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                visible: window.playlistDetail
                                spacing: 12

                                RowLayout {
                                    Layout.fillWidth: true
                                    RoundIcon {
                                        icon: "‹"
                                        iconSize: 28
                                        onClicked: {
                                            window.playlistDetail = false
                                            window.playlistMenuOpen = false
                                        }
                                    }
                                    Item {
                                        Layout.fillWidth: true
                                    }
                                    RoundIcon {
                                        icon: "•••"
                                        iconSize: 13
                                        onClicked: window.playlistMenuOpen = !window.playlistMenuOpen
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 176
                                    spacing: 22

                                    Item {
                                        Layout.preferredWidth: 172
                                        Layout.preferredHeight: 172

                                        Rectangle {
                                            width: 164
                                            height: 164
                                            radius: 24
                                            color: "#292b32"
                                            clip: true

                                            Image {
                                                id: selectedPlaylistImage
                                                anchors.fill: parent
                                                source: window.selectedPlaylistArt || ""
                                                fillMode: Image.PreserveAspectCrop
                                                asynchronous: true
                                                visible: source.toString().length > 0
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                visible: !selectedPlaylistImage.visible
                                                text: window.selectedFavorite ? "★" : "♫"
                                                color: window.selectedFavorite ? "#ff7890" : "#7e8088"
                                                font.pixelSize: 44
                                            }
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing: 6

                                        Text {
                                            text: window.selectedPlaylistName || "Playlist"
                                            color: "#ffffff"
                                            font.pixelSize: 29
                                            font.weight: Font.DemiBold
                                        }

                                        Text {
                                            text: window.playlistTracks.length + " songs" + (window.selectedPlaylistCustomArt ? "  •  custom cover" : "")
                                            color: "#e1e8ec"
                                            font.pixelSize: 9
                                            font.weight: Font.Medium
                                        }

                                        Item {
                                            height: 6
                                        }

                                        Row {
                                            spacing: 9
                                            SoftButton {
                                                label: "▶  Play"
                                                active: true
                                                onClicked: window.action(["load", window.selectedPlaylist], "")
                                            }
                                            SoftButton {
                                                label: window.editPlaylist ? "Done" : "Edit"
                                                onClicked: window.editPlaylist = !window.editPlaylist
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 1
                                    color: "#44363a43"
                                }

                                ListView {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    clip: true
                                    spacing: 2
                                    model: window.playlistTracks

                                    delegate: Rectangle {
                                        required property int index
                                        required property var modelData
                                        width: ListView.view.width
                                        height: 66
                                        radius: 15
                                        color: playlistTrackMouse.containsMouse ? "#2affffff" : "transparent"

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 7
                                            spacing: 12

                                            Rectangle {
                                                Layout.preferredWidth: 50
                                                Layout.preferredHeight: 50
                                                radius: 13
                                                color: "#2a2c33"
                                                clip: true
                                                Image {
                                                    id: playlistTrackArt
                                                    anchors.fill: parent
                                                    source: modelData.artUrl || ""
                                                    fillMode: Image.PreserveAspectCrop
                                                    asynchronous: true
                                                    visible: source.toString().length > 0
                                                }
                                                Text {
                                                    anchors.centerIn: parent
                                                    visible: !playlistTrackArt.visible
                                                    text: "♫"
                                                    color: "#777982"
                                                    font.pixelSize: 15
                                                }
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 1
                                                Text {
                                                    Layout.fillWidth: true
                                                    text: modelData.title
                                                    color: modelData.path === window.now.path ? "#ffffff" : "#f8fafb"
                                                    font.pixelSize: 11
                                                    font.weight: modelData.path === window.now.path ? Font.Bold : Font.DemiBold
                                                    elide: Text.ElideRight
                                                }
                                                Text {
                                                    Layout.fillWidth: true
                                                    text: (modelData.artist || "Unknown Artist") + (modelData.album ? "  •  " + modelData.album : "")
                                                    color: "#d9e0e4"
                                                    font.pixelSize: 8
                                                    font.weight: Font.Medium
                                                    elide: Text.ElideRight
                                                }
                                            }

                                            Text {
                                                visible: !window.editPlaylist
                                                text: window.fmt(modelData.duration || 0)
                                                color: "#eef2f4"
                                                font.pixelSize: 8
                                                font.weight: Font.Medium
                                            }

                                            Row {
                                                visible: window.editPlaylist
                                                spacing: 0
                                                ToolButton {
                                                    text: "↑"
                                                    enabled: index > 0
                                                    onClicked: window.action(["move", window.selectedPlaylist, String(index), String(index - 1)], "")
                                                }
                                                ToolButton {
                                                    text: "↓"
                                                    enabled: index < window.playlistTracks.length - 1
                                                    onClicked: window.action(["move", window.selectedPlaylist, String(index), String(index + 1)], "")
                                                }
                                                ToolButton {
                                                    text: "×"
                                                    onClicked: window.action(["remove", window.selectedPlaylist, String(index)], "")
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: playlistTrackMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            enabled: !window.editPlaylist
                                            onClicked: window.action(["play-from", window.selectedPlaylist, String(index)], "")
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.topMargin: 44
                                width: 210
                                height: menuColumn.implicitHeight + 14
                                radius: 18
                                color: "#ef1b1d24"
                                border.width: 1
                                border.color: "#60464a54"
                                visible: window.playlistDetail && window.playlistMenuOpen
                                z: 30

                                Column {
                                    id: menuColumn
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 7
                                    spacing: 3

                                    Repeater {
                                        model: [
                                            {show: true, label: "Set Cover Art", action: "art", danger: false},
                                            {show: window.selectedPlaylistCustomArt, label: "Clear Custom Cover", action: "clearart", danger: false},
                                            {show: !window.selectedFavorite, label: "Rename Playlist", action: "rename", danger: false},
                                            {show: !window.selectedFavorite, label: "Delete Playlist", action: "delete", danger: true}
                                        ]

                                        delegate: Rectangle {
                                            required property var modelData
                                            visible: modelData.show
                                            width: parent.width
                                            height: 39
                                            radius: 12
                                            color: menuMouse.containsMouse ? (modelData.danger ? "#5d27303a" : "#3a30343d") : "transparent"

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.left: parent.left
                                                anchors.leftMargin: 12
                                                text: modelData.label
                                                color: modelData.danger ? "#ff7b90" : "#f5f5f7"
                                                font.pixelSize: 10
                                            }

                                            MouseArea {
                                                id: menuMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    window.playlistMenuOpen = false
                                                    if (modelData.action === "art") {
                                                        window.artSheetOpen = true
                                                        window.artPath = ""
                                                    } else if (modelData.action === "clearart") {
                                                        window.action(["clear-art", window.selectedPlaylist], "")
                                                    } else if (modelData.action === "rename") {
                                                        window.renameSheetOpen = true
                                                    } else if (modelData.action === "delete") {
                                                        const doomed = window.selectedPlaylist
                                                        window.playlistDetail = false
                                                        window.selectedPlaylist = ""
                                                        window.playlistTracks = []
                                                        window.action(["delete", doomed], "")
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                
                    // The fourth tab belongs to the player, not the playback service.
                    Item {
                        Rectangle {
                            anchors.fill: parent
                            radius: 24
                            color: "#29232d"
                            border.width: 1
                            border.color: "#514c59"

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 28
                                spacing: 16

                                Text {
                                    text: "PLAYER THEMES"
                                    color: "#e6e1e5"
                                    font.family: "Inter"
                                    font.pixelSize: 23
                                    font.weight: Font.DemiBold
                                }
                                Text {
                                    text: "One music library. Three different interfaces. Your choice is remembered."
                                    color: "#b7b0be"
                                    font.family: "Inter"
                                    font.pixelSize: 13
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 330
                                    spacing: 15
                                    Repeater {
                                        model: [
                                            { key: "glass", name: "Liquid Glass", caption: "The original luminous, rounded Lumina design", background: "#242333", surface: "#504b65", accent: "#f1aecb", dark: false },
                                            { key: "nexus", name: "Cyberpunk NEXUS", caption: "Black panels, technical grid and red controls", background: "#0b0b0c", surface: "#191717", accent: "#d52f29", dark: true },
                                            { key: "material", name: "Material 3 · Sung", caption: "Warm surfaces, peach controls and a navigation rail", background: "#181211", surface: "#382c28", accent: "#ffb596", dark: false }
                                        ]
                                        delegate: Rectangle {
                                            required property var modelData
                                            readonly property bool selected: window.themeController && window.themeController.currentTheme === modelData.key
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            radius: 20
                                            color: modelData.background
                                            border.width: selected ? 2 : 1
                                            border.color: selected ? modelData.accent : "#514c59"

                                            ColumnLayout {
                                                anchors.fill: parent
                                                anchors.margins: 20
                                                spacing: 12
                                                Rectangle {
                                                    Layout.fillWidth: true
                                                    Layout.preferredHeight: 145
                                                    radius: modelData.dark ? 3 : 18
                                                    color: modelData.surface
                                                    border.width: 1
                                                    border.color: modelData.accent
                                                    Rectangle {
                                                        x: 17; y: 18; width: 64; height: 64
                                                        radius: modelData.dark ? 0 : 12
                                                        color: modelData.accent
                                                        opacity: 0.8
                                                    }
                                                    Rectangle {
                                                        x: 98; y: 25; width: Math.max(10, parent.width - 130); height: 8
                                                        radius: modelData.dark ? 0 : 4
                                                        color: "#e6e1e5"
                                                    }
                                                    Rectangle {
                                                        x: 98; y: 44; width: Math.max(10, parent.width - 170); height: 5
                                                        radius: modelData.dark ? 0 : 3
                                                        color: "#b7b0be"
                                                    }
                                                    Rectangle {
                                                        x: 17; y: 110; width: Math.max(10, parent.width - 34); height: 6
                                                        radius: modelData.dark ? 0 : 3
                                                        color: modelData.accent
                                                    }
                                                }
                                                Text {
                                                    text: modelData.name
                                                    color: "#ffffff"
                                                    font.family: modelData.dark ? "monospace" : "Inter"
                                                    font.pixelSize: 17
                                                    font.weight: Font.DemiBold
                                                }
                                                Text {
                                                    Layout.fillWidth: true
                                                    text: modelData.caption
                                                    color: "#c9c3ce"
                                                    font.family: "Inter"
                                                    font.pixelSize: 11
                                                    wrapMode: Text.WordWrap
                                                }
                                                Item { Layout.fillHeight: true }
                                                Text {
                                                    text: selected ? "✓  CURRENT THEME" : "SELECT THEME  →"
                                                    color: modelData.accent
                                                    font.family: modelData.dark ? "monospace" : "Inter"
                                                    font.pixelSize: 11
                                                    font.weight: Font.DemiBold
                                                }
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (window.themeController)
                                                        window.themeController.setTheme(modelData.key)
                                                }
                                            }
                                        }
                                    }
                                }
                                Item { Layout.fillHeight: true }
                            }
                        }
                    }
}

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: window.page === 0 || !window.now.running ? 0 : 70
                    visible: window.page !== 0 && window.now.running
                    radius: 35
                    color: "#b51a1c22"
                    border.width: 1
                    border.color: "#5d444852"
                    clip: true

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 9
                        spacing: 12

                        Item {
                            Layout.preferredWidth: 52
                            Layout.preferredHeight: 52

                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: "#2c2e35"
                                border.width: 1
                                border.color: "#55ffffff"
                            }

                            Canvas {
                                id: miniPlayerArt
                                anchors.fill: parent
                                antialiasing: true
                                property string artSource: window.now.artUrl || ""

                                function reloadArt() {
                                    if (artSource.length > 0 && !isImageLoaded(artSource))
                                        loadImage(artSource)
                                    requestPaint()
                                }

                                Component.onCompleted: reloadArt()
                                onArtSourceChanged: reloadArt()
                                onImageLoaded: requestPaint()

                                onPaint: {
                                    const ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)

                                    if (artSource.length === 0 || !isImageLoaded(artSource))
                                        return

                                    ctx.save()
                                    ctx.beginPath()
                                    ctx.arc(width / 2, height / 2, Math.min(width, height) / 2 - 1, 0, Math.PI * 2)
                                    ctx.closePath()
                                    ctx.clip()
                                    ctx.drawImage(artSource, 0, 0, width, height)
                                    ctx.restore()
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    window.page = 0
                                    window.playlistDetail = false
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.preferredWidth: 230
                            spacing: 0
                            Text {
                                Layout.fillWidth: true
                                text: window.now.title || "Nothing Playing"
                                color: "#ffffff"
                                font.pixelSize: 10
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                text: window.now.artist || ""
                                color: "#c2c9d1"
                                font.pixelSize: 8
                                elide: Text.ElideRight
                            }
                        }

                        Item { Layout.fillWidth: true }

                        RoundIcon {
                            icon: "⏮"
                            iconSize: 18
                            onClicked: window.action(["previous"], "")
                        }
                        RoundIcon {
                            icon: window.now.playing ? "⏸" : "▶"
                            iconSize: 22
                            onClicked: window.action(["toggle"], "")
                        }
                        RoundIcon {
                            icon: "⏭"
                            iconSize: 18
                            onClicked: window.action(["next"], "")
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: "♫"
                            color: "#ced3da"
                            font.pixelSize: 11
                        }

                        GlowSlider {
                            Layout.preferredWidth: 120
                            Layout.preferredHeight: 28
                            from: 0
                            to: 130
                            value: window.playerVolumeUi
                            accentColor: window.now.theme.accent || "#f1aecb"
                            onPressedChanged: {
                                window.playerVolumeDragging = pressed
                                window.playerVolumeHoldUntil = Date.now() + 1200
                                if (!pressed) {
                                    window.playerVolumeUi = value
                                    window.action(["volume", String(value)], "")
                                }
                            }
                            onMoved: {
                                window.playerVolumeUi = value
                                window.playerVolumeHoldUntil = Date.now() + 1200
                            }
                        }

                        GlowSlider {
                            Layout.preferredWidth: 240
                            from: 0
                            to: Math.max(1, Number(window.now.duration) || 1)
                            value: window.seekUi
                            accentColor: window.now.theme.accent || "#f1aecb"
                            onPressedChanged: {
                                window.seekDragging = pressed
                                if (!pressed) {
                                    window.seekUi = value
                                    window.action(["seek", String(value)], "")
                                }
                            }
                            onMoved: window.seekUi = value
                        }

                        Text {
                            text: window.fmt(window.seekUi)
                            color: "#d5dbe1"
                            font.pixelSize: 8
                        }
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                visible: window.addSheetOpen
                color: "#8a000000"
                z: 100
                MouseArea {
                    anchors.fill: parent
                    onClicked: window.closeAdd()
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 500
                    height: 540
                    radius: 28
                    color: "#f01a1c23"
                    border.width: 1
                    border.color: "#60464b55"
                    MouseArea {
                        anchors.fill: parent
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "Add to Playlist"
                                color: "#ffffff"
                                font.pixelSize: 19
                                font.weight: Font.DemiBold
                            }
                            Item {
                                Layout.fillWidth: true
                            }
                            RoundIcon {
                                icon: "×"
                                iconSize: 18
                                onClicked: window.closeAdd()
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: window.addTrackTitle
                            color: "#989aa2"
                            font.pixelSize: 9
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
                            radius: 20
                            color: "#33232a34"
                            border.width: 1
                            border.color: "#4c5a6672"
                            TextField {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                background: null
                                color: "#ffffff"
                                placeholderText: "Search playlists"
                                onTextChanged: window.addSearch = text
                            }
                        }

                        SoftButton {
                            label: "+  New Playlist"
                            active: true
                            onClicked: {
                                window.addNewOpen = true
                                addNewField.forceActiveFocus()
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: window.addNewOpen ? 46 : 0
                            visible: window.addNewOpen
                            radius: 18
                            color: "#33232a34"
                            border.width: 1
                            border.color: "#4c5a6672"
                            TextField {
                                id: addNewField
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                background: null
                                color: "#ffffff"
                                placeholderText: "New playlist name"
                                onAccepted: {
                                    if (text.trim().length > 0 && window.addTrackPath.length > 0) {
                                        window.action(["create-add", text.trim(), window.addTrackPath], "")
                                        text = ""
                                        window.closeAdd()
                                    }
                                }
                            }
                        }

                        ListView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 3
                            model: window.playlists.filter(function(p) {
                                const query = window.addSearch.toLowerCase()
                                return query.length === 0 || p.name.toLowerCase().indexOf(query) >= 0
                            })

                            delegate: Rectangle {
                                required property var modelData
                                width: ListView.view.width
                                height: 58
                                radius: 14
                                color: addPlaylistMouse.containsMouse ? "#35282b33" : "transparent"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 7
                                    spacing: 10

                                    Rectangle {
                                        Layout.preferredWidth: 42
                                        Layout.preferredHeight: 42
                                        radius: 11
                                        color: "#292b32"
                                        clip: true
                                        Image {
                                            id: addPlaylistArt
                                            anchors.fill: parent
                                            source: modelData.artUrl || ""
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            visible: source.toString().length > 0
                                        }
                                        Text {
                                            anchors.centerIn: parent
                                            visible: !addPlaylistArt.visible
                                            text: modelData.favorite ? "★" : "♫"
                                            color: modelData.favorite ? "#ff7890" : "#777982"
                                            font.pixelSize: 14
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Text {
                                            text: modelData.name
                                            color: "#ffffff"
                                            font.pixelSize: 11
                                        }
                                        Text {
                                            text: modelData.count + " songs"
                                            color: "#85868e"
                                            font.pixelSize: 8
                                        }
                                    }

                                    Text {
                                        text: "+"
                                        color: window.now.theme.accent || "#f1aecb"
                                        font.pixelSize: 18
                                    }
                                }

                                MouseArea {
                                    id: addPlaylistMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        window.action(["add", modelData.path, window.addTrackPath], "")
                                        window.closeAdd()
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                visible: window.artSheetOpen
                color: "#8a000000"
                z: 105
                MouseArea {
                    anchors.fill: parent
                    onClicked: window.artSheetOpen = false
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 540
                    height: 205
                    radius: 28
                    color: "#f01a1c23"
                    border.width: 1
                    border.color: "#60464b55"
                    MouseArea {
                        anchors.fill: parent
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 12

                        Text {
                            text: "Set Playlist Cover"
                            color: "#ffffff"
                            font.pixelSize: 19
                            font.weight: Font.DemiBold
                        }

                        Text {
                            text: "Choose a JPG, PNG or WEBP image. Lumina will copy it into its own data folder, so the original can be deleted later."
                            color: "#b7b8c0"
                            font.pixelSize: 10
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }

                        Item { Layout.preferredHeight: 6 }

                        RowLayout {
                            Layout.fillWidth: true
                            Item { Layout.fillWidth: true }
                            SoftButton {
                                label: "Cancel"
                                onClicked: window.artSheetOpen = false
                            }
                            SoftButton {
                                label: "Choose Image"
                                active: true
                                onClicked: {
                                    if (!browseArtProc.running) {
                                        // A layer-shell overlay sits above normal windows. Hide it
                                        // while the native picker is open, then restore it afterward.
                                        window.visible = false
                                        browseArtProc.command = [window.ctl, "pick-art"]
                                        browseArtProc.running = true
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                visible: window.renameSheetOpen
                color: "#8a000000"
                z: 106
                MouseArea {
                    anchors.fill: parent
                    onClicked: window.renameSheetOpen = false
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 440
                    height: 190
                    radius: 26
                    color: "#f01a1c23"
                    border.width: 1
                    border.color: "#60464b55"
                    MouseArea {
                        anchors.fill: parent
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 12

                        Text {
                            text: "Rename Playlist"
                            color: "#ffffff"
                            font.pixelSize: 18
                            font.weight: Font.DemiBold
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            radius: 18
                            color: "#33232a34"
                            border.width: 1
                            border.color: "#4c5a6672"
                            TextField {
                                id: renameField
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                background: null
                                color: "#ffffff"
                                placeholderText: "New name"
                                onAccepted: {
                                    if (text.trim().length > 0) {
                                        window.renameSheetOpen = false
                                        window.action(["rename", window.selectedPlaylist, text.trim()], "")
                                        window.playlistDetail = false
                                        window.selectedPlaylist = ""
                                        text = ""
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 12
                width: toastText.implicitWidth + 28
                height: 32
                radius: 16
                color: "#e02a2d35"
                border.width: 1
                border.color: "#5c454952"
                visible: window.message.length > 0
                z: 120

                Text {
                    id: toastText
                    anchors.centerIn: parent
                    text: window.message
                    color: "#ffffff"
                    font.pixelSize: 9
                }
            }
        }
    }
