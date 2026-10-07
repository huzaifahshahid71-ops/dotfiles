#!/usr/bin/env python3
"""Assemble a candidate AppDir from tested host inputs, without installation."""
import argparse
import importlib.util
import importlib.metadata
import json
import os
from pathlib import Path
import pwd
import re
import shutil
import subprocess
import sys
import zipfile

from core import PROFILES, SetupError, no_symlink_parents, relative_path, sha256
from staging import HOME_TOKEN, USER_TOKEN, portable, SKIP_NAMES, included, PREFIX
from eclipse_launchers import add_launchers
from eclipse_defaults import ECLIPSE_CONFIGS, render_defaults as eclipse_defaults
from runtime_sources import state_code, wallpaper_asset, special_source, LUMINA_DEFAULT, lumina_wallpaper_defaults, CIPHER_SHELL, cipher_shell_path
from maintenance import valid_paths, write_json

ROOT = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('prepare_host', ROOT / 'prepare-host.py')
prepare = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prepare)
RUNTIME_EXTENSIONS = {'.qml','.js','.mjs','.json','.jsonc','.toml','.ini','.conf','.sh','.py',
                      '.css','.scss','.svg','.png','.webp','.jpg','.jpeg','.qsb','.ttf','.otf',
                      '.xml','.qrc','.desktop','.lua','.kdl','.frag','.vert','.glsl','.so','.qmltypes','.txt'}
SECRET = re.compile(rb'(?:gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|'
                    rb'sk-[A-Za-z0-9_-]{20,}|-----BEGIN (?:RSA |OPENSSH |EC )?PRIVATE KEY-----)')


def production_path(relative):
    path = relative_path(relative)
    ignored = SKIP_NAMES - {'state', '.state'} if state_code(relative) else SKIP_NAMES
    extras = {'docs', 'screenshots', 'recordings', 'test', 'tests',
              'wallpapers', 'downloads', '.venv', 'build'}
    if wallpaper_asset(relative): extras.remove('wallpapers')
    return (not any(part in ignored | extras for part in path.parts)
            and not re.search(r'\.(bak|backup|orig|old)(?:$|[-.])|\.(log|pyc)$|\.pre-|\.before-', relative)
            and (path.suffix.lower() in RUNTIME_EXTENSIONS or path.suffix == '' or
                 path.name.startswith(('LICENSE', 'COPYING', 'NOTICE'))))


