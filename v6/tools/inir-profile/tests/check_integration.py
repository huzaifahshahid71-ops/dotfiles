#!/usr/bin/env python3
"""Exercise real file transactions and pinned adaptation; mock host-only runtimes."""
import base64
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
from unittest.mock import patch
import io

PACKAGE=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(PACKAGE))
import adapt
import environment
import install
import fonts
from transaction import digest

def check_dependencies():
    assert 'ttf-roboto-flex' not in install.PACKAGES
    assert 'polkit-gnome' not in install.PACKAGES
    for scenario in ['installed','available','unavailable','query-failure']:
        calls=[]
        def fake(args,**kwargs):
            calls.append(args)
            if args[:2]==['pacman','-T']:
                if scenario=='query-failure': return subprocess.CompletedProcess(args,1,'','database error')
                missing=scenario!='installed' and not any(x[0]=='sudo' for x in calls)
                return subprocess.CompletedProcess(args,127 if missing else 0,'qt6-imageformats\n' if missing else '','')
            if args[:2]==['pacman','-Si']:
                return subprocess.CompletedProcess(args,1 if scenario=='unavailable' else 0,'','')
            assert args==['sudo','pacman','-S','--needed','qt6-imageformats']
            return subprocess.CompletedProcess(args,0)
        with patch.object(install.subprocess,'run',fake):
            if scenario in ['unavailable','query-failure']:
                try: install.dependencies(True); raise AssertionError('dependency failure accepted')
                except RuntimeError as error:
                    assert ('Unavailable' if scenario=='unavailable' else 'database error') in str(error)
            else: install.dependencies(True)
        assert any(x[0]=='sudo' for x in calls)==(scenario=='available')
    print('PASS: repository preflight stops unavailable packages before sudo; installed/available dependencies pass')

def check_polkit():
    with tempfile.TemporaryDirectory(prefix='inir-polkit-') as name:
        base=Path(name); missing=base/'missing'; disabled=base/'disabled'; agent=base/'agent'
        disabled.write_text('#!/bin/sh\nexit 0\n'); disabled.chmod(0o644)
        assert adapt.polkit_fallback([missing,disabled]) is None
        agent.write_text('#!/bin/sh\nexit 0\n'); agent.chmod(0o755)
        assert adapt.polkit_fallback([missing,disabled,agent])==str(agent)
        old_root=install.ROOT
        try:
            install.ROOT=base/'profile'; (install.ROOT/'runtime').mkdir(parents=True)
            for fallback,fail in [(None,False),(str(agent),False),(None,True)]:
                (install.ROOT/'POLKIT.json').write_text(json.dumps({'fallback':fallback}))
                def component_check(args,env,log,**kwargs):
                    harness=(install.ROOT/'runtime/multi-rice-check.qml').read_text()
                    assert ('services/PolkitServiceImpl.qml' in harness)==(fallback is None)
                    assert 'component.createObject' not in harness
                    assert env['QT_QPA_PLATFORM']=='wayland' and env['WAYLAND_DISPLAY']==str(base/'wayland-test')
                    assert env['HOME']==str(install.ROOT/'home') and 'DBUS_SESSION_BUS_ADDRESS' not in env
                    return 0,'INIR_COMPONENT_FAILURE: services/PolkitServiceImpl.qml' if fail else 'INIR_COMPONENTS_READY'
                with patch.dict(os.environ,WAYLAND_DISPLAY=str(base/'wayland-test')),\
                     patch.object(Path,'is_socket',side_effect=lambda:True),\
                     patch.object(install,'run',return_value=''),patch.object(install,'run_qml_check',component_check):
                    if fail:
                        try: install.validate_runtime(); raise AssertionError('missing native authentication accepted')
                        except RuntimeError as error: assert 'PolkitServiceImpl.qml' in str(error)
                    else: install.validate_runtime()
        finally: install.ROOT=old_root
    print('PASS: standalone Polkit fallback requires an existing executable; no conflicting agent dependency')

