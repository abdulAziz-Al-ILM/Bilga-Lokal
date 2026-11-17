#!/usr/bin/env python3
"""Check concrete release prerequisites in an apkanalyzer XML manifest.

This is not a substitute for Play Console or real-device acceptance.
"""
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from verify_voice_scope import verify_voice

ANDROID = '{http://schemas.android.com/apk/res/android}'


def verify_manifest(xml):
    root = ET.fromstring(xml)
    if root.get('package') != 'com.ilmmizan.bilga':
        raise ValueError('Application ID changed')
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
    return f"PASS package identity; target API {sdk.get(ANDROID + 'targetSdkVersion')}; Billing {version}; {voice}"


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('Usage: verify_play_manifest.py <apkanalyzer-manifest.xml>')
    try:
        print(verify_manifest(Path(sys.argv[1]).read_text()))
    except (ValueError, ET.ParseError) as error:
        raise SystemExit(f'Manifest validation failed: {error}') from error
