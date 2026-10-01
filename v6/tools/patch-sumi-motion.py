#!/usr/bin/env python3
"""Patch locally fetched Sumi QML with continuous, buffered circular motion."""
from pathlib import Path
import sys

MARKER = "// Huzaifah Sumi motion v2"
MOTION = r'''    // Huzaifah Sumi motion v2
    property bool previewsWarm: false
    readonly property int previewWidth: 880
    readonly property int previewHeight: 480
    readonly property int slotCount: 2 * maxVisible + 5
    readonly property int leftRadius: Math.min(maxVisible, Math.floor((dotsArray.length - 1) / 2))
    readonly property int rightRadius: Math.min(maxVisible, Math.floor(dotsArray.length / 2))
    property int scrollTarget: 0
    property real visualPosition: scrollTarget
    property real wheelCarry: 0
    onSelFiltChanged: {
        if (!previewsWarm) scrollTarget = selFilt
    }
    Behavior on visualPosition {
        enabled: panel.previewsWarm
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }

    function wrapIndex(index) {
        var count = dotsArray.length
        return count ? ((index % count) + count) % count : 0
    }

    // Pool slots recycle at +/-7.5, beyond the fading visible +/-6 fan.
    // Every slot keeps its image and identity while crossing the center.
    function virtualIndex(slot, position) {
        return slot + Math.floor((position - slot + slotCount / 2) / slotCount) * slotCount
    }

    function selectVirtual(index) {
        if (!ready || dotsArray.length === 0) return
        scrollTarget = index
        selFilt = wrapIndex(index)
    }

    function scrollWheel(wheel) {
        if (!ready) return
        var units = wheel.angleDelta.y ? wheel.angleDelta.y / 120 : wheel.pixelDelta.y / 60
        wheelCarry -= units
        var steps = wheelCarry < 0 ? Math.ceil(wheelCarry) : Math.floor(wheelCarry)
        if (steps !== 0) {
            wheelCarry -= steps
            moveSel(steps)
        }
        wheel.accepted = true
    }

    // Keep every decoded image resident even when its card is out of view.
    Item {
        visible: false
        Repeater {
            id: previewWarmers
            model: panel.dotsArray.length
            delegate: Image {
                required property int index
                source: panel.previewFor(panel.dotsArray[index].name)
                sourceSize.width: panel.previewWidth
                sourceSize.height: panel.previewHeight
                asynchronous: true
                cache: true
            }
        }
    }

    // Warm the real card scene, including focused titles, borders and textures.
    // Image.Ready alone does not mean those first-use render paths are warm.
    FrameAnimation {
        running: panel.loaded && panel.layoutSettled && !panel.previewsWarm
        property int warmIndex: 0
        property int warmFrames: 0
        property int restoreFrames: 0
        onTriggered: {
            for (var i = 0; i < previewWarmers.count; ++i) {
                var image = previewWarmers.itemAt(i)
                if (!image || image.status === Image.Loading ||
                        (image.status === Image.Null && String(image.source).length > 0))
                    return
            }
            if (warmIndex < panel.dotsArray.length) {
                panel.scrollTarget = warmIndex
                if (++warmFrames >= 2) {
                    ++warmIndex
                    warmFrames = 0
                }
                return
            }
            panel.scrollTarget = panel.selFilt
            if (++restoreFrames >= 3) panel.previewsWarm = true
        }
    }

'''

POOL = r'''                readonly property int virtualIdx: panel.virtualIndex(index, panel.visualPosition)
                readonly property int catalogIdx: panel.wrapIndex(virtualIdx)
                readonly property var entry: panel.dotsArray[catalogIdx] || null
                readonly property real relIdx: virtualIdx - panel.visualPosition
                readonly property bool focused: virtualIdx === panel.scrollTarget
                readonly property real focusAmount: Math.max(0, 1 - Math.abs(relIdx))
                readonly property real edgeAmount: Math.max(0, Math.min(1,
                    Math.min(relIdx + panel.leftRadius + 1, panel.rightRadius + 1 - relIdx)))
                readonly property bool near: edgeAmount > 0
                readonly property real effRel: Math.max(-6, Math.min(6, relIdx))
                property bool hovered: false
                property real hoverGrow: hovered && focused ? 0.045 : 0
                Behavior on hoverGrow {
                    enabled: panel.previewsWarm
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }
'''


def replace_once(text, old, new):
    if text.count(old) != 1:
        raise ValueError("Unexpected Sumi Deck layout near " + repr(old[:80]) + "; no changes made")
    return text.replace(old, new, 1)


