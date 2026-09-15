// Wallpaper carousel: a strip of thumbnails over a full-screen view of the one
// in the middle, with the palette it will give the rice.
//
// Browsing is previewed for real, and nothing on screen is allowed to lag the
// carousel - it all changes on the same frame:
//   - the backdrop cross-fades to the new image,
//   - the same image fades in under the bar, in a strip on the BOTTOM layer
//     (above awww, below waybar), because awww needs ~0.25s to catch up,
//   - waybar's colors.css is written straight from the cached palette, so the
//     bar recolours at once instead of after matugen.
// Behind all that, `rice-wallpaper preview` (after a short pause) really sets
// the image and palette, so borders, cava and the bar's files are right.
//
// Enter commits (`rice-wallpaper commit`, every other app re-themes), Esc
// previews the original again. Either way the overlay only closes once awww
// shows the chosen image, so closing never reveals a stale wallpaper.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets

Scope {
    id: root

    property bool open: false
    property bool loading: false
    property string closing: ""       // "" | "commit" | "cancel"
    property string closeTarget: ""
    property var walls: []            // [{path, name, thumb, colors}]
    property int index: 0
    property string original: ""      // on screen when the carousel opened
    property string requested: ""     // last path handed to a preview
    property string shown: ""         // path awww is known to display
    property real barInset: 0         // height of the bar's exclusive zone
    property var targetScreen: null
    property var queued: null
    property var current: null        // the rice-wallpaper run in progress
    property bool fading: false       // the backdrop is mid cross-fade
    readonly property int fadeMs: 450

    readonly property string home: Quickshell.env("HOME")
    readonly property string bin: home + "/.local/share/desktop-profiles/sayconlun/support/bin/"
    readonly property var wall: walls.length ? walls[Math.max(0, Math.min(index, walls.length - 1))] : null
    readonly property var pal: wall ? wall.colors : null

    // The roles palette.css defines - waybar's colors.css must keep all of them.
    readonly property var barRoles: ["primary", "on_primary", "primary_container", "on_primary_container",
        "secondary", "on_secondary", "secondary_container", "on_secondary_container",
        "tertiary", "on_tertiary", "error", "on_error",
        "surface", "surface_container_low", "surface_container", "surface_container_high",
        "surface_container_highest", "on_surface", "on_surface_variant",
        "outline", "outline_variant", "shadow"]

    // A role from the wallpaper being browsed, falling back to the live theme.
    function c(role) {
        return (pal && pal[role]) ? pal[role] : Theme[role]
    }

    function show() {
        if (open)
            return
        targetScreen = focusedScreen()
        loading = true
        fading = false
        closing = ""
        open = true
        lister.running = true
    }

    function toggle() {
        open ? cancel() : show()
    }

    function cancel() {
        finish("cancel", original)
    }

    function commit() {
        if (wall)
            finish("commit", wall.path)
    }

    function step(d) {
        if (walls.length && !closing)
            index = (index + d + walls.length) % walls.length
    }

    function finish(kind, path) {
        if (!open || closing)
            return
        if (!path) {                   // nothing loaded yet
            open = false
            return
        }
        debounce.stop()
        barDebounce.stop()
        closing = kind
        closeTarget = path

        const i = walls.findIndex(w => w.path === path)
        if (i >= 0) {
            index = i                  // Esc cross-fades back to the original first
            writeBarColours(walls[i])
        }
        safety.restart()
        if (shown === path && !worker.running && !queued) {
            done(false)
            return
        }
        if (worker.running && current && current.kind === "preview" && current.path === path)
            queued = null              // already on its way
        else
            run("preview", path)
    }

    // Closing mid cross-fade would cut the fade short, so wait for it
    // (onFadingChanged comes back here) unless the safety timer forces it.
    function done(force) {
        if (fading && !force)
            return
        safety.stop()
        const kind = closing, path = closeTarget
        open = false
        closing = ""
        fading = false
        if (kind === "commit")
            run("commit", path)
    }

    function focusedScreen() {
        const name = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
        const screens = Quickshell.screens
        for (let i = 0; i < screens.length; i++)
            if (screens[i].name === name)
                return screens[i]
        return screens[0]
    }

    function writeBarColours(w) {
        if (!w || !w.colors)
            return
        let css = `/* Written by the wallpaper carousel from ${w.path} - matugen replaces it. */\n`
        for (const role of barRoles)
            if (w.colors[role])
                css += `@define-color ${role} ${w.colors[role]};\n`
        barCss.setText(css)
    }

    // One rice-wallpaper at a time, newest request wins: a preview finishing
    // after a commit would leave the wrong image up.
    function run(kind, path) {
        queued = { kind: kind, path: path }
        drain()
    }

    function drain() {
        if (worker.running || !queued)
            return
        current = queued
        queued = null
        worker.command = [bin + "rice-wallpaper", current.kind, current.path]
        worker.running = true
    }

    onIndexChanged: {
        if (!open || loading || closing || !wall)
            return
        barDebounce.restart()
        debounce.restart()
    }

    onFadingChanged: {
        if (!fading && closing && shown === closeTarget && !worker.running && !queued)
            done(false)
    }

    // Lands the bar's recolour partway through the image cross-fade, so
    // neither leads; also coalesces a held arrow key.
    Timer {
        id: barDebounce
        interval: 200
        onTriggered: root.writeBarColours(root.wall)
    }

    Timer {
        id: debounce
        interval: 120
        onTriggered: {
            if (root.open && root.wall && root.wall.path !== root.requested) {
                root.requested = root.wall.path
                root.run("preview", root.wall.path)
            }
        }
    }

    // If rice-wallpaper hangs, close anyway rather than trap the keyboard.
    Timer {
        id: safety
        interval: 2500
        onTriggered: if (root.closing) root.done(true)
    }

    Process {
        id: worker
        onExited: {
            if (root.current && root.current.kind === "preview")
                root.shown = root.current.path
            root.current = null
            if (root.closing && root.shown === root.closeTarget && !root.queued)
                root.done(false)
            Qt.callLater(root.drain)
        }
    }

    Process {
        id: lister
        command: [root.bin + "rice-wallpaper", "palettes"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text)
                    root.original = data.current
                    root.requested = data.current
                    root.shown = data.current
                    root.walls = data.walls
                    root.index = Math.max(0, data.walls.findIndex(w => w.path === data.current))
                } catch (e) {
                    console.warn("WallpaperCarousel: bad list:", e)
                }
                root.loading = false
            }
        }
    }

    FileView {
        id: barCss
        path: root.home + "/.local/share/desktop-profiles/sayconlun/support/waybar/colors.css"
        preload: false
        atomicWrites: false            // written in place, like matugen does
    }

    // The previewed image laid out on the WHOLE output, cropped the way awww
    // crops. Both windows use it; same source and size share one decode.
    //
    // A real cross-fade: the image on screen stays fully opaque while the next
    // one fades in ON TOP of it, and only once that image has decoded - the
    // big wallpapers take longer than the fade, so fading an empty slot made
    // the picture pop in. Browsing on mid-fade stacks the next one above, and
    // everything underneath is dropped once the top one is fully in.
    component Backdrop: Item {
        id: backdrop

        property bool reports: false   // the overlay's copy: closing waits for its fade
        property bool settled: true
        property bool revealedOnce: false
        property int stack: 0

        onSettledChanged: if (reports) root.fading = !settled

        function settle(i) {
            for (let j = 0; j < slots.count; j++) {
                const s = slots.itemAt(j)
                if (s && j !== i)
                    s.opacity = 0
            }
            revealedOnce = true
            settled = true
        }

        Repeater {
            id: slots
            model: root.walls

            Loader {
                id: slot
                required property var modelData
                required property int index
                readonly property bool isShown: index === root.index
                readonly property bool ready: item !== null
                    && (item.status === Image.Ready || item.status === Image.Error)

                anchors.fill: parent
                active: isShown || Math.abs(index - root.index) <= 1 || opacity > 0
                visible: opacity > 0
                opacity: 0

                function target() {
                    z = ++backdrop.stack
                    backdrop.settled = false
                    reveal()
                }

                function reveal() {
                    if (!isShown || !ready || fadeIn.running)
                        return
                    if (opacity >= 1) {
                        backdrop.settle(index)
                        return
                    }
                    // The first image rides the overlay's own fade-in.
                    fadeIn.duration = backdrop.revealedOnce ? root.fadeMs : 180
                    fadeIn.start()
                }

                Component.onCompleted: if (isShown) target()
                onIsShownChanged: isShown ? target() : fadeIn.stop()
                onReadyChanged: reveal()

                NumberAnimation {
                    id: fadeIn
                    target: slot
                    property: "opacity"
                    to: 1
                    easing.type: Easing.InOutQuad
                    onFinished: if (slot.isShown) backdrop.settle(slot.index)
                }

                sourceComponent: Image {
                    source: "file://" + slot.modelData.path
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: slot.width
                    sourceSize.height: slot.height
                }
            }
        }
    }

    // Under the bar. Created with the overlay, not on the first move: a Loader
    // made mid-browse starts at full opacity and pops in ahead of the backdrop's
    // cross-fade. Made up front it shows what awww shows, then fades in step.
    LazyLoader {
        active: root.open && root.barInset > 0

        PanelWindow {
            screen: root.targetScreen
            anchors {
                top: true
                left: true
                right: true
            }
            implicitHeight: root.barInset
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "rice-wallpaper-strip"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Backdrop {
                width: parent.width
                height: root.targetScreen ? root.targetScreen.height : parent.height
            }
        }
    }

    LazyLoader {
        active: root.open

        PanelWindow {
            screen: root.targetScreen
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            // Out of the bar's exclusive zone, so the bar stays visible.
            exclusionMode: ExclusionMode.Normal
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "rice-wallpaper"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            Item {
                id: stage
                // The window starts below the bar's zone; awww crops to the
                // whole output, so the backdrop is shifted up by the zone.
                readonly property real topInset: root.targetScreen ? Math.max(0, root.targetScreen.height - height) : 0
                onTopInsetChanged: root.barInset = topInset

                anchors.fill: parent
                focus: true
                opacity: 0
                Component.onCompleted: {
                    root.barInset = topInset
                    forceActiveFocus()
                    opacity = 1
                }
                Behavior on opacity {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }

                Keys.onPressed: event => {
                    event.accepted = true
                    if (root.closing)
                        return
                    switch (event.key) {
                    case Qt.Key_Left: case Qt.Key_H: case Qt.Key_A:
                        root.step(-1); break
                    case Qt.Key_Right: case Qt.Key_L: case Qt.Key_D:
                        root.step(1); break
                    case Qt.Key_Home:
                        root.index = 0; break
                    case Qt.Key_End:
                        root.index = root.walls.length - 1; break
                    case Qt.Key_Return: case Qt.Key_Enter: case Qt.Key_Space:
                        root.commit(); break
                    case Qt.Key_Escape: case Qt.Key_Q:
                        root.cancel(); break
                    default:
                        event.accepted = false
                    }
                }

                // Solid ground, so a cross-fade never lets the windows show through.
                Rectangle {
                    anchors.fill: parent
                    color: root.c("surface")
                }

                Backdrop {
                    reports: true
                    x: 0
                    y: -stage.topInset
                    width: stage.width
                    height: stage.height + stage.topInset
                }

                Rectangle {
                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                    }
                    height: parent.height * 0.5
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.55) }
                    }
                }

                Rectangle {
                    id: card
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 56
                    width: Math.min(parent.width - 120, 1640)
                    height: 380
                    radius: 30
                    color: Theme.alpha(root.c("surface_container"), 0.86)
                    border.width: 1
                    border.color: Theme.alpha(root.c("outline_variant"), 0.7)
                    Behavior on color {
                        ColorAnimation { duration: 300 }
                    }

                    WheelHandler {
                        onWheel: event => {
                            const d = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
                            root.step(d > 0 ? -1 : 1)
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 26
                        spacing: 14

                        ListView {
                            id: strip
                            readonly property int itemWidth: 300

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            orientation: ListView.Horizontal
                            interactive: false        // index is driven by keys and wheel only
                            spacing: 22
                            model: root.walls
                            currentIndex: root.index
                            highlightRangeMode: ListView.StrictlyEnforceRange
                            preferredHighlightBegin: width / 2 - itemWidth / 2
                            preferredHighlightEnd: width / 2 + itemWidth / 2
                            highlightMoveDuration: 280

                            delegate: Item {
                                id: tile
                                required property var modelData
                                required property int index
                                readonly property bool isCurrent: index === root.index

                                width: strip.itemWidth
                                height: strip.height
                                z: isCurrent ? 1 : 0

                                ClippingRectangle {
                                    anchors.centerIn: parent
                                    width: parent.width
                                    height: width * 10 / 16
                                    radius: 18
                                    color: root.c("surface_container_high")
                                    border.width: tile.isCurrent ? 3 : 0
                                    border.color: root.c("primary")
                                    scale: tile.isCurrent ? 1.22 : 0.86
                                    opacity: tile.isCurrent ? 1 : 0.55
                                    Behavior on scale {
                                        NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                                    }
                                    Behavior on opacity {
                                        NumberAnimation { duration: 240 }
                                    }

                                    Image {
                                        anchors.fill: parent
                                        source: "file://" + tile.modelData.thumb
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: tile.isCurrent ? root.commit() : root.index = tile.index
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 14

                            Text {
                                Layout.maximumWidth: 560
                                elide: Text.ElideRight
                                text: root.wall ? root.wall.name
                                    : root.loading ? "Building thumbnails and palettes…"
                                    : "No wallpapers in ~/Pictures/Wallpapers"
                                color: root.c("on_surface")
                                font.family: Theme.font
                                font.pixelSize: 21
                                font.weight: Font.DemiBold
                            }

                            Text {
                                text: root.walls.length ? `${root.index + 1} / ${root.walls.length}` : ""
                                color: root.c("on_surface_variant")
                                font.family: Theme.mono
                                font.pixelSize: 14
                            }

                            Item { Layout.fillWidth: true }

                            Row {
                                spacing: 8
                                Repeater {
                                    model: ["primary", "secondary", "tertiary", "primary_container",
                                            "surface_container_highest", "on_surface"]

                                    Rectangle {
                                        required property string modelData
                                        width: 28
                                        height: 28
                                        radius: 14
                                        color: root.c(modelData)
                                        border.width: 1
                                        border.color: Theme.alpha(root.c("on_surface"), 0.25)
                                        Behavior on color {
                                            ColorAnimation { duration: 300 }
                                        }
                                    }
                                }
                            }

                            Item { implicitWidth: 18 }

                            Text {
                                text: "←  →  browse     Enter  apply     Esc  cancel"
                                color: root.c("on_surface_variant")
                                font.family: Theme.font
                                font.pixelSize: 14
                            }
                        }
                    }
                }
            }
        }
    }
}
