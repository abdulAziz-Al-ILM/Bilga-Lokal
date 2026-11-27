"""Refuse incompatible review upgrades; never target or uninstall production."""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile

from apk_signer_fingerprint import fingerprints
from verify_review_manifest import verify_review


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('serial')
    parser.add_argument('apk', type=Path)
    parser.add_argument('--install', action='store_true')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    environment = os.environ.copy()
    if not environment.get('JAVA_HOME'):
        candidates = list((root / '.bilga-tools/java').glob('jdk-*'))
        if len(candidates) != 1:
            raise SystemExit('Set JAVA_HOME to the installed JDK before verifying an APK')
        environment['JAVA_HOME'] = str(candidates[0])
    environment['PATH'] = environment['JAVA_HOME'] + '/bin:' + environment.get('PATH', '')
    sdk = Path(os.environ.get('ANDROID_HOME', root / '.bilga-tools/android'))
    adb = [str(sdk / 'platform-tools/adb'), '-s', args.serial]
    manifest = subprocess.check_output([
        str(sdk / 'cmdline-tools/latest/bin/apkanalyzer'), 'manifest', 'print', str(args.apk)], text=True, env=environment)
    print(verify_review(manifest))
    subprocess.run([str(sdk / 'build-tools/36.0.0/apksigner'), 'verify', str(args.apk)], check=True, env=environment)
    proposed = fingerprints(args.apk)
    installed = subprocess.run(adb + ['shell', 'pm', 'path', 'com.ilmmizan.bilga.review'],
        capture_output=True, text=True, check=True).stdout.strip().splitlines()
    if installed:
        if len(installed) != 1 or not installed[0].startswith('package:/data/app/'):
            raise SystemExit('Unexpected review package layout; refusing any install')
        with tempfile.TemporaryDirectory(prefix='bilga-review-cert-') as directory:
            old = Path(directory) / 'installed-review.apk'
            subprocess.run(adb + ['pull', installed[0][len('package:'):], str(old)],
                check=True, stdout=subprocess.DEVNULL)
            if fingerprints(old) != proposed:
                raise SystemExit('Review signing mismatch. Preserve the installed review app; never uninstall to bypass this check.')
        print('PASS existing review signer matches; use an in-place upgrade')
    else:
        print('PASS isolated review package is absent')
    if args.install:
        subprocess.run(adb + ['install', '-r', str(args.apk)], check=True)


if __name__ == '__main__':
    main()
