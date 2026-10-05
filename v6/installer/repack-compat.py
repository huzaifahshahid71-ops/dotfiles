#!/usr/bin/env python3
"""Build RC5 from retained candidate inputs and a verified private GUI runtime."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import shutil
import sys
import zipfile

from core import SetupError, load_manifest, no_symlink_parents, sha256, verified
from maintenance import write_json

ROOT = Path(__file__).resolve().parent


def module():
    spec = importlib.util.spec_from_file_location("sumi_packager", ROOT / "package-release.py")
    packager = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(packager)
    packager.IMAGE = "multi-rice-v6.0.0-rc5-x86_64.AppImage"
    packager.BACKEND_FILES = tuple(dict.fromkeys((*packager.BACKEND_FILES, 'eclipse_defaults.py')))
    return packager


def link_or_copy(source, destination):
    try:
        os.link(source, destination)
    except OSError:
        shutil.copy2(source, destination)
    return destination


def replace_file(source, destination):
    destination.parent.mkdir(parents=True, exist_ok=True)
    temp = destination.with_name(destination.name + ".compat-new")
    if temp.exists() or temp.is_symlink():
        raise SetupError("Unexpected retained temporary file: " + str(temp))
    shutil.copy2(source, temp)
    os.replace(temp, destination)


def deck_bindings(payload, rows):
    toolkit = ROOT / 'build-support/sumi-deck-binding'
    spec = importlib.util.spec_from_file_location('shared_deck_installer', toolkit / 'install.py')
    installer = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(installer)
    launcher = '@MULTI_RICE_HOME@/.local/bin/multi-rice-deck'

    def generated(relative, data, mode=0o644):
        target = payload / 'home' / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        temporary = target.with_name(target.name + '.deck-new')
        if temporary.exists() or temporary.is_symlink():
            raise SetupError('Unexpected retained Deck temporary file: ' + str(temporary))
        temporary.write_bytes(data.encode() if isinstance(data, str) else data)
        temporary.chmod(mode)
        os.replace(temporary, target)
        rows[relative] = dict(rows.get(relative, {}), path=relative, source='home/' + relative,
                              mode=mode, bytes=target.stat().st_size, sha256=sha256(target),
                              template=b'@MULTI_RICE_HOME@' in target.read_bytes())

    prefix = '.local/share/desktop-profiles/'
    for name in installer.HYPR:
        relative = prefix + name + '/hypr/hyprland.lua'
        if relative not in rows:
            raise SetupError('Sumi Deck binding source is missing: ' + relative)
        generated(relative, installer.lua_patch((payload / rows[relative]['source']).read_text(), launcher))
    for name in installer.NIRI:
        relative = prefix + name
        if relative not in rows:
            raise SetupError('Sumi Deck binding source is missing: ' + relative)
        generated(relative, installer.niri_patch((payload / rows[relative]['source']).read_text(), launcher))
    manifest = json.loads((toolkit / 'payload-manifest.json').read_text())
    for name, fingerprint in manifest['files'].items():
        source = toolkit / name
        if sha256(source) != fingerprint:
            raise SetupError('Sumi Deck launcher source hash differs: ' + name)
        generated('.local/share/multi-rice-deck/' + name, source.read_bytes(), 0o755)
    generated('.local/bin/multi-rice-deck',
              '#!/usr/bin/env bash\nexec /usr/bin/python3 "$HOME/.local/share/multi-rice-deck/launcher.py" "$@"\n', 0o755)


def refresh_candidate(candidate, output, packager):
    original_report = json.loads((candidate.parent / "assembly-report.json").read_text())
    if original_report.get("plan_sha256") != sha256(candidate / "payload/plan.json"):
        raise SetupError("Original candidate differs from its assembly report.")
    copied = output / "candidate/AppDir"
    shutil.copytree(candidate, copied, copy_function=link_or_copy, symlinks=True)
    payload = copied / "payload"
    plan = json.loads((payload / "plan.json").read_text())
    prefix = ".local/share/multi-rice-setup/runtime/"
    rows = {record["path"]: record for record in plan["user_files"]}
    # Replace, never write through the hard links into the retained RC1.
    for name in packager.GUI_FILES:
        relative = prefix + name
        source = "home/" + relative
        destination = payload / source
        replace_file(ROOT / name, destination)
        old = rows.get(relative, {})
        rows[relative] = dict(old, path=relative, source=source, bytes=destination.stat().st_size,
                             sha256=sha256(destination), mode=0o644, template=False)
    deck_bindings(payload, rows)
    runtime_additions(payload, rows, original_report['plan_sha256'])
    lumina_background_defaults(payload, rows)
    cipher_startup_defaults(payload, rows)
    reviewed_startup_defaults(payload,rows)
    from shared_runtime_defaults import reviewed_shared_defaults
    reviewed_shared_defaults(payload, rows, ROOT / "build-support/shared-runtime/refresh-rate-ctl")
    from bundle_fixes import apply as final_bundle_fixes
    final_checks = final_bundle_fixes(payload, rows, ROOT)
    package_additions(payload, plan['packages'])
    plan["user_files"] = list(rows.values())
    temporary = payload / "plan.compat-new.json"
    write_json(temporary, plan)
    os.replace(temporary, payload / "plan.json")
    for name in packager.BACKEND_FILES:
        replace_file(ROOT / name, copied / "backend" / name)
    import subprocess
    check = subprocess.run([sys.executable, '-B', '-c', 'import payload_backend'],
                           cwd=copied/'backend',capture_output=True,text=True,timeout=30)
    if check.returncode:
        raise SetupError('Bundled backend import check failed: '+check.stderr[-4000:])
    report = dict(original_report, plan_sha256=sha256(payload / "plan.json"),
                  files=len(plan["user_files"]), packages=len(plan['packages']), compatibility_policy="reuse-installed; add-missing-only")
    report['final_bundle_checks'] = final_checks
    write_json(copied.parent / "assembly-report.json", report)
    return copied


def runtime_additions(payload, rows, base_plan_sha256):
    addon=ROOT/'runtime-repair'
    path=addon/'manifest.json'
    if not path.is_file():
        raise SetupError('Prepare the runtime repair additions before rebuilding RC5.')
    manifest=json.loads(path.read_text())
    if manifest.get('base_plan_sha256')!=base_plan_sha256:
        raise SetupError('Runtime additions belong to a different candidate; use the RC4 candidate checked by the audit.')
    spec=importlib.util.spec_from_file_location('runtime_source_repair',ROOT/'build-support/runtime-repair/repair.py')
    repair=importlib.util.module_from_spec(spec);spec.loader.exec_module(repair)
    for record,data in repair.checked_rows(addon):
        if record['path'] in rows:
            raise SetupError('Runtime addition overlaps an existing candidate source: '+record['path'])
        destination=payload/record['source']
        if destination.exists() or destination.is_symlink():
            raise SetupError('Unexpected existing runtime addition target: '+record['path'])
        replace_file(addon/record['source'],destination)
        destination.chmod(record['mode'])
        rows[record['path']]=dict(record)


def cipher_startup_defaults(payload, rows):
    from runtime_sources import CIPHER_SHELL, cipher_shell_path
    row=rows.get(CIPHER_SHELL)
    if not row:raise SetupError('Cipher native shell is absent from the candidate')
    target=payload/row['source'];data=cipher_shell_path(target.read_bytes())
    temporary=target.with_name(target.name+'.cipher-new')
    if temporary.exists() or temporary.is_symlink():raise SetupError('Unexpected retained Cipher temporary file')
    temporary.write_bytes(data);temporary.chmod(row['mode']);os.replace(temporary,target)
    rows[CIPHER_SHELL]=dict(row,bytes=len(data),sha256=sha256(target))

def reviewed_startup_defaults(payload,rows):
    from runtime_sources import END4_STARTUP,SOLSTICE_CONFIG,ECLIPSE_UPDATES,startup_source_defaults
    from staging import HOME_TOKEN
    for relative in (END4_STARTUP,SOLSTICE_CONFIG,ECLIPSE_UPDATES):
        row=rows.get(relative)
        if not row:raise SetupError('Reviewed startup source missing: '+relative)
        target=payload/row['source'];before=target.read_bytes()
        data=startup_source_defaults(relative,before,HOME_TOKEN)
        if data==before:continue
        temporary=target.with_name(target.name+'.startup-new')
        if temporary.exists() or temporary.is_symlink():raise SetupError('Unexpected retained startup temporary file')
        temporary.write_bytes(data);temporary.chmod(row['mode']);os.replace(temporary,target)
        rows[relative]=dict(row,bytes=len(data),sha256=sha256(target),template=row.get('template',False) or HOME_TOKEN.encode() in data)


def package_additions(payload, packages):
    from package_policy import archive_metadata
    addon=ROOT/'runtime-packages'
    manifest=json.loads((addon/'manifest.json').read_text())
    records=manifest.get('packages',[])
    if manifest.get('schema')!=1 or len(records)!=1:
        raise SetupError('Prepare the verified wallpaper package before rebuilding RC5.')
    existing={r['name']:r for r in packages}
    for row in records:
        import re
        relative=Path(row['source'])
        if (not re.fullmatch(r'awww(?:-git|-bin)?',row['name']) or relative.is_absolute() or
            len(relative.parts)!=2 or relative.parts[0]!='packages' or '..' in relative.parts):
            raise SetupError('Unexpected wallpaper package addition')
        source=addon/relative
        no_symlink_parents(source)
        if not verified(source,row):raise SetupError('Wallpaper package addition hash differs')
        metadata=archive_metadata(source)
        if (metadata['name'],metadata['version'])!=(row['name'],row['version']):
            raise SetupError('Wallpaper package addition metadata differs')
        if row['name'] in existing:
            if existing[row['name']]!=row:raise SetupError('Wallpaper package would replace a different candidate package')
            continue
        destination=payload/relative
        if destination.exists() or destination.is_symlink():raise SetupError('Wallpaper archive filename collides')
        replace_file(source,destination)
        packages.append(dict(row))


def lumina_background_defaults(payload, rows):
    from runtime_sources import LUMINA_DEFAULT, lumina_wallpaper_defaults
    relative='.local/share/desktop-profiles/sayconlun/support/bin/rice-wallpaper'
    if LUMINA_DEFAULT not in rows or relative not in rows:
        raise SetupError('Prepare the bundled Lumina default wallpaper before rebuilding RC5.')
    row=rows[relative];destination=payload/row['source']
    data=lumina_wallpaper_defaults(destination.read_bytes())
    temp=destination.with_name(destination.name+'.wallpaper-new')
    if temp.exists() or temp.is_symlink():raise SetupError('Unexpected temporary wallpaper helper')
    temp.write_bytes(data);temp.chmod(row['mode']);os.replace(temp,destination)
    rows[relative]=dict(row,bytes=len(data),sha256=sha256(destination))


def reuse_gui(previous_gui, output, packager):
    runtime = previous_gui / "runtime/SumiSetup"
    stamp = previous_gui / "gui-complete.json"
    if not stamp.is_file() or json.loads(stamp.read_text()) != packager.runtime_records(runtime):
        raise SetupError("The retained GUI runtime differs from its recorded hashes.")
    sources = list(packager.GUI_FILES) + [str(p.relative_to(ROOT)) for p in (ROOT / "assets").glob("*.webp")]
    for relative in sources:
        if sha256(runtime / "source" / relative) != sha256(ROOT / relative):
            raise SetupError("The retained GUI source differs: " + relative)
    target = output / "runtime/SumiSetup"
    if target.exists():
        raise SetupError("Unrecorded GUI output exists; use a new output directory.")
    shutil.copytree(runtime, target, symlinks=True)
    packager.run([target / "SumiSetup", "--offline", "--screenshot", output / "sumi-runtime.png"],
                 output, "Check retained GUI runtime", 60, env=dict(os.environ, QT_QPA_PLATFORM="offscreen"))
    screenshot = output / "sumi-runtime.png"
    if not screenshot.is_file() or screenshot.stat().st_size < 1000:
        raise SetupError("The retained GUI did not render its smoke-test screenshot.")
    write_json(output / "gui-complete.json", packager.runtime_records(target))
    return target


def build(candidate, previous, output, resume=False, gui_from=None):
    for path in (candidate, previous, output, *([gui_from] if gui_from else [])):
        no_symlink_parents(path)
    if any(output.is_relative_to(p) or p.is_relative_to(output) for p in (candidate.parent, previous, *([gui_from] if gui_from else []))):
        raise SetupError("Use a new output directory separate from the existing candidate and RC1 build.")
    packager = module()
    identity = {"candidate": str(candidate), "previous": str(previous),
                "original_plan_sha256": sha256(candidate / "payload/plan.json"),
                "source_sha256": packager.source_hash(), "repack_sha256": sha256(ROOT / "repack-compat.py"),
                "gui_from": str(gui_from) if gui_from else None,
                "gui_stamp_sha256": sha256(gui_from / "gui-complete.json") if gui_from else None}
    identity['deck_toolkit'] = {name: sha256(ROOT / 'build-support/sumi-deck-binding' / name)
                                for name in ('install.py', 'launcher.py', 'payload-manifest.json')}
    identity['runtime_repair_manifest']=sha256(ROOT/'runtime-repair/manifest.json')
    identity['runtime_repair_tool']=sha256(ROOT/'build-support/runtime-repair/repair.py')
    identity['runtime_packages_manifest']=sha256(ROOT/'runtime-packages/manifest.json')
    identity['bundle_fixes'] = {name:sha256(ROOT/name) for name in ('bundle_fixes.py','eclipse_defaults.py','eclipse_launchers.py','shared_runtime_defaults.py')}
    identity['eclipse_launchers_manifest'] = sha256(ROOT/'build-support/eclipse-launcher/manifest.json')
    identity['refresh_helper_sha256'] = sha256(ROOT/'build-support/shared-runtime/refresh-rate-ctl')
    from eclipse_launchers import read_inputs
    read_inputs(ROOT/'build-support/eclipse-launcher')
    if output.exists():
        marker = output / "compatibility-inputs.json"
        if not resume or not marker.is_file() or json.loads(marker.read_text()) != identity:
            raise SetupError("Use a new output directory, or --resume with the unchanged kit and candidate.")
    elif resume:
        raise SetupError("There is no retained output to resume.")
    if not (previous / "build-venv/bin/python").is_file() or not (previous / "wheels").is_dir():
        raise SetupError("The retained private GUI toolchain is missing.")
    if shutil.disk_usage(output.parent).free < 8 * 1024**3:
        raise SetupError("The RC5 rebuild needs at least 8 GiB free on its output filesystem.")
    original = load_manifest(previous / "release.json")
    print("Checking retained RC1 AppImage", flush=True)
    if not verified(previous / original["image"]["asset"], original["image"]):
        raise SetupError("The RC1 AppImage no longer matches its manifest.")
    output.mkdir(mode=0o700, exist_ok=True)
    write_json(output / "compatibility-inputs.json", identity)
    print("Create separate candidate; retain source/package archives", flush=True)
    completed = output / "candidate-complete.json"
    updated = output / "candidate/AppDir"
    if completed.is_file():
        if json.loads(completed.read_text())["plan_sha256"] != sha256(updated / "payload/plan.json"):
            raise SetupError("Retained candidate plan changed; use a new output directory.")
    else:
        if (output / "candidate").exists():
            shutil.rmtree(output / "candidate")
        updated = refresh_candidate(candidate, output, packager)
        write_json(completed, {"plan_sha256": sha256(updated / "payload/plan.json")})
    plan, assembly = packager.verify_candidate(updated, output)
    runtime = (reuse_gui(gui_from, output, packager) if gui_from and not (output / "gui-complete.json").exists()
               else packager.gui_runtime(output, existing_build=previous))
    image = packager.build_image(updated, runtime, output, assembly)
    parts = packager.split_image(image, output)
    manifest = packager.make_manifest(image, parts, plan)
    write_json(output / "release.json", manifest)
    load_manifest(output / "release.json")
    write_json(runtime / "release.json", manifest)
    for offline in (True, False):
        script = runtime / ("launch-offline.sh" if offline else "launch-online.sh")
        script.write_text(packager.launcher(offline))
        script.chmod(0o755)
    write_json(output / "gui-complete.json", packager.runtime_records(runtime))
    artifacts = [image, *parts, output / "release.json"]
    (output / "SHA256SUMS").write_text("".join(sha256(p) + "  " + p.name + "\n" for p in artifacts))
    report = {"status": "packaged-vm-candidate", "image": manifest["image"],
              "parts": manifest["parts"], "published": False, "system_changes": False,
              "plan_sha256": assembly["plan_sha256"], "gui_smoke_test": True,
              "package_policy": "Preserve installed versions and known Aether providers; add compatible missing packages only",
              "release_features": assembly["release_features"],
              "final_bundle_checks": assembly.get('final_bundle_checks',{}),
              "remaining": ["VM installation", "Native desktop acceptance", "GRUB boot/restore", "Upgrade/restore", "Publication"]}
    write_json(output / "compatibility-build-report.json", report)
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidate", type=Path, required=True)
    parser.add_argument("--previous", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--resume", action="store_true")
    parser.add_argument("--gui-from", type=Path, help="Reuse a checked, unchanged GUI runtime")
    args = parser.parse_args()
    if os.getuid() == 0:
        parser.error("Run as the desktop user, without sudo.")
    paths = [p.expanduser().absolute() for p in (args.candidate, args.previous, args.output)]
    output = paths[-1]
    report = {}
    try:
        report = build(*paths, resume=args.resume,
                       gui_from=args.gui_from.expanduser().absolute() if args.gui_from else None)
        print("PACKAGED: " + str(output / report["image"]["asset"]), flush=True)
    except (OSError, ValueError, KeyError, SetupError) as error:
        report = {"status": "failed", "error": str(error)}
        print("Compatibility rebuild stopped: " + str(error), file=sys.stderr)
    report_zip = Path.home() / "Downloads/multi-rice-v6-compatibility-build-report.zip"
    with zipfile.ZipFile(report_zip, "w", zipfile.ZIP_DEFLATED) as archive:
        archive.writestr("report.json", json.dumps(report, indent=2) + "\n")
        for name in ("packaging.log", "compatibility-build-report.json"):
            if (output / name).is_file():
                archive.write(output / name, name)
    print("REPORT: " + str(report_zip), flush=True)
    return 1 if report.get("status") == "failed" else 0


if __name__ == "__main__":
    sys.exit(main())
