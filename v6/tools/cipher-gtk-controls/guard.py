#!/usr/bin/env python3
"""Read-only compatibility check for the private GTK3 controls."""
import ctypes
import hashlib
import json
from pathlib import Path
import runpy
import sys

HERE = Path(__file__).resolve().parent

def main():
    manifest = json.loads((HERE/'manifest.json').read_text())
    for relative, expected in manifest['sha256'].items():
        path = HERE/relative
        if path.is_symlink() or hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            raise RuntimeError('Private GTK asset changed: '+relative)
    gtk = ctypes.CDLL('libgtk-3.so.0')
    gtk.gtk_get_major_version.restype = ctypes.c_uint
    if gtk.gtk_get_major_version() != 3:
        raise RuntimeError('GTK3 is unavailable.')
    module = ctypes.CDLL(str(HERE/'libcipher-gtk3.so'))
    getattr(module, 'gtk_module_init')  # Check ABI/export; do not initialize a display.
    runpy.run_path(str(HERE/'preview.py'), run_name='gtk_css_guard')['validate_css']()

if __name__ == '__main__':
    try: main()
    except Exception as error:
        print('Cipher GTK controls unavailable:', error, file=sys.stderr)
        sys.exit(1)
