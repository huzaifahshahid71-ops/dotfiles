import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile
from patch_sources import core_text, app_text

SOURCE = Path(sys.argv.pop(1))
namespace = {'__name__': 'fast_wallpaper_tests'}
exec(compile(core_text(SOURCE.read_text()),str(SOURCE),'exec'),namespace)


class PackTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.root=Path(self.tmp.name)
        self.cache=namespace['Cache'](self.root/'cache')
        self.destination=self.root/'TEST WALLPAPERS'
        self.items=[];self.parts=[];self.files={};self.calls=[]
        self.base='https://github.com/example/wallpapers/releases/download/test/'
        for i in range(3):
            data=('wallpaper '+str(i)).encode()
            name='IMG_'+str(i)+'.png'
            self.items.append(self.record(name,data,path=name))
            archive=self.root/('pack'+str(i)+'.zip')
            with zipfile.ZipFile(archive,'w') as out:out.writestr('Wallpapers/'+name,data)
            record=self.record(archive.name,archive.read_bytes());self.parts.append(record);self.files[archive.name]=archive
        manifest=self.root/'manifest.json'
        manifest.write_text(json.dumps({'schema':1,'snapshot_sha256':'snapshot','wallpapers':self.items}))
        self.files[manifest.name]=manifest
        self.pin={'repository':'example/wallpapers','tag':'test','snapshot_sha256':'snapshot',
                  'wallpaper_count':3,'manifest':self.record(manifest.name,manifest.read_bytes()),
                  'packs':{'full':{'format':'independent-zips','parts':self.parts}}}
        def download(record,target,callback):
            self.calls.append(record['asset'])
            return self.files[record['asset']]
        self.download=patch.dict(namespace,{'download':download});self.download.start()

    def record(self,name,data,**kw):
        return dict(asset=name,bytes=len(data),sha256=hashlib.sha256(data).hexdigest(),url=self.base+name,**kw)

    def run_full(self):
        return namespace['online_wallpapers'](self.pin,'full',self.destination,self.cache,lambda e:None)

    def tearDown(self):self.download.stop();self.tmp.cleanup()

    def replace_archive(self,index,members):
        path=self.files[self.parts[index]['asset']]
        with zipfile.ZipFile(path,'w') as out:
            for name,data in members:out.writestr(name,data)
        self.parts[index].update(self.record(path.name,path.read_bytes()))

    def test_full_uses_only_manifest_and_three_pack_requests(self):
        result=self.run_full()
        self.assertEqual(len(result),3)
        self.assertEqual(set(self.calls),{'manifest.json','pack0.zip','pack1.zip','pack2.zip'})
        self.assertEqual((self.destination/'IMG_2.png').read_bytes(),b'wallpaper 2')

    def test_existing_user_image_preserved_with_checksum_suffix(self):
        self.destination.mkdir();(self.destination/'IMG_0.png').write_bytes(b'personal image')
        self.run_full()
        self.assertEqual((self.destination/'IMG_0.png').read_bytes(),b'personal image')
        self.assertEqual(len(list(self.destination.glob('IMG_0-*.png'))),1)

    def test_resume_reuses_same_destination_images(self):
        self.run_full();result=self.run_full()
        self.assertTrue(all(r['status']=='existing' for r in result))
        self.assertEqual(len(list(self.destination.iterdir())),3)

    def test_wrong_image_hash_refused_and_staging_removed(self):
        self.replace_archive(0,[('Wallpapers/IMG_0.png',b'corrupted!!')])
        with self.assertRaises(Exception):self.run_full()
        self.assertFalse((self.destination/'IMG_0.png').exists())
        self.assertEqual(list(self.cache.root.glob('.wallpaper-pack-*')),[])

    def test_unexpected_traversal_rejected_before_any_image_write(self):
        self.replace_archive(2,[('../escape.png',b'wallpaper 2')])
        with self.assertRaises(namespace['SetupError']):self.run_full()
        self.assertEqual(list(self.destination.iterdir()),[])

    def test_duplicate_members_across_packs_refused(self):
        self.replace_archive(2,[('Wallpapers/IMG_0.png',b'wallpaper 0')])
        with self.assertRaises(namespace['SetupError']):self.run_full()
        self.assertEqual(list(self.destination.iterdir()),[])

    def test_missing_image_refused(self):
        self.replace_archive(2,[])
        with self.assertRaises(namespace['SetupError']):self.run_full()

    def test_count_mismatch_refused(self):
        self.pin['wallpaper_count']=4
        with self.assertRaises(namespace['SetupError']):self.run_full()

    def test_patch_idempotent_and_selection_path_unchanged(self):
        updated=core_text(SOURCE.read_text())
        self.assertEqual(core_text(updated),updated)
        with patch.dict(namespace,{'_online_wallpapers_individual':lambda *a:'selection unchanged'}):
            self.assertEqual(namespace['online_wallpapers'](self.pin,'selection',self.destination,self.cache,lambda e:None),'selection unchanged')


if __name__=='__main__':unittest.main()
