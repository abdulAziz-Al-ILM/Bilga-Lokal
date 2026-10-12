"""Public model acquisition integrity/resume tests; no external network."""
import hashlib
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from prepare_uzbek_voice import acquire


class Response:
    def __init__(self, data, status=200, content_range=''):
        self.data, self.status = data, status
        self.headers = {'Content-Range': content_range}
        self.url = 'https://huggingface.co/public-model'

    def __enter__(self):
        return self

    def __exit__(self, *args):
        pass

    def read(self, count):
        result, self.data = self.data[:count], self.data[count:]
        return result


class IntegrityTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.target = Path(self.temp.name) / 'model.onnx'
        self.part = self.target.with_name('model.onnx.part')
        self.data = b'public model fixture'
        self.entry = {'bytes': len(self.data), 'sha256': hashlib.sha256(self.data).hexdigest()}

    def test_resume_verifies_entire_result(self):
        self.part.write_bytes(self.data[:5])
        with patch('urllib.request.urlopen', return_value=Response(self.data[5:], 206, f'bytes 5-{len(self.data)-1}/{len(self.data)}')) as request:
            acquire('https://huggingface.co/pinned', self.target, self.entry)
            self.assertEqual(request.call_args.args[0].get_header('Range'), 'bytes=5-')
        self.assertEqual(self.target.read_bytes(), self.data)
        self.assertFalse(self.part.exists())

    def test_wrong_hash_never_commits(self):
        with patch('urllib.request.urlopen', return_value=Response(b'x' * len(self.data))):
            with self.assertRaisesRegex(ValueError, 'SHA-256'):
                acquire('https://huggingface.co/pinned', self.target, self.entry)
        self.assertFalse(self.target.exists())
        self.assertFalse(self.part.exists())

    def test_wrong_resume_range_never_commits(self):
        self.part.write_bytes(self.data[:5])
        with patch('urllib.request.urlopen', return_value=Response(self.data[5:], 206, f'bytes 0-{len(self.data)-1}/{len(self.data)}')):
            with self.assertRaisesRegex(ValueError, 'resume'):
                acquire('https://huggingface.co/pinned', self.target, self.entry)
        self.assertFalse(self.target.exists())

    def test_ignored_range_restarts(self):
        self.part.write_bytes(b'wrong partial')
        with patch('urllib.request.urlopen', return_value=Response(self.data)):
            acquire('https://huggingface.co/pinned', self.target, self.entry)
        self.assertEqual(self.target.read_bytes(), self.data)


if __name__ == '__main__':
    unittest.main()