def check_wayland_environment():
    with tempfile.TemporaryDirectory(prefix='inir-wayland-') as name:
        path=Path(name)
        # A real compositor/socket is host-only; mock the OS socket inspection.
        with patch.object(Path,'is_socket',lambda file:file==path/'wayland-1'):
            original=dict(os.environ,HOME='/home/gamer',WAYLAND_DISPLAY='wayland-1',XDG_RUNTIME_DIR=name,
                          QT_QPA_PLATFORM='offscreen',DBUS_SESSION_BUS_ADDRESS='session-bus',
                          NIRI_SOCKET='niri-ipc',DISPLAY=':0',HYPRLAND_INSTANCE_SIGNATURE='other-rice')
            env=install.qml_check_environment(original)
            assert env['QT_QPA_PLATFORM']=='wayland' and env['WAYLAND_DISPLAY']=='wayland-1'
            assert env['XDG_RUNTIME_DIR']==name and env['QT_QUICK_BACKEND']=='software'
            assert env['HOME']==str(install.ROOT/'home')
            assert not any(key in env for key in ['DBUS_SESSION_BUS_ADDRESS','NIRI_SOCKET','DISPLAY','HYPRLAND_INSTANCE_SIGNATURE'])
            assert original['QT_QPA_PLATFORM']=='offscreen' and original['HOME']=='/home/gamer'
            for missing in ['', 'missing-wayland']:
                try: install.qml_check_environment(dict(original,WAYLAND_DISPLAY=missing));raise AssertionError('missing display accepted')
                except RuntimeError as error: assert 'Wayland' in str(error)
    print('PASS: QML checker retains the live Wayland socket while isolating HOME, bus and compositor IPC')

def check_qml_process_cleanup():
    old_root=install.ROOT
    with tempfile.TemporaryDirectory(prefix='inir-qml-process-') as name:
        try:
            install.ROOT=Path(name)
            fake_proc=install.ROOT/'proc';fake_proc.mkdir()
            expected=[b'/usr/bin/qs',b'-p',os.fsencode(install.ROOT/'runtime/multi-rice-check.qml')]
            context=[b'INIR_PROFILE_ROOT='+os.fsencode(install.ROOT),b'HOME='+os.fsencode(install.ROOT/'home'),
                     b'QT_QPA_PLATFORM=offscreen']
            for pid,cmd,env in [(100,expected,context),(101,expected,[]),
                                (102,[b'/usr/bin/qs',b'-p',b'/normal/shell.qml'],context),
                                (103,expected,context[:-1]+[b'QT_QPA_PLATFORM=wayland'])]:
                entry=fake_proc/str(pid);entry.mkdir()
                (entry/'cmdline').write_bytes(b'\0'.join(cmd)+b'\0')
                (entry/'environ').write_bytes(b'\0'.join(env)+b'\0')
            assert set(install.previous_check_pids(fake_proc))=={100,103}
            signals=[]
            with patch.object(install,'previous_check_pids',side_effect=[[100],[100]]),\
                 patch.object(install.os,'kill',side_effect=lambda pid,sig:signals.append((pid,sig))),\
                 patch.object(install.time,'sleep',return_value=None):
                install.stop_previous_checks()
            import signal
            assert signals==[(100,signal.SIGTERM),(100,signal.SIGKILL)]
            code,output=install.run_qml_check([sys.executable,'-c','print("INIR_COMPONENTS_READY",flush=True)'],
                                           os.environ,install.ROOT/'logs/success.log',timeout=2)
            assert code==0 and 'INIR_COMPONENTS_READY' in output
            # Both parent and child ignore TERM; only the checker process group
            # may be killed. Output must survive the timeout.
            script=('import subprocess,signal,time,os;signal.signal(signal.SIGTERM,signal.SIG_IGN);'
                    'child=subprocess.Popen(["'+sys.executable+'","-c",'
                    '"import signal,time;signal.signal(signal.SIGTERM,signal.SIG_IGN);time.sleep(30)"]);'
                    'print("CHILD_PID="+str(child.pid),flush=True);time.sleep(30)')
            log=install.ROOT/'logs/timeout.log'
            try:
                install.run_qml_check([sys.executable,'-c',script],os.environ,log,timeout=.3)
                raise AssertionError('hung checker accepted')
            except RuntimeError as error:
                assert 'timed out' in str(error) and 'CHILD_PID=' in str(error)
            pid=int(log.read_text().strip().split('=')[1])
            status=Path('/proc')/str(pid)/'stat'
            import time
            for _ in range(20):
                if not status.exists() or status.read_text().split()[2]=='Z': break
                time.sleep(.05)
            assert not status.exists() or status.read_text().split()[2]=='Z','checker child remained live'
        finally: install.ROOT=old_root
    print('PASS: timeout retains output and terminates only the isolated checker process group')