def shortcut_menu(layer, toolkit):
    spec = importlib.util.spec_from_file_location('shared_shortcut_install', toolkit / 'install.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    launcher = HOME_TOKEN + '/.local/bin/multi-rice-shortcuts'
    for name in module.HYPR:
        relative = PREFIX + name + '/hypr/hyprland.lua'
        layer.generated(relative,module.lua_patch((layer.payload / 'home' / relative).read_text(),launcher))
    for name in module.NIRI:
        relative = PREFIX + name
        layer.generated(relative,module.niri_patch((layer.payload / 'home' / relative).read_text(),launcher))
    manifest = json.loads((toolkit / 'payload-manifest.json').read_text())
    for name, fingerprint in manifest['files'].items():
        layer.add(toolkit / name,'.local/share/multi-rice-shortcuts/' + name,expected=fingerprint)
    layer.generated('.local/bin/multi-rice-shortcuts',
                    '#!/usr/bin/env bash\nexec /usr/bin/python3 "$HOME/.local/share/multi-rice-shortcuts/launcher.py" "$@"\n',0o755)


def load_tool(path,name):
    spec=importlib.util.spec_from_file_location(name,path)
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    return module


def solstice_update(layer,toolkit):
    module=load_tool(toolkit/'install.py','candidate_solstice_update')
    source=layer.payload/'home'/module.PREFIX
    changes=module.plan(source)
    for name,data in changes.items():
        relative=module.PREFIX+'/'+name
        layer.generated(relative,data.decode(),init=layer.files.get(relative,{}).get('init',False))
    return {'repository':'MystiaFin/JAQC-shell','commit':json.loads((toolkit/'upstream.json').read_text())['head'],'changed_files':len(changes),'custom_seek':True,'idle_timeouts_default':False}


def login_cards(layer,toolkit):
    module=load_tool(toolkit/'patch.py','candidate_sumi_login')
    relative='.local/share/desktop-switcher/themes/sumi-deck/DotsBrowser.qml'
    text=module.patch_with_grub((layer.payload/'home'/relative).read_text())
    layer.generated(relative,text)
    layer.generated('.local/share/multi-rice-sddm/LoginCards.qml',text)
    layer.add(toolkit/'backend.py','.local/share/multi-rice-sddm/backend.py')
    layer.generated('.local/bin/multi-rice-sddm','#!/usr/bin/env bash\nexec /usr/bin/python3 "$HOME/.local/share/multi-rice-sddm/backend.py" "$@"\n',0o755)


def grub_cards(layer,toolkit,prepared):
    for name in ('backend.py','catalog.json'):
        layer.add(toolkit/name,'.local/share/multi-rice-grub/'+name)
    manifest=json.loads((prepared/'install-manifest.json').read_text())
    expected={c['id']+'.webp' for c in json.loads((toolkit/'catalog.json').read_text())['cards']}
    supplied={Path(r['path']).name for r in manifest['files'] if Path(r['path']).parts[0]=='previews'}
    if supplied!=expected:raise SetupError('Prepare all eight GRUB previews first with multi-rice-grub/install.py --install')
    for item in manifest['files']:
        relative=relative_path(item['path'])
        if relative.parts[0]!='previews' or len(relative.parts)!=2:continue
        layer.add(prepared/relative,'.local/share/multi-rice-grub/'+str(relative),expected=item['sha256'])
    if len(list((prepared/'previews').glob('*.webp')))!=8:raise SetupError('Prepare all eight GRUB previews first with multi-rice-grub/install.py --install')
    layer.generated('.local/bin/multi-rice-grub','#!/usr/bin/env bash\nexec /usr/bin/python3 "$HOME/.local/share/multi-rice-grub/backend.py" "$@"\n',0o755)


def grub_system_files(payload,toolkit,library=Path('/usr/local/share/evangelion'),eva=Path('/usr/local/bin/eva')):
    # Bundle the installed, ready manager/catalog; do not copy machine boot state.
    if not eva.is_file() or not (library/'themes/catalog.json').is_file():raise SetupError('Installed Evangelion manager/catalog missing')
    records=[]
    pairs=[(eva,'usr/local/bin/eva'),(toolkit/'system.py','usr/local/libexec/multi-rice-grub.py')]
    pairs += [(p,'usr/local/share/evangelion/'+p.relative_to(library).as_posix()) for p in library.rglob('*')
              if p.is_file() and (p.relative_to(library).parts[0] in ('bin','docs','themes') or p.name=='LICENSE')]
    for source,relative in pairs:
        no_symlink_parents(source)
        if source.is_symlink() or (source!=toolkit/'system.py' and (source.stat().st_uid!=0 or source.stat().st_mode & 0o022)):raise SetupError('Unsafe installed GRUB source: '+str(source))
        destination=payload/'system/grub-manager'/relative;destination.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,destination)
        mode=0o755 if relative=='usr/local/bin/eva' or relative.endswith(('/bin/eva','/bin/install.sh')) else 0o644
        records.append({'path':relative,'source':destination.relative_to(payload).as_posix(),'mode':mode,'sha256':sha256(destination)})
    return records


