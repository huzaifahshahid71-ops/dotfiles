import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile
import hashlib
import ast

KIT=Path(__file__).resolve().parent
SOURCE=Path.home()/'Downloads/sumi-v6-build-prep'
if not (SOURCE/'core.py').is_file():SOURCE=KIT.parents[1]/'installer'
sys.path.insert(0,str(SOURCE))
sys.path.insert(0,str(KIT))
import login_defaults as login
from maintenance import fingerprint
from core import SetupError
import patch_sources as patches
import icon_bundle
from icon_inventory import THEMES
import boot_fixes
import publish
import grub_records
import bundle
from core import PROFILES


class LoginTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.root=Path(self.tmp.name)
        unit=self.root/'usr/lib/systemd/system/sddm.service';unit.parent.mkdir(parents=True);unit.write_text('[Service]\nExecStart=/usr/bin/sddm\n');unit.chmod(0o644)
        self.alias=self.root/login.ALIAS;self.alias.parent.mkdir(parents=True);self.alias.symlink_to('/usr/lib/systemd/system/greetd.service')
    def tearDown(self):self.tmp.cleanup()
    def test_login_enablement_and_restore_keep_live_services_untouched(self):
        other=self.alias.parent/'multi-user.target.wants/greetd.service';other.parent.mkdir();other.symlink_to('/usr/lib/systemd/system/greetd.service')
        record=login.prepare(self.root);login.change(self.root,record,'installed')
        self.assertEqual(os.readlink(self.alias),login.TARGET);self.assertFalse(other.is_symlink());self.assertEqual(login.conflicts(self.root,record),[])
        login.change(self.root,record,'before')
        self.assertEqual(Path(os.readlink(self.alias)).name,'greetd.service');self.assertTrue(other.is_symlink())
    def test_missing_alias_returns_to_absent_on_restore(self):
        self.alias.unlink();record=login.prepare(self.root);login.change(self.root,record,'installed');login.change(self.root,record,'before')
        self.assertFalse(self.alias.is_symlink())
    def test_unknown_manager_and_regular_file_preserved(self):
        self.alias.unlink();self.alias.symlink_to('/usr/lib/systemd/system/gdm.service')
        with self.assertRaises(SetupError):login.prepare(self.root)
        self.alias.unlink();self.alias.write_text('custom')
        with self.assertRaises(SetupError):login.prepare(self.root)
        self.assertEqual(self.alias.read_text(),'custom')
    def test_concurrent_edit_blocks_restore(self):
        record=login.prepare(self.root);login.change(self.root,record,'installed');self.alias.unlink();self.alias.symlink_to('/usr/lib/systemd/system/gdm.service')
        self.assertEqual(login.conflicts(self.root,record),[login.ALIAS])
        with self.assertRaises(SetupError):login.change(self.root,record,'before')
    def test_partial_install_can_roll_back(self):
        record=login.prepare(self.root)
        def fail():raise OSError('receipt write failed')
        with self.assertRaises(OSError):login.change(self.root,record,'installed',fail)
        login.change(self.root,record,'before',partial=True)
        self.assertEqual(Path(os.readlink(self.alias)).name,'greetd.service')
    def test_receipt_cannot_restore_arbitrary_system_path(self):
        record=login.prepare(self.root);record['files'].append({'path':'etc/shadow','before':{'kind':'absent'},'installed':{'kind':'absent'}})
        with self.assertRaises(SetupError):login.conflicts(self.root,record)


