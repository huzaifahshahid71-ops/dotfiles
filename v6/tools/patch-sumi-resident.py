#!/usr/bin/env python3
"""Keep locally downloaded Sumi previews alive between normal openings."""
from pathlib import Path
import sys

MARKER = "// Huzaifah Sumi resident v1"
RESIDENT = r'''    // Huzaifah Sumi resident v1
    property bool reopenPending: false
    property bool restoringSelection: false
    property string catalogSignature: ""

    IpcHandler {
        target: "huzaifahSumiDeck"
        function reopenDeck(): void { panel.reopenDeck() }
        function shutdownDeck(): void { Qt.quit() }
    }

    function reopenDeck() {
        if (visible) {
            Qt.callLater(function() { stage.forceActiveFocus() })
            return
        }
        // Refresh active state before mapping, keeping unchanged preview objects.
        reopenPending = true
        colorReader.running = true
        scannerProc.running = true
    }

    function restoreSelection(index) {
        restoringSelection = true
        selFilt = index
        scrollTarget = index
        wheelCarry = 0
        restoringSelection = false
    }

    function updateCatalogSignature(signature) {
        if (signature === catalogSignature) return
        catalogSignature = signature
        previewsWarm = false
        previewWarmup.warmIndex = 0
        previewWarmup.warmFrames = 0
        previewWarmup.restoreFrames = 0
    }

'''


def replace_once(text, old, new):
    if text.count(old) != 1:
        raise ValueError("Unexpected Sumi resident layout near " + repr(old[:70]) + "; no changes made")
    return text.replace(old, new, 1)


def patch(text):
    if MARKER in text:
        if text.count(MARKER) != 1 or 'target: "huzaifahSumiDeck"' not in text:
            raise ValueError("Incomplete Sumi resident patch; no changes made")
        return text
    if "// Huzaifah Sumi motion v3" not in text:
        raise ValueError("Apply the current Sumi motion patch first")
    close = '''    function close() {
        panel.loaded        = false
        panel.layoutSettled = false
        panel.reveal        = 0
        Qt.callLater(Qt.quit)
    }
'''
    text = replace_once(text, close, '''    function close() {
        panel.reopenPending = false
        panel.visible = false
    }
''')
    text = replace_once(text, "    // ── geometry ──\n", RESIDENT + "    // ── geometry ──\n")
    text = replace_once(text, "        enabled: panel.previewsWarm\n        NumberAnimation { duration: 220;",
        "        enabled: panel.previewsWarm && !panel.restoringSelection\n        NumberAnimation { duration: 220;")
    text = replace_once(text, "    FrameAnimation {\n", "    FrameAnimation {\n        id: previewWarmup\n")
    text = replace_once(text, "                panel.dotsArray = list\n", '''                panel.updateCatalogSignature(JSON.stringify(list.map(function(entry) { return entry.name })))
                panel.dotsArray = list
''')
    text = replace_once(text, "                panel.selFilt = activeIndex\n", "                panel.restoreSelection(activeIndex)\n")
    text = replace_once(text, "                panel.loaded = list.length > 0\n", '''                panel.loaded = list.length > 0
                if (panel.reopenPending) {
                    panel.reopenPending = false
                    panel.visible = true
                }
''')
    # Switching profiles and leaving for THEMES retain the old process-exit behavior.
    text = replace_once(text, "        panel.close()\n    }\n\n    function moveSel", "        panel.close()\n        Qt.callLater(Qt.quit)\n    }\n\n    function moveSel")
    text = replace_once(text, "                panel.close()\n            }\n        }\n    }\n\n    // Top Header",
        "                panel.close()\n                Qt.callLater(Qt.quit)\n            }\n        }\n    }\n\n    // Top Header")
    return text


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: patch-sumi-resident.py /path/to/DotsBrowser.qml")
    path = Path(sys.argv[1]).resolve(strict=True)
    try:
        original = path.read_text(encoding="utf-8")
        updated = patch(original)
    except ValueError as exc:
        raise SystemExit(str(exc))
    if updated != original:
        path.write_text(updated, encoding="utf-8")
    print("PASS: Sumi reuse, catalog refresh, active selection, and switch/theme shutdown patched")