def patch(text):
    if MARKER in text:
        if text.count(MARKER) != 1 or "panel.virtualIndex(index, panel.visualPosition)" not in text:
            raise ValueError("Incomplete Sumi motion patch; no changes made")
        return text
    if "// Huzaifah Sumi motion v1" in text:
        raise ValueError("Rebuild the pinned deck with install-switcher-themes.sh to upgrade v1")
    if "// Huzaifah Sumi desktop previews v1" not in text:
        raise ValueError("Install the Sumi preview patch before the motion patch")
    text = replace_once(text, "    readonly property bool ready: loaded && layoutSettled",
                        "    readonly property bool ready: loaded && layoutSettled && previewsWarm")
    text = replace_once(text,
        "selFilt = Math.max(0, Math.min(dotsArray.length - 1, selFilt + delta))",
        "if (ready) selectVirtual(scrollTarget + delta)")
    text = replace_once(text, 'panel.moveSel(wheel.angleDelta.y < 0 ? 1 : -1)',
                        "panel.scrollWheel(wheel)")
    text = replace_once(text, "            model: panel.dotsArray.length\n",
                        "            model: panel.dotsArray.length ? panel.slotCount : 0\n")
    old = '''                readonly property var  entry:   panel.dotsArray[index] || null
                readonly property int  relIdx:  index - panel.selFilt
                readonly property bool focused: relIdx === 0
                readonly property bool near:    Math.abs(relIdx) <= panel.maxVisible
                readonly property int  effRel:  Math.max(-6, Math.min(6, relIdx))
                property bool hovered: false
'''
    text = replace_once(text, old, POOL)
    changes = [
        ("y: Math.abs(effRel) * 7 + (focused ? -14 : 0)",
         "y: Math.abs(effRel) * 7 - 14 * focusAmount"),
        ("scale: focused ? (hovered ? 1.045 : 1.0) : 0.97",
         "scale: 0.97 + 0.03 * focusAmount + hoverGrow"),
        ("z: focused ? 100 : 50 - Math.abs(relIdx)",
         "z: 50 - Math.abs(relIdx) + 50 * focusAmount"),
        ("opacity: near ? (focused ? 1 : 0.88) : 0",
         "opacity: edgeAmount * (0.88 + 0.12 * focusAmount)"),
        ("onClicked: item.focused ? panel.applySelected() : (panel.selFilt = index)",
         "onClicked: item.focused ? panel.applySelected() : panel.selectVirtual(item.virtualIdx)"),
        ("                    hoverEnabled: true\n", "                    hoverEnabled: true\n                    enabled: panel.ready\n"),
        ("sourceSize.width: 1320", "sourceSize.width: panel.previewWidth"),
        ("sourceSize.height: 720", "sourceSize.height: panel.previewHeight"),
        ("        Keys.priority: Keys.BeforeItem\n        Keys.onPressed: function(event) {\n",
         "        Keys.priority: Keys.BeforeItem\n        Keys.onPressed: function(event) {\n"
         "            if (!panel.ready) {\n"
         "                if (event.key === Qt.Key_Escape) panel.close()\n"
         "                event.accepted = true\n"
         "                return\n"
         "            }\n"),
        ("        opacity: panel.reveal\n        anchors.centerIn: parent",
         "        opacity: panel.previewsWarm ? panel.reveal : 0.001\n        anchors.centerIn: parent"),
        ("                    id: frame\n", "                    id: frame\n                    layer.enabled: true\n                    layer.smooth: true\n"),
        ("border.width: item.focused ? 2 : 1", "border.width: 1 + item.focusAmount"),
        ("Behavior on border.color { ColorAnimation { duration: 180 } }",
         "Behavior on border.color { enabled: panel.previewsWarm; ColorAnimation { duration: 180 } }"),
        ("opacity: item.focused ? 0 : (Math.abs(item.relIdx) === 1 ? 0.36 : 0.62)",
         "opacity: (1 - item.focusAmount) * 0.36 + Math.min(1, Math.max(0, Math.abs(item.relIdx) - 1)) * 0.26"),
    ]
    # Stage and footer share a visible expression; change only the stage.
    visible_old = "        visible: panel.ready && panel.dotsArray.length > 0\n"
    if text.count(visible_old) != 2:
        raise ValueError("Unexpected stage/footer layout; no changes made")
    text = text.replace(visible_old,
        "        visible: panel.loaded && panel.layoutSettled && panel.dotsArray.length > 0\n", 1)
    for old, new in changes:
        text = replace_once(text, old, new)
    # Position drives all geometry once; per-card Behaviors would chase it each frame.
    for old in [
        "                            Behavior on opacity { NumberAnimation { duration: 200 } }\n",
        "                    Behavior on angle { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }\n",
        "                Behavior on y       { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }\n",
        "                Behavior on scale   { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }\n",
        "                Behavior on opacity { NumberAnimation { duration: 200 } }\n",
    ]:
        text = replace_once(text, old, "")
    text = replace_once(text, "    onReadyChanged: reveal = ready ? 1 : 0",
        "    onReadyChanged: {\n"
        "        reveal = ready ? 1 : 0\n"
        "        if (ready) Qt.callLater(function() { stage.forceActiveFocus() })\n"
        "    }")
    text = replace_once(text, "    // ── geometry ──\n", MOTION + "    // ── geometry ──\n")
    text = text.replace('"Loading Quickshell Dots…"', '"Loading Huzaifah Profiles…"')
    return text


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: patch-sumi-motion.py /path/to/DotsBrowser.qml")
    path = Path(sys.argv[1]).resolve(strict=True)
    try:
        original = path.read_text(encoding="utf-8")
        updated = patch(original)
    except ValueError as exc:
        raise SystemExit(str(exc))
    if updated != original:
        path.write_text(updated, encoding="utf-8")
    print("PASS: buffered continuous Sumi motion and full-card warmup patched")
