#!/usr/bin/env python3
"""
Read-aloud tile - GTK3 + gtk-layer-shell.

A small overlay card shown while read-aloud.sh is playing: the sentence
currently being spoken, with a play/pause button and progress beneath it.

Sync is exact rather than estimated. read-aloud.sh renders ONE WAV PER
SENTENCE and queues them in order, so mpv's `playlist-pos` IS the sentence
index - there is no timing model to drift. Subtitles land on the sentence
boundary because they are the same boundary.

State arrives by `observe_property` over mpv's IPC socket, not by polling,
so pause and sentence changes show up immediately.

Colours are read from the matugen-generated GTK colours at startup. matugen
derives the theme from the wallpaper, so hardcoding a palette here would go
stale the next time the wallpaper rotates.

Usage: tts-tile.py <render-dir> <mpv-ipc-socket>
"""

import json
import math
import os
import re
import socket
import subprocess
import sys

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import Gdk, GLib, Gtk, GtkLayerShell, Pango  # noqa: E402

CARD_W, CARD_H = 640, 152
RADIUS = 14
MARGIN_BOTTOM = 60
BTN = 38

# Fallback palette (Sakura Ember) for when the generated colours are absent.
FALLBACK = {
    "card_bg_color": "#251f29",
    "window_fg_color": "#ebd5d3",
    "accent_color": "#cc655e",
    "headerbar_bg_color": "#382e3d",
}


def load_palette():
    """Parse @define-color out of the matugen-generated GTK3 colours."""
    path = os.path.expanduser("~/.local/share/desktop-profiles/sayconlun/support/runtime/gtk-3.0/colors.css")
    pal = dict(FALLBACK)
    try:
        with open(path) as fh:
            found = dict(re.findall(
                r"@define-color\s+(\w+)\s+(#[0-9a-fA-F]{6})", fh.read()))
        for key in pal:
            if key in found:
                pal[key] = found[key]
    except OSError:
        pass
    return pal


PAL = load_palette()
SURFACE = PAL["card_bg_color"]
TEXT = PAL["window_fg_color"]
ACCENT = PAL["accent_color"]
LINE = PAL["headerbar_bg_color"]


def _rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def _dim(h, f=0.55):
    r, g, b = _rgb(h)
    br, bg, bb = _rgb(SURFACE)
    return (br + (r - br) * f, bg + (g - bg) * f, bb + (b - bb) * f)


def _rounded(cr, x, y, w, h, r):
    cr.new_sub_path()
    cr.arc(x + w - r, y + r, r, -math.pi / 2, 0)
    cr.arc(x + w - r, y + h - r, r, 0, math.pi / 2)
    cr.arc(x + r, y + h - r, r, math.pi / 2, math.pi)
    cr.arc(x + r, y + r, r, math.pi, 3 * math.pi / 2)
    cr.close_path()


