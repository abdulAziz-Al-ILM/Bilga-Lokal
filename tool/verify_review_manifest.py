#!/usr/bin/env python3
"""Refuse production packages and non-debug binaries in the USB review flow."""
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ANDROID = '{http://schemas.android.com/apk/res/android}'


def verify_review(xml):
    root = ET.fromstring(xml)
    app = root.find('application')
    if root.get('package') != 'com.ilmmizan.bilga.review':
        raise ValueError('Review testing must never target the installed production package')
    if app is None or app.get(ANDROID + 'debuggable') != 'true' or app.get(ANDROID + 'label') != 'Bilga Review':
        raise ValueError('Expected a clearly labeled debug-only review build')
    if any(n.get(ANDROID + 'name') == 'android.permission.RECORD_AUDIO' for n in root if n.tag.startswith('uses-permission')):
        raise ValueError('Microphone permission is outside the current scope')
    return 'PASS isolated review package, explicit label, debug flag and no microphone permission'


if __name__ == '__main__':
    print(verify_review(Path(sys.argv[1]).read_text()))
