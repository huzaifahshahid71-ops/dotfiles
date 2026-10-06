#!/usr/bin/env python3
"""Run against the reviewed modern helper without touching the real system."""
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
from restore_guard import patched

source = Path(sys.argv.pop(1)).read_text()
namespace = {'__name__': 'restore_guard_test'}
exec(compile(patched(source), '<reviewed-helper>', 'exec'), namespace)
Transaction = namespace['SystemTransaction']
fingerprint = namespace['fingerprint']
SetupError = namespace['SetupError']


class RestoreGuardTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.transaction = Transaction(root=self.root)
        self.identifier = 'a' * 32
        self.state = self.transaction.state_root(1000, self.identifier)
        (self.state / 'before').mkdir(parents=True)
        self.receipt = {'schema': 1, 'uid': 1000, 'id': self.identifier,
                        'version': '6.0.0', 'status': 'installed', 'files': []}
        self.add('usr/local/share/multi-rice-sddm/catalog.json', b'catalog', b'catalog')
        self.add('usr/local/share/multi-rice-sddm/sources/astronaut/metadata.desktop', b'metadata', b'metadata')
        self.selected = self.root / 'usr/local/share/multi-rice-sddm/selected.json'
        self.selected.write_text('{"id":"astronaut-pixel-sakura"}')

    def tearDown(self):
        self.tmp.cleanup()

    def add(self, relative, before, installed):
        index = len(self.receipt['files'])
        backup = self.state / 'before' / f'{index:04d}'
        if before is not None:
            backup.write_bytes(before)
        destination = self.root / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(installed)
        self.receipt['files'].append({'path': relative, 'before': fingerprint(backup),
                                      'installed': fingerprint(destination)})

    def inspect(self):
        (self.state / 'receipt.json').write_text(json.dumps(self.receipt))
        return self.transaction.inspect(1000, self.identifier)[2]

    def test_unchanged_reinstall_restores_and_preserves_selection(self):
        self.assertEqual(self.inspect(), [])
        selected = self.selected.read_bytes()
        self.transaction.restore(1000, self.identifier, callback=lambda *a, **kw: None)
        self.assertEqual(self.selected.read_bytes(), selected)
        self.assertEqual(json.loads((self.state / 'receipt.json').read_text())['status'], 'restored')

    def test_fresh_catalog_removal_remains_blocked(self):
        (self.state / 'before/0000').unlink()
        self.receipt['files'][0]['before'] = {'kind': 'absent'}
        self.assertTrue(any('Login theme selection' in c for c in self.inspect()))

    def test_new_theme_asset_removal_remains_blocked(self):
        self.add('usr/local/share/multi-rice-sddm/sources/new/Main.qml', None, b'new theme')
        self.assertTrue(any('Login theme selection' in c for c in self.inspect()))

    def test_previous_catalog_change_remains_blocked(self):
        (self.state / 'before/0000').write_bytes(b'old catalog')
        self.receipt['files'][0]['before'] = fingerprint(self.state / 'before/0000')
        self.assertTrue(any('Login theme selection' in c for c in self.inspect()))

    def test_edited_metadata_remains_blocked(self):
        path = self.receipt['files'][1]['path']
        (self.root / path).write_bytes(b'edited selection metadata')
        self.assertIn(path, self.inspect())

    def test_corrupt_backup_remains_blocked(self):
        (self.state / 'before/0000').write_bytes(b'corrupt')
        with self.assertRaises(SetupError):
            self.inspect()

    def test_grub_removal_guard_unchanged(self):
        self.add('usr/local/bin/eva', None, b'eva')
        state = self.root / 'var/lib/evangelion-grub/state.json'
        state.parent.mkdir(parents=True)
        state.write_text('{}')
        self.assertTrue(any('GRUB selection' in c for c in self.inspect()))

    def test_patch_is_idempotent_and_rejects_unknown_guard(self):
        result = patched(source)
        self.assertEqual(patched(result), result)
        with self.assertRaises(RuntimeError):
            patched('different version')


if __name__ == '__main__':
    unittest.main()