def check_fonts():
    with tempfile.TemporaryDirectory(prefix='inir-font-') as name:
        work=Path(name); runtime=work/'runtime'
        fonts.prepare_font(PACKAGE,runtime)
        assets=runtime/'assets/fonts/roboto-flex'
        # A source checkout downloads the same bytes; corrupt bundles fail closed.
        package=work/'source'; package.mkdir()
        shutil.copy2(PACKAGE/'font-manifest.json',package/'font-manifest.json')
        manifest=json.loads((package/'font-manifest.json').read_text())
        def fetch(url,**kwargs):
            item=next(x for x in manifest['files'] if x['url']==url)
            return io.BytesIO((assets/item['name']).read_bytes())
        with patch.object(fonts.urllib.request,'urlopen',fetch):
            fonts.prepare_font(package,work/'downloaded-runtime')
        bundled=package/'assets/fonts/roboto-flex'; bundled.mkdir(parents=True)
        (bundled/'RobotoFlex.ttf').write_bytes(b'corrupt')
        with patch.object(fonts.urllib.request,'urlopen',side_effect=AssertionError('corrupt font redownloaded')):
            try: fonts.prepare_font(package,work/'corrupt-runtime'); raise AssertionError('corrupt font accepted')
            except RuntimeError as error: assert 'checksum differs' in str(error)
        assert not (work/'home/.local/share/fonts').exists()
    print('PASS: private font assets and license verify hashes; pinned source fallback and corruption guard pass')

def module(path,name):
    spec=importlib.util.spec_from_file_location(name,path)
    m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
    return m

def shell(script,*args,env=None):
    return subprocess.run(['/usr/bin/bash','-c',script,'test',*map(str,args)],
                          env=env,capture_output=True,text=True,check=True).stdout

def check_environment():
    original=dict(os.environ,HOME='/home/gamer',XDG_CACHE_HOME='',XDG_STATE_HOME='/custom/state',
                  QT_SCALE_FACTOR='1.25',GSETTINGS_BACKEND='dconf')
    original.pop('XDG_CONFIG_HOME',None)
    root=Path('/home/gamer/.local/share/desktop-profiles/inir')
    private=environment.private_env(root,original)
    assert private['HOME'] == str(root/'home') and private['GSETTINGS_BACKEND']=='keyfile'
    assert environment.private_env(root,private)==private
    restored=environment.application_env(private)
    for key in environment.KEYS:
        assert restored.get(key)==original.get(key) and (key in restored)==(key in original),key
    assert not any(k.startswith('INIR_') for k in restored)
    result=subprocess.run([sys.executable,str(PACKAGE/'environment.py'),'--raw','--',sys.executable,
                           '-c','import os,json;print(json.dumps(dict(os.environ)))'],
                           capture_output=True,text=True,env=private,check=True)
    launched=json.loads(result.stdout)
    assert launched['HOME']=='/home/gamer' and launched['XDG_CACHE_HOME']==''
    assert 'XDG_CONFIG_HOME' not in launched
    print('PASS: subprocess application environment restores real HOME, custom XDG, unset/empty and Qt values')

