import copy
import hashlib
import json
from pathlib import Path
import shutil
import tempfile
import unittest
import zipfile
import importlib.util
from unittest.mock import patch
import bundle
import fixes
import publish
from common import sha,record,save,write
from desktop_defaults import desktop_defaults

REAL_KIT=Path(__file__).resolve().parent

class PayloadTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(prefix='desktop release ');self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name);self.kit=self.root/'kit';shutil.copytree(REAL_KIT/'verified',self.kit/'verified')
        self.payload=self.root/'payload';self.addon=self.root/'addon';self.rows=[]
        self.patch=patch.object(fixes,'KIT',self.kit);self.patch.start();self.addCleanup(self.patch.stop)
        self.patch2=patch.object(bundle,'KIT',self.kit);self.patch2.start();self.addCleanup(self.patch2.stop)
        for path,before,after,mode in fixes.verified_changes():self.row(path,before,template=b'@MULTI_RICE_HOME@' in before)
        self.row('.config/important-setting',b'preserve this')
        manifest=json.loads((self.kit/'verified/crimson-manifest.json').read_text())
        for name in manifest['anchors']:
            self.row('.local/src/ambxst/'+name,name.encode())
            manifest['anchors'][name]=hashlib.sha256(name.encode()).hexdigest()
        for r in manifest['files']:
            data=r['path'].encode();r.update(bytes=len(data),sha256=hashlib.sha256(data).hexdigest())
            write(self.addon/r['source'],data,r['mode'])
        save(self.kit/'verified/crimson-manifest.json',manifest)
        self.plan={'schema':1,'user_files':self.rows,'packages':[{'name':'glibc','sha256':'preserve'}],
                   'system_files':[{'path':'boot-setting','sha256':'preserve'}],'user_links':[],
                   'icon_bundle':{'unpacked_bytes':603730520},'login_defaults':'sddm-next-boot-v1'}
        save(self.payload/'plan.json',self.plan);self.baseline=self.root/'before.json';save(self.baseline,self.plan)

    def row(self,path,data,template=False):
        target=self.payload/'home'/path;write(target,data)
        self.rows.append({'path':path,'source':'home/'+path,'bytes':len(data),'sha256':sha(target),
                          'mode':0o644,'template':template,'init':False})

    def test_imports_all_twelve_sources_and_preserves_other_records(self):
        plan,changed=fixes.apply(self.payload,self.addon)
        self.assertEqual(len(changed),12)
        bundle.verify_preserved(self.baseline,self.payload/'plan.json')
        self.assertEqual(plan['packages'],self.plan['packages'])
        self.assertEqual(plan['icon_bundle'],self.plan['icon_bundle'])
        for path,before,after,mode in fixes.verified_changes():
            self.assertEqual((self.payload/'home'/path).read_bytes(),after)
            self.assertNotIn(b'/home/gamer',after)
            self.assertIn(b'@MULTI_RICE_HOME@',after if path.endswith('.kdl') else b'@MULTI_RICE_HOME@')
        again,changed=fixes.apply(self.payload,self.addon)
        self.assertEqual(changed,[]);self.assertEqual(plan,again)

    def test_rejects_custom_configuration_before_writing_any_repairs(self):
        path=fixes.verified_changes()[0][0];write(self.payload/'home'/path,b'custom config')
        before=(self.payload/'plan.json').read_bytes()
        with self.assertRaisesRegex(RuntimeError,'baseline'):fixes.apply(self.payload,self.addon)
        self.assertEqual((self.payload/'plan.json').read_bytes(),before)
        self.assertFalse((self.payload/'home'/fixes.CRIMSON).exists())

    def test_corrupt_last_addition_is_caught_before_any_import(self):
        manifest=json.loads((self.kit/'verified/crimson-manifest.json').read_text())
        write(self.addon/manifest['files'][-1]['source'],b'broken')
        with self.assertRaisesRegex(RuntimeError,'checksum'):fixes.apply(self.payload,self.addon)
        self.assertFalse((self.payload/'home'/fixes.CRIMSON).exists())

    def test_symlink_addition_refused(self):
        manifest=json.loads((self.kit/'verified/crimson-manifest.json').read_text())
        target=self.addon/manifest['files'][0]['source'];body=target.read_bytes();target.unlink()
        other=self.root/'other';other.write_bytes(body);target.symlink_to(other)
        with self.assertRaisesRegex(RuntimeError,'symlink'):fixes.apply(self.payload,self.addon)

    def retained_archive(self):
        # Use the original repair producer rather than inventing an extracted
        # directory layout, which missed the actual retained addon.zip format.
        spec=importlib.util.spec_from_file_location('crimson_producer',REAL_KIT/'fixtures/crimson-repair-producer.py')
        producer=importlib.util.module_from_spec(spec);spec.loader.exec_module(producer)
        manifest=json.loads((self.kit/'verified/crimson-manifest.json').read_text())
        source=self.root/'working-crimson'
        for name in manifest['anchors']:write(source/name,name.encode())
        for row in manifest['files']:
            write(source/Path(row['path']).relative_to(producer.PREFIX), (self.addon/row['source']).read_bytes())
        with patch.object(producer,'ANCHORS',manifest['anchors']):raw,actual=producer.bundle(source)
        self.assertEqual(actual,manifest)
        archive=self.addon/'addon.zip';write(archive,raw)
        save(self.kit/'verified/crimson-archive.json',{'asset':'addon.zip','sha256':sha(archive)})
        save(self.addon/'manifest.json',manifest)
        shutil.rmtree(self.addon/'home')
        return archive

    def rewrite_archive(self,transform):
        archive=self.retained_archive()
        with zipfile.ZipFile(archive) as z:files={n:z.read(n) for n in z.namelist()}
        transform(files)
        archive.unlink()
        with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
            for n,data in files.items():z.writestr(n,data)
        save(self.kit/'verified/crimson-archive.json',{'asset':'addon.zip','sha256':sha(archive)})
        return archive

    def test_actual_repair_producer_archive_imports_and_repeats(self):
        self.retained_archive()
        plan,changed=fixes.apply(self.payload,self.addon)
        self.assertEqual(len(changed),12)
        bundle.verify_preserved(self.baseline,self.payload/'plan.json')
        self.assertEqual(fixes.apply(self.payload,self.addon)[1],[])
        for row,data in fixes.crimson_sources(self.addon):
            self.assertEqual((self.payload/row['source']).read_bytes(),data)

    def test_archive_is_discovered_without_extracted_home(self):
        self.retained_archive()
        retained=self.root/'development/sumi-v6-build-prep/crimson-repair/accepted'
        retained.parent.mkdir(parents=True);shutil.move(self.addon,retained)
        with patch.object(bundle,'DEV',self.root/'development'),patch.object(bundle,'HOME',self.root/'home'):
            self.assertEqual(bundle.addon(),retained)
        self.assertFalse((retained/'home').exists())

    def test_archive_digest_difference_blocks_all_writes(self):
        archive=self.retained_archive();write(archive,b'broken')
        with self.assertRaisesRegex(RuntimeError,'archive checksum'):fixes.apply(self.payload,self.addon)
        self.assertEqual(json.loads((self.payload/'plan.json').read_text()),self.plan)
        self.assertFalse((self.payload/'home'/fixes.CRIMSON).exists())

    def test_archive_last_member_corruption_blocks_all_writes(self):
        manifest=json.loads((self.kit/'verified/crimson-manifest.json').read_text())
        name=manifest['files'][-1]['source']
        self.rewrite_archive(lambda files:files.update({name:b'x'*len(files[name])}))
        with self.assertRaisesRegex(RuntimeError,'source checksum'):fixes.apply(self.payload,self.addon)
        self.assertEqual(json.loads((self.payload/'plan.json').read_text()),self.plan)
        self.assertFalse((self.payload/'home'/fixes.CRIMSON).exists())

    def test_archive_unregistered_member_refused(self):
        self.rewrite_archive(lambda files:files.update({'../unregistered':b'bad'}))
        with self.assertRaisesRegex(RuntimeError,'unexpected members'):fixes.apply(self.payload,self.addon)
        self.assertFalse((self.payload/'home'/fixes.CRIMSON).exists())

    def test_archive_manifest_difference_refused(self):
        self.rewrite_archive(lambda files:files.update({'manifest.json':b'{}'}))
        with self.assertRaisesRegex(RuntimeError,'manifest differs'):fixes.apply(self.payload,self.addon)

    def test_archive_duplicate_member_refused(self):
        archive=self.retained_archive()
        import warnings
        with warnings.catch_warnings():
            warnings.simplefilter('ignore',UserWarning)
            with zipfile.ZipFile(archive,'a') as z:z.writestr('manifest.json',b'{}')
        save(self.kit/'verified/crimson-archive.json',{'asset':'addon.zip','sha256':sha(archive)})
        with self.assertRaisesRegex(RuntimeError,'duplicate'):fixes.apply(self.payload,self.addon)

    def test_archive_symlink_member_refused(self):
        archive=self.retained_archive()
        with zipfile.ZipFile(archive) as z:files={n:z.read(n) for n in z.namelist()}
        archive.unlink()
        with zipfile.ZipFile(archive,'w') as z:
            for index,(name,data) in enumerate(files.items()):
                info=zipfile.ZipInfo(name)
                info.external_attr=(0o120777 if index==0 else 0o100644)<<16
                z.writestr(info,data)
        save(self.kit/'verified/crimson-archive.json',{'asset':'addon.zip','sha256':sha(archive)})
        with self.assertRaisesRegex(RuntimeError,'symlink'):fixes.apply(self.payload,self.addon)

    def test_unrelated_system_edit_blocks_publication(self):
        fixes.apply(self.payload,self.addon)
        plan=json.loads((self.payload/'plan.json').read_text());plan['system_files'][0]['sha256']='changed';save(self.payload/'plan.json',plan)
        with self.assertRaisesRegex(RuntimeError,'Non-user'):bundle.verify_preserved(self.baseline,self.payload/'plan.json')

    def test_unrelated_user_edit_blocks_publication(self):
        fixes.apply(self.payload,self.addon)
        plan=json.loads((self.payload/'plan.json').read_text());next(r for r in plan['user_files'] if r['path']=='.config/important-setting')['sha256']='changed';save(self.payload/'plan.json',plan)
        with self.assertRaisesRegex(RuntimeError,'Unrelated'):bundle.verify_preserved(self.baseline,self.payload/'plan.json')

    def published_template(self):
        path,before,after,mode=fixes.verified_changes()[0]
        data=b'// published template settings retained\n'+before
        write(self.payload/'home'/path,data)
        row=next(r for r in self.rows if r['path']==path);row.update(bytes=len(data),sha256=hashlib.sha256(data).hexdigest())
        save(self.payload/'plan.json',self.plan)
        save(self.kit/'verified/cipher-published-baseline.json',{'path':path,'bytes':len(data),'sha256':row['sha256'],'mode':mode,'template':row['template']})
        return path,data

    def test_known_published_template_changes_only_search_binding(self):
        path,data=self.published_template()
        plan,changed=fixes.apply(self.payload,self.addon)
        result=(self.payload/'home'/path).read_bytes()
        self.assertTrue(result.startswith(b'// published template settings retained\n'))
        self.assertEqual(result,fixes.cipher_binding(data))
        self.assertEqual(fixes.apply(self.payload,self.addon)[1],[])

    def test_unknown_template_difference_refused(self):
        path,data=self.published_template()
        write(self.payload/'home'/path,b'// unreviewed edit\n'+data)
        with self.assertRaisesRegex(RuntimeError,'baseline'):fixes.apply(self.payload,self.addon)
        self.assertFalse((self.payload/'home'/fixes.CRIMSON).exists())

    def test_known_already_correct_published_template_is_retained(self):
        path,data=self.published_template();correct=fixes.cipher_binding(data)
        write(self.payload/'home'/path,correct)
        row=next(r for r in self.rows if r['path']==path);row.update(bytes=len(correct),sha256=hashlib.sha256(correct).hexdigest())
        save(self.payload/'plan.json',self.plan)
        save(self.kit/'verified/cipher-published-baseline.json',{'path':path,'bytes':len(correct),'sha256':row['sha256'],'mode':row['mode'],'template':row['template']})
        plan,changed=fixes.apply(self.payload,self.addon)
        self.assertNotIn(path,changed)
        self.assertEqual((self.payload/'home'/path).read_bytes(),correct)

