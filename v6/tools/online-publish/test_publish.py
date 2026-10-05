import ast
import importlib.util
from pathlib import Path
import tempfile
import json
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import publish


class PublishTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.root=Path(self.tmp.name)
        self.output=patch.object(publish,'OUTPUT',self.root);self.output.start()
        self.script=self.root/'ONLINE-INSTALL-v6.sh';self.script.write_text('new launcher')
        self.record={'bytes':self.script.stat().st_size,'sha256':publish.sha(self.script)}
        self.original={'assets':{'release.json':{'bytes':3,'sha256':'a'*64}}}
        self.current={'release.json':{'name':'release.json','size':3,'digest':'sha256:'+'a'*64,'state':'uploaded'}}
        self.body='Original notes';self.uploads=[];self.patches=[]
        def api(endpoint,payload=None,method=None,optional=False):
            if payload:
                self.body=payload['body'];return {'body':self.body}
            return {'id':1,'draft':False,'prerelease':False,'body':self.body,'html_url':'https://github.com/release'}
        def upload(args,**kw):
            self.uploads.append(args)
            self.current[self.script.name]={'name':self.script.name,'size':self.record['bytes'],'digest':'sha256:'+self.record['sha256'],'state':'uploaded'}
        self.patches=[patch.object(publish,'api',side_effect=api),patch.object(publish,'assets',side_effect=lambda _:self.current),
                      patch.object(publish,'source_commit',return_value='b'*40),patch.object(publish.subprocess,'run',side_effect=upload)]
        for p in self.patches:p.start()

    def tearDown(self):
        for p in reversed(self.patches):p.stop()
        self.output.stop();self.tmp.cleanup()

    def test_adds_verified_revision_then_advertises_preserving_notes(self):
        publish.publish([self.script],self.original)
        self.assertEqual(len(self.uploads),1)
        self.assertIn(publish.MARKER,self.body)
        self.assertTrue(self.body.endswith('Original notes'))
        self.assertEqual(self.current['release.json']['digest'],'sha256:'+'a'*64)

    def test_changed_existing_public_asset_stops_before_upload(self):
        self.current['release.json']['digest']='sha256:wrong'
        with self.assertRaises(RuntimeError):publish.publish([self.script],self.original)
        self.assertEqual(self.uploads,[]);self.assertEqual(self.body,'Original notes')

    def test_revision_name_collision_does_not_replace_file(self):
        self.current[self.script.name]={'size':3,'digest':'sha256:wrong'}
        with self.assertRaises(RuntimeError):publish.publish([self.script],self.original)
        self.assertEqual(self.uploads,[]);self.assertEqual(self.body,'Original notes')

    def test_verified_upload_resumed_without_reupload(self):
        self.current[self.script.name]={'size':self.record['bytes'],'digest':'sha256:'+self.record['sha256'],'state':'uploaded'}
        publish.publish([self.script],self.original)
        self.assertEqual(self.uploads,[])

    def test_generated_launcher_python_parses(self):
        template=Path(__file__).with_name('bootstrap.py').read_text()
        generated=template.replace('@INFO_SHA256@','a'*64).replace('@INFO_BYTES@','1234')
        ast.parse(generated)
        self.assertNotIn('@INFO_',generated)


class LauncherTests(unittest.TestCase):
    def test_prepared_metadata_and_archive_open_verified_online_gui(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder=Path(temporary);root=folder/'sources';root.mkdir()
            tested=folder/'tested';runtime=tested/'runtime/SumiSetup';(runtime/'source').mkdir(parents=True)
            values={'core.py':'# SUMI_WALLPAPER_ZIP_PACKS_V1\n','app.py':'# wallpaper count from pin\n',
                    'wallpapers.json':json.dumps({'wallpaper_count':631})}
            for name,value in values.items():
                (root/name).write_text(value);(runtime/'source'/name).write_text(value)
            (runtime/'SumiSetup').write_text('#!/bin/sh\nexit 0\n');(runtime/'SumiSetup').chmod(0o755)
            records=[{'path':str(p.relative_to(runtime)),'sha256':publish.sha(p)} for p in sorted(runtime.rglob('*')) if p.is_file()]
            (tested/'gui-complete.json').write_text(json.dumps(records))
            final=folder/'final';final.mkdir();manifest=final/'release.json';manifest.write_text('{"version":"6.0.0"}')
            (final/'published.json').write_text(json.dumps({'assets':{'release.json':{'bytes':manifest.stat().st_size,'sha256':publish.sha(manifest)}}}))
            pack=SimpleNamespace(runtime_records=lambda _:records)
            loader=SimpleNamespace(exec_module=lambda _:None)
            spec=SimpleNamespace(loader=loader)
            with patch.object(publish,'ROOT',root),patch.object(publish,'TEST',tested),patch.object(publish,'FINAL',final),\
                 patch.object(publish,'OUTPUT',folder/'output'),patch.object(publish.importlib.util,'spec_from_file_location',return_value=spec),\
                 patch.object(publish.importlib.util,'module_from_spec',return_value=pack):
                files,_=publish.prepare()
                launcher=next(p for p in files if p.name.endswith('.sh')).read_text().split("python3 - <<'SUMI_ONLINE_PY'\n",1)[1].rsplit('\nSUMI_ONLINE_PY',1)[0]
            tree=ast.parse(launcher)
            tree.body=tree.body[:-1] # Remove CLI exception wrapper; exercise main directly.
            namespace={};exec(compile(tree,'test-bootstrap','exec'),namespace)
            downloads={p.name:p for p in files};downloads['release.json']=manifest
            namespace['fetch']=lambda record,_:downloads[record['asset']]
            client=folder/'client';client.mkdir()
            with patch.object(Path,'home',return_value=client),patch.object(namespace['os'],'geteuid',return_value=1000),\
                 patch.object(namespace['os'],'uname',return_value=SimpleNamespace(machine='x86_64')),\
                 patch.dict(namespace['os'].environ,{'WAYLAND_DISPLAY':'wayland-1','QT_PLUGIN_PATH':'foreign'},clear=True),\
                 patch.object(namespace['os'],'execve') as launch:
                namespace['main']()
                executable,args,env=launch.call_args.args
                self.assertTrue(Path(executable).is_file())
                self.assertEqual(args[1:],[ '--manifest',str(manifest)])
                self.assertEqual(env['QT_QPA_PLATFORM'],'wayland')
                self.assertNotIn('QT_PLUGIN_PATH',env)
                cached=Path(executable).parent
                self.assertTrue(namespace['valid_runtime'](cached,records))
                (cached/'unrecorded.py').write_text('unexpected')
                self.assertFalse(namespace['valid_runtime'](cached,records))


if __name__=='__main__':unittest.main()
