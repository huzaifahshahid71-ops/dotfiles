#!/usr/bin/env python3
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
spec=importlib.util.spec_from_file_location('assemble',Path(__file__).with_name('assemble-v6.py'))
assemble=importlib.util.module_from_spec(spec);spec.loader.exec_module(assemble)


class AssemblerTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.old=Path.cwd();os.chdir(self.tmp.name)
        def record(name,data):
            Path(name).write_bytes(data)
            return {'asset':name,'bytes':len(data),'sha256':assemble.digest(Path(name)),'url':assemble.BASE+name}
        a=record('image.part001',b'first');b=record('image.part002',b'second')
        image=record('image.AppImage',b'firstsecond');Path('image.AppImage').unlink()
        Path('release.json').write_text(json.dumps({'version':'6.0.0','status':'ready','image':image,'parts':[a,b]}))

    def tearDown(self):os.chdir(self.old);self.tmp.cleanup()

    def test_offline_parts_assemble_in_manifest_order(self):
        assemble.main()
        self.assertEqual(Path('image.AppImage').read_bytes(),b'firstsecond')
        assemble.main()

    def test_corrupt_existing_part_is_preserved_and_not_assembled(self):
        Path('image.part001').write_bytes(b'corrupt')
        with self.assertRaises(RuntimeError):assemble.main()
        self.assertEqual(Path('image.part001').read_bytes(),b'corrupt')
        self.assertFalse(Path('image.AppImage').exists())

    def test_existing_wrong_image_is_preserved(self):
        Path('image.AppImage').write_bytes(b'personal file')
        with self.assertRaises(RuntimeError):assemble.main()
        self.assertEqual(Path('image.AppImage').read_bytes(),b'personal file')


if __name__=='__main__':unittest.main()
