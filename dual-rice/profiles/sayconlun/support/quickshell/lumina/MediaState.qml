pragma Singleton

// The media player the dashboard shows: the one picked in its player
// switcher, else whichever is playing, else the first. Position is polled -
// MPRIS does not push it - only while something is watching.
//
// Album art is the player's own, or for browser players with none, the
// YouTube thumbnail of the video they are playing (as Nisfere does).
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    property bool watched: false
    property string pinned: ""              // dbusName picked in the switcher
    property real position: 0

    readonly property var players: Array.from(Mpris.players.values)
    readonly property var player: players.find(p => p.dbusName === pinned)
        || players.find(p => p.isPlaying) || players[0] || null
    readonly property bool playing: player ? player.isPlaying : false
    readonly property string title: player ? (player.trackTitle || "Unknown title") : "Nothing playing"
    readonly property string artist: player ? (player.trackArtist || player.identity || "") : ""
    readonly property real length: {
        if (!player || !player.lengthSupported || player.length <= 0)
            return 0
        return player.length > 100000 ? player.length / 1e6 : player.length
    }
    readonly property string art: {
        if (!player)
            return ""
        if (player.trackArtUrl)
            return player.trackArtUrl
        const url = String((player.metadata || {})["xesam:url"] || "")
        const m = url.match(/(?:youtube\.com\/watch\?v=|youtu\.be\/)([\w-]{11})/)
        return m ? `https://img.youtube.com/vi/${m[1]}/hqdefault.jpg` : ""
    }

    Timer {
        interval: 500
        repeat: true
        running: root.watched && root.player !== null
        triggeredOnStart: true
        onTriggered: {
            root.player.positionChanged()
            root.position = root.player.position
        }
    }

    function toggle() {
        if (player && player.canTogglePlaying)
            player.togglePlaying()
    }

    function next() {
        if (player && player.canGoNext)
            player.next()
    }

    function previous() {
        if (player && player.canGoPrevious)
            player.previous()
    }

    function seek(seconds) {
        if (player && player.canSeek) {
            player.position = seconds
            position = seconds
        }
    }

    function pick(p) {
        pinned = p ? p.dbusName : ""
    }

    function time(seconds) {
        const s = Math.max(0, Math.floor(seconds))
        return Math.floor(s / 60) + ":" + (s % 60 < 10 ? "0" : "") + s % 60
    }
}
