#!/usr/bin/env bash
# Compile the isolated instrumentation companion; never installs or clears apps.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
if [[ "${BILGA_NATIVE_REVIEW_LOCKED:-}" != 1 ]]; then
  exec flock --close -n .bilga-tools/build.lock env BILGA_NATIVE_REVIEW_LOCKED=1 bash "$PWD/tool/build_native_review_tests.sh"
fi
export JAVA_HOME="$PWD/.bilga-tools/java/jdk-21.0.13+9"
export ANDROID_HOME="$PWD/.bilga-tools/android"
export PATH="$JAVA_HOME/bin:$PATH"
export PUB_CACHE="$PWD/.bilga-tools/pub-cache"
export DART_SUPPRESS_ANALYTICS=true
export GRADLE_OPTS="-Dorg.gradle.daemon=false"
test -f .bilga-tools/review-signing/debug.keystore
if [[ "${BILGA_REVIEW_PROFILE:-}" == 1 ]]; then
  exec ./android/gradlew -p android :app:assembleProfileAndroidTest \
    -PbilgaReview=true -PbilgaReviewProfileTest=true
fi
exec ./android/gradlew -p android :app:assembleDebugAndroidTest -PbilgaReview=true
