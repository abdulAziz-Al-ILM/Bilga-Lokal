#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source tool/android_env.sh
# No unlimited preview. Normal debug follows the genuine 40-day trial policy.
# Test scenarios can only restrict access/simulate outages, never grant ownership.
bilga_test_args=(build apk --debug)
if [[ -f google_config.json ]]; then
  bilga_test_args+=(--dart-define-from-file=google_config.json)
fi
case "${BILGA_TRIAL_TEST:-normal}" in
  normal) ;;
  expired|billing_unavailable)
    bilga_test_args+=("--dart-define=BILGA_TRIAL_TEST=$BILGA_TRIAL_TEST") ;;
  *) echo 'BILGA_TRIAL_TEST: normal, expired yoki billing_unavailable bo‘lishi kerak.' >&2; exit 1 ;;
esac
flutter "${bilga_test_args[@]}"
bash tool/verify_android_apk.sh
printf '\nDebug APK: build/app/outputs/flutter-apk/app-debug.apk\n'
printf '40 kunlik haqiqiy trial. Test rejimi pullik huquq bermaydi.\n'
