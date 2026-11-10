import unittest

from verify_play_manifest import verify_manifest
from verify_review_manifest import verify_review


MANIFEST = '''<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="com.ilmmizan.bilga">
<uses-sdk android:minSdkVersion="26" android:targetSdkVersion="36"/>
<application><meta-data android:name="com.google.android.play.billingclient.version" android:value="9.1.0"/></application>
</manifest>'''


class ManifestChecks(unittest.TestCase):
    def test_valid(self):
        self.assertIn('PASS', verify_manifest(MANIFEST))

    def test_rejects_incompatible_identity_target_and_billing(self):
        for old, new in [('com.ilmmizan.bilga', 'com.example.app'), ('targetSdkVersion="36"', 'targetSdkVersion="35"'), ('9.1.0', '7.1.1')]:
            with self.subTest(change=old), self.assertRaises(ValueError):
                verify_manifest(MANIFEST.replace(old, new))

    def test_requires_billing_metadata(self):
        with self.assertRaises(ValueError):
            verify_manifest(MANIFEST.replace('com.google.android.play.billingclient.version', 'missing'))

    def test_rejects_transitive_microphone_permission(self):
        for tag in ['uses-permission', 'uses-permission-sdk-23']:
            with self.subTest(tag=tag), self.assertRaises(ValueError):
                verify_manifest(MANIFEST.replace('<application>', f'<{tag} android:name="android.permission.RECORD_AUDIO"/><application>'))


class ReviewManifestChecks(unittest.TestCase):
    manifest = MANIFEST.replace('package="com.ilmmizan.bilga"', 'package="com.ilmmizan.bilga.review"').replace(
        '<application>', '<application android:debuggable="true" android:label="Bilga Review">')

    def test_isolated_review_identity(self):
        self.assertIn('PASS', verify_review(self.manifest))

    def test_rejects_production_identity_release_flags_and_ambiguous_label(self):
        for old, new in [('com.ilmmizan.bilga.review', 'com.ilmmizan.bilga'),
                         ('debuggable="true"', 'debuggable="false"'),
                         ('label="Bilga Review"', 'label="Bilga"')]:
            with self.subTest(change=old), self.assertRaises(ValueError):
                verify_review(self.manifest.replace(old, new))

    def test_rejects_microphone_from_any_manifest_permission_tag(self):
        for tag in ['uses-permission', 'uses-permission-sdk-23']:
            with self.subTest(tag=tag), self.assertRaises(ValueError):
                verify_review(self.manifest.replace('<uses-sdk ', f'<{tag} android:name="android.permission.RECORD_AUDIO"/><uses-sdk '))


if __name__ == '__main__':
    unittest.main()
