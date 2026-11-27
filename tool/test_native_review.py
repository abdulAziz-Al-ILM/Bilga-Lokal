"""Run synthetic native checks only after verifying the isolated review target."""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile
import xml.etree.ElementTree as ET

from apk_signer_fingerprint import fingerprints

REVIEW = 'com.ilmmizan.bilga.review'
ANDROID = '{http://schemas.android.com/apk/res/android}'


def verify_manifest(source):
    root = ET.fromstring(source)
    if root.get('package') != REVIEW + '.test':
        raise ValueError('Native tests must use the isolated review test package')
    runners = {item.get(ANDROID + 'name'): item.get(ANDROID + 'targetPackage')
               for item in root.findall('instrumentation')}
    if runners != {'com.ilmmizan.bilga.NotesWidgetChecks': REVIEW,
                   'com.ilmmizan.bilga.WidgetUiProbe': REVIEW + '.test'}:
        raise ValueError('Unexpected instrumentation target; refusing device access')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('serial')
    parser.add_argument('apk', type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    environment = os.environ.copy()
    jdk, = (root / '.bilga-tools/java').glob('jdk-*')
    environment.setdefault('JAVA_HOME', str(jdk))
    environment['PATH'] = environment['JAVA_HOME'] + '/bin:' + environment.get('PATH', '')
    sdk = Path(environment.get('ANDROID_HOME', root / '.bilga-tools/android'))
    manifest = subprocess.check_output([
        str(sdk / 'cmdline-tools/latest/bin/apkanalyzer'), 'manifest', 'print',
        str(args.apk)], text=True, env=environment)
    verify_manifest(manifest)  # Must precede every device call.
    subprocess.run([str(sdk / 'build-tools/36.0.0/apksigner'), 'verify', str(args.apk)],
                   check=True, env=environment)
    proposed = fingerprints(args.apk)
    adb = [str(sdk / 'platform-tools/adb'), '-s', args.serial]
    with tempfile.TemporaryDirectory(prefix='bilga-native-review-') as directory:
        for package in (REVIEW, REVIEW + '.test'):
            query = subprocess.run(adb + ['shell', 'pm', 'path', package],
                                   capture_output=True, text=True, check=False)
            paths = query.stdout.strip().splitlines()
            if (not paths and not query.stderr.strip() and query.returncode in (0, 1)
                    and package == REVIEW + '.test'):
                continue
            if query.returncode != 0 or len(paths) != 1 or not paths[0].startswith('package:/data/app/'):
                raise SystemExit('Expected a single installed review APK; refusing install')
            old = Path(directory) / (package + '.apk')
            subprocess.run(adb + ['pull', paths[0][len('package:'):], str(old)],
                           check=True, stdout=subprocess.DEVNULL)
            if fingerprints(old) != proposed:
                raise SystemExit('Review signer mismatch; preserve existing app and test data')
    subprocess.run(adb + ['install', '-r', '-t', str(args.apk)], check=True)
    for options in ([], ['-e', 'todoChecks', 'true'], ['-e', 'speechChecks', 'true']):
        result = subprocess.run(adb + ['shell', 'am', 'instrument', '-w', '-r'] + options + [
            REVIEW + '.test/com.ilmmizan.bilga.NotesWidgetChecks'],
            capture_output=True, text=True, check=True, timeout=180)
        print(result.stdout, end='')
        if 'INSTRUMENTATION_CODE: -1' not in result.stdout or 'FAILED' in result.stdout:
            raise SystemExit('Native review checks failed')


if __name__ == '__main__':
    main()
