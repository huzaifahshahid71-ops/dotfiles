#!/usr/bin/env python3
"""Patch pinned upstream Revo DotsBrowser into Huzaifah "Sumi Deck".

The upstream QML itself is NOT vendored in this repository. The installer
fetches the exact pinned upstream file locally, then runs this patch.
"""

from pathlib import Path
import sys

if len(sys.argv) != 2:
    raise SystemExit("usage: patch-sumi-deck.py /path/to/DotsBrowser.qml")

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")

start = text.find("    // ── scan script ──")
apply = text.find("    function applySelected() {", start)
move = text.find("    function moveSel(delta) {", apply)

if start < 0 or apply < 0 or move < 0:
    raise SystemExit("Pinned Revo DotsBrowser layout changed; refusing unsafe patch")

scanner_and_apply = r'''    // ── Huzaifah unified profile scan ──
    Process {
        id: scannerProc
        command: [
            Quickshell.env("HOME") + "/.local/bin/multi-rice-control",
            "list"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.trim().split("\n")
                var list = []

                for (var i = 0; i < lines.length; ++i) {
                    var line = lines[i].trim()
                    if (!line)
                        continue

                    var parts = line.split("|")
                    if (parts.length < 6 || parts[4] !== "true")
                        continue

                    list.push({
                        name: parts[0],
                        title: parts[1],
                        desc: (parts[3] === "hyprland"
                               ? "Hyprland Desktop Profile"
                               : "Niri Desktop Profile"),
                        icon: parts[2],
                        isActive: parts[5] === "true"
                    })
                }

                panel.dotsArray = list

                var activeIndex = 0
                for (var j = 0; j < list.length; ++j) {
                    if (list[j].isActive) {
                        activeIndex = j
                        break
                    }
                }

                panel.selFilt = activeIndex
                panel.loaded = list.length > 0
                Qt.callLater(function() {
                    panel.layoutSettled = true
                    if (list.length > 0)
                        stage.forceActiveFocus()
                })
            }
        }
    }

    function applySelected() {
        if (!loaded || dotsArray.length === 0)
            return
        if (selFilt < 0 || selFilt >= dotsArray.length)
            return

        var item = dotsArray[selFilt]
        if (!item || !item.name)
            return

        Quickshell.execDetached([
            Quickshell.env("HOME") + "/.local/bin/multi-rice-control",
            "switch",
            item.name
        ])
        panel.close()
    }

'''

text = text[:start] + scanner_and_apply + text[move:]

text = text.replace(
    'text: "QUICKSHELL DOTS"',
    'text: "HUZAIFAH · SUMI DECK"'
)
text = text.replace(
    'text: "Quickshell Theme · " + (panel.sel ? panel.sel.title : "")',
    'text: "Desktop Profile · " + (panel.sel ? panel.sel.title : "")'
)
text = text.replace(
    'text: "Loading Quickshell Dots…"',
    'text: "Loading Huzaifah Profiles…"'
)
text = text.replace(
    'text: panel.layoutSettled && !panel.loaded\n'
    '              ? "No Quickshell dots found\\n\\nEsc or click to close"',
    'text: panel.layoutSettled && !panel.loaded\n'
    '              ? "No desktop profiles found\\n\\nEsc or click to close"'
)

marker = "    // Top Header\n"
if marker not in text:
    raise SystemExit("Pinned Revo DotsBrowser header marker changed; refusing unsafe patch")

themes_button = r'''    // Huzaifah theme picker escape hatch.
    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 34
        anchors.rightMargin: 42
        width: 118
        height: 34
        radius: 17
        color: Qt.rgba(panel.frameBg.r, panel.frameBg.g, panel.frameBg.b, 0.88)
        border.width: 1
        border.color: panel.accentDim
        opacity: panel.reveal

        Text {
            anchors.centerIn: parent
            text: "THEMES  ◐"
            color: panel.sumiHi
            font.family: panel.mono
            font.pixelSize: 11
            font.weight: Font.Medium
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Quickshell.execDetached([
                    "bash", "-lc",
                    "HUZAIFAH_SWITCHER_FORCE_PICKER=1 qs -c multi-rice-switcher"
                ])
                panel.close()
            }
        }
    }

'''

text = text.replace(marker, themes_button + marker, 1)

path.write_text(text, encoding="utf-8")
