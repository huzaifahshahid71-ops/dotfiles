#!/usr/bin/env python3
"""Prepare a temporary same-process Sumi reopen test; never edit installed QML."""
from pathlib import Path
import sys

INSTALLED = Path.home() / ".local/share/desktop-switcher/themes/sumi-deck/DotsBrowser.qml"
TARGET = Path("/tmp/huzaifah-sumi-resident-test.qml")
CLOSE = '''    function close() {
        panel.loaded        = false
        panel.layoutSettled = false
        panel.reveal        = 0
        Qt.callLater(Qt.quit)
    }
'''
IPC = '''    // Temporary Huzaifah same-process reopen diagnostic.
    IpcHandler {
        target: "huzaifahSumiTest"
        function reopenDeck(): void {
            panel.visible = true
            Qt.callLater(function() { stage.forceActiveFocus() })
        }
        function quit(): void { Qt.quit() }
    }

'''


def patch(text):
    marker = "    // ── geometry ──\n"
    if "// Huzaifah Sumi motion v3" not in text:
        raise ValueError("This test requires the current v3 Sumi update")
    if text.count(CLOSE) != 1 or text.count(marker) != 1:
        raise ValueError("Installed deck layout differs; no changes made")
    return text.replace(CLOSE, "    function close() { panel.visible = false }\n", 1).replace(marker, IPC + marker, 1)


if __name__ == "__main__":
    try:
        result = patch(INSTALLED.read_text(encoding="utf-8"))
        # Refuse preexisting links or files owned by another user in /tmp.
        if TARGET.is_symlink() or (TARGET.exists() and TARGET.stat().st_uid != INSTALLED.stat().st_uid):
            raise ValueError("Unsafe temporary target; no changes made")
        TARGET.write_text(result, encoding="utf-8")
    except (OSError, ValueError) as exc:
        sys.exit(str(exc))
    print("Prepared:", TARGET)
    print("Installed deck is untouched. Launch the test, scroll, press Esc, then use IPC reopenDeck to reopen.")
