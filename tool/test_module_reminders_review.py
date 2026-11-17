"""Prove a real Habit or Finance alarm fires after only the isolated Review process exits."""
import argparse
import json
import hashlib
import os
from pathlib import Path
import re
import subprocess
import tempfile
import time
from apk_signer_fingerprint import fingerprints
from test_native_review import verify_manifest
from verify_review_manifest import verify_review

ROOT = Path(__file__).resolve().parents[1]
REVIEW = 'com.ilmmizan.bilga.review'

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('serial')
    parser.add_argument('test_apk', type=Path)
    parser.add_argument('--app-apk', type=Path, required=True, help='Exact already-installed ordinary Review APK')
    parser.add_argument('--kind', choices=['habit','finance'], default='habit')
    parser.add_argument('--evidence', type=Path, default=ROOT / 'build/review/evidence/module-reminder-delivery.json')
    args = parser.parse_args()
    env = os.environ.copy()
    jdk, = (ROOT / '.bilga-tools/java').glob('jdk-*')
    env.setdefault('JAVA_HOME', str(jdk))
    env['PATH'] = env['JAVA_HOME'] + '/bin:' + env.get('PATH', '')
    sdk = ROOT / '.bilga-tools/android'
    manifest = subprocess.check_output([str(sdk / 'cmdline-tools/latest/bin/apkanalyzer'), 'manifest', 'print', str(args.test_apk)], text=True, env=env)
    verify_manifest(manifest)  # Must precede every device action.
    app_manifest = subprocess.check_output([str(sdk / 'cmdline-tools/latest/bin/apkanalyzer'), 'manifest', 'print', str(args.app_apk)], text=True, env=env)
    verify_review(app_manifest)
    subprocess.run([str(sdk / 'build-tools/36.0.0/apksigner'), 'verify', str(args.app_apk)], check=True, env=env)
    expected_app_digest = hashlib.sha256(args.app_apk.read_bytes()).hexdigest()

    subprocess.run([str(sdk / 'build-tools/36.0.0/apksigner'), 'verify', str(args.test_apk)], check=True, env=env)
    proposed = fingerprints(args.test_apk)
    if fingerprints(args.app_apk) != proposed:
        raise SystemExit('Review app and test signer must match')
    adb = [str(sdk / 'platform-tools/adb'), '-s', args.serial]
    with tempfile.TemporaryDirectory(prefix='bilga-module-review-signer-') as temp:
        for package in (REVIEW, REVIEW + '.test'):
            query = subprocess.run(adb + ['shell', 'pm', 'path', package], capture_output=True, text=True)
            lines = query.stdout.strip().splitlines()
            if not lines and package == REVIEW + '.test' and query.returncode in (0, 1):
                continue
            if query.returncode or len(lines) != 1 or not lines[0].startswith('package:/data/app/'):
                raise SystemExit('Expected an installed isolated Review app; refusing any install')
            old = Path(temp) / (package + '.apk')
            subprocess.run(adb + ['pull', lines[0][8:], str(old)], check=True, stdout=subprocess.DEVNULL)
            if package == REVIEW and hashlib.sha256(old.read_bytes()).hexdigest() != expected_app_digest:
                raise SystemExit('Installed Review app differs from declared source APK; no device mutation performed')
            if fingerprints(old) != proposed:
                raise SystemExit('Review signer mismatch; preserve existing app/test data')
    subprocess.run(adb + ['install', '-r', '-t', str(args.test_apk)], check=True)
    fixture = 'bilga-review-module-' + str(time.time_ns())
    runner = REVIEW + '.test/com.ilmmizan.bilga.NotesWidgetChecks'
    def run(operation):
        result = subprocess.check_output(adb + ['shell', 'am', 'instrument', '-w', '-r', '-e', 'moduleOperation', operation, '-e', 'moduleId', fixture, '-e', 'moduleKind', args.kind, runner], text=True, timeout=60)
        if 'INSTRUMENTATION_CODE: -1' not in result or 'failed:' in result.lower():
            raise RuntimeError('Guarded module instrumentation failed: ' + result[-1000:])
        return result
    def pid():
        return subprocess.run(adb + ['shell', 'pidof', REVIEW], capture_output=True, text=True).stdout.strip()
    prepared = False
    try:
        prepared = True
        result = run('prepare')
        match = re.search(r'MODULE_PREPARED:(\d+)', result)
        if not match:
            raise RuntimeError('No real scheduled time returned')
        at = int(match[1])
        subprocess.run(adb + ['shell', 'input', 'keyevent', '3'], check=True)
        before = pid()
        if before:
            # am kill is deliberately distinct from force-stop: Android cancels
            # alarms for force-stopped packages. Never target production here.
            subprocess.run(adb + ['shell', 'am', 'kill', REVIEW], check=True)
        stopped = pid()
        kill_deadline = time.monotonic() + 5
        while stopped and time.monotonic() < kill_deadline:
            time.sleep(.1)
            stopped = pid()
        if stopped:
            raise RuntimeError('Review process is still running; process-death acceptance not proved')
        print('Review process absent; real ' + args.kind + ' alarm scheduled:', at, flush=True)
        # Do not launch instrumentation before the deadline: the receiver must
        # be able to start its own process without Flutter or an open Activity.
        # Alarm timestamps belong to the tablet clock, not the host clock.
        device_now = int(subprocess.check_output(adb + ['shell', 'date', '+%s'], text=True).strip()) * 1000
        if device_now >= at:
            raise RuntimeError('Alarm deadline elapsed before process-death observation')
        wait_until = time.monotonic() + (at - device_now) / 1000 + 3
        while time.monotonic() < wait_until:
            time.sleep(min(2, max(.05, wait_until - time.monotonic())))
        deadline = time.monotonic() + 40
        delivered = False
        while time.monotonic() < deadline:
            if 'MODULE_NOTIFICATION:true' in run('exists'):
                delivered = True; break
            time.sleep(2)
        if not delivered:
            raise RuntimeError('Native ' + args.kind + ' notification was not observed')
        print('PASS real ' + args.kind + ' notification delivered without a running Review process', flush=True)
    finally:
        if prepared:
            restored = run('restore')
            if 'MODULE_ORIGINAL_RESTORED' not in restored:
                raise RuntimeError('Original encrypted reminder mirror was not restored')
            print('Original encrypted reminder mirror restored; synthetic notification removed', flush=True)
    args.evidence.parent.mkdir(parents=True, exist_ok=True)
    args.evidence.write_text(json.dumps({'device': args.serial, 'package': REVIEW, 'result': 'PASS', 'actual_native_calendar_alarm': True, 'kind':args.kind, 'app_sha256':expected_app_digest, 'process_before_kill': before, 'process_after_kill': stopped, 'force_stop_used': False, 'flutter_activity_required_for_delivery': False, 'production_touched': False, 'original_mirror_restored': True, 'scheduled_at_millis': at, 'fixture': fixture}, indent=2) + '\n')

if __name__ == '__main__':
    main()