class PatchTests(unittest.TestCase):
    def test_source_patches_are_repeatable_and_compile(self):
        for name,transform in [('system_transaction.py',patches.transaction),('payload_backend.py',patches.backend)]:
            before=(KIT/'fixtures'/name).read_text();after=transform(before)
            self.assertNotEqual(before,after);self.assertEqual(transform(after),after);compile(after,name,'exec')
    def test_unknown_backend_source_refuses(self):
        with self.assertRaises(RuntimeError):patches.backend('unrelated = True\n')
    def test_observed_backend_native_check_is_preserved(self):
        before=(KIT/'fixtures/payload_backend.py').read_text();after=patches.backend(before)
        hashes=json.loads((KIT/'fixtures/observed-source-hashes.json').read_text())
        self.assertEqual(hashlib.sha256(before.encode()).hexdigest(),hashes['payload_backend.py'])
        def native(text):
            return ast.dump(next(n for n in ast.parse(text).body if isinstance(n,ast.FunctionDef) and n.name=='validate_native'))
        self.assertEqual(native(before),native(after))
        self.assertIn('validate_native(payload, plan, callback)',after)
        self.assertLess(after.index('validate_native(payload, plan, callback)'),after.index('install_icons(payload'))
        self.assertIn('failure or "System operation did not complete."',after)
        self.assertEqual(patches.backend(after),after)
    def test_original_backend_remains_supported(self):
        before=(KIT/'fixtures/payload_backend-original.py').read_text();after=patches.backend(before)
        self.assertEqual(patches.backend(after),after);compile(after,'original_backend','exec')
    def test_grub_owned_block_retains_original_arguments(self):
        original=(KIT/'fixtures/install.sh').read_text();after=patches.grub_manager(original)
        self.assertEqual(patches.grub_manager(after),after)
        with tempfile.TemporaryDirectory() as d:
            path=Path(d)/'install.sh';path.write_text(after);subprocess.run(['bash','-n',str(path)],check=True)
        # Exercise the actual generated override as shell configuration.
        start=after.index("'GRUB_CMDLINE_LINUX_DEFAULT=")+1;end=after.index("'",start)
        assignment=after[start:end]
        run=subprocess.run(['bash','-c','GRUB_CMDLINE_LINUX_DEFAULT="rootflags=subvol=@ cryptdevice=UUID:123:root resume=UUID:xyz"\n'+assignment+'\nprintf "%s" "$GRUB_CMDLINE_LINUX_DEFAULT"'],capture_output=True,text=True,check=True)
        self.assertTrue(run.stdout.startswith('rootflags=subvol=@ cryptdevice=UUID:123:root resume=UUID:xyz '))
        self.assertTrue(run.stdout.endswith('quiet systemd.show_status=false rd.systemd.show_status=false'))
    def test_real_awk_keeps_boot_arguments_and_error_messages(self):
        source=boot_fixes.quiet_generator((KIT/'fixtures/boot-console.awk').read_text())
        menu="set theme=\"$prefix/themes/evangelion/theme.txt\"\nmenuentry 'CachyOS' {\n echo 'Loading Linux linux-cachyos ...'\n linux /vmlinuz root=UUID=sample rw rootflags=subvol=@ quiet splash systemd.show_status=false\n echo 'Loading initial ramdisk ...'\n initrd /initramfs\n}\necho 'Disk error'\n"
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);(root/'parser').write_text(source);(root/'menu').write_text(menu)
            run=subprocess.run(['awk','-f',str(root/'parser'),'/','0','unused',str(root/'menu')],capture_output=True,text=True,check=True)
        boot_fixes.validate_menu(run.stdout);self.assertIn("echo 'Disk error'",run.stdout);self.assertIn('root=UUID=sample rw rootflags=subvol=@ quiet splash',run.stdout)
    def test_actual_transaction_restores_recorded_login_routes(self):
        ns={'__name__':'revision_transaction_test'}
        exec(compile(patches.transaction((KIT/'fixtures/system_transaction.py').read_text()),'transaction','exec'),ns)
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);alias=root/login.ALIAS;alias.parent.mkdir(parents=True);alias.symlink_to('/usr/lib/systemd/system/greetd.service')
            unit=root/'usr/lib/systemd/system/sddm.service';unit.parent.mkdir(parents=True);unit.write_text('sddm')
            record=login.prepare(root);login.change(root,record,'installed')
            tx=ns['SystemTransaction'](root=root);identifier='a'*32;state=tx.state_root(1000,identifier);(state/'before').mkdir(parents=True)
            receipt={'schema':1,'version':'6.0.0','uid':1000,'id':identifier,'status':'installed','files':[],'login_defaults':record}
            (state/'receipt.json').write_text(json.dumps(receipt));tx.restore(1000,identifier,callback=lambda *a,**kw:None)
            self.assertEqual(Path(os.readlink(alias)).name,'greetd.service')
            self.assertEqual(json.loads((state/'receipt.json').read_text())['status'],'restored')

    def exercise_install(self,fail=False):
        ns={'__name__':'revision_transaction_test'}
        exec(compile(patches.transaction((KIT/'fixtures/system_transaction.py').read_text()),'transaction','exec'),ns)
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);payload=root/'payload';payload.mkdir();(payload/'source').write_bytes(b'new')
            target=root/'usr/local/bin/multi-rice-session';target.parent.mkdir(parents=True);target.write_bytes(b'previous')
            unit=root/'usr/lib/systemd/system/sddm.service';unit.parent.mkdir(parents=True);unit.write_text('sddm')
            alias=root/login.ALIAS;alias.parent.mkdir(parents=True);alias.symlink_to('/usr/lib/systemd/system/greetd.service')
            installed={'test':{'name':'test','version':'1-1','depends':[]}}
            tx=ns['SystemTransaction'](root=root,query=lambda args:{'test':'1-1'},package_database=lambda:installed)
            plan={'schema':1,'version':'6.0.0','login_defaults':'sddm-next-boot-v1','packages':[{'name':'test','version':'1-1'}],
                  'system_files':[{'path':'usr/local/bin/multi-rice-session','source':'source','mode':0o755,'sha256':hashlib.sha256(b'new').hexdigest()}]}
            def callback(message,*args,**kw):
                if fail and message.startswith('SDDM selected'):raise OSError('interrupted after login route commit')
            if fail:
                with self.assertRaises(OSError):tx.install(payload,plan,1000,callback)
            else:
                identifier=tx.install(payload,plan,1000,callback)
                self.assertEqual(os.readlink(alias),login.TARGET);self.assertEqual(target.read_bytes(),b'new')
                tx.restore(1000,identifier,callback)
            self.assertEqual(Path(os.readlink(alias)).name,'greetd.service');self.assertEqual(target.read_bytes(),b'previous')
    def test_real_install_and_restore_include_next_boot_login_selection(self):self.exercise_install()
    def test_real_install_failure_rolls_back_login_selection_and_files(self):self.exercise_install(fail=True)