def host_fixture(temp,source):
    home=temp/'home/gamer'; base=home/'.local/share/desktop-profiles'; base.mkdir(parents=True)
    metadata=home/'.local/share/desktop-switcher/profile-metadata.sh'; metadata.parent.mkdir()
    repo=PACKAGE.parents[2]
    original=(repo/'dual-rice/lib/profile-metadata.sh').read_text()
    original=original.replace('caelestia|end4|ambxst|dms|serpantinum|noctalia|sayconlun)',
                              'caelestia|end4|ambxst|dms|serpantinum|noctalia|sayconlun|tsugumori)')
    original=original.replace('        jaqc)        echo "Solstice" ;;','        tsugumori)   echo "Tsugumori" ;;\n        jaqc)        echo "Solstice" ;;')
    original=original.replace('         jaqc         clavis','         tsugumori         jaqc         clavis')
    metadata.write_text(original)
    ids=shell('source "$1"; profile_ids',metadata).splitlines()
    assert len(ids)==11 and 'tsugumori' in ids
    for profile in ids:
        kind='niri' if profile in ['jaqc','clavis','nixri'] else 'hypr'
        config=base/profile/kind/('config.kdl' if kind=='niri' else 'hyprland.lua')
        config.parent.mkdir(parents=True); config.write_text('// fixture\n')
    local=home/'.local/bin'; local.mkdir(parents=True)
    # Model inactive host services for direct rollback is-active queries.
    (local/'systemctl').write_text('#!/bin/sh\nexit 3\n'); (local/'systemctl').chmod(0o755)
    os.environ['PATH']=str(local)+':'+os.environ['PATH']
    for name in ['multi-rice-control','desktop-switch','lumina-player-overlay']:
        content=(repo/'dual-rice/bin/multi-rice-control').read_bytes() if name=='multi-rice-control' else b'#!/usr/bin/env bash\nexit 0\n'
        (local/name).write_bytes(content); (local/name).chmod(0o755)
    route=(repo/'dual-rice/bin/multi-rice-session').read_bytes()
    system=temp/'system/multi-rice-session'; system.parent.mkdir(); system.write_bytes(route); system.chmod(0o751)
    (local/'multi-rice-session').write_bytes(route); (local/'multi-rice-session').chmod(0o755)
    state=home/'.config/desktop-profile'; state.mkdir(parents=True)
    (state/'active').write_text('clavis\n')
    link=home/'.config/niri'; link.symlink_to(base/'clavis/niri')
    cipher=base/'clavis/native'; cipher.mkdir()
    (cipher/'READY').write_text('ready'); (cipher/'session.sh').write_text('#!/bin/bash\nexit 0\n'); (cipher/'session.sh').chmod(0o755)
    root=base/'inir'
    install.HOME=home; install.BASE=base; install.ROOT=root; install.SYSTEM=system
    install.METADATA=metadata; install.LOCAL_ROUTE=local/'multi-rice-session'
    helper=module(PACKAGE/'system-route.py','route_fixture')
    helper.TARGET=system; helper.BACKUPS=temp/'root-backups'; helper.BACKUPS.mkdir()
    events=[]
    real_run=install.run
    env=dict(os.environ,HOME=str(home),XDG_CURRENT_DESKTOP='niri')
    def run(args,**kwargs):
        args=list(map(str,args))
        if args[0] in ['systemctl','systemd-analyze']:
            events.append(args); return ''
        return real_run(args,env=env,**kwargs)
    install.run=run
    install.prerequisites=lambda deps:None
    install.fetch_source=lambda:source
    install.create_venv=lambda:None
    install.validate_runtime=lambda:None
    def write(state,action): helper.transact(dict(state['system'],action=action))
    install.system_write=write
    return home,base,root,metadata,system,env,events,write

def check_transactions(source):
    original_run=install.run
    for scenario in ['success','root-interruption','user-interruption']:
        install.run=original_run
        with tempfile.TemporaryDirectory(prefix='inir-fixture-') as name:
            home,base,root,metadata,system,env,events,write=host_fixture(Path(name),source)
            prior={p:(p.read_bytes(),p.stat().st_mode & 0o777) for p in [metadata,system,install.LOCAL_ROUTE]}
            active=(home/'.config/desktop-profile/active').read_bytes()
            link=(home/'.config/niri').readlink()
            original_atomic=install.atomic
            if scenario=='root-interruption':
                def interrupted(state,action):
                    write(state,action)
                    if action=='install': raise KeyboardInterrupt('root commit acknowledged late')
                install.system_write=interrupted
            elif scenario=='user-interruption':
                def interrupted_atomic(path,data,mode=0o644):
                    original_atomic(path,data,mode)
                    if path==metadata: raise KeyboardInterrupt('user commit acknowledged late')
                install.atomic=interrupted_atomic
            try:
                if scenario=='success':
                    install.install()
                    assert root.is_dir() and (root/'READY').is_file()
                    taskbar=(root/'runtime/modules/waffle/bar/WaffleBar.qml').read_text()
                    assert 'mask: Region {\n                    width: barRoot.width\n                    height: barRoot.height\n                }' in taskbar
                    binds=(root/'niri/config.d/70-binds.kdl').read_text()
                    expected='Mod+Shift+D { spawn "/usr/bin/qs" "-p" '+json.dumps(str(home/'.config/quickshell/multi-rice-switcher/shell.qml'))+'; }'
                    assert expected in binds and str(home/'.local/bin/desktop-switch') not in binds
                    listing=shell('"$1" list',home/'.local/bin/multi-rice-control',env=env).splitlines()
                    assert len(listing)==12 and any(x.startswith('tsugumori|Tsugumori|') for x in listing)
                    assert any(x.startswith('inir|Eclipse|◌|niri|true|') for x in listing)
                    assert (home/'.config/desktop-profile/active').read_bytes()==active
                    assert (home/'.config/niri').readlink()==link
                    for profile in ['clavis','jaqc','nixri','inir']:
                        (home/'.config/desktop-profile/active').write_text(profile+'\n')
                        output=shell('"$1" --dry-run',system,env=env)
                        expected=str(base/'clavis/native/session.sh') if profile=='clavis' else str(root/'session.sh') if profile=='inir' else 'niri-session'
                        if profile in ['jaqc','nixri']:
                            # Provide the stock launcher for this fixture only.
                            pass
                        assert expected in output,(profile,output)
                    (home/'.config/desktop-profile/active').write_bytes(active)
                    # Post-install edits are never overwritten by rollback.
                    clean=metadata.read_bytes(); metadata.write_bytes(clean+b'# user edit\n')
                    try: install.rollback(); raise AssertionError('edited metadata accepted')
                    except RuntimeError as error: assert 'preserved' in str(error)
                    assert metadata.read_bytes().endswith(b'# user edit\n')
                    metadata.write_bytes(clean)
                    install.rollback()
                    assert not root.exists()
                    print('PASS: 12-profile discovery, preserved Tsugumori/Cipher routes, edited-file guard and exact rollback')
                else:
                    try: install.install(); raise AssertionError('interruption not delivered')
                    except KeyboardInterrupt: pass
                    assert not root.exists()
                    print('PASS: '+scenario+' recovers committed files and root route')
                for path,(data,mode) in prior.items():
                    assert path.read_bytes()==data and path.stat().st_mode & 0o777==mode,str(path)
                assert (home/'.config/desktop-profile/active').read_bytes()==active
                assert (home/'.config/niri').readlink()==link
                assert not any('start' in event for event in events)
            finally: install.atomic=original_atomic
    install.run=original_run

