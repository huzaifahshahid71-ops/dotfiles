#!/usr/bin/env python3
"""Build an opt-in GTK3 module and open a new, disposable Chrome profile."""
import argparse
import ctypes
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent

def validate_css():
    gtk = ctypes.CDLL('libgtk-3.so.0')
    gobj = ctypes.CDLL('libgobject-2.0.so.0')
    glib = ctypes.CDLL('libglib-2.0.so.0')
    gtk.gtk_css_provider_new.restype = ctypes.c_void_p
    gtk.gtk_css_provider_load_from_path.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.POINTER(ctypes.c_void_p)]
    gtk.gtk_css_provider_load_from_path.restype = ctypes.c_int
    gobj.g_object_unref.argtypes = [ctypes.c_void_p]
    glib.g_error_free.argtypes = [ctypes.c_void_p]
    class Error(ctypes.Structure):
        _fields_ = [('domain', ctypes.c_uint), ('code', ctypes.c_int), ('message', ctypes.c_char_p)]
    provider, error = gtk.gtk_css_provider_new(), ctypes.c_void_p()
    try:
        if not gtk.gtk_css_provider_load_from_path(provider, os.fsencode(HERE/'buttons.css'), ctypes.byref(error)):
            message = ctypes.cast(error, ctypes.POINTER(Error)).contents.message.decode() if error.value else 'unknown CSS error'
            raise RuntimeError(message)
    finally:
        if error.value: glib.g_error_free(error)
        gobj.g_object_unref(provider)

def build():
    cc = shutil.which('cc')
    if not cc: raise RuntimeError('A C compiler is required (cc).')
    validate_css()
    destination = HERE/'libcipher-gtk3.so'
    fd, name = tempfile.mkstemp(prefix='.module-', suffix='.so', dir=HERE)
    os.close(fd)
    try:
        subprocess.run([cc, '-std=c11', '-O2', '-Wall', '-Wextra', '-Werror', '-fPIC', '-shared',
                        str(HERE/'buttons.c'), '-o', name, '-ldl'], check=True, timeout=60)
        os.replace(name, destination)
    finally:
        if os.path.exists(name): os.unlink(name)
    return destination

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true', help='compile and parse CSS without opening a browser')
    args = parser.parse_args()
    module = build()
    print('PASS: GTK3 CSS parsed and module compiled.', flush=True)
    if args.check: return
    if os.geteuid() == 0: raise RuntimeError('Run the preview as your normal desktop user.')
    if os.environ.get('CIPHER_GENIE_BUTTONS') != '1' or not os.environ.get('WAYLAND_DISPLAY'):
        raise RuntimeError('Open this preview from your activated Cipher Genie desktop.')
    browser = next((shutil.which(x) for x in ['google-chrome', 'google-chrome-stable', 'chromium'] if shutil.which(x)), None)
    if not browser: raise RuntimeError('No native Chrome/Chromium executable found.')
    state = Path.home()/'.local/share/desktop-profiles/cipher-genie-session/buttons'
    state.mkdir(parents=True, exist_ok=True)
    profile = Path(tempfile.mkdtemp(prefix='chrome-controls-preview-', dir=state))
    default = profile/'Default'
    default.mkdir()
    preferences = {'browser': {'custom_chrome_frame': True, 'check_default_browser': False},
                   'extensions': {'theme': {'system_theme': 1}}}
    (default/'Preferences').write_text(json.dumps(preferences)+'\n')
    env = os.environ.copy()
    env['GTK_MODULES'] = str(module)
    env['CIPHER_GTK_PREVIEW'] = '1'
    env['CIPHER_GTK_BUTTONS_CSS'] = str(HERE/'buttons.css')
    logpath = profile/'preview.log'
    with logpath.open('w') as log:
        p = subprocess.Popen([browser, '--ozone-platform=wayland', '--gtk-version=3',
                              '--user-data-dir='+str(profile), '--no-first-run',
                              '--no-default-browser-check', '--new-window', 'about:blank'],
                             env=env, stdout=log, stderr=log, start_new_session=True)
    print('Opened separate Chrome preview. Your normal browser profile is unchanged.', flush=True)
    print('Test red close, yellow Genie minimize/Dock restore, green maximize/restore.', flush=True)
    print('If unstyled, choose GTK under Appearance inside this preview browser.', flush=True)
    print('Preview PID:', p.pid, '\nLog:', logpath, flush=True)

if __name__ == '__main__':
    try: main()
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        print('Cipher Chrome preview:', error, file=sys.stderr)
        sys.exit(1)
