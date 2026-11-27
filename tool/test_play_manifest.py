import unittest

from verify_play_manifest import verify_manifest
from verify_review_manifest import verify_review
from test_native_review import verify_manifest as verify_native


MANIFEST = '''<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="com.ilmmizan.bilga">
<uses-sdk android:minSdkVersion="26" android:targetSdkVersion="36"/>
<application><meta-data android:name="com.google.android.play.billingclient.version" android:value="9.1.0"/></application>
</manifest>'''


class ManifestChecks(unittest.TestCase):
    def test_valid(self):
        self.assertIn('PASS', verify_manifest(MANIFEST))

    def test_play_release_has_no_debug_or_test_flags(self):
        self.assertIn('non-debuggable release', verify_manifest(MANIFEST, require_release=True))
        for flag in ('debuggable', 'testOnly'):
            source = MANIFEST.replace('<application>', f'<application android:{flag}="true">')
            with self.subTest(flag=flag), self.assertRaises(ValueError):
                verify_manifest(source, require_release=True)
        source = MANIFEST.replace('<application>', '<instrumentation android:name="fixture"/><application>')
        with self.assertRaises(ValueError):
            verify_manifest(source, require_release=True)

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


class AuthorizedVoiceManifestChecks(unittest.TestCase):
    def voice(self, source):
        return source.replace('<uses-sdk ', '<uses-permission android:name="android.permission.RECORD_AUDIO"/><queries><intent><action android:name="android.speech.RecognitionService"/></intent></queries><uses-sdk ').replace('</application>', '<meta-data android:name="bilga.voice.mode" android:value="push_to_talk"/></application>')

    def test_explicit_push_to_talk_is_authorized(self):
        self.assertIn('push-to-talk',verify_manifest(self.voice(MANIFEST)))
        self.assertIn('push-to-talk',verify_review(self.voice(ReviewManifestChecks.manifest)))

    def test_explicit_foreground_voice_session_is_authorized(self):
        source=self.voice(ReviewManifestChecks.manifest).replace('push_to_talk','foreground_session')
        self.assertIn('foreground voice session',verify_review(source))

    def test_background_microphone_remains_forbidden(self):
        source=self.voice(MANIFEST).replace('push_to_talk','foreground_session')
        for bad in [source.replace('<uses-sdk ', '<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE"/><uses-sdk '),source.replace('</application>','<service android:name=".Capture" android:foregroundServiceType="microphone"/></application>')]:
            with self.assertRaises(ValueError):verify_manifest(bad)

    def test_microphone_requires_queries_and_explicit_mode(self):
        source=self.voice(MANIFEST)
        for old,new in [('push_to_talk','always_listening'),('android.speech.RecognitionService','missing.Service')]:
            with self.assertRaises(ValueError):verify_manifest(source.replace(old,new))


class NativeReviewManifestChecks(unittest.TestCase):
    manifest = '''<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="com.ilmmizan.bilga.review.test">
    <instrumentation android:name="com.ilmmizan.bilga.NotesWidgetChecks" android:targetPackage="com.ilmmizan.bilga.review"/>
    <instrumentation android:name="com.ilmmizan.bilga.WidgetUiProbe" android:targetPackage="com.ilmmizan.bilga.review.test"/>
    </manifest>'''

    def test_review_native_target(self):
        verify_native(self.manifest)

    def test_rejects_production_target_before_device_access(self):
        for source in (self.manifest.replace('.review', ''),
                       self.manifest.replace('targetPackage="com.ilmmizan.bilga.review"',
                                             'targetPackage="com.ilmmizan.bilga"'),
                       self.manifest.replace('com.ilmmizan.bilga.WidgetUiProbe', 'unknown.Runner')):
            with self.subTest(source=source), self.assertRaises(ValueError):
                verify_native(source)


if __name__ == '__main__':
    unittest.main()