class Tile(Gtk.DrawingArea):
    """The whole card, drawn in cairo so no GTK theme can bleed into it."""

    def __init__(self, on_toggle):
        super().__init__()
        self.text = "Preparing audio..."
        self.paused = False
        self.pos = 0
        self.total = 0
        self.on_toggle = on_toggle
        self.set_size_request(CARD_W, CARD_H)
        self.add_events(Gdk.EventMask.BUTTON_PRESS_MASK
                        | Gdk.EventMask.POINTER_MOTION_MASK)
        self.connect("draw", self._draw)
        self.connect("button-press-event", self._click)
        self.connect("motion-notify-event", self._motion)
        self._hover = False

    def update(self, **kw):
        for k, v in kw.items():
            setattr(self, k, v)
        self.queue_draw()

    # -- button geometry, shared by drawing and hit-testing -------------
    def _btn_rect(self):
        return 22, CARD_H - 22 - BTN, BTN, BTN

    def _in_btn(self, x, y):
        bx, by, bw, bh = self._btn_rect()
        return bx <= x <= bx + bw and by <= y <= by + bh

    def _click(self, _w, ev):
        if self._in_btn(ev.x, ev.y):
            self.on_toggle()
        return True

    def _motion(self, _w, ev):
        hover = self._in_btn(ev.x, ev.y)
        if hover != self._hover:
            self._hover = hover
            win = self.get_window()
            if win:
                win.set_cursor(Gdk.Cursor.new_from_name(
                    win.get_display(), "pointer" if hover else "default"))
            self.queue_draw()
        return True

    def _draw(self, _w, cr):
        _rounded(cr, 1, 1, CARD_W - 2, CARD_H - 2, RADIUS)
        cr.set_source_rgb(*_rgb(SURFACE))
        cr.fill_preserve()
        cr.set_source_rgb(*_rgb(ACCENT))
        cr.set_line_width(2)
        cr.stroke()

        # -- subtitle. Pango handles wrapping; ellipsize keeps a long
        # -- sentence from pushing the controls out of the card.
        layout = self.create_pango_layout(self.text)
        layout.set_font_description(Pango.FontDescription("Inter Variable 13"))
        layout.set_width((CARD_W - 44) * Pango.SCALE)
        layout.set_wrap(Pango.WrapMode.WORD_CHAR)
        layout.set_ellipsize(Pango.EllipsizeMode.END)
        layout.set_height(-3)
        cr.set_source_rgb(*_rgb(TEXT))
        cr.move_to(22, 18)
        from gi.repository import PangoCairo
        PangoCairo.show_layout(cr, layout)

        # -- play / pause button
        bx, by, bw, bh = self._btn_rect()
        cr.arc(bx + bw / 2, by + bh / 2, bw / 2, 0, 2 * math.pi)
        cr.set_source_rgb(*(_rgb(ACCENT) if self._hover else _dim(ACCENT, 0.85)))
        cr.fill()
        cx, cy = bx + bw / 2, by + bh / 2
        cr.set_source_rgb(*_rgb(SURFACE))
        if self.paused:
            cr.move_to(cx - 5, cy - 8)
            cr.line_to(cx + 8, cy)
            cr.line_to(cx - 5, cy + 8)
            cr.close_path()
            cr.fill()
        else:
            cr.rectangle(cx - 6, cy - 8, 4.5, 16)
            cr.rectangle(cx + 1.5, cy - 8, 4.5, 16)
            cr.fill()

        # -- counter, right aligned on the control row
        label = f"{min(self.pos + 1, self.total)}/{self.total}" if self.total else ""
        cr.select_font_face("Inter Variable")
        cr.set_font_size(12)
        cr.set_source_rgb(*_dim(TEXT, 0.7))
        ext = cr.text_extents(label)
        cr.move_to(CARD_W - 22 - ext.width, cy + 4)
        cr.show_text(label)

        # -- progress bar between button and counter
        px = bx + bw + 16
        pw = CARD_W - 22 - ext.width - 14 - px
        ph = 5
        py = cy - ph / 2
        if pw > 20:
            _rounded(cr, px, py, pw, ph, ph / 2)
            # Not LINE: in some generated palettes headerbar_bg_color is
            # identical to card_bg_color, which hides the track entirely.
            cr.set_source_rgb(*_dim(TEXT, 0.20))
            cr.fill()
            frac = (self.pos + 1) / self.total if self.total else 0
            frac = max(0.0, min(1.0, frac))
            if frac > 0:
                _rounded(cr, px, py, max(ph, pw * frac), ph, ph / 2)
                cr.set_source_rgb(*_rgb(ACCENT))
                cr.fill()
        return False


