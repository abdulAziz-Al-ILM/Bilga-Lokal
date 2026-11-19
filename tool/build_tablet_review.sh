#!/usr/bin/env bash
# Build only: installation is a separate, package/signature-checked action.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
mkdir -p .bilga-tools
# Keep the lock in flock's parent, never in ADB/Gradle descendants.
if [[ "${BILGA_REVIEW_LOCKED:-}" != 1 ]]; then
  exec flock --close -n .bilga-tools/build.lock env BILGA_REVIEW_LOCKED=1 bash "$PWD/tool/build_tablet_review.sh" "$@"
fi
bilga_flutter="${BILGA_FLUTTER:-$PWD/.bilga-tools/flutter/bin/flutter}"
bilga_sdk="${ANDROID_HOME:-$PWD/.bilga-tools/android}"
bilga_java="${JAVA_HOME:-$(printf '%s\n' "$PWD"/.bilga-tools/java/jdk-*)}"
export ANDROID_HOME="$bilga_sdk"
export JAVA_HOME="$bilga_java"
export PATH="$bilga_java/bin:$PATH"
export PUB_CACHE="${PUB_CACHE:-$PWD/.bilga-tools/pub-cache}"
export DART_SUPPRESS_ANALYTICS=true
export GRADLE_OPTS="${GRADLE_OPTS:-} -Dorg.gradle.daemon=false"
export ORG_GRADLE_PROJECT_bilgaReview=true
test -f .bilga-tools/review-signing/debug.keystore || {
  echo 'Missing isolated development keystore. Do not replace any production signing key.' >&2
  exit 1
}
bilga_mode=debug
if [[ "${BILGA_REVIEW_PROFILE:-}" == 1 ]]; then
  bilga_mode=profile
fi
"$bilga_flutter" build apk "--$bilga_mode" --no-pub "$@"
mkdir -p build/review
bilga_output="build/review/bilga-review-$bilga_mode.apk"
cp "build/app/outputs/flutter-apk/app-$bilga_mode.apk" "$bilga_output"
"$bilga_sdk/cmdline-tools/latest/bin/apkanalyzer" manifest print "$bilga_output" > build/review/manifest.xml
python3 tool/verify_review_manifest.py build/review/manifest.xml
"$bilga_sdk/build-tools/36.0.0/apksigner" verify --verbose "$bilga_output"
sha256sum "$bilga_output"
