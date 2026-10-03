# Source and notices

QWhiteSurGtkDecorations, version 0.1.6, pinned Git commit
`c68082c3e9019e7ea27d06fdc8d8b242c6e12961`:
https://github.com/FengZhongShaoNian/QWhiteSurGtkDecorations

The source derives from FedoraQt/QAdwaitaDecorations. Its code carries Jan
Grulich's copyright and LGPL-2.1-or-later notices; its LICENSE is retained.
The titlebutton SVG resources derive from vinceliuice/WhiteSur-gtk-theme, whose
GPL-3.0 COPYING is included separately as WhiteSur-GTK-COPYING. Preserve both
sets of notices and the actual corresponding source/resources when shipping.
Do not describe this complete resource-containing adaptation as LGPL-only.

`upstream/` retains the fetched source/resource text. `patched/` adapts only:

- Default left-side close/minimize/maximize buttons, including when no GNOME
  portal layout is available. Keep this requested layout when a portal
  supplies a different default; initialize the dark preference to false.
- Correct WaylandClient CMake component and explicit Qt DBus dependency.
- Explicit standard algorithm, QTimer and member-type includes.

Native mouse/touch dispatch, window minimize/maximize/close and dragging remain
the upstream implementation. Its Qt >= 6.10 compatibility branches are retained.
Private Qt ABI compatibility is established by compiling/loading against the
actual device SDK, not by the repository's claimed minimum version alone.