class CollectorTests(unittest.TestCase):
    def test_defaults_match_all_vm_accepted_changes(self):
        for path,before,after,mode in fixes.verified_changes():
            self.assertEqual(desktop_defaults(path,before),after)
            self.assertEqual(desktop_defaults(path,after),after)
        self.assertEqual(desktop_defaults('unrelated.lua',b'caelestia shell -d'),b'caelestia shell -d')

    def test_custom_environment_retained(self):
        with self.assertRaisesRegex(RuntimeError,'Custom'):
            desktop_defaults('.local/share/desktop-profiles/caelestia/hypr/hyprland/execs.lua',b'hl.exec_cmd("env QS_ICON_THEME=Custom caelestia shell -d")')

    def test_classifier_keeps_ui_and_still_excludes_cache_and_wallpaper_downloads(self):
        source='''def production_path(relative):
    path = relative_path(relative)
    extras = {"wallpapers", "cache", "tests"}
    return not any(x in extras for x in path.parts)
'''
        transformed=fixes.assembler(source);self.assertEqual(fixes.assembler(transformed),transformed)
        namespace={'relative_path':Path};exec(transformed,namespace);test=namespace['production_path']
        self.assertTrue(test('modules/widgets/dashboard/wallpapers/WallpapersTab.qml'))
        self.assertFalse(test('modules/widgets/dashboard/wallpapers/cache/file.qml'))
        self.assertFalse(test('wallpapers/image.png'))
        self.assertFalse(test('modules/widgets/dashboard/wallpapers/download.jpg'))

    def test_staging_transform_compiles_and_is_repeatable(self):
        source='''def production_path(relative):
    path = relative_path(relative)
    return True
class Layer:
    def add(self, source, relative):
        data = source.read_bytes()
        data, _ = portable(data, str(self.home))
        return data
'''
        revised=fixes.collector(source);self.assertEqual(fixes.collector(revised),revised)
        self.assertIn('data = desktop_defaults(relative, data)',revised)

    def test_unknown_assembler_refused(self):
        with self.assertRaisesRegex(RuntimeError,'Unknown'):fixes.collector('print("unknown")\n')

    def test_observed_public_assembler_transform(self):
        source=(REAL_KIT/'fixtures/published-assembler.py').read_text()
        result=fixes.collector(source)
        self.assertEqual(fixes.collector(result),result)
        self.assertIn('data = desktop_defaults(relative, data)',result)

class PublicationTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup);root=Path(self.temp.name)
        self.old=root/'old/ONLINE-INSTALL-v6.sh';self.new=root/'new/ONLINE-INSTALL-v6.sh'
        write(self.old,b'old');write(self.new,b'new');self.prior=record(self.old);self.expected=record(self.new)
        self.current={'ONLINE-INSTALL-v6.sh':self.asset(self.prior)}

    def asset(self,r):return {'id':1,'state':'uploaded','size':r['bytes'],'digest':'sha256:'+r['sha256']}

    def api(self,endpoint,payload=None,method=None):
        self.assertEqual(method,'DELETE');self.current={}

    def test_successful_switch(self):
        def upload(p):self.current={'ONLINE-INSTALL-v6.sh':self.asset(record(p))}
        with patch.object(publish,'assets',lambda identifier:self.current),patch.object(publish,'api',self.api),patch.object(publish,'upload',upload):
            publish.switch_launcher(1,self.expected,self.prior,self.old,self.new)
        self.assertEqual(self.current['ONLINE-INSTALL-v6.sh']['digest'],'sha256:'+self.expected['sha256'])

    def test_failed_upload_restores_prior_launcher(self):
        def upload(p):
            if p==self.new:raise RuntimeError('upload failed')
            self.current={'ONLINE-INSTALL-v6.sh':self.asset(record(p))}
        with patch.object(publish,'assets',lambda identifier:self.current),patch.object(publish,'api',self.api),patch.object(publish,'upload',upload):
            with self.assertRaisesRegex(RuntimeError,'upload failed'):publish.switch_launcher(1,self.expected,self.prior,self.old,self.new)
        self.assertEqual(self.current['ONLINE-INSTALL-v6.sh']['digest'],'sha256:'+self.prior['sha256'])

    def test_unknown_launcher_retained(self):
        self.current['ONLINE-INSTALL-v6.sh']['digest']='sha256:unknown'
        with patch.object(publish,'assets',lambda identifier:self.current),patch.object(publish,'api') as api:
            with self.assertRaisesRegex(RuntimeError,'changed'):publish.switch_launcher(1,self.expected,self.prior,self.old,self.new)
            api.assert_not_called()

    def test_current_launcher_requires_no_mutation(self):
        self.current['ONLINE-INSTALL-v6.sh']=self.asset(self.expected)
        with patch.object(publish,'assets',lambda identifier:self.current),patch.object(publish,'api') as api:
            publish.switch_launcher(1,self.expected,self.prior,self.old,self.new);api.assert_not_called()

class BaselineTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(prefix='packaged baseline ');self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name);self.output=self.root/'output';self.output.mkdir()
        self.p=patch.object(bundle,'OUTPUT',self.output);self.p.start();self.addCleanup(self.p.stop)

    def test_reuses_final_packed_backend_instead_of_stale_candidate(self):
        r2=self.root/'r2';source=self.root/'published-source';source.mkdir()
        write(source/'core.py',b'# accepted fast downloader\n')
        write(r2/'candidate/AppDir/backend/core.py',b'# old RC5 downloader\n')
        write(r2/'packed.AppDir/backend/core.py',(source/'core.py').read_bytes())
        save(r2/'packed.AppDir/payload/plan.json',{'user_files':[]})
        save(r2/'candidate/assembly-report.json',{'status':'candidate-appdir','release_features':{'login_cards':74,'grub_cards':8},'plan_sha256':sha(r2/'packed.AppDir/payload/plan.json')})
        manifest={'image':{'asset':'r2.AppImage','sha256':'accepted','bytes':123}}
        with patch.object(bundle,'locate',lambda name,required:r2):
            candidate=bundle.obtain_candidate(manifest,self.output)
            bundle.verify_backend(candidate,source)
            self.assertEqual(bundle.obtain_candidate(manifest,self.output),candidate)
        self.assertEqual((r2/'candidate/AppDir/backend/core.py').read_bytes(),b'# old RC5 downloader\n')
        self.assertFalse((r2/'assembly-report.json').exists())
        self.assertTrue(candidate.is_relative_to(self.output))

    def test_different_packaged_backend_still_refused(self):
        candidate=self.root/'candidate';source=self.root/'source'
        write(candidate/'backend/core.py',b'changed');write(source/'core.py',b'published')
        with self.assertRaisesRegex(RuntimeError,'packaged backend/source'):bundle.verify_backend(candidate,source)

    def test_early_kit_update_keeps_verified_downloads_and_old_identity(self):
        old={'baseline':'same','gui':'same','kit':{'version':'v1'}};new=dict(old,kit={'version':'v2'})
        save(self.output/'inputs.json',old)
        write(self.output/'downloads/source.zip',b'keep verified bytes')
        write(self.output/'sources/core.py',b'early source copy')
        bundle.prepare_identity(new)
        self.assertEqual(json.loads((self.output/'inputs.json').read_text()),new)
        self.assertEqual((self.output/'downloads/source.zip').read_bytes(),b'keep verified bytes')
        self.assertEqual(json.loads(next(self.output.glob('inputs-before-kit-*.json')).read_text()),old)

    def test_kit_update_refused_after_candidate_or_publication_started(self):
        old={'baseline':'same','gui':'same','kit':{'version':'v1'}};new=dict(old,kit={'version':'v2'})
        save(self.output/'inputs.json',old);save(self.output/'candidate-ready.json',{'plan_sha256':'completed'})
        with self.assertRaisesRegex(RuntimeError,'candidate/release output'):bundle.prepare_identity(new)
        self.assertEqual(json.loads((self.output/'inputs.json').read_text()),old)

    def test_changed_baseline_refused_even_during_early_preparation(self):
        old={'baseline':'old','gui':'same','kit':{'version':'v1'}};new=dict(old,baseline='different')
        save(self.output/'inputs.json',old)
        with self.assertRaisesRegex(RuntimeError,'different baseline'):bundle.prepare_identity(new)

    def interrupted_candidate(self):
        manifest=self.output/'downloads/release-r2.json';save(manifest,{'image':{'sha256':'published','asset':'r2'}})
        baseline=self.output/'base-candidate'
        save(baseline/'complete.json',{'sha256':'published','asset':'r2'})
        save(baseline/'AppDir/payload/plan.json',{'user_files':[]})
        write(baseline/'AppDir/backend/core.py',b'published')
        save(baseline/'assembly-report.json',{'plan_sha256':sha(baseline/'AppDir/payload/plan.json')})
        shutil.copytree(baseline/'AppDir',self.output/'candidate/AppDir',copy_function=bundle.link)
        old={'baseline':{'release-r2.json':{'sha256':sha(manifest)}},'gui':'same','kit':{'version':'v2'}}
        save(self.output/'inputs.json',old)
        return old,dict(old,kit={'version':'v3'})

    def test_unchanged_interrupted_candidate_can_migrate_without_redownloading(self):
        old,new=self.interrupted_candidate();bundle.prepare_identity(new)
        self.assertEqual(json.loads((self.output/'inputs.json').read_text()),new)
        self.assertTrue((self.output/'candidate/AppDir/backend/core.py').is_file())

    def test_modified_interrupted_candidate_blocks_migration(self):
        old,new=self.interrupted_candidate()
        write(self.output/'candidate/AppDir/backend/core.py',b'changed only in candidate')
        with self.assertRaisesRegex(RuntimeError,'already has changes'):bundle.prepare_identity(new)
        self.assertEqual(json.loads((self.output/'inputs.json').read_text()),old)

    def test_added_interrupted_candidate_file_blocks_migration(self):
        old,new=self.interrupted_candidate()
        write(self.output/'candidate/AppDir/payload/unregistered',b'new')
        with self.assertRaisesRegex(RuntimeError,'already has changes'):bundle.prepare_identity(new)

if __name__=='__main__':unittest.main(verbosity=2)