class GrubOwnershipTests(unittest.TestCase):
    def setup_tree(self,root,edited=False):
        state=root/'recovery';(state/'staged').mkdir(parents=True)
        library=root/grub_records.LIBRARY;library.parent.mkdir(parents=True);library.write_bytes(b'old parser')
        (state/'staged/0000').write_bytes(b'new parser');(state/'staged/0000').chmod(0o644)
        records=[{'path':grub_records.LIBRARY,'before':fingerprint(library),'installed':fingerprint(state/'staged/0000')}]
        parser=root/grub_records.PARSER;parser.parent.mkdir(parents=True);parser.write_bytes(b'old parser')
        manager=root/grub_records.MANAGER;manager.write_text(json.dumps({'files':{grub_records.LIBRARY:hashlib.sha256(b'old parser').hexdigest()},'keep':'value'}))
        meta=root/grub_records.STATE;meta.write_text(json.dumps({'boot_files':{grub_records.PARSER:hashlib.sha256(b'old parser').hexdigest()},'theme':'wunder'}))
        if edited:parser.write_bytes(b'custom parser')
        return state,records,parser,manager,meta
    def test_existing_owner_hashes_and_runtime_parser_update_and_restore(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);state,files,parser,manager,meta=self.setup_tree(root)
            before={p:p.read_bytes() for p in (parser,manager,meta)}
            receipt=grub_records.prepare(root,state,files);grub_records.change(root,state,receipt,'installed')
            self.assertEqual(parser.read_bytes(),b'new parser');self.assertEqual(json.loads(meta.read_text())['theme'],'wunder')
            self.assertEqual(json.loads(manager.read_text())['files'][grub_records.LIBRARY],hashlib.sha256(b'new parser').hexdigest())
            self.assertEqual(grub_records.conflicts(root,state,receipt),[])
            grub_records.change(root,state,receipt,'before')
            for path,data in before.items():self.assertEqual(path.read_bytes(),data)
    def test_custom_runtime_parser_blocks_update(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);state,files,parser,_,_=self.setup_tree(root,edited=True)
            with self.assertRaises(SetupError):grub_records.prepare(root,state,files)
            self.assertEqual(parser.read_bytes(),b'custom parser')
    def test_later_metadata_edit_blocks_restore(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);state,files,_,manager,_=self.setup_tree(root)
            receipt=grub_records.prepare(root,state,files);grub_records.change(root,state,receipt,'installed');manager.write_text('edited')
            self.assertIn(grub_records.MANAGER,grub_records.conflicts(root,state,receipt))
            with self.assertRaises(SetupError):grub_records.change(root,state,receipt,'before')