class TtsTile:
    def __init__(self, rdir, sock_path):
        self.rdir = rdir
        self.sock_path = sock_path
        self.sentences = []
        self.sock = None
        self.buf = b""
        self._load_sentences()

        self.tile = Tile(self.toggle)
        self.win = Gtk.Window(type=Gtk.WindowType.TOPLEVEL)
        self.win.set_app_paintable(True)
        visual = self.win.get_screen().get_rgba_visual()
        if visual:
            self.win.set_visual(visual)

        GtkLayerShell.init_for_window(self.win)
        GtkLayerShell.set_layer(self.win, GtkLayerShell.Layer.OVERLAY)
        # ON_DEMAND, not NONE: the button needs pointer input. The input
        # region is left alone deliberately - setting an input shape here
        # clipped the rendering last time.
        GtkLayerShell.set_keyboard_mode(self.win, GtkLayerShell.KeyboardMode.NONE)
        GtkLayerShell.set_anchor(self.win, GtkLayerShell.Edge.BOTTOM, True)
        GtkLayerShell.set_margin(self.win, GtkLayerShell.Edge.BOTTOM, MARGIN_BOTTOM)
        GtkLayerShell.set_namespace(self.win, "tts-tile")
        name = self._focused_output()
        if name:
            mon = self._gdk_monitor(name)
            if mon:
                GtkLayerShell.set_monitor(self.win, mon)
        self.win.add(self.tile)
        self.win.show_all()

        self.tile.update(total=len(self.sentences))
        GLib.timeout_add(200, self._connect)

    def _focused_output(self):
        try:
            out = subprocess.run(["hyprctl", "monitors", "-j"],
                                 capture_output=True, text=True, timeout=1).stdout
            for m in json.loads(out):
                if m.get("focused"):
                    return m.get("name")
        except Exception:
            pass
        return None

    def _gdk_monitor(self, name):
        display = Gdk.Display.get_default()
        for i in range(display.get_n_monitors()):
            mon = display.get_monitor(i)
            if mon.get_model() == name:
                return mon
        return None

    def _load_sentences(self):
        try:
            with open(os.path.join(self.rdir, "sentences.json")) as fh:
                self.sentences = json.load(fh)
        except OSError:
            self.sentences = []

    # -- mpv IPC -------------------------------------------------------
    def _connect(self):
        if not os.path.exists(self.sock_path):
            return True                      # mpv not up yet; keep waiting
        try:
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.connect(self.sock_path)
        except OSError:
            return True
        self.sock = s
        for i, prop in enumerate(("playlist-pos", "pause"), start=1):
            self._send({"command": ["observe_property", i, prop]})
        ch = GLib.IOChannel.unix_new(s.fileno())
        ch.set_encoding(None)
        ch.set_flags(GLib.IOFlags.NONBLOCK)
        GLib.io_add_watch(ch, GLib.PRIORITY_DEFAULT,
                          GLib.IOCondition.IN | GLib.IOCondition.HUP,
                          self._on_data)
        return False

    def _send(self, obj):
        if not self.sock:
            return
        try:
            self.sock.sendall((json.dumps(obj) + "\n").encode())
        except OSError:
            Gtk.main_quit()

    def toggle(self):
        self._send({"command": ["cycle", "pause"]})

    def _on_data(self, _ch, cond):
        if cond & GLib.IOCondition.HUP:
            Gtk.main_quit()
            return False
        try:
            data = self.sock.recv(65536)
        except OSError:
            return True
        if not data:                          # mpv exited - playback is over
            Gtk.main_quit()
            return False
        self.buf += data
        while b"\n" in self.buf:
            line, self.buf = self.buf.split(b"\n", 1)
            if line.strip():
                self._handle(line)
        return True

    def _handle(self, line):
        try:
            msg = json.loads(line)
        except ValueError:
            return
        if msg.get("event") != "property-change":
            return
        name, value = msg.get("name"), msg.get("data")
        if name == "pause":
            self.tile.update(paused=bool(value))
        elif name == "playlist-pos" and isinstance(value, int) and value >= 0:
            # Sentences may still be rendering, so re-read the manifest when
            # playback runs past what we last loaded.
            if value >= len(self.sentences):
                self._load_sentences()
            text = (self.sentences[value] if value < len(self.sentences)
                    else "...")
            self.tile.update(text=text, pos=value, total=len(self.sentences))


def main():
    if len(sys.argv) < 3:
        print("usage: tts-tile.py <render-dir> <mpv-ipc-socket>", file=sys.stderr)
        return 1
    TtsTile(sys.argv[1], sys.argv[2])
    Gtk.main()
    return 0


if __name__ == "__main__":
    sys.exit(main())
