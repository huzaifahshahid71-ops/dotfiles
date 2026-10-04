"""Bounded JSON-lines connection to the verified payload's backend."""
import json
import os
from pathlib import Path
import selectors
import signal
import subprocess
import time

from core import PROFILES, SetupError, verified
from maintenance import inspect_receipt, write_json


def install(image, manifest, cache, home, callback):
    if not verified(image, manifest["image"], callback):
        raise SetupError("The AppImage changed after preparation; installation stopped.")
    options = {"protocol": 1, "version": "6.0.0", "action": "install",
               "home": str(home), "profiles": list(PROFILES),
               "hardware_changes": False, "grub": False, "remove_packages": False}
    options_path = cache.path("options.json")
    write_json(options_path, options)
    env = dict(os.environ, APPIMAGE_EXTRACT_AND_RUN="1")
    process = subprocess.Popen([str(image), "--multi-rice-backend", str(options_path)],
                               stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, env=env, start_new_session=True)
    result = None
    selector = selectors.DefaultSelector()
    selector.register(process.stdout, selectors.EVENT_READ)
    pending = b""
    started = time.monotonic()
    try:
        with cache.path("install.log").open("ab") as log:
            while selector.get_map():
                if time.monotonic() - started > 3600:
                    raise SetupError("Installation exceeded one hour; check the retained log and backup.")
                for key, _ in selector.select(timeout=1):
                    block = os.read(key.fileobj.fileno(), 65536)
                    if not block:
                        selector.unregister(key.fileobj)
                        if pending:
                            raise SetupError("The backend emitted an incomplete progress record.")
                        break
                    log.write(block)
                    log.flush()
                    pending += block
                    if len(pending) > 2 * 1024 * 1024:
                        raise SetupError("The backend emitted an oversized progress record.")
                    while b"\n" in pending:
                        line, pending = pending.split(b"\n", 1)
                        try:
                            event = json.loads(line)
                        except (ValueError, UnicodeError) as error:
                            raise SetupError("The payload does not implement the v6 single-window protocol.") from error
                        if not isinstance(event, dict) or event.get("protocol") != 1 or not isinstance(event.get("message"), str):
                            raise SetupError("Invalid backend progress record.")
                        callback(event)
                        if event.get("result") == "installed":
                            if result:
                                raise SetupError("Duplicate installation result.")
                            result = event
            code = process.wait(timeout=15)
        if code != 0 or not result:
            raise SetupError("Installation did not report success. Retained log: " + str(cache.path("install.log")))
        inspect_receipt(Path(result["receipt"]), home)
        # Successful-operation logs belong with recovery state, not disposable
        # downloads. Retain the receipt and log after the cleanup checkbox.
        import shutil
        shutil.copyfile(cache.path("install.log"), Path(result["receipt"]).parent / "install.log")
        return result
    finally:
        selector.close()
        if process.poll() is None:
            os.killpg(process.pid, signal.SIGTERM)
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
        process.stdout.close()