class IconTests(unittest.TestCase):
    def archive(self,root,tampered=False,traversal=False):
        path=root/'assets/mactahoe.zip';path.parent.mkdir(parents=True)
        data=b'[Icon Theme]\nName=MacTahoe\n';records=[]
        with zipfile.ZipFile(path,'w') as z:
            for theme in THEMES:
                for name in ('index.theme','places/folder.svg'):
                    relative=theme+'/'+name;z.writestr(relative,data)
                    records.append({'path':relative,'bytes':len(data),'sha256':hashlib.sha256(data if not tampered else b'changed').hexdigest()})
            if traversal:records[0]['path']='../outside'
            z.writestr('manifest.json',json.dumps({'schema':1,'themes':list(THEMES),'files':records,'bytes':len(data)*len(records)}))
        return {'schema':1,'source':'assets/mactahoe.zip','themes':list(THEMES),'bytes':path.stat().st_size,
                'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'files':len(records),'unpacked_bytes':len(data)*len(records)}
    def test_verified_icons_replace_three_roots_and_keep_old_directories(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);payload=root/'payload';home=root/'home';backups=root/'backups';backups.mkdir();home.mkdir()
            old=home/icon_bundle.PATHS[0];old.mkdir(parents=True);(old/'custom').write_text('keep')
            record=self.archive(payload);changed=[]
            icon_bundle.install(payload,record,home,backups,changed,lambda *a,**kw:None)
            self.assertEqual(len(changed),3);self.assertEqual((changed[0][1]/'custom').read_text(),'keep')
            for theme in THEMES:self.assertTrue((home/'.local/share/icons'/theme/'index.theme').is_file())
    def test_member_corruption_is_caught_before_any_theme_replacement(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);payload=root/'payload';home=root/'home';backups=root/'backups';backups.mkdir();home.mkdir()
            old=home/icon_bundle.PATHS[0];old.mkdir(parents=True);(old/'custom').write_text('keep');record=self.archive(payload,tampered=True);changed=[]
            with self.assertRaises(RuntimeError):icon_bundle.install(payload,record,home,backups,changed,lambda *a,**kw:None)
            self.assertEqual(changed,[]);self.assertEqual((old/'custom').read_text(),'keep')
    def test_archive_traversal_is_refused(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);record=self.archive(root,traversal=True)
            with self.assertRaises(RuntimeError):icon_bundle.source(root,record)


class ActualBackendTests(unittest.TestCase):
    def exercise(self,fail=False):
        source=patches.backend((KIT/'fixtures/payload_backend.py').read_text())
        ns={'__name__':'observed_backend_test','__file__':str(KIT/'fixtures/payload_backend.py')}
        exec(compile(source,'observed_backend','exec'),ns)
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);home=root/'home';home.mkdir();payload=root/'payload'
            record=IconTests().archive(payload)
            plan={'schema':1,'version':'6.0.0','profiles':PROFILES,'user_files':[],
                  'user_links':[],'icon_bundle':record}
            (payload/'plan.json').write_text(json.dumps(plan))
            for relative in icon_bundle.PATHS:
                path=home/relative;path.mkdir(parents=True);(path/'original').write_text(relative)
            phases=[];root_actions=[]
            def root_call(action,*args):root_actions.append(action);return {'system_id':'fake-test-receipt'}
            def command(args,*a,**kw):
                phases.append('runtime')
                for relative in icon_bundle.PATHS:self.assertTrue((home/relative/'index.theme').is_file())
                if fail:raise SetupError('failure after icon installation')
            ns['command']=command;ns['validate_native']=lambda *a,**kw:phases.append('native')
            options={'protocol':1,'version':'6.0.0','action':'install','home':str(home),
                     'profiles':list(PROFILES),'hardware_changes':False,'grub':False,'remove_packages':False}
            if fail:
                with self.assertRaisesRegex(SetupError,'failure after'):ns['install'](payload,options,home,root_caller=root_call,callback=lambda *a,**kw:None)
                self.assertEqual(root_actions,['install','restore'])
                receipt_path=next((home/'.local/share/huzaifah-multi-rice/v6-installations').glob('*/receipt.json'))
                self.assertEqual(json.loads(receipt_path.read_text())['status'],'failed')
            else:
                receipt_path=ns['install'](payload,options,home,root_caller=root_call,callback=lambda *a,**kw:None)
                receipt=json.loads(receipt_path.read_text())
                self.assertTrue(set(icon_bundle.PATHS)<={r['path'] for r in receipt['paths']})
                self.assertEqual(receipt['status'],'installed')
                ns['restore'](receipt_path,home,lambda *a,**kw:None)
                self.assertEqual(json.loads(receipt_path.read_text())['status'],'restored')
            self.assertEqual(phases[0],'native')
            for relative in icon_bundle.PATHS:
                path=home/relative
                self.assertEqual((path/'original').read_text(),relative)
                self.assertFalse((path/'index.theme').exists())
    def test_observed_install_snapshots_all_icon_roots_and_restores_them(self):self.exercise()
    def test_observed_install_failure_rolls_back_icons_and_system(self):self.exercise(fail=True)


