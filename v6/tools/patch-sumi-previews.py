#!/usr/bin/env python3
"""Add screenshots to locally installed Sumi Deck; never vendor upstream QML."""
from pathlib import Path
import sys

MARKER = "// Huzaifah Sumi desktop previews v1"
ART = r'''                        // Huzaifah Sumi desktop previews v1
                        // Assets match this 440x240 interior, with rounded alpha corners.
                        // This avoids shader effects and works with software rendering too.
                        Image {
                            id: desktopPreview
                            anchors.fill: parent
                            source: item.entry
                                    ? panel.previewFor(item.entry.name) : ""
                            fillMode: Image.PreserveAspectCrop
                            horizontalAlignment: Image.AlignHCenter
                            verticalAlignment: Image.AlignVCenter
                            sourceSize.width: 1320
                            sourceSize.height: 720
                            asynchronous: true
                            cache: true
                            smooth: true
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            visible: desktopPreview.status === Image.Ready
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "#14000000" }
                                GradientStop { position: 0.48; color: "#10000000" }
                                GradientStop { position: 0.70; color: "#78000000" }
                                GradientStop { position: 1.0; color: "#e6000000" }
                            }
                        }

'''


def patch(text):
    if MARKER in text:
        if text.count(MARKER) != 1 or 'panel.previewFor(item.entry.name)' not in text:
            raise ValueError("Incomplete existing preview patch; no changes made")
        return text
    if 'HUZAIFAH · SUMI DECK' not in text or 'multi-rice-control' not in text:
        raise ValueError("This is not the expected Huzaifah Sumi Deck; no changes made")
    icon = "                        // icon art\n                        Text {\n"
    badge = "                            color: Qt.rgba(panel.accent.r, panel.accent.g, panel.accent.b, 0.22)"
    for anchor in ("import QtQuick\n", icon, badge, "    // ── geometry ──\n"):
        if text.count(anchor) != 1:
            raise ValueError("Sumi Deck layout differs from the pinned version; no changes made")
    # The rounded artwork is generated for the exact pinned card dimensions.
    for geometry in ("focusedW:   460", "focusedH:   260", "anchors.margins: 10\n                        radius: 6"):
        if geometry not in text:
            raise ValueError("Card geometry changed; refusing mismatched rounded artwork")
    helper = '''    // Resolve by backend profile ID, so the catalog remains dynamic.
    function previewFor(profileId) {
        var id = String(profileId || "")
        if (!/^[A-Za-z0-9_-]+$/.test(id)) return ""
        return "file://" + Quickshell.env("HOME")
                + "/.local/share/desktop-switcher/previews/" + id + ".webp"
    }

'''
    text = text.replace("    // ── geometry ──\n", helper + "    // ── geometry ──\n", 1)
    text = text.replace(icon, ART + icon + "                            visible: desktopPreview.status !== Image.Ready\n"
                        + "                            color: panel.accent\n", 1)
    text = text.replace(badge, '''                            color: desktopPreview.status === Image.Ready
                                   ? Qt.rgba(panel.paper.r, panel.paper.g, panel.paper.b, 0.90)
                                   : Qt.rgba(panel.accent.r, panel.accent.g, panel.accent.b, 0.22)''', 1)
    return text


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: patch-sumi-previews.py /path/to/DotsBrowser.qml")
    path = Path(sys.argv[1]).resolve(strict=True)
    try:
        original = path.read_text(encoding="utf-8")
        updated = patch(original)
    except ValueError as exc:
        raise SystemExit(str(exc))
    if updated != original:
        path.write_text(updated, encoding="utf-8")
    print("PASS: Sumi Deck screenshot artwork patched")