def login_system_files(stage,payload,toolkit):
    if not (stage/'install-manifest.json').is_file():
        raise SetupError('Prepare the login themes first with multi-rice-sddm/install.py --install --prepare-only.')
    manifest=json.loads((stage/'install-manifest.json').read_text())
    if manifest.get('schema')!=1:raise SetupError('Unsupported login source manifest')
    records=[];names=set()
    for item in manifest['files']:
        relative=relative_path(item['path'])
        if relative.parts[0] not in ('sources','previews') and str(relative)!='catalog.json':raise SetupError('Unregistered login payload path')
        if str(relative) in names:raise SetupError('Duplicate login payload file')
        names.add(str(relative));source=stage/relative;no_symlink_parents(source)
        if sha256(source)!=item['sha256']:raise SetupError('Prepared login source changed: '+str(relative))
        target=payload/'system/login-themes'/relative;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,target)
        if sha256(target)!=item['sha256']:raise SetupError('Login source copy differs')
        records.append({'path':'usr/local/share/multi-rice-sddm/'+str(relative),'source':target.relative_to(payload).as_posix(),'mode':0o644,'sha256':item['sha256']})
    helper=toolkit/'system.py'
    if sha256(helper)!=manifest['helper_sha256']:raise SetupError('Theme helper differs from the prepared version; rerun theme preparation')
    destination=payload/'system/multi-rice-sddm.py';shutil.copyfile(helper,destination)
    records.append({'path':'usr/local/libexec/multi-rice-sddm.py','source':destination.relative_to(payload).as_posix(),'mode':0o644,'sha256':sha256(destination)})
    load_tool(toolkit/'system.py','candidate_theme_validate').cards(payload/'system/login-themes')
    return records


class Layer:
    def __init__(self, payload, home):
        self.payload, self.home = payload, home
        self.files, self.links = {}, {}

    def add(self, source, relative, init=False, expected=None, force_mode=None):
        relative_path(relative)
        real = source.resolve(strict=True)
        if not real.is_file():
            raise SetupError('Expected runtime file: ' + str(source))
        if expected and sha256(real) != expected:
            raise SetupError('Source staging changed: ' + relative)
        destination = self.payload / 'home' / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(real, destination)
        template = False
        if destination.stat().st_size < 20 * 1024**2:
            data = destination.read_bytes()
            if b'\x00' not in data and SECRET.search(data):
                destination.unlink()
                raise SetupError('Possible credential in runtime input; retained on host: ' + relative)
            data, _ = portable(data, str(self.home))
            if relative in ECLIPSE_CONFIGS:
                data = eclipse_defaults(data)
            if relative==CIPHER_SHELL:data=cipher_shell_path(data)
            from runtime_sources import startup_source_defaults
            data=startup_source_defaults(relative,data,HOME_TOKEN)
            if relative == ".local/bin/background-music":
                from shared_runtime_defaults import music_defaults
                data=music_defaults(data)
            destination.write_bytes(data)
            template = HOME_TOKEN.encode() in data or USER_TOKEN.encode() in data
        mode = force_mode or (0o755 if real.stat().st_mode & 0o111 else 0o644)
        destination.chmod(mode)
        self.files[relative] = {'path': relative, 'source': 'home/' + relative, 'mode': mode,
                                'sha256': sha256(destination), 'bytes': destination.stat().st_size,
                                'template': template, 'init': init}

    def generated(self, relative, text, mode=0o644, init=False):
        relative_path(relative)
        destination = self.payload / 'home' / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(text)
        destination.chmod(mode)
        self.files[relative] = {'path': relative, 'source': 'home/' + relative, 'mode': mode,
                                'sha256': sha256(destination), 'bytes': destination.stat().st_size,
                                'template': HOME_TOKEN in text or USER_TOKEN in text, 'init': init}

    def link(self, relative, target):
        relative_path(relative)
        if relative in self.files:
            raise SetupError('A discovery link overlaps an assembled file: ' + relative)
        self.links[relative] = {'path': relative, 'target': HOME_TOKEN + '/' + target}

    def git_tree(self, source, target):
        source.resolve(strict=True).relative_to(self.home)
        check = subprocess.run(['git','-C',str(source),'rev-parse','--show-toplevel'],
                               capture_output=True,text=True,timeout=20)
        if check.returncode or Path(check.stdout.strip()).resolve() != source.resolve():
            prepare.progress('Using installed runtime copy: ' + target)
            before = len(self.files)
            self.directory(source,target)
            count = len(self.files) - before
            if not count:
                raise SetupError('Installed runtime copy contains no production files: ' + target)
            return {'kind':'installed-copy','commit':None,'files':count,
                    'provenance':'Individual file fingerprints in payload plan; no Git commit inferred'}
        commit = prepare.run(['git','-C',str(source),'rev-parse','HEAD'])
        tracked = prepare.run(['git','-C',str(source),'ls-files','-z'])
        count = 0
        for relative in tracked.split('\x00'):
            if not relative or not production_path(relative):
                continue
            path = source / relative
            if not path.is_file():
                continue
            path.resolve(strict=True).relative_to(self.home)
            self.add(path, target + '/' + relative)
            count += 1
        if not count:
            raise SetupError('External Git runtime is empty: ' + str(source))
        return {'kind':'git-working-tree','commit': commit, 'files': count,
                'working_diff_sha256': __import__('hashlib').sha256(
                    prepare.run(['git','-C',str(source),'diff','HEAD','--']).encode()).hexdigest()}

    def directory(self, source, target):
        source.resolve(strict=True).relative_to(self.home)
        if not source.is_dir():
            raise SetupError('Missing runtime directory: ' + str(source))
        for directory, children, files in os.walk(source, followlinks=False):
            children[:] = sorted(name for name in children if name not in SKIP_NAMES or
                name in {'state','.state'} and special_source(target+'/'+(Path(directory)/name).relative_to(source).as_posix(), directory=True))
            for name in sorted(files):
                path = Path(directory) / name
                relative = path.relative_to(source).as_posix()
                if production_path(relative) and path.is_file():
                    path.resolve(strict=True).relative_to(self.home)
                    self.add(path, target + '/' + relative)


