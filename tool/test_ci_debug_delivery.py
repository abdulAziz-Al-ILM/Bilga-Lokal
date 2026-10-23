"""Small delivery safety checks; no Flutter, Java, network or real APKs/keys."""
import hashlib
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import ci_debug_delivery as delivery


class DeliverySafetyTest(unittest.TestCase):
    def test_independent_hashes_agree(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "synthetic.txt"
            path.write_bytes(b"synthetic delivery fixture\n")
            self.assertEqual(delivery.hashes(path), hashlib.sha256(path.read_bytes()).hexdigest())

    def test_hash_disagreement_stops(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "synthetic.txt"
            path.write_bytes(b"synthetic")
            with patch.object(delivery, "run", return_value="0" * 64 + "  synthetic.txt\n"):
                with self.assertRaisesRegex(RuntimeError, "SHA-256 mismatch"):
                    delivery.hashes(path)

    def test_change_during_read_stops(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "synthetic.txt"
            path.write_bytes(b"before")

            def change_file(*args):
                path.write_bytes(b"after which has a different size")
                return hashlib.sha256(b"before").hexdigest()

            with patch.object(delivery, "run", side_effect=change_file):
                with self.assertRaisesRegex(RuntimeError, "File changed"):
                    delivery.hashes(path)

    def test_public_or_wrong_repository_rejected(self):
        for repo in (dict(private=False, full_name=delivery.REPO),
                     dict(private=True, full_name="other/repo")):
            with self.subTest(repo=repo), patch.object(delivery, "gh_json", return_value=repo):
                with self.assertRaisesRegex(RuntimeError, "PRIVATE"):
                    delivery.private_repo()

    def test_publish_checks_privacy_before_any_file_or_release(self):
        with patch.object(delivery, "gh_json", return_value=dict(private=False, full_name=delivery.REPO)) as api:
            with self.assertRaises(RuntimeError):
                delivery.publish(Path("not-an-existing-directory"))
            self.assertEqual(api.call_count, 1)

    def test_local_main_and_automatic_runs_rejected(self):
        baseline = dict(GITHUB_ACTIONS="true", RUNNER_ENVIRONMENT="github-hosted",
                        GITHUB_EVENT_NAME="workflow_dispatch", GITHUB_REPOSITORY=delivery.REPO,
                        GITHUB_REF=delivery.REF)
        for override in (dict(GITHUB_ACTIONS="false"), dict(GITHUB_REF="refs/heads/main"),
                         dict(GITHUB_EVENT_NAME="push"), dict(RUNNER_ENVIRONMENT="self-hosted")):
            with self.subTest(override=override), patch.dict(os.environ, baseline | override, clear=True):
                with self.assertRaisesRegex(RuntimeError, "manual private-WIP"):
                    delivery.main()


if __name__ == "__main__":
    unittest.main()
