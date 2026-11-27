#!/usr/bin/env python3
"""Refuse production packages and non-debug binaries in the USB review flow."""
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from verify_voice_scope import verify_voice

ANDROID = '{http://schemas.android.com/apk/res/android}'


def verify_review(xml):
    root = ET.fromstring(xml)
    app = root.find('application')
    if root.get('package') != 'com.ilmmizan.bilga.review':
        raise ValueError('Review testing must never target the installed production package')
    if app is None or app.get(ANDROID + 'debuggable') != 'true' or app.get(ANDROID + 'label') != 'Bilga Review':
        raise ValueError('Expected a clearly labeled debug-only review build')
    voice=verify_voice(root)
    return 'PASS isolated review package, explicit label, debug flag; '+voice


if __name__ == '__main__':
    print(verify_review(Path(sys.argv[1]).read_text()))
