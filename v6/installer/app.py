#!/usr/bin/env python3
"""The shared Sumi setup window; online and offline use the same backend."""
from __future__ import annotations
import argparse
import json
import os
from pathlib import Path
import pwd
import sys

from core import (Cache, PROFILES, SetupError, load_manifest, local_wallpapers,
                  online_wallpapers, preflight, prepare_image, external_environment)
from maintenance import inspect_receipt, root_for
from recovery import restore_installation as restore
import runner
import grub_setup

HERE = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--offline", action="store_true")
    parser.add_argument("--preflight", action="store_true", help="Run lightweight checks in the terminal")
    parser.add_argument("--restore", type=Path, help="Restore an installed v6 user configuration receipt")
    parser.add_argument("--yes", action="store_true", help="Confirm terminal restoration")
    parser.add_argument("--manifest", type=Path, default=HERE / "release.json")
    parser.add_argument("--screenshot", type=Path, help=argparse.SUPPRESS)
    args = parser.parse_args()
    home = Path(pwd.getpwuid(os.getuid()).pw_dir)
    cache = Cache(home / ".cache/huzaifah-multi-rice/v6.0.0")
    manifest, unavailable = None, ""
    try:
        manifest = load_manifest(args.manifest)
    except (OSError, ValueError, SetupError) as error:
        unavailable = str(error)
    if args.preflight:
        checks = preflight(home, cache, manifest)
        for check in checks:
            print(("PASS" if check["passed"] else "FAIL") + ": " + check["name"] + " — " + check["detail"])
        print("Payload: " + ("release manifest ready" if manifest else unavailable))
        return 0 if all(x["passed"] for x in checks) else 1
    if args.restore:
        receipt, conflicts = inspect_receipt(args.restore, home)
        if conflicts:
            raise SetupError("Restore blocked by changed files: " + ", ".join(conflicts))
        print("This restores backed-up user configuration and desktop session routes. Packages remain installed.")
        if not args.yes and input("Proceed? [y/N] ").lower() != "y":
            return 0
        print(json.dumps(restore(args.restore, home, lambda event: print(event["message"])), indent=2))
        return 0
    if not (os.environ.get("DISPLAY") or os.environ.get("WAYLAND_DISPLAY") or args.screenshot):
        raise SetupError("No graphical session. Use --preflight or --restore RECEIPT for lightweight terminal maintenance.")
    try:
        from PySide6.QtCore import Qt, QThread, Signal, QTimer
        from PySide6.QtGui import QPixmap, QFont
        from PySide6.QtWidgets import (QApplication, QMainWindow, QWidget, QHBoxLayout, QVBoxLayout,
            QLabel, QPushButton, QStackedWidget, QFrame, QGridLayout, QComboBox,
            QLineEdit, QFileDialog, QProgressBar, QPlainTextEdit, QCheckBox, QMessageBox, QScrollArea, QSizePolicy)
    except ImportError as error:
        raise SetupError("The window needs python-pyside6. On Arch/CachyOS: sudo pacman -S --needed python-pyside6. Terminal preflight/restore need only Python.") from error

    class Job(QThread):
        progress = Signal(dict)
        success = Signal(object)
        failed = Signal(str)

        def __init__(self, operation):
            super().__init__()
            self.operation = operation

        def run(self):
            try:
                self.success.emit(self.operation(self.progress.emit))
            except Exception as error:
                self.failed.emit(str(error))

    class Window(QMainWindow):
        def __init__(self):
            super().__init__()
            self.setWindowTitle("Sumi Setup · Huzaifah Multi-Rice")
            self.resize(1120, 900)
            self.setMinimumSize(940, 740)
            self.job = None
            self.image = None
            self.receipt = None
            self.page_index = 0
            self.preflight_ok = False
            self.source_folders = [str(args.manifest.resolve().parent)]
            self.setStyleSheet("""
                QMainWindow, QWidget { background:#0d0f09; color:#e2e3d8; font-size:14px; }
                QLabel#muted { color:#c5c8b9; } QLabel#eyebrow { color:#b4d088; letter-spacing:2px; }
                QLabel { background:transparent; }
                QLabel#mark { font-size:48px; font-family:serif; color:#b4d088; }
                QLabel#title { font-size:32px; font-weight:600; }
                QLabel#hero { font-size:42px; font-weight:600; }
                QFrame#sidebar { background:#151810; border-right:1px solid #33362e; }
                QFrame#card { background:#1e2019; border:1px solid #33362e; border-radius:16px; }
                QFrame#card QLabel { background:transparent; }
                QPushButton { background:#252b1d; border:1px solid #414a35; padding:11px 18px; border-radius:10px; }
                QPushButton:hover { background:#333e27; border-color:#b4d088; }
                QPushButton:focus, QComboBox:focus, QLineEdit:focus { border:2px solid #b4d088; }
                QPushButton#primary { background:#b4d088; color:#18200d; border:1px solid #b4d088; font-weight:600; }
                QPushButton#primary:hover { background:#c9e79b; }
                QPushButton:disabled { background:#1c2016; color:#767c6b; border-color:#33362e; }
                QPushButton#primary:disabled { background:#1c2016; color:#767c6b; border:1px solid #33362e; }
                QLineEdit, QComboBox { background:#1e2019; border:1px solid #414a35; padding:10px; border-radius:8px; }
                QPlainTextEdit { background:#0d0f09; border:1px solid #33362e; border-radius:8px; font-size:12px; }
                QProgressBar { background:#252b1d; border:0; border-radius:5px; text-align:center; min-height:16px; }
                QProgressBar::chunk { background:#b4d088; border-radius:5px; }
                QScrollArea { border:0; } QCheckBox { spacing:10px; }
                QCheckBox::indicator { width:20px; height:20px; border:2px solid #a2aa92; border-radius:4px; background:#151810; }
                QCheckBox::indicator:hover { border-color:#e2e3d8; }
                QCheckBox::indicator:checked { background:#b4d088; border-color:#b4d088; }
                QCheckBox::indicator:disabled { background:#1c2016; border-color:#414a35; }
            """)
            outer = QWidget()
            self.setCentralWidget(outer)
            row = QHBoxLayout(outer)
            row.setContentsMargins(0, 0, 0, 0)
            row.setSpacing(0)
            side = QFrame()
            side.setObjectName("sidebar")
            side.setFixedWidth(224)
            sidebar = QVBoxLayout(side)
            sidebar.setContentsMargins(26, 30, 20, 24)
            mark = QLabel("S.")
            mark.setObjectName("mark")
            mark.setFont(QFont("Noto Serif", 44))
            sidebar.addWidget(mark)
            sidebar.addWidget(self.label("SUMI / SETUP", "eyebrow"))
            sidebar.addWidget(self.label("Huzaifah Multi-Rice\nv6.0.0", "muted"))
            sidebar.addSpacing(34)
            self.steps = []
            for index, title in enumerate(("Welcome", "Preflight", "Wallpapers", "Prepare", "Review", "Install", "Finish")):
                label = QLabel(f"{index + 1:02d}   {title}")
                sidebar.addWidget(label)
                sidebar.addSpacing(13)
                self.steps.append(label)
            sidebar.addStretch()
            sidebar.addWidget(self.label("OFFLINE EDITION" if args.offline else "ONLINE EDITION", "eyebrow"))
            sidebar.addWidget(self.label("Twelve spaces.\nOne setup.", "muted"))
            row.addWidget(side)
            right = QWidget()
            layout = QVBoxLayout(right)
            layout.setContentsMargins(30, 28, 30, 22)
            self.stack = QStackedWidget()
            layout.addWidget(self.stack, 1)
            self.activity = self.label("Ready when you are.", "muted")
            layout.addWidget(self.activity)
            self.progress = QProgressBar()
            self.progress.setRange(0, 100)
            self.progress.setValue(0)
            self.progress.setTextVisible(False)
            layout.addWidget(self.progress)
            self.logs = QPlainTextEdit()
            self.logs.setReadOnly(True)
            self.logs.setMaximumBlockCount(1000)
            self.logs.setMaximumHeight(104)
            self.logs.hide()
            layout.addWidget(self.logs)
            foot = QHBoxLayout()
            details = QPushButton("Details")
            details.clicked.connect(lambda: self.logs.setVisible(not self.logs.isVisible()))
            foot.addWidget(details)
            foot.addStretch()
            self.back = QPushButton("Back")
            self.back.clicked.connect(self.go_back)
            foot.addWidget(self.back)
            self.next = QPushButton("Begin setup")
            self.next.setObjectName("primary")
            self.next.clicked.connect(self.advance)
            foot.addWidget(self.next)
            layout.addLayout(foot)
            row.addWidget(right, 1)
            self.welcome()
            self.checks_page()
            self.wallpaper_page()
            self.prepare_page()
            self.review_page()
            self.install_page()
            self.finish_page()
            self.show_page(0)

        def label(self, text, name=None):
            result = QLabel(text)
            result.setWordWrap(True)
            if name:
                result.setObjectName(name)
            return result

        def page(self, eyebrow, title, subtitle):
            body = QWidget()
            box = QVBoxLayout(body)
            box.setContentsMargins(0, 0, 0, 0)
            box.setSpacing(16)
            box.addWidget(self.label(eyebrow, "eyebrow"))
            box.addWidget(self.label(title, "title"))
            box.addWidget(self.label(subtitle, "muted"))
            scroll = QScrollArea()
            scroll.setWidgetResizable(True)
            scroll.setWidget(body)
            self.stack.addWidget(scroll)
            return box

        def welcome(self):
            box = self.page("YOUR DESKTOP, REIMAGINED", "Welcome to Multi-Rice.",
                            "A guided setup for twelve desktops, shared music and your own space to make them yours.")
            hero = QFrame()
            hero.setObjectName("card")
            content = QHBoxLayout(hero)
            content.setContentsMargins(22, 20, 22, 20)
            words = QVBoxLayout()
            words.addWidget(self.label("Find your rhythm.", "hero"))
            words.addWidget(self.label("Eight Hyprland profiles. Four Niri profiles.\nSwitch with Sumi Deck. Listen with Lumina Music.", "muted"))
            content.addLayout(words, 3)
            accent = self.label("12\nDESKTOPS", "title")
            accent.setAlignment(Qt.AlignCenter)
            content.addWidget(accent, 1)
            box.addWidget(hero)
            grid = QGridLayout()
            for index, (key, name) in enumerate(PROFILES.items()):
                tile = QFrame()
                tile.setObjectName("card")
                card = QVBoxLayout(tile)
                card.setContentsMargins(12, 10, 12, 10)
                artwork = HERE / "assets" / (key + ".webp")
                if artwork.exists():
                    picture = QLabel()
                    picture.setPixmap(QPixmap(str(artwork)).scaled(200, 54, Qt.KeepAspectRatioByExpanding, Qt.SmoothTransformation))
                    picture.setMinimumWidth(1)
                    picture.setSizePolicy(QSizePolicy.Ignored, QSizePolicy.Fixed)
                    picture.setFixedHeight(54)
                    picture.setMaximumHeight(54)
                    card.addWidget(picture)
                card.addWidget(self.label(name))
                card.addWidget(self.label("HYPRLAND" if index < 8 else "NIRI", "muted"))
                grid.addWidget(tile, index // 4, index % 4)
            box.addLayout(grid)
            if not manifest:
                box.addWidget(self.label("DEVELOPMENT PREVIEW · Full payload publication is pending. Preflight and recovery work independently.", "muted"))
            actions = QHBoxLayout()
            checks = QPushButton("Run preflight only")
            checks.clicked.connect(lambda: (self.show_page(1), self.check_host()))
            actions.addWidget(checks)
            recovery = QPushButton("Restore user configuration")
            recovery.clicked.connect(self.choose_restore)
            actions.addWidget(recovery)
            box.addLayout(actions)
            box.addStretch()

        def checks_page(self):
            box = self.page("01 / BEFORE WE START", "A quick system check.",
                            "Check compatibility and free space before downloading. This does not change packages or configuration.")
            self.check_results = QPlainTextEdit()
            self.check_results.setReadOnly(True)
            box.addWidget(self.check_results, 1)
            retry = QPushButton("Run checks again")
            retry.clicked.connect(self.check_host)
            box.addWidget(retry)

        def wallpaper_page(self):
            box = self.page("02 / MAKE IT YOURS", "Bring your wallpapers.",
                            "Existing images stay in place. A different image with the same name gets a checksum suffix.")
            self.wallpaper_choice = QComboBox()
            self.wallpaper_choice.addItem("Skip wallpapers", "skip")
            if args.offline:
                self.wallpaper_choice.addItem("Copy from a local folder", "local")
            else:
                self.wallpaper_choice.addItem("Download a selection · 36 images", "selection")
                self.wallpaper_choice.addItem("Download the full collection · 302 images", "full")
            box.addWidget(self.wallpaper_choice)
            self.wallpaper_source = QLineEdit()
            if args.offline:
                box.addWidget(self.label("Wallpaper source folder", "muted"))
                line = QHBoxLayout()
                line.addWidget(self.wallpaper_source)
                browse = QPushButton("Choose folder")
                browse.clicked.connect(lambda: self.browse_into(self.wallpaper_source))
                line.addWidget(browse)
                box.addLayout(line)
            box.addWidget(self.label("Destination", "muted"))
            self.wallpaper_destination = QLineEdit(str(home / "Pictures/Wallpapers"))
            line = QHBoxLayout()
            line.addWidget(self.wallpaper_destination)
            choose = QPushButton("Change")
            choose.clicked.connect(lambda: self.browse_into(self.wallpaper_destination))
            line.addWidget(choose)
            box.addLayout(line)
            box.addWidget(self.label("You can skip this step and add wallpapers later. Offline originals are kept untouched.", "muted"))
            box.addStretch()

        def prepare_page(self):
            box = self.page("03 / PREPARE THE INSTALLER", "Checked at every step.",
                            "Each part is checked with SHA-256. The parts are joined and the complete AppImage is checked again before it runs.")
            self.payload_status = self.label("Payload: " + (f"{manifest['image']['bytes'] / 1024**3:.2f} GiB · x86_64 · v6.0.0" if manifest else unavailable), "muted")
            box.addWidget(self.payload_status)
            if args.offline:
                box.addWidget(self.label("Add a folder containing the expected split parts or the assembled AppImage.", "muted"))
                self.folders = QPlainTextEdit()
                self.folders.setReadOnly(True)
                self.folders.setPlainText("\n".join(self.source_folders))
                box.addWidget(self.folders)
                add = QPushButton("Choose / scan parts folder")
                add.clicked.connect(self.add_folder)
                box.addWidget(add)
            else:
                box.addWidget(self.label("A matching cached image is reused after verification. Interrupted part downloads can resume.", "muted"))
            box.addWidget(self.label("Cache: " + str(cache.root), "muted"))
            box.addStretch()

        def review_page(self):
            box = self.page("04 / REVIEW YOUR SETUP", "Everything in its place.",
                            "Your current managed user configuration is backed up before replacement. The recovery tool remains after cleanup.")
            box.addWidget(self.label("12 desktop profiles\nSumi Deck profile switcher · 74 LOGIN cards · 8 GRUB theme cards\nShared Lumina Music · Super + Shift + M\nProfile-scoped refresh and wallpaper helpers"))
            box.addWidget(self.label("GRUB boot menu", "eyebrow"))
            self.grub_choice = QComboBox()
            self.grub_choice.setObjectName("grub_choice")
            self.grub_choice.addItem("Keep current GRUB appearance", "")
            for identifier, title in grub_setup.THEMES:
                self.grub_choice.addItem("Apply Evangelion · " + title, identifier)
            detected = grub_setup.available()
            self.grub_choice.setEnabled(detected)
            box.addWidget(self.grub_choice)
            box.addWidget(self.label("Existing GRUB detected. A selected theme is applied after desktop installation, with a separate authentication prompt and Evangelion backup. Restore the theme through Sumi Deck before restoring a newly installed theme manager."
                                    if detected else "No existing GRUB installation detected. Theme cards are included; bootloader installation is separate.", "muted"))
            advanced = QPushButton("Advanced options ▸")
            box.addWidget(advanced)
            panel = self.label("Hardware and kernel changes stay opt-in. This setup does not apply device recipes.\nGRUB theme configuration uses your existing bootloader; it does not install a bootloader or change firmware boot entries.", "muted")
            panel.hide()
            advanced.clicked.connect(lambda: panel.setVisible(not panel.isVisible()))
            box.addWidget(panel)
            self.confirm = QCheckBox("Back up and replace the managed desktop configuration")
            self.confirm.setObjectName("confirm_install")
            self.confirm.toggled.connect(lambda checked: self.show_page(self.page_index) if self.page_index == 4 else None)
            box.addWidget(self.confirm)
            self.confirm_hint = self.label("Tick the confirmation above to enable Back up & install.", "muted")
            box.addWidget(self.confirm_hint)
            box.addStretch()

        def install_page(self):
            box = self.page("05 / INSTALLING", "Your new spaces are taking shape.",
                            "Keep this window open while setup runs. Progress comes from the installer; authentication uses your system prompt.")
            box.addWidget(self.label("Desktop installation and the optional GRUB theme step report their outcomes separately.", "muted"))
            box.addStretch()

        def finish_page(self):
            box = self.page("06 / THANK YOU", "Welcome to your new desktop.",
                            "Thanks for installing Huzaifah Multi-Rice. Your backup and recovery tools remain available.")
            self.finish_result = self.label("")
            box.addWidget(self.finish_result)
            self.cleanup = QCheckBox("Remove downloaded installer files after closing")
            box.addWidget(self.cleanup)
            box.addWidget(self.label("Cleanup preserves wallpapers, installation backups, installed profiles and offline source files.", "muted"))
            restart = QPushButton("Reboot now…")
            restart.clicked.connect(self.reboot)
            box.addWidget(restart)
            box.addStretch()

        def browse_into(self, edit):
            folder = QFileDialog.getExistingDirectory(self, "Choose folder", str(home))
            if folder:
                edit.setText(folder)

        def add_folder(self):
            folder = QFileDialog.getExistingDirectory(self, "Choose parts folder", str(home))
            if folder and folder not in self.source_folders:
                self.source_folders.append(folder)
                lines = []
                for source in self.source_folders:
                    lines.append(source)
                    if manifest:
                        for item in [manifest["image"], *manifest["parts"]]:
                            candidate = Path(source) / item["asset"]
                            if candidate.exists():
                                lines.append("  Found · " + candidate.name + " (checksum checked during preparation)")
                self.folders.setPlainText("\n".join(lines))

        def show_page(self, index):
            self.page_index = index
            self.stack.setCurrentIndex(index)
            for step, label in enumerate(self.steps):
                label.setStyleSheet("color:#b4d088;font-weight:600" if step == index else "color:#a2aa92")
            self.back.setEnabled(index in (1, 2, 3, 4) and self.job is None)
            titles = ("Begin setup", "Continue", "Continue", "Prepare verified image", "Back up & install", "Installing…", "Finish / Later")
            self.next.setText(titles[index])
            enabled = (index != 5 and self.job is None)
            if index == 1:
                enabled = enabled and self.preflight_ok
            if index == 3:
                enabled = enabled and manifest is not None
            if index == 4:
                enabled = enabled and self.confirm.isChecked()
                self.confirm_hint.setVisible(not self.confirm.isChecked())
            self.next.setEnabled(enabled)

        def go_back(self):
            if not self.job:
                self.show_page(max(0, self.page_index - 1))

        def start_job(self, operation, success):
            if self.job:
                return
            self.back.setEnabled(False)
            self.next.setEnabled(False)
            self.progress.setRange(0, 0)
            job = Job(operation)
            self.job = job
            job.progress.connect(self.update_progress)
            job.success.connect(lambda result: self.complete_job(job, success, result))
            job.failed.connect(lambda error: self.fail_job(job, error))
            job.start()

        def complete_job(self, job, success, result):
            job.wait()
            self.job = None
            job.deleteLater()
            self.progress.setRange(0, 100)
            self.progress.setValue(100)
            success(result)
            self.show_page(self.page_index)

        def fail_job(self, job, error):
            job.wait()
            self.job = None
            job.deleteLater()
            self.progress.setRange(0, 100)
            self.progress.setValue(0)
            self.activity.setText("Setup stopped. Your downloads and backups are retained.")
            self.logs.appendPlainText(error)
            self.logs.show()
            if self.page_index == 5:
                self.show_page(4)
            else:
                self.show_page(self.page_index)
            QMessageBox.warning(self, "Setup stopped", error)

        def update_progress(self, event):
            self.activity.setText(event.get("message", "Working…"))
            total, done = event.get("total", 0), event.get("completed", 0)
            if type(total) is int and type(done) is int and total > 0:
                self.progress.setRange(0, 1000)
                self.progress.setValue(min(1000, max(0, done * 1000 // total)))
            else:
                self.progress.setRange(0, 0)
            self.logs.appendPlainText(event.get("stage", "setup") + ": " + event.get("message", ""))

        def check_host(self):
            def done(checks):
                self.preflight_ok = all(x["passed"] for x in checks)
                self.check_results.setPlainText("\n\n".join(("PASS  " if x["passed"] else "CHECK  ") + x["name"] + "\n" + x["detail"] for x in checks))
                self.activity.setText("Preflight passed." if self.preflight_ok else "Resolve the checks above, then run preflight again.")
            self.start_job(lambda callback: preflight(home, cache, manifest), done)

        def advance(self):
            if self.job:
                return
            index = self.page_index
            if index == 0:
                self.show_page(1)
                self.check_host()
            elif index == 1 and self.preflight_ok:
                self.show_page(2)
            elif index == 2:
                choice = self.wallpaper_choice.currentData()
                if choice == "skip":
                    self.show_page(3)
                else:
                    destination = Path(self.wallpaper_destination.text()).expanduser().absolute()
                    if choice == "local":
                        source = self.wallpaper_source.text()
                        operation = lambda callback: local_wallpapers(source, destination, callback)
                    else:
                        pin = json.loads((HERE / "wallpapers.json").read_text())
                        operation = lambda callback: online_wallpapers(pin, choice, destination, cache, callback)
                    self.start_job(operation, lambda result: self.show_page(3))
            elif index == 3 and manifest:
                folders = tuple(self.source_folders)
                self.start_job(lambda callback: prepare_image(manifest, cache, callback, folders, args.offline), self.image_ready)
            elif index == 4 and self.confirm.isChecked():
                selected_theme = self.grub_choice.currentData()
                self.show_page(5)
                self.start_job(lambda callback: grub_setup.install_with_theme(
                    lambda progress: runner.install(self.image, manifest, cache, home, progress),
                    selected_theme, callback), self.installed)
            elif index == 6:
                if self.cleanup.isChecked():
                    cache.cleanup()
                self.close()

        def image_ready(self, image):
            self.image = image
            self.activity.setText("Complete AppImage verified. Ready for review.")
            self.show_page(4)

        def installed(self, result):
            self.receipt = result["receipt"]
            grub = result.get("grub", {"status": "retained"})
            if grub["status"] == "configured":
                grub_text = "GRUB theme configured: " + dict(grub_setup.THEMES)[grub["theme"]] + ". Restore through Sumi Deck → GRUB THEMES."
            elif grub["status"] == "failed":
                grub_text = "Desktop installed; GRUB theme step failed: " + grub["message"]
            else:
                grub_text = "GRUB: current appearance retained; eight theme cards are available in Sumi Deck."
            self.finish_result.setText("Backup / receipt: " + self.receipt + "\n" + grub_text + "\nReboot when you're ready.")
            self.cleanup.setText(f"Remove downloaded installer files · {cache.cleanup_size() / 1024**3:.2f} GiB")
            self.show_page(6)

        def choose_restore(self):
            path, _ = QFileDialog.getOpenFileName(self, "Choose a v6 configuration receipt", str(root_for(home)), "Receipt (receipt.json)")
            if not path:
                return
            try:
                _, conflicts = inspect_receipt(Path(path), home)
                if conflicts:
                    raise SetupError("These configurations changed after installation:\n" + "\n".join(conflicts))
                answer = QMessageBox.question(self, "Restore user configuration", "Restore the backed-up user configuration? Packages and system settings are retained.")
                if answer == QMessageBox.Yes:
                    self.start_job(lambda callback: restore(Path(path), home, callback), lambda result: QMessageBox.information(self, "Restored", result["message"]))
            except (OSError, ValueError, SetupError) as error:
                QMessageBox.warning(self, "Restore stopped", str(error))

        def reboot(self):
            if QMessageBox.question(self, "Reboot", "Reboot now? Save your work in other applications first.") == QMessageBox.Yes:
                import subprocess
                if self.cleanup.isChecked():
                    cache.cleanup()
                result = subprocess.run(["systemctl", "reboot"], capture_output=True, text=True,
                                        env=external_environment())
                if result.returncode:
                    QMessageBox.warning(self, "Reboot stopped", result.stderr)

        def closeEvent(self, event):
            if self.job:
                QMessageBox.information(self, "Setup is running", "Wait for the current operation to finish. Downloads and backups are retained if the operation fails.")
                event.ignore()
            else:
                event.accept()

    application = QApplication(sys.argv[:1])
    application.setFont(QFont("Noto Sans", 10))
    window = Window()
    available = application.primaryScreen().availableGeometry()
    if not args.screenshot:
        window.resize(min(1120, available.width()), min(900, available.height() - 40))
    window.show()
    if args.screenshot:
        QTimer.singleShot(500, lambda: (window.grab().save(str(args.screenshot)), application.quit()))
    return application.exec()


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, SetupError) as error:
        print("Multi-Rice setup stopped:", error, file=sys.stderr)
        sys.exit(1)
