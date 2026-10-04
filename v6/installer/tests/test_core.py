import hashlib
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from core import Cache, PROFILES, SetupError, download, load_manifest, local_wallpapers, prepare_image
from maintenance import snapshot, finalize, restore, inspect_receipt

BASE = "https://github.com/huzaifahshahid71-ops/dotfiles/releases/download/v6.0.0/"
EVENT = lambda event: None


def spec(name, content):
    return {"asset": name, "bytes": len(content), "sha256": hashlib.sha256(content).hexdigest(), "url": BASE + name}


class Response(io.BytesIO):
    def __init__(self, content, status=200, headers=None):
        super().__init__(content)
        self.status = status
        self.headers = headers or {"Content-Length": str(len(content))}


class TransportTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.cache = Cache(self.root / "cache")

    def tearDown(self):
        self.temp.cleanup()

    def test_resume_validates_range_and_reuses_result(self):
        payload = b"a known complete asset"
        record = spec("part01", payload)
        target = self.cache.path("part01")
        target.with_name("part01.partial").write_bytes(payload[:5])
        def open_request(request, timeout):
            self.assertEqual(request.headers["Range"], "bytes=5-")
            return Response(payload[5:], 206, {"Content-Range": f"bytes 5-{len(payload)-1}/{len(payload)}", "Content-Length": str(len(payload)-5)})
        download(record, target, EVENT, open_request)
        self.assertEqual(target.read_bytes(), payload)
        download(record, target, EVENT, lambda *a, **k: self.fail("Verified cache must not download"))

    def test_server_ignoring_range_restarts_partial(self):
        payload = b"new data"
        target = self.cache.path("part01")
        target.with_name("part01.partial").write_bytes(b"old")
        download(spec("part01", payload), target, EVENT, lambda *a, **k: Response(payload))
        self.assertEqual(target.read_bytes(), payload)

    def test_invalid_resume_preserves_partial(self):
        target = self.cache.path("part01")
        partial = target.with_name("part01.partial")
        partial.write_bytes(b"first")
        with self.assertRaises(SetupError):
            download(spec("part01", b"firstlast"), target, EVENT,
                     lambda *a, **k: Response(b"last", 206, {"Content-Range": "bytes 0-3/4"}))
        self.assertEqual(partial.read_bytes(), b"first")
        self.assertFalse(target.exists())

    def test_corruption_and_oversized_download_never_promoted(self):
        target = self.cache.path("asset")
        with self.assertRaises(SetupError):
            download(spec("asset", b"good"), target, EVENT, lambda *a, **k: Response(b"evil"))
        self.assertFalse(target.exists())
        with self.assertRaises(SetupError):
            download(spec("asset", b"good"), target, EVENT, lambda *a, **k: Response(b"goodextra", headers={"Content-Length": "4"}))
        self.assertFalse(target.exists())

    def test_manifest_rejects_wrong_protocol_release_and_part_lengths(self):
        payload = b"complete"
        manifest = {"schema": 1, "version": "6.0.0", "arch": "x86_64", "backend_protocol": 1,
                    "status": "ready", "profiles": PROFILES, "image": spec("rice.AppImage", payload),
                    "parts": [spec("part01", payload)], "installed_bytes": 1024}
        path = self.root / "release.json"
        path.write_text(json.dumps(manifest))
        self.assertEqual(load_manifest(path)["version"], "6.0.0")
        for key, value in (("backend_protocol", 2), ("status", "development"), ("version", "5.0.0")):
            altered = dict(manifest, **{key: value})
            path.write_text(json.dumps(altered))
            with self.assertRaises(SetupError):
                load_manifest(path)
        manifest["parts"][0]["bytes"] += 1
        path.write_text(json.dumps(manifest))
        with self.assertRaises(SetupError):
            load_manifest(path)

    def test_offline_join_order_and_final_hash(self):
        source = self.root / "offline"
        source.mkdir()
        chunks = [b"first", b"second"]
        manifest = {"image": spec("rice.AppImage", b"".join(chunks)),
                    "parts": [spec(f"part{i}", value) for i, value in enumerate(chunks)]}
        for record, value in zip(manifest["parts"], chunks):
            (source / record["asset"]).write_bytes(value)
        with patch("core.download", side_effect=AssertionError("Offline must not connect")):
            image = prepare_image(manifest, self.cache, EVENT, [source], offline=True)
        self.assertEqual(image.read_bytes(), b"firstsecond")
        self.assertEqual((source / "part0").read_bytes(), b"first")
        self.cache.cleanup()
        self.assertTrue(source.exists())
        self.assertFalse(image.exists())
        manifest["image"]["sha256"] = "0" * 64
        with self.assertRaises(SetupError):
            prepare_image(manifest, self.cache, EVENT, [source], offline=True)
        self.assertFalse(image.exists())

    def test_missing_offline_part_and_symlink_cache_stop(self):
        with self.assertRaises(SetupError):
            prepare_image({"image": spec("rice.AppImage", b"a"), "parts": [spec("part", b"a")]}, self.cache, EVENT, [], True)
        external = self.root / "external"
        external.mkdir()
        (self.cache.root / "asset").symlink_to(external / "file")
        with self.assertRaises(SetupError):
            self.cache.path("asset")
        self.cache.cleanup()
        self.assertTrue(external.exists())

    def test_offline_copy_cannot_follow_partial_symlink(self):
        source = self.root / "offline"
        source.mkdir()
        payload = b"verified image"
        (source / "rice.AppImage").write_bytes(payload)
        external = self.root / "keep"
        external.write_bytes(b"unrelated")
        (self.cache.root / "rice.AppImage.partial").symlink_to(external)
        with self.assertRaises(SetupError):
            prepare_image({"image": spec("rice.AppImage", payload), "parts": []}, self.cache, EVENT, [source], True)
        self.assertEqual(external.read_bytes(), b"unrelated")

    def test_wallpaper_conflicts_and_source_preservation(self):
        source, destination = self.root / "source", self.root / "destination"
        source.mkdir()
        destination.mkdir()
        (source / "image.png").write_bytes(b"new image")
        (destination / "image.png").write_bytes(b"my image")
        (source / "private.txt").write_text("do not copy")
        (source / "link.png").symlink_to(source / "image.png")
        result = local_wallpapers(source, destination, EVENT)
        self.assertEqual(len(result), 1)
        self.assertEqual((destination / "image.png").read_bytes(), b"my image")
        self.assertEqual(Path(result[0]["path"]).read_bytes(), b"new image")
        self.assertEqual((source / "image.png").read_bytes(), b"new image")
        self.assertEqual(local_wallpapers(source, destination, EVENT)[0]["status"], "existing")


class RecoveryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.home = Path(self.temp.name)
        (self.home / ".config").mkdir()
        (self.home / ".config/one").write_text("original")

    def tearDown(self):
        self.temp.cleanup()

    def installed(self):
        receipt = snapshot(self.home, [".config/one", ".config/new"])
        (self.home / ".config/one").write_text("installed")
        (self.home / ".config/new").write_text("new")
        finalize(receipt)
        return receipt

    def test_restore_works_after_payload_cache_deleted(self):
        receipt = self.installed()
        result = restore(receipt, self.home, EVENT)
        self.assertEqual((self.home / ".config/one").read_text(), "original")
        self.assertFalse((self.home / ".config/new").exists())
        self.assertTrue(Path(result["retained"]).exists())

    def test_drift_and_corrupt_backup_refuse_before_changes(self):
        receipt = self.installed()
        (self.home / ".config/one").write_text("my later edit")
        with self.assertRaises(SetupError):
            restore(receipt, self.home, EVENT)
        self.assertEqual((self.home / ".config/one").read_text(), "my later edit")
        (self.home / ".config/one").write_text("installed")
        (receipt.parent / "before/0000").write_text("corrupt backup")
        with self.assertRaises(SetupError):
            restore(receipt, self.home, EVENT)
        self.assertEqual((self.home / ".config/one").read_text(), "installed")

    def test_partial_restore_failure_rolls_back(self):
        receipt = self.installed()
        def callback(event):
            raise OSError("simulated interruption after first file")
        with self.assertRaises(OSError):
            restore(receipt, self.home, callback)
        self.assertEqual((self.home / ".config/one").read_text(), "installed")
        self.assertEqual((self.home / ".config/new").read_text(), "new")
        self.assertEqual(inspect_receipt(receipt, self.home)[1], [])

    def test_overlapping_and_escaping_paths_refused(self):
        for paths in (("../outside",), (".config", ".config/one"), ("Pictures/Wallpapers",)):
            with self.assertRaises(SetupError):
                snapshot(self.home, paths)


if __name__ == "__main__":
    unittest.main()