class ResumeTests(unittest.TestCase):
    def identity(self):return {'sources':{'payload_backend.py':'same-source'},'icons':'same-icons','lumina':'same-lumina','original_manifest':'same-release','kit':{'bundle.py':'new-kit'}}
    def stage(self,root):
        root.mkdir();previous=self.identity();previous['kit']={'bundle.py':'old-kit'}
        (root/'inputs.json').write_text(json.dumps(previous));(root/'sources').mkdir()
        (root/'sources/payload_backend.py').write_text('retained source')
        return previous
    def test_observed_early_failure_resumes_with_same_repair_inputs(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d)/'output';previous=self.stage(root)
            with patch.object(bundle,'OUTPUT',root):bundle.prepare_output(self.identity());bundle.prepare_output(self.identity())
            self.assertEqual(json.loads((root/'inputs.json').read_text()),self.identity())
            backup=next(root.glob('inputs-before-kit-*.json'));self.assertEqual(json.loads(backup.read_text()),previous)
            self.assertEqual((root/'sources/payload_backend.py').read_text(),'retained source')
    def test_changed_source_cannot_resume_existing_output(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d)/'output';previous=self.stage(root);identity=self.identity();identity['sources']={'payload_backend.py':'different'}
            with patch.object(bundle,'OUTPUT',root),self.assertRaisesRegex(RuntimeError,'source/repair'):bundle.prepare_output(identity)
            self.assertEqual(json.loads((root/'inputs.json').read_text()),previous)
    def test_existing_candidate_or_publication_cannot_resume_changed_kit(self):
        for name in ('candidate','image-complete.json','publication-assets.json','source-commit.json','published.json'):
            with tempfile.TemporaryDirectory() as d,self.subTest(name=name):
                root=Path(d)/'output';previous=self.stage(root);(root/name).write_text('keep')
                with patch.object(bundle,'OUTPUT',root),self.assertRaisesRegex(RuntimeError,'candidate/release'):bundle.prepare_output(self.identity())
                self.assertEqual((root/name).read_text(),'keep');self.assertEqual(json.loads((root/'inputs.json').read_text()),previous)
    def test_symlink_output_is_preserved(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d)/'output';target=Path(d)/'target';target.mkdir();root.symlink_to(target)
            with patch.object(bundle,'OUTPUT',root),self.assertRaisesRegex(RuntimeError,'symlink'):bundle.prepare_output(self.identity())
            self.assertEqual(list(target.iterdir()),[])