def check_lifecycle():
    with tempfile.TemporaryDirectory(prefix='inir-session-') as name:
        root=Path(name)
        shutil.copy2(PACKAGE/'session.sh',root/'session.sh'); (root/'READY').touch()
        bin=root/'bin'; bin.mkdir()
        log=root/'events.jsonl'
        fake=bin/'systemctl'
        fake.write_text('''#!/usr/bin/env python3
import json,os,sys
args=sys.argv[1:]
with open(os.environ['EVENTS'],'a') as f: f.write(json.dumps(args)+'\\n')
if 'show-environment' in args: print('PATH=\\nNIRI_CONFIG=previous config')
elif 'is-active' in args: sys.exit(3)
elif '--wait' in args: sys.exit(5)
'''); fake.chmod(0o755)
        env=dict(os.environ,PATH=str(bin)+':'+os.environ['PATH'],EVENTS=str(log))
        for key in ['DISPLAY','WAYLAND_DISPLAY']: env.pop(key,None)
        result=subprocess.run(['/usr/bin/bash',str(root/'session.sh')],env=env)
        assert result.returncode==5
        events=[json.loads(x) for x in log.read_text().splitlines()]
        assert ['--user','set-environment','PATH='] in events
        assert ['--user','set-environment','NIRI_CONFIG=previous config'] in events
        assert any(x[:3]==['--user','stop','huzaifah-inir-shell.service'] for x in events)
        print('PASS: failed compositor login restores empty PATH and previous NIRI_CONFIG and stops only owned services')

def check_metadata_layouts(source):
    original_run=install.run
    for layout in ['symlink','fallback','dangling-symlink']:
        install.run=original_run
        with tempfile.TemporaryDirectory(prefix='inir-layout-') as name:
            home,base,root,metadata,system,env,events,write=host_fixture(Path(name),source)
            data=metadata.read_bytes()
            backing=home/'.local/lib/profile-metadata.sh'
            backing.parent.mkdir(); backing.write_bytes(data)
            metadata.unlink()
            if layout=='symlink': metadata.symlink_to(backing)
            elif layout=='dangling-symlink': metadata.symlink_to('missing-old-metadata.sh')
            old_link=str(metadata.readlink()) if metadata.is_symlink() else None
            install.install()
            assert metadata.is_file() and not metadata.is_symlink()
            assert backing.read_bytes()==data
            listing=shell('"$1" list',home/'.local/bin/multi-rice-control',env=env).splitlines()
            assert len(listing)==12 and any(x.startswith('tsugumori|Tsugumori|') for x in listing)
            install.rollback()
            assert backing.read_bytes()==data
            if old_link is None: assert not metadata.exists() and not metadata.is_symlink()
            else: assert metadata.is_symlink() and str(metadata.readlink())==old_link
            print('PASS: '+layout+' metadata discovery preserves backing source and restores the original entry')
    install.run=original_run

