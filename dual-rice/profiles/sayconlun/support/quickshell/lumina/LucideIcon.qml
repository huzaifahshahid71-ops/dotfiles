// A Lucide icon from ./icons, recoloured: the SVGs draw in currentColor, and
// IconImage tints them with `color`. (Ported from Nisfere; icons/CREDITS.md.)
import QtQuick
import QtQuick.Controls.impl
import Quickshell

IconImage {
    property string icon: ""
    property int size: 20

    // IconImage's implicit size is read-only; it follows sourceSize.
    source: icon ? Quickshell.shellDir + "/icons/" + icon + ".svg" : ""
    sourceSize.width: size
    sourceSize.height: size
    asynchronous: true
    color: Theme.on_surface
}
