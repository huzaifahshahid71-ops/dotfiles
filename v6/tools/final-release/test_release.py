#!/usr/bin/env python3
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import release


class PublicationTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory()
        self.folder=Path(self.tmp.name)
        self.output=patch.object(release,'OUTPUT',self.folder);self.output.start()
        (self.folder/'RELEASE-v6.0.0.md').write_text('<!-- sumi-v6-final-release-v1 -->\nNotes')
        self.asset=self.folder/'one.part001';self.asset.write_bytes(b'payload')
        self.record={'name':self.asset.name,'size':7,'digest':'sha256:'+release.sha(self.asset),'state':'uploaded'}
        self.created=False;self.published=False;self.uploaded={};self.operations=[]
        self.commit='a'*40
        def api(endpoint,payload=None,optional=False):
            if endpoint=='user':return {'login':'huzaifahshahid71-ops'}
            if endpoint.endswith('/git/ref/tags/v6.0.0'):
                return {'object':{'type':'commit','sha':self.commit}} if self.published else None
            if endpoint.endswith('/releases'):
                self.created=True
                return {'id':1,'draft':True,'target_commitish':self.commit}
            if endpoint.endswith('/releases/1'):
                return {'draft':False,'prerelease':False,'html_url':'https://github.com/release'}
            raise AssertionError(endpoint)
        def run(args,**kw):
            self.operations.append(args)
            if args[:3]==['gh','release','upload']:self.uploaded[self.asset.name]=self.record
            elif args[:3]==['gh','release','edit']:self.published=True
            else:raise AssertionError(args)
        self.patches=[patch.object(release,'api',side_effect=api),
                      patch.object(release,'run',side_effect=run),
                      patch.object(release,'source_commit',return_value=self.commit),
                      patch.object(release,'all_releases',return_value=[]),
                      patch.object(release,'release_assets',side_effect=lambda _:self.uploaded),
                      patch.object(release.shutil,'which',return_value='/usr/bin/gh')]
        for p in self.patches:p.start()

    def tearDown(self):
        for p in reversed(self.patches):p.stop()
        self.output.stop();self.tmp.cleanup()

    def test_draft_upload_verified_before_publication(self):
        release.publish([self.asset])
        self.assertTrue(self.created and self.published)
        self.assertEqual(self.operations[0][:3],['gh','release','upload'])
        self.assertEqual(self.operations[-1][:3],['gh','release','edit'])
        self.assertTrue((self.folder/'published.json').is_file())

    def test_existing_bad_digest_never_publishes(self):
        self.uploaded[self.asset.name]=dict(self.record,digest='sha256:wrong')
        with self.assertRaises(RuntimeError):release.publish([self.asset])
        self.assertFalse(self.published)
        self.assertEqual(self.operations,[])

    def test_verified_asset_is_reused(self):
        self.uploaded[self.asset.name]=self.record
        release.publish([self.asset])
        self.assertTrue(self.published)
        self.assertEqual(len(self.operations),1)

    def test_unknown_extra_asset_keeps_draft(self):
        self.uploaded['unrelated']={'name':'unrelated'}
        with self.assertRaises(RuntimeError):release.publish([self.asset])
        self.assertFalse(self.published)

    def test_wrong_public_release_is_never_modified(self):
        public={'tag_name':release.TAG,'id':1,'draft':False,'html_url':'https://github.com/release'}
        with patch.object(release,'all_releases',return_value=[public]):
            with self.assertRaises(RuntimeError):release.publish([self.asset])
        self.assertFalse(self.created or self.published)
        self.assertEqual(self.operations,[])


if __name__=='__main__':unittest.main()