class PublicationTests(unittest.TestCase):
    def test_already_current_launcher_needs_no_mutation(self):
        expected={'bytes':3,'sha256':'a'*64};current={'ONLINE-INSTALL-v6.sh':{'size':3,'digest':'sha256:'+'a'*64,'state':'uploaded'}}
        with patch.object(publish,'api') as api:publish.switch_launcher(1,current,expected,{},Path('old'),Path('new'))
        api.assert_not_called()
    def test_unknown_public_launcher_is_preserved(self):
        with patch.object(publish,'api') as api,self.assertRaises(RuntimeError):publish.switch_launcher(1,{}, {'bytes':1,'sha256':'a'*64},{'bytes':2,'sha256':'b'*64},Path('old'),Path('new'))
        api.assert_not_called()
    def test_failed_launcher_upload_restores_old_asset(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);old=root/'old';old.write_bytes(b'previous');new=root/'new';new.write_bytes(b'new')
            prior={'bytes':old.stat().st_size,'sha256':hashlib.sha256(old.read_bytes()).hexdigest()}
            expected={'bytes':3,'sha256':hashlib.sha256(b'new').hexdigest()};current={'ONLINE-INSTALL-v6.sh':{'id':5,'size':prior['bytes'],'digest':'sha256:'+prior['sha256'],'state':'uploaded'}}
            with patch.object(publish,'api'),patch.object(publish,'assets',return_value={}),patch.object(publish,'upload',side_effect=[OSError('network failure'),None]) as upload,self.assertRaises(OSError):
                publish.switch_launcher(1,current,expected,prior,old,new)
            self.assertEqual([call.args[0] for call in upload.call_args_list],[new,old])


class LuminaExportTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.root=Path(self.tmp.name)
        self.lumina=self.root/'lumina-assets-repair/lumina-assets-5aef042f384b'
        self.manifest=json.loads((KIT/'fixtures/lumina-export-manifest.json').read_text())
        for record in self.manifest['files']:
            data=('fixture:'+record['path']).encode();path=self.lumina/record['source']
            path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
            record.update(bytes=len(data),sha256=hashlib.sha256(data).hexdigest())
        (self.lumina/'manifest.json').write_text(json.dumps(self.manifest))
    def tearDown(self):self.tmp.cleanup()
    def test_addons_accepts_complete_twenty_file_export(self):
        self.assertEqual(len(self.manifest['files']),20)
        appearance=self.root/'appearance-repair/appearance-auth-b5ac73e71a25';appearance.mkdir(parents=True)
        (appearance/'checkpoint.json').write_text(json.dumps({'status':'prepared-next-boot','icons':{'total':164921}}))
        with zipfile.ZipFile(appearance/'icons.zip','w'):pass
        with patch.object(bundle,'ROOT',self.root),patch.object(bundle,'inventory',return_value={'files':[None]*164921,'bytes':603730520}):
            _,_,manifest,_=bundle.addons()
        self.assertEqual(manifest,self.manifest)
    def test_every_exported_file_is_checksum_checked(self):
        for record in self.manifest['files']:
            with self.subTest(path=record['path']):
                path=self.lumina/record['source'];before=path.read_bytes();path.write_bytes(b'X'+before[1:])
                with self.assertRaisesRegex(RuntimeError,'checksum'):bundle.validate_lumina(self.manifest,self.lumina)
                path.write_bytes(before)
    def test_duplicate_path_is_refused(self):
        self.manifest['files'].append(dict(self.manifest['files'][0]))
        with self.assertRaisesRegex(RuntimeError,'Duplicate'):bundle.validate_lumina(self.manifest,self.lumina)
    def test_missing_required_template_is_refused(self):
        self.manifest['files'].pop()
        with self.assertRaisesRegex(RuntimeError,'missing='):bundle.validate_lumina(self.manifest,self.lumina)
    def test_unexpected_asset_is_refused(self):
        self.manifest['files'].append(dict(self.manifest['files'][0],path=LUMINA_TEST_EXTRA))
        with self.assertRaisesRegex(RuntimeError,'extra='):bundle.validate_lumina(self.manifest,self.lumina)
    def test_source_traversal_is_refused(self):
        self.manifest['files'][0]['source']='../outside'
        with self.assertRaisesRegex(RuntimeError,'source path'):bundle.validate_lumina(self.manifest,self.lumina)
    def test_exported_file_symlink_is_refused(self):
        path=self.lumina/self.manifest['files'][0]['source'];path.rename(path.with_suffix('.saved'))
        path.symlink_to(path.with_suffix('.saved'))
        with self.assertRaisesRegex(RuntimeError,'symlink'):bundle.validate_lumina(self.manifest,self.lumina)


