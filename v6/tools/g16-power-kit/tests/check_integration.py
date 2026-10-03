#!/usr/bin/env python3
"""Verify reconstruction and safe patch preparation without building a kernel."""
import contextlib
import io
from pathlib import Path
import shutil
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from apply import BUNDLE, GROUPS, git_apply, process, verify_bundle
from prepare import adapt_recipe


def quiet(*args, **kwargs):
    with contextlib.redirect_stdout(io.StringIO()):
        return process(*args, **kwargs)


def contents(root):
    return {name: (root / name).read_bytes() for name in GROUPS['kernel']['files']}


def main():
    verify_bundle()
    with tempfile.TemporaryDirectory() as temporary:
        root = Path(temporary)
        for version in ('7.2.5', '7.2.8'):
            tree = root / version
            shutil.copytree(BUNDLE / 'reference' / ('stock-' + version), tree)
            before = contents(tree)
            assert quiet(tree, 'kernel') == 'applicable'
            assert contents(tree) == before, 'Check mode mutated source'
            assert quiet(tree, 'kernel', True) == 'applied'
            if version == '7.2.5':
                expected = contents(BUNDLE / 'reference/working-7.2.5')
                assert contents(tree) == expected, 'Recovered patch lost working source edits'
            after = contents(tree)
            assert quiet(tree, 'kernel', True) == 'already-applied'
            assert contents(tree) == after
            print(f'PASS: {version} applicability, check mode and repeated application')
        tree = root / 'partial'
        shutil.copytree(BUNDLE / 'reference/stock-7.2.5', tree)
        patch = BUNDLE / 'patches/kernel' / GROUPS['kernel']['patches'][0]
        assert git_apply(tree, patch).returncode == 0
        quiet(tree, 'kernel', True)
        assert contents(tree) == contents(BUNDLE / 'reference/working-7.2.5')
        print('PASS: partially applied series reconstructed exactly')
        tree = root / 'conflict'
        shutil.copytree(BUNDLE / 'reference/stock-7.2.5', tree)
        path = tree / 'drivers/pci/pcie/aspm.c'
        text = path.read_text()
        assert 'link->aspm_default = link->aspm_enabled;' in text
        path.write_text(text.replace('link->aspm_default = link->aspm_enabled;',
                                    'link->aspm_default = 0; /* incompatible upstream change */'))
        before = contents(tree)
        try:
            quiet(tree, 'kernel', True)
            raise AssertionError('Conflicting source unexpectedly accepted')
        except RuntimeError as exc:
            assert 'needs review' in str(exc)
        assert contents(tree) == before, 'Earlier patch leaked into source after later failure'
        print('PASS: later-stage conflict stops without source mutation')
        tree = root / 'asusctl'
        shutil.copytree(BUNDLE / 'reference/asusctl-6.5.0', tree)
        patch = BUNDLE / 'patches/asusctl' / GROUPS['asusctl']['patches'][0]
        expected = (tree / GROUPS['asusctl']['files'][0]).read_bytes()
        assert git_apply(tree, patch, reverse=True).returncode == 0
        quiet(tree, 'asusctl', True)
        assert (tree / GROUPS['asusctl']['files'][0]).read_bytes() == expected
        assert quiet(tree, 'asusctl', True) == 'already-applied'
        print('PASS: asusctl patch reconstructs captured source and is idempotent')
        upstream = (BUNDLE / 'recipes/7.2.8/PKGBUILD').read_text()
        custom_line = '# Separate package: retain the working vmdtest kernel.\n_pkgsuffix=cachyos-g16\n'
        hook = '    python3 "$startdir/g16-patches/apply.py" --kernel --source "$PWD" --apply || _die "G16 power patch verification failed"\n\n'
        plain = upstream.replace(custom_line, '').replace(hook, '')
        assert adapt_recipe(plain) == upstream
        for invalid in (upstream, plain.replace('pkgbase="linux-$_pkgsuffix"', 'pkgbase=changed')):
            try:
                adapt_recipe(invalid)
                raise AssertionError('Invalid recipe accepted')
            except RuntimeError:
                pass
        print('PASS: separately named recipe and changed/already-adapted guards')
    print('PASS: all source-level integration checks; no kernel was compiled or booted')


if __name__ == '__main__':
    main()
