#!/usr/bin/env python3
"""Pair the guarded Review Flutter test with real Android DocumentsUI actions."""
import argparse
import os
import signal
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
    parser.add_argument('--restart', action='store_true', help='Require the saved fixture to reopen after a real process restart')
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
        inside_fixture = False
        internal_storage = False
        in_downloads = False
        deadline = time.monotonic() + 45
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
                if inside_fixture and n.attrib.get('text') == filename:
                    tap(n)
                    print(f'SAF selected original fixture: {kind}', flush=True)
                    return
            storage = next((n for n in nodes if n.attrib.get('text') in ('Tab 16','Tab16_NEU','Internal storage','Internal shared storage') and n.attrib.get('resource-id','').endswith('/title')),None)
            if storage is not None and opened_roots:
                tap(storage)
                opened_roots=False
                internal_storage=True
                in_downloads=False
                continue
            folder = next((n for n in nodes if n.attrib.get('text') == args.fixture_folder and n.attrib.get('resource-id','').endswith('/title')), None)
            if folder is not None:
                tap(folder)
                inside_fixture = True
                continue
            downloads = next((n for n in nodes if n.attrib.get('text') in ('Downloads', 'Download', 'Загрузки', 'Yuklanmalar') and n.attrib.get('resource-id','').endswith('/title')), None)
            if downloads is not None and (opened_roots or (internal_storage and not in_downloads)):
                tap(downloads)
                opened_roots = False
                in_downloads=True
                continue
            menu = next((n for n in nodes if n.attrib.get('content-desc') in ('Show roots', 'Open navigation drawer', 'Показать корневые папки', 'Ko‘rsatish', "Ko'rsatish") or n.attrib.get('resource-id') == 'android:id/home'), None)
            if menu is not None and not opened_roots:
                tap(menu)
                opened_roots = True
                continue
            time.sleep(.3)
        raise RuntimeError(f'Could not select synthetic fixture {kind} in DocumentsUI')

    command = ['bash', 'tool/test_tablet_review.sh', args.serial, args.apk, 'integration_test/reading_saf_review_test.dart']
    process = subprocess.Popen(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1, start_new_session=True)
    seen = []
    restart_verified = False
    try:
        for line in process.stdout:
            print(line, end='', flush=True)
            if 'Unhandled Exception:' in line:
                raise RuntimeError('Unhandled Dart failure; an empty runner success is not acceptance')
            if 'BILGA_RESTART_VERIFIED:154' in line:
                restart_verified = True
            match = re.search(r'BILGA_SAF_READY:(CANCEL|PDF|EPUB|TXT|Invalid)', line)
            if match:
                if args.restart:
                    raise RuntimeError('Restart checkpoint missing; refusing to repeat the picker and call it recovery')
                seen.append(match.group(1))
                choose(match.group(1))
        code = process.wait()
        if code:
            raise SystemExit(code)
        if args.restart and not restart_verified:
            raise RuntimeError('Real restart assertions did not execute')
        if not args.restart and seen != ['CANCEL','PDF','EPUB','TXT','PDF','Invalid']:
            raise RuntimeError('Actual SAF acceptance sequence did not execute completely')
    finally:
        if process.poll() is None:
            os.killpg(process.pid, signal.SIGTERM)
            process.wait(timeout=30)


if __name__ == '__main__':
    main()
