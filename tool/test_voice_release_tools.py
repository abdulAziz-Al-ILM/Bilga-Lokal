"""Key isolation and archive allowlist tests with ephemeral local fixtures."""
import base64
import hashlib
import json
from pathlib import Path
import stat
import tempfile
import unittest
import zipfile

from create_voice_catalog_key import create_key
from package_voice_release import package


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.checkout = self.root / 'checkout'
        self.checkout.mkdir()

    def test_key_is_private_outside_checkout_and_never_overwritten(self):
        key = self.root / 'secure' / 'catalog.seed'
        create_key(key, self.checkout)
        self.assertEqual(stat.S_IMODE(key.stat().st_mode), 0o600)
        self.assertEqual(stat.S_IMODE(key.parent.stat().st_mode), 0o700)
        self.assertEqual(len(base64.b64decode(key.read_text())), 32)
        original = key.read_bytes()
        with self.assertRaises(FileExistsError): create_key(key, self.checkout)
        self.assertEqual(key.read_bytes(), original)

    def test_key_rejects_checkout_shared_directory_and_symlink(self):
        with self.assertRaises(ValueError): create_key(self.checkout / 'key.seed', self.checkout)
        shared = self.root / 'shared'
        shared.mkdir(mode=0o755)
        with self.assertRaises(ValueError): create_key(shared / 'key.seed', self.checkout)
        linked = self.root / 'linked'
        linked.symlink_to(shared, target_is_directory=True)
        with self.assertRaises(ValueError): create_key(linked / 'key.seed', self.checkout)

    def test_archive_is_deterministic_and_omits_unlisted_private_files(self):
        assets = self.root / 'assets'
        assets.mkdir()
        (assets / 'public.onnx').write_bytes(b'public model')
        (assets / 'private.seed').write_text('never publish')
        payload = self.root / 'payload.json'
        entry = {'path': 'model.onnx', 'asset': 'public.onnx', 'bytes': 12,
                 'sha256': hashlib.sha256(b'public model').hexdigest()}
        payload.write_text(json.dumps({'models': [{'id': 'test', 'files': [entry]}]}))
        archive = assets / 'model.zip'
        package(payload, assets, archive)
        original = archive.read_bytes()
        package(payload, assets, archive)
        self.assertEqual(archive.read_bytes(), original)
        with zipfile.ZipFile(archive) as output:
            self.assertEqual(output.namelist(), ['model.onnx'])
        (assets / 'public.onnx').write_bytes(b'corrupt data')
        with self.assertRaises(ValueError): package(payload, assets, archive)
        self.assertEqual(archive.read_bytes(), original)


if __name__ == '__main__': unittest.main()