def bundled_lumina_defaults(layer,addon):
    manifest=json.loads((addon/'manifest.json').read_text())
    row=next((r for r in manifest['files'] if r['path']==LUMINA_DEFAULT),None)
    if not row:raise SetupError('Prepare the pinned default Lumina wallpaper before assembly.')
    layer.add(addon/relative_path(row['source']),LUMINA_DEFAULT,expected=row['sha256'],force_mode=0o644)
    relative='.local/share/desktop-profiles/sayconlun/support/bin/rice-wallpaper'
    helper=layer.files[relative]
    data=lumina_wallpaper_defaults((layer.payload/helper['source']).read_bytes())
    layer.generated(relative,data.decode(),mode=helper['mode'],init=helper.get('init',False))


def assemble(preparation, output, home):
    no_symlink_parents(preparation)
    no_symlink_parents(output)
    if not preparation.is_relative_to(home) or not output.is_relative_to(home):
        raise SetupError('Build and preparation directories must be inside your home.')
    if output.exists():
        raise SetupError('Use a new candidate directory; existing work is retained.')
    report_zip = home / 'Downloads/multi-rice-v6-assembly-report.zip'
    no_symlink_parents(report_zip)
    if report_zip.exists():
        raise SetupError('An earlier assembly report exists; rename it before assembling: ' + str(report_zip))
    report = json.loads((preparation / 'build-report.json').read_text())
    if report.get('audit_revision') != 2 or report.get('missing_archives') or report.get('missing_runtime') or report.get('changed_pinned_runtime'):
        raise SetupError('The corrected host preparation is incomplete.')
    output.mkdir(parents=True)
    appdir = output / 'AppDir'
    payload = appdir / 'payload'
    payload.mkdir(parents=True)
    layer = Layer(payload, home)
    provenance = {}
    prepare.progress('Assembling reviewed twelve-profile source layer')
    sources = json.loads((preparation / 'sources/source-layer.json').read_text())
    for index, record in enumerate(sources['files'], 1):
        if record['path'].startswith(PREFIX) and not included(record['path']) and record['path'] != PREFIX + 'inir/home/.config/inir/config.json':
            continue
        layer.add(preparation / 'sources/home' / str(relative_path(record['path'])), record['path'],
                  expected=record['sha256'], init=record.get('init',False),
                  force_mode=0o755 if record['mode'] & 0o111 else 0o644)
        if index % 500 == 0:
            prepare.progress(f'Assembled source files {index}/{len(sources["files"])}')
    for name in ('nexus-netrate','nexus-page','nexus-refresh','nexus-system'):
        relative = PREFIX + 'tsugumori/support/config/waybar/scripts/' + name
        layer.add(home / relative,relative,force_mode=0o755)
    # Stable shared defaults come from the development branch, never from the
    # user's live playlists, browser/account settings or private desktop state.
    defaults = ROOT / 'build-support/defaults'
    if not defaults.is_dir():
        raise SetupError('The candidate kit lacks shared defaults.')
    for path in sorted(defaults.rglob('*')):
        if path.is_file():
            relative = path.relative_to(defaults).as_posix()
            if relative not in layer.files:
                layer.add(path, relative, init=relative.startswith('.config/') and '/systemd/' not in relative)
    if ".local/bin/refresh-rate-ctl" not in layer.files:
        layer.add(ROOT / "build-support/shared-runtime/refresh-rate-ctl", ".local/bin/refresh-rate-ctl", force_mode=0o755)
    add_launchers(layer, ROOT / 'build-support/eclipse-launcher')
    prepare.progress('Assembling external end4 and Ambxst runtimes')
    for source, target in ((home / '.local/src/end4-dots','.local/src/end4-dots'),
                           (home / '.config/quickshell/end4-pC','.config/quickshell/end4-pC'),
                           (home / '.local/src/ambxst','.local/src/ambxst')):
        provenance[target] = layer.git_tree(source, target)
    # ii remains an independent discovery entry; the target's entire subtree
    # has already been staged from the tracked upstream tree.
    layer.link('.config/quickshell/ii','.local/src/end4-dots/dots/.config/quickshell/ii')
    prepare.progress('Assembling Aurora production runtime and shared music plugin')
    serp = home / '.local/share/serpantinum'
    for child in ('bin','src'):
        layer.directory(serp / child, '.local/share/serpantinum/' + child)
    layer.add(serp / 'version.txt','.local/share/serpantinum/version.txt')
    for name in ('serpantinum','serpantinumd'):
        layer.link('.local/bin/' + name,'.local/share/serpantinum/bin/' + name)
    layer.add(home / '.local/lib/huzaifah/mpv-mpris/mpris.so','.local/lib/huzaifah/mpv-mpris/mpris.so')
    prepare.progress('Staging Eclipse materialyoucolor 3.0.4 and ABI provenance')
    python = home / '.local/share/desktop-profiles/inir/venv/bin/python'
    query = ('import importlib.metadata as m,importlib.util as u,json,sys; '
             'd=m.distribution("materialyoucolor"); '
             'print(json.dumps({"version":d.version,"package":list(u.find_spec("materialyoucolor").submodule_search_locations)[0],'
             '"metadata":str(d._path),"abi":sys.implementation.cache_tag}))')
    private_python = json.loads(prepare.run([str(python),'-c',query]))
    if private_python['version'] != '3.0.4':
        raise SetupError('Eclipse private dependency version differs from the tested 3.0.4.')
    base = '.local/share/desktop-profiles/inir/python'
    layer.directory(Path(private_python['package']),base + '/materialyoucolor')
    # Installed wheel metadata includes licenses and exact package provenance.
    metadata = Path(private_python['metadata'])
    for path in metadata.rglob('*'):
        if path.is_file() and '__pycache__' not in path.parts:
            layer.add(path,base + '/' + metadata.name + '/' + path.relative_to(metadata).as_posix())
    for name in ('lumina','solstice','clavis'):
        profile = {'lumina':'sayconlun','solstice':'jaqc','clavis':'clavis'}[name]
        layer.link('.config/quickshell/' + name,'.local/share/desktop-profiles/' + profile + '/support/quickshell/' + name)
    for name in ('nixri-dms','nixri-dms-ipc','nixri-dms-restart'):
        layer.link('.local/bin/' + name,'.local/share/desktop-profiles/nixri/support/bin/' + name)
    for name in ('refresh-rate-auto.service','rice-wallpaper-auto.service'):
        layer.link('.config/systemd/user/wayland-session-xdg-autostart@hyprland.desktop.target.wants/' + name,
                   '.config/systemd/user/' + name)
    layer.generated('.local/bin/ambxst','#!/usr/bin/env bash\nexport PATH="$HOME/.local/bin:$PATH"\nexec "$HOME/.local/src/ambxst/cli.sh" "$@"\n',0o755)
    layer.generated('.local/share/desktop-profiles/clavis/native/READY','6.0.0\n')
    layer.generated('.config/desktop-switcher/theme','sumi-deck\n',init=True)
    prepare.progress('Adding shared Super+/ shortcut menu to all twelve profiles')
    shortcut_menu(layer,ROOT / 'build-support/shortcut-menu')
    prepare.progress('Adding Solstice update and Sumi Deck login theme cards')
    provenance['solstice-update']=solstice_update(layer,ROOT/'build-support/solstice-update')
    login_cards(layer,ROOT/'build-support/sddm-themes')
    grub_cards(layer,ROOT/'build-support/grub-themes',home/'.local/share/multi-rice-grub-preparation')
    bundled_lumina_defaults(layer,ROOT/'runtime-repair')
    # Persist the small UI/maintenance source alongside configuration receipts;
    # the giant payload is not needed to preflight or restore an installation.
    for name in ('app.py','core.py','maintenance.py','runner.py','recovery.py','release.json','wallpapers.json'):
        layer.add(ROOT / name,'.local/share/multi-rice-setup/runtime/' + name)
    for path in (ROOT / 'assets').glob('*.webp'):
        layer.add(path,'.local/share/multi-rice-setup/runtime/assets/' + path.name)
    valid_paths([*layer.files,*layer.links])
    missing_targets = [link['target'] for link in layer.links.values()
                       if not any(path == link['target'][len(HOME_TOKEN)+1:] or
                                  path.startswith(link['target'][len(HOME_TOKEN)+1:] + '/') for path in layer.files)]
    if missing_targets:
        raise SetupError('Discovery targets were not assembled: ' + ', '.join(missing_targets))
    prepare.progress('Resolving candidate packages with the installed Aether shell provider')
    database = prepare.read_database(Path('/var/lib/pacman/local'))
    targets = (ROOT / 'build-targets.txt').read_text().split()
    targets = ['caelestia-shell' if name == 'dim-caelestia-shell-git' else name for name in targets]
    targets += ['awww','sddm','qt6-declarative','qt6-svg','qt6-5compat','qt6-virtualkeyboard','qt6-multimedia','qt6-imageformats','imagemagick','ffmpeg','ttf-dejavu',*report['cached_packages']]
    closure, unresolved, mapping = prepare.resolve_closure(database, targets,
        lambda a,b: int(prepare.run(['/usr/bin/vercmp',a,b])))
    if unresolved:
        write_json(output / 'assembly-report.json',{'status':'blocked','unresolved':unresolved})
        raise SetupError('Candidate dependency closure incomplete: ' + ', '.join(unresolved))
    cached, missing = prepare.cache_archives([preparation / 'packages',Path('/var/cache/pacman/pkg'),home / '.cache/paru'], database,closure)
    if missing:
        write_json(output / 'assembly-report.json',{'status':'blocked','missing_archives':missing})
        raise SetupError('Additional exact archives needed: ' + ', '.join(missing))
    required = sum(path.stat().st_size for path in cached.values())
    if shutil.disk_usage(output).free < required + 1024**3:
        raise SetupError('Insufficient space for candidate package copies.')
    directory = payload / 'packages'
    directory.mkdir()
    packages = []
    staged_records = {record['name']:record for record in json.loads((preparation / 'packages.json').read_text())}
    for index,(name,source) in enumerate(sorted(cached.items()),1):
        digest = sha256(source)
        previous = staged_records.get(name)
        if previous and previous['sha256'] != digest:
            raise SetupError('Prepared package fingerprint differs: ' + name)
        destination = directory / source.name
        shutil.copyfile(source,destination)
        if sha256(destination) != digest:
            raise SetupError('Candidate package copy failed: ' + name)
        packages.append({'name':name,'version':database[name]['VERSION'][0],
                         'source':'packages/' + source.name,'bytes':destination.stat().st_size,'sha256':digest})
        if index % 25 == 0 or index == len(cached):
            prepare.progress(f'Assembled candidate archives {index}/{len(cached)}')
    system_files = []
    system = payload / 'system'
    system.mkdir()
    for name,text in [('multi-rice-session','#!/usr/bin/env bash\nexec "$HOME/.local/bin/multi-rice-session" "$@"\n'),
                      ('ambxst','#!/usr/bin/env bash\nexec "$HOME/.local/bin/ambxst" "$@"\n')]:
        destination = system / name
        destination.write_text(text)
        system_files.append({'path':'usr/local/bin/' + name,'source':'system/' + name,'mode':0o755,'sha256':sha256(destination)})
    axctl = Path('/usr/local/bin/axctl')
    if not axctl.is_file():
        axctl = home / '.local/bin/axctl'
    if not axctl.is_file():
        raise SetupError('The tested Ambxst axctl executable is missing.')
    shutil.copyfile(axctl,system / 'axctl')
    system_files.append({'path':'usr/local/bin/axctl','source':'system/axctl','mode':0o755,'sha256':sha256(system / 'axctl')})
    session = system / 'huzaifah-multi-rice.desktop'
    session.write_text('[Desktop Entry]\nName=Huzaifah Multi-Rice\nComment=Twelve profile desktops\nExec=/usr/local/bin/multi-rice-session\nType=Application\nDesktopNames=Hyprland;niri;\n')
    system_files.append({'path':'usr/share/wayland-sessions/' + session.name,'source':'system/' + session.name,'mode':0o644,'sha256':sha256(session)})
    prepare.progress('Bundling verified login theme sources and previews')
    system_files.extend(login_system_files(home/'.local/share/multi-rice-sddm-preparation',payload,ROOT/'build-support/sddm-themes'))
    system_files.extend(grub_system_files(payload,ROOT/'build-support/grub-themes'))
    provenance['login-themes']=json.loads((home/'.local/share/multi-rice-sddm-preparation/catalog.json').read_text())
    plan = {'schema':1,'version':'6.0.0','status':'candidate','profiles':PROFILES,
            'user_files':list(layer.files.values()),'user_links':list(layer.links.values()),
            'system_files':system_files,'packages':packages,'private_python':{'abi':private_python['abi'],'version':'3.0.4'},
            'provenance':provenance}
    write_json(payload / 'plan.json',plan)
    backend = appdir / 'backend'
    backend.mkdir()
    for name in ('payload_backend.py','system_transaction.py','core.py','maintenance.py','recovery.py','staging.py'):
        shutil.copyfile(ROOT / name,backend / name)
    apprun = appdir / 'AppRun'
    apprun.write_text('#!/usr/bin/env bash\nset -euo pipefail\nROOT="$(cd -- "$(dirname -- "$0")" && pwd)"\ncase "${1:-}" in\n --multi-rice-protocol) printf \'{"protocol":1,"version":"6.0.0","status":"candidate"}\\n\' ;;\n --multi-rice-backend) [[ $# == 2 ]] || exit 2; exec /usr/bin/python3 "$ROOT/backend/payload_backend.py" "$2" --payload "$ROOT/payload" ;;\n *) printf \'Candidate payload. Use Sumi Setup after release validation, or test the backend in a disposable VM.\\n\'; exit 2 ;;\nesac\n')
    apprun.chmod(0o755)
    (appdir / 'multi-rice.desktop').write_text('[Desktop Entry]\nType=Application\nName=Multi-Rice candidate payload\nExec=AppRun\nIcon=multi-rice\nCategories=Utility;\n')
    (appdir / 'multi-rice.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128"><rect width="128" height="128" rx="24" fill="#0d0f09"/><text x="32" y="90" font-size="80" fill="#b4d088">S</text></svg>')
    # Structural verification does not launch a compositor or authenticate.
    from payload_backend import validate_plan
    validate_plan(payload,home)
    result = {'status':'candidate-appdir','version':'6.0.0','profiles':PROFILES,
              'files':len(layer.files),'links':len(layer.links),'packages':len(packages),
              'package_bytes':required,'plan_sha256':sha256(payload / 'plan.json'),
              'aether_provider':mapping['caelestia-shell'],'provenance':provenance,
              'private_python':plan['private_python'],
              'release_features':{'login_cards':len(provenance['login-themes']['cards']),
                                  'grub_cards':len(json.loads((ROOT/'build-support/grub-themes/catalog.json').read_text())['cards']),
                                  'sumi_catalogs':['DESKTOPS','LOGIN','GRUB THEMES'],
                                  'shared_authentication':True,'stable_sumi_tabs':True,
                                  'shortcut_design':'Lumina native'},
              'remaining':['AppImage packaging','Small GUI runtime bundle','VM fresh installation, upgrade and restore tests','VM login and GRUB selection tests','Publication'],
              'system_changes':False}
    packagers = [Path('/usr/bin/appimagetool'),home / '.local/bin/appimagetool',
                 home / 'dotfiles/installer-appimage-offline/.build/appimagetool-modern-x86_64.AppImage']
    result['appimage_packager_candidates'] = [{'path':str(path),'bytes':path.stat().st_size,'sha256':sha256(path)}
                                              for path in packagers if path.is_file()]
    result['mksquashfs_available'] = Path('/usr/bin/mksquashfs').is_file()
    result['gui_toolchain']={'python':sys.version.split()[0],'python_abi':sys.implementation.cache_tag,
                             'pyside6_available':importlib.util.find_spec('PySide6') is not None}
    for distribution in ('PySide6','shiboken6'):
        try:result['gui_toolchain'][distribution]=importlib.metadata.version(distribution)
        except importlib.metadata.PackageNotFoundError:pass
    result['package_architectures'] = sorted({path.name.rsplit('.pkg.tar.',1)[0].rsplit('-',1)[-1]
                                             for path in cached.values()})
    write_json(output / 'assembly-report.json',result)
    report_zip.parent.mkdir(parents=True,exist_ok=True)
    if report_zip.exists():
        raise SetupError('Report ZIP already exists; candidate retained: ' + str(output))
    with zipfile.ZipFile(report_zip,'w',zipfile.ZIP_DEFLATED) as archive:
        archive.write(output / 'assembly-report.json','assembly-report.json')
    prepare.progress('ASSEMBLED: ' + str(appdir))
    prepare.progress('REPORT: ' + str(report_zip))
    prepare.progress('Candidate only. No installation, desktop restart, upgrade or upload was performed.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--preparation',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args = parser.parse_args()
    home = Path(pwd.getpwuid(os.getuid()).pw_dir).resolve()
    if os.getuid() == 0 or os.environ.get('HOME') != str(home):
        raise SetupError('Run as the desktop user without sudo.')
    assemble(args.preparation.expanduser().absolute(),args.output.expanduser().absolute(),home)


if __name__ == '__main__':
    try:
        main()
    except (OSError,ValueError,KeyError,SetupError,subprocess.TimeoutExpired) as error:
        prepare.progress('Candidate assembly stopped: ' + str(error))
        sys.exit(1)
