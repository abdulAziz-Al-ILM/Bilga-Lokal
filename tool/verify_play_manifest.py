#!/usr/bin/env python3
"""Check concrete release prerequisites in an apkanalyzer XML manifest.

This is not a substitute for Play Console or real-device acceptance.
"""
import argparse
import xml.etree.ElementTree as ET
from pathlib import Path
from verify_voice_scope import verify_voice

ANDROID = '{http://schemas.android.com/apk/res/android}'


def verify_manifest(xml, *, require_release=False):
    root = ET.fromstring(xml)
    if root.get('package') != 'com.ilmmizan.bilga':
        raise ValueError('Application ID changed')
    if require_release:
        application = root.find('application')
        if application is None or any(
            application.get(ANDROID + flag, 'false') != 'false'
            for flag in ('debuggable', 'testOnly')
        ) or root.find('instrumentation') is not None:
            raise ValueError('Play bundle must be a non-debuggable release without test components')
    sdk = root.find('uses-sdk')
    if sdk is None or int(sdk.get(ANDROID + 'targetSdkVersion', '0')) < 36:
        raise ValueError('Target SDK must be at least 36 for the current mobile submission policy')
    billing = root.find(f"application/meta-data[@{ANDROID}name='com.google.android.play.billingclient.version']")
    if billing is None:
        raise ValueError('Play Billing version metadata missing')
    version = billing.get(ANDROID + 'value', '')
    if int(version.split('.')[0]) < 8:
        raise ValueError('Play Billing 7 and earlier are no longer supported for submissions')
    voice=verify_voice(root)
    mode = 'non-debuggable release; ' if require_release else ''
    return f"PASS {mode}package identity; target API {sdk.get(ANDROID + 'targetSdkVersion')}; Billing {version}; {voice}"


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('manifest', type=Path)
    parser.add_argument('--release', action='store_true')
    args = parser.parse_args()
    try:
        print(verify_manifest(args.manifest.read_text(), require_release=args.release))
    except (ValueError, ET.ParseError) as error:
        raise SystemExit(f'Manifest validation failed: {error}') from error