LUMINA_TEST_EXTRA='.local/share/desktop-profiles/sayconlun/support/rofi/unreviewed.rasi'


class CandidateTests(unittest.TestCase):
    def test_candidate_bundles_registered_assets_without_mutating_old_payload(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);final=root/'final';output=root/'output';source=root/'source';source.mkdir();old=final/'candidate/AppDir'
            payload=old/'payload';payload.mkdir(parents=True);(old/'backend').mkdir()
            rows=[];systems=[]
            def add(path,data,mode=0o644,system=False):
                relative=('system/' if system else 'home/')+path;target=payload/relative;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
                target.chmod(mode);record={'path':path,'source':relative,'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest(),'mode':mode,'template':False}
                (systems if system else rows).append(record)
            add('.local/bin/retained',b'keep',0o755)
            catalog=SOURCE/'build-support/shortcut-menu/catalog.py'
            if not catalog.is_file():catalog=KIT.parents[0]/'shortcut-menu/catalog.py'
            add('.local/share/multi-rice-shortcuts/catalog.py',catalog.read_bytes())
            for filename in ('payload_backend.py','system_transaction.py',*bundle.MODULES):
                original=(KIT/'fixtures'/filename).read_bytes() if filename in ('payload_backend.py','system_transaction.py') else (KIT/filename).read_bytes()
                if filename=='payload_backend.py':original=patches.backend(original.decode()).encode()
                if filename=='system_transaction.py':original=patches.transaction(original.decode()).encode()
                (source/filename).write_bytes(original)
            add('usr/local/share/evangelion/bin/install.sh',(KIT/'fixtures/install.sh').read_bytes(),0o755,system=True)
            add('usr/local/share/evangelion/bin/boot-console.awk',(KIT/'fixtures/boot-console.awk').read_bytes(),system=True)
            plan={'schema':1,'version':'6.0.0','profiles':PROFILES,'user_files':rows,'user_links':[],'system_files':systems,'packages':[]}
            (payload/'plan.json').write_text(json.dumps(plan))
            before={p:hashlib.sha256(p.read_bytes()).hexdigest() for p in payload.rglob('*') if p.is_file()}
            report={'status':'candidate-appdir','plan_sha256':bundle.sha(payload/'plan.json'),'release_features':{'login_cards':74,'grub_cards':8}}
            (old.parent/'assembly-report.json').write_text(json.dumps(report))
            appearance=root/'appearance';appearance.mkdir();icons=IconTests().archive(appearance)
            # Use the real exported inventory to test registration of all
            # twenty sources alongside the existing candidate payload.
            lumina=root/'lumina';manifest={'files':[]}
            for path in sorted(bundle.LUMINA_FILES):
                src='home/'+path
                target=lumina/src;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(b'@MULTI_RICE_HOME@')
                manifest['files'].append({'path':path,'source':src})
            (appearance/'icons.zip').write_bytes((appearance/'assets/mactahoe.zip').read_bytes())
            with zipfile.ZipFile(appearance/'icons.zip') as z:icon_data=json.loads(z.read('manifest.json'))
            with patch.object(bundle,'FINAL',final),patch.object(bundle,'OUTPUT',output):
                target=bundle.candidate(source,appearance,lumina,manifest,icon_data)
            for path,digest in before.items():self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(),digest)
            revised=json.loads((target/'payload/plan.json').read_text())
            self.assertEqual(json.loads((target.parent/'assembly-report.json').read_text())['appearance_fixes']['lumina_assets'],20)
            self.assertEqual(revised['login_defaults'],'sddm-next-boot-v1');self.assertEqual(revised['icon_bundle']['files'],6)
            expected={r['source'] for r in revised['user_files']+revised['system_files']}|{'plan.json'}
            actual={str(p.relative_to(target/'payload')) for p in (target/'payload').rglob('*') if p.is_file()}
            self.assertEqual(expected,actual)
            from payload_backend import validate_plan
            validate_plan(target/'payload',root/'home')
            self.assertTrue(all(r['template'] for r in revised['user_files'] if r['path'].endswith('.rasi')))


if __name__=='__main__':unittest.main()
