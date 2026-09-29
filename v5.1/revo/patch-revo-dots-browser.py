#!/usr/bin/env python3
"""Patch the pinned Revo DotsBrowser to use Huzaifah's unified profile backend.

This intentionally patches the locally cloned upstream file instead of vendoring
Revo's full QML source in this repository.
"""

from pathlib import Path
import re
import sys

if len(sys.argv) != 2:
    raise SystemExit("usage: patch-revo-dots-browser.py /path/to/DotsBrowser.qml")

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")

start = text.find("    // ── scan script ──")
apply = text.find("    function applySelected() {", start)
move = text.find("    function moveSel(delta) {", apply)

if start < 0 or apply < 0 or move < 0:
    raise SystemExit("Pinned Revo DotsBrowser layout changed; refusing an unsafe patch")

scanner_and_apply = r'''    // ── unified Huzaifah/Revo profile scan ──
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

                    var kind = parts.length > 6 ? parts[6] : "desktop"
                    var shell = parts.length > 7 ? parts[7] : ""
                    var subtitle = kind === "revo-shell"
                        ? "Revo Shell" + (shell ? " · " + shell : "")
                        : "Huzaifah Profile · " + parts[3]

                    list.push({
                        name: parts[0],
                        title: parts[1],
                        desc: subtitle,
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
text = text.replace('text: "QUICKSHELL DOTS"', 'text: "REVO × HUZAIFAH"')
text = text.replace(
    'text: "Quickshell Theme · " + (panel.sel ? panel.sel.title : "")',
    'text: "Desktop Profile · " + (panel.sel ? panel.sel.title : "")'
)
text = text.replace(
    'text: "Loading Quickshell Dots…"',
    'text: "Loading Desktop Profiles…"'
)
text = text.replace(
    'text: panel.layoutSettled && !panel.loaded\n              ? "No Quickshell dots found\\n\\nEsc or click to close"',
    'text: panel.layoutSettled && !panel.loaded\n              ? "No desktop profiles found\\n\\nEsc or click to close"'
)

path.write_text(text, encoding="utf-8")
