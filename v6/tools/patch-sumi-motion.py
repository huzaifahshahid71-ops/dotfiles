#!/usr/bin/env python3
"""Patch only locally fetched Sumi QML: circular navigation and preview warmup."""
from pathlib import Path
import sys

MARKER = "// Huzaifah Sumi motion v1"
WARMUP = r'''    // Huzaifah Sumi motion v1
    property bool previewsWarm: false
    // Decode at twice the card size; keep the original high-resolution assets.
    readonly property int previewWidth: 880
    readonly property int previewHeight: 480

    // Nonzero, one-pixel surfaces prime scene-graph textures as well as decoding.
    // Keep their Image objects alive so every card reuses the same cached image.
    Item {
        width: 1
        height: 1
        opacity: panel.previewsWarm ? 0 : 0.001
        Repeater {
            id: previewWarmers
            model: panel.dotsArray.length
            delegate: Image {
                required property int index
                width: 1
                height: 1
                source: panel.previewFor(panel.dotsArray[index].name)
                sourceSize.width: panel.previewWidth
                sourceSize.height: panel.previewHeight
                asynchronous: true
                cache: true
            }
        }
    }

    // Yield to rendering after all images are ready (or missing), before reveal.
    FrameAnimation {
        running: panel.loaded && panel.layoutSettled && !panel.previewsWarm
        property int settledFrames: 0
        onTriggered: {
            for (var i = 0; i < previewWarmers.count; ++i) {
                var image = previewWarmers.itemAt(i)
                if (!image || image.status === Image.Loading ||
                        (image.status === Image.Null && String(image.source).length > 0)) {
                    settledFrames = 0
                    return
                }
            }
            if (++settledFrames >= 3)
                panel.previewsWarm = true
        }
    }

    // Keep neighboring cards on the shorter side of the circular catalog.
    function relativeIndex(index) {
        var count = dotsArray.length
        if (count === 0) return 0
        var offset = (index - selFilt + count) % count
        return offset > Math.floor(count / 2) ? offset - count : offset
    }

'''


def replace_once(text, old, new):
    if text.count(old) != 1:
        raise ValueError("Unexpected Sumi Deck layout; no changes made")
    return text.replace(old, new, 1)


def patch(text):
    if MARKER in text:
        if text.count(MARKER) != 1 or "panel.relativeIndex(index)" not in text:
            raise ValueError("Incomplete Sumi motion patch; no changes made")
        return text
    if "// Huzaifah Sumi desktop previews v1" not in text:
        raise ValueError("Install the Sumi preview patch before the motion patch")
    text = replace_once(text, "    readonly property bool ready: loaded && layoutSettled",
                        "    readonly property bool ready: loaded && layoutSettled && previewsWarm")
    text = replace_once(text, "    // ── geometry ──\n", WARMUP + "    // ── geometry ──\n")
    text = replace_once(text,
                        "selFilt = Math.max(0, Math.min(dotsArray.length - 1, selFilt + delta))",
                        "selFilt = ((selFilt + delta) % dotsArray.length + dotsArray.length) % dotsArray.length")
    text = replace_once(text, "relIdx:  index - panel.selFilt", "relIdx:  panel.relativeIndex(index)")
    text = replace_once(text, "sourceSize.width: 1320", "sourceSize.width: panel.previewWidth")
    text = replace_once(text, "sourceSize.height: 720", "sourceSize.height: panel.previewHeight")
    # Recycling the darkest far card must not sweep it across the focused card.
    text = replace_once(text,
        "Behavior on angle { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }",
        "Behavior on angle {\n"
        "                        enabled: Math.abs(item.relIdx) < Math.min(panel.maxVisible, Math.floor(panel.dotsArray.length / 2))\n"
        "                        NumberAnimation { duration: 280; easing.type: Easing.OutCubic }\n"
        "                    }")
    text = replace_once(text, "    onReadyChanged: reveal = ready ? 1 : 0",
        "    onReadyChanged: {\n"
        "        reveal = ready ? 1 : 0\n"
        "        if (ready) Qt.callLater(function() { stage.forceActiveFocus() })\n"
        "    }")
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
    print("PASS: circular Sumi navigation and preview warmup patched")
