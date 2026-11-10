#!/usr/bin/env bash
# A prebuilt, verified binary is mandatory: no implicit production-app build.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
if [[ $# != 2 ]]; then
  echo 'Usage: bash tool/test_tablet_review.sh <device-serial> <review-test.apk>' >&2
  exit 1
fi
bilga_device="$1"
bilga_apk="$2"
export ANDROID_HOME="${ANDROID_HOME:-$PWD/.bilga-tools/android}"
export JAVA_HOME="${JAVA_HOME:-$(printf '%s\n' "$PWD"/.bilga-tools/java/jdk-*)}"
export PATH="$JAVA_HOME/bin:$PATH"
export PUB_CACHE="${PUB_CACHE:-$PWD/.bilga-tools/pub-cache}"
export DART_SUPPRESS_ANALYTICS=true
mkdir -p build/review/evidence
"$ANDROID_HOME/cmdline-tools/latest/bin/apkanalyzer" manifest print "$bilga_apk" > build/review/test-manifest.xml
python3 tool/verify_review_manifest.py build/review/test-manifest.xml
"$ANDROID_HOME/build-tools/36.0.0/apksigner" verify "$bilga_apk"
"$JAVA_HOME/bin/keytool" -exportcert -keystore .bilga-tools/review-signing/debug.keystore -alias androiddebugkey -storepass android -file build/review/review-cert.der
python3 - "$bilga_apk" <<'PY'
import hashlib, sys
from pathlib import Path
from tool.apk_signer_fingerprint import fingerprints
expected = hashlib.sha256(Path('build/review/review-cert.der').read_bytes()).hexdigest()
if fingerprints(sys.argv[1]) != [expected]:
    raise SystemExit('APK must use this checkout\'s isolated review signing key')
PY
"$ANDROID_HOME/platform-tools/adb" -s "$bilga_device" get-state
python3 tool/check_tablet_review_install.py "$bilga_device" "$bilga_apk"
# Flutter reads the actual package from this checked APK. The target specifies
# test identity for the driver; --use-application-binary prevents rebuilding.
.bilga-tools/flutter/bin/flutter drive --no-pub -d "$bilga_device" \
  --keep-app-running \
  --target integration_test/tablet_review_test.dart \
  --driver test_driver/tablet_review_driver.dart \
  --use-application-binary "$bilga_apk"
