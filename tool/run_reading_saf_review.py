#!/usr/bin/env python3
"""Pair the guarded Review Flutter test with real Android DocumentsUI actions."""
import argparse
import re
import subprocess
import time
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ADB = ROOT / '.bilga-tools/android/platform-tools/adb'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('serial')
    parser.add_argument('apk')
    parser.add_argument('fixture_folder', help='Exact generated folder name inside Downloads')
    args = parser.parse_args()
    if not re.fullmatch(r'BilgaReviewReader-[A-Za-z0-9-]+', args.fixture_folder):
        raise SystemExit('Expected the isolated synthetic fixture folder name')

    def adb(*parts):
        return subprocess.check_output([str(ADB), '-s', args.serial, *parts], text=True, timeout=30)

    def tap(node):
        values = [int(n) for n in re.findall(r'\d+', node.attrib.get('bounds', ''))]
        if len(values) != 4:
            raise RuntimeError('Picker target has no visible bounds')
        adb('shell', 'input', 'tap', str((values[0] + values[2]) // 2), str((values[1] + values[3]) // 2))

    def choose(kind):
        if kind == 'CANCEL':
            time.sleep(2)
            adb('shell', 'input', 'keyevent', '4')
            return
        filename = f'BilgaReaderFixture-{kind}.{"pdf" if kind == "PDF" else "txt" if kind == "TXT" else "epub"}'
        opened_roots = False
        deadline = time.monotonic() + 18
        while time.monotonic() < deadline:
            adb('shell', 'uiautomator', 'dump', '--compressed', '/data/local/tmp/bilga-review-picker.xml')
            tree = ET.fromstring(adb('exec-out', 'cat', '/data/local/tmp/bilga-review-picker.xml'))
            nodes = list(tree.iter('node'))
            # Never operate on production Bilga or choose an owner document.
            packages = {n.attrib.get('package', '') for n in nodes}
            if not any('documentsui' in p for p in packages):
                time.sleep(.3)
                continue
            for n in nodes:
                if n.attrib.get('text') == filename:
                    tap(n)
                    print(f'SAF selected original fixture: {kind}', flush=True)
                    return
            folder = next((n for n in nodes if n.attrib.get('text') == args.fixture_folder), None)
            if folder is not None:
                tap(folder)
                continue
            downloads = next((n for n in nodes if n.attrib.get('text') in ('Downloads', 'Download', 'Загрузки') and ('title' in n.attrib.get('resource-id', ''))), None)
            if downloads is not None and opened_roots:
                tap(downloads)
                opened_roots = False
                continue
            menu = next((n for n in nodes if n.attrib.get('content-desc') in ('Show roots', 'Open navigation drawer', 'Показать корневые папки') or n.attrib.get('resource-id') == 'android:id/home'), None)
            if menu is not None and not opened_roots:
                tap(menu)
                opened_roots = True
                continue
            time.sleep(.3)
        raise RuntimeError(f'Could not select synthetic fixture {kind} in DocumentsUI')

    command = ['bash', 'tool/test_tablet_review.sh', args.serial, args.apk, 'integration_test/reading_saf_review_test.dart']
    process = subprocess.Popen(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
    try:
        for line in process.stdout:
            print(line, end='', flush=True)
            match = re.search(r'BILGA_SAF_READY:(CANCEL|PDF|EPUB|TXT|Invalid)', line)
            if match:
                choose(match.group(1))
        raise SystemExit(process.wait())
    finally:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=30)


if __name__ == '__main__':
    main()