def check_name_changes(source):
    original_run=install.run
    for scenario in ['success','metadata-interruption','receipt-interruption','pending-recovery']:
        install.run=original_run
        with tempfile.TemporaryDirectory(prefix='inir-name-fixture-') as name:
            home,base,root,metadata,system,env,events,write=host_fixture(Path(name),source)
            baseline_system=system.read_bytes()
            install.install()
            # Model the user's existing pre-Eclipse installation and receipt.
            receipt=root/'installed.json'
            legacy=metadata.read_bytes().replace(b'then echo Eclipse; else inir_original_profile_name',
                                                b'then echo iNiR; else inir_original_profile_name')
            metadata.write_bytes(legacy)
            state=json.loads(receipt.read_text());state.pop('profileName',None)
            next(r for r in state['records'] if r['path']==str(metadata))['installedSha256']=install.sha(legacy)
            receipt.write_text(json.dumps(state,indent=2)+'\n')
            old_receipt=receipt.read_bytes()
            active=home/'.config/desktop-profile/active';active.write_text('inir\n')
            link=(home/'.config/niri').readlink();prior_system=system.read_bytes()
            old_atomic=install.atomic
            target=metadata if scenario=='metadata-interruption' else receipt
            delivered=False
            if scenario.endswith('interruption'):
                def interrupted(path,data,mode=0o644):
                    nonlocal delivered
                    old_atomic(path,data,mode)
                    if path==target and not delivered:
                        delivered=True;raise KeyboardInterrupt('name commit acknowledged late')
                install.atomic=interrupted
            old_recover=install.recover_name_change
            if scenario=='pending-recovery':
                # Emulate abrupt process death: the recovery journal survives.
                install.recover_name_change=lambda:None
                def interrupted(path,data,mode=0o644):
                    old_atomic(path,data,mode)
                    if path==metadata:raise KeyboardInterrupt('simulated process death')
                install.atomic=interrupted
            try:
                if scenario=='success':
                    install.rename_profile('Eclipse');install.rename_profile('Eclipse')
                    state=json.loads(receipt.read_text());install.verify_records(state['records'],True)
                    listing=shell('"$1" list',home/'.local/bin/multi-rice-control',env=env).splitlines()
                    assert any(row.startswith('inir|Eclipse|◌|niri|true|') for row in listing)
                    # User edits remain protected after the authorized rename.
                    clean=metadata.read_bytes();metadata.write_bytes(clean+b'# user edit\n')
                    try:install.rename_profile('Umbra');raise AssertionError('edited metadata overwritten')
                    except RuntimeError as error:assert 'preserved' in str(error)
                    metadata.write_bytes(clean)
                    assert system.read_bytes()==prior_system
                    active.write_text('clavis\n');install.rollback()
                else:
                    try:install.rename_profile('Eclipse');raise AssertionError('name interruption not delivered')
                    except KeyboardInterrupt:pass
                    install.atomic=old_atomic;install.recover_name_change=old_recover
                    install.recover_name_change()
                    assert metadata.read_bytes()==legacy and receipt.read_bytes()==old_receipt
                    assert not (root/'name-change-pending.json').exists()
                assert (home/'.config/niri').readlink()==link
                assert system.read_bytes()==(baseline_system if scenario=='success' else prior_system)
                assert active.read_text()==('clavis\n' if scenario=='success' else 'inir\n')
                assert not any('start' in event for event in events)
                print('PASS: display-name '+scenario+' preserves IDs, routes, active session and rollback')
            finally:
                install.atomic=old_atomic;install.recover_name_change=old_recover
    install.run=original_run

def main():
    source=Path(sys.argv[1]).resolve()
    assert subprocess.check_output(['git','-C',str(source),'rev-parse','HEAD'],text=True).strip()==adapt.REVISION
    check_dependencies()
    check_polkit()
    check_wayland_environment()
    check_qml_process_cleanup()
    check_fonts()
    check_environment()
    # Only stock-launcher availability is mocked for route dry-runs.
    with tempfile.TemporaryDirectory(prefix='inir-stock-command-') as name:
        command=Path(name)/'niri-session'; command.write_text('#!/bin/sh\nexit 0\n'); command.chmod(0o755)
        os.environ['PATH']=name+':'+os.environ['PATH']
        check_transactions(source)
        check_metadata_layouts(source)
        check_name_changes(source)
    check_lifecycle()
    print('PASS: host Qt/Niri/service startup checks intentionally deferred to the laptop installer')

if __name__=='__main__': main()
