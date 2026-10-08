#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
if [[ ! -f android/key.properties ]]; then
  echo 'Avval CHIQARISH.md dagi imzolash kalitini sozlang.' >&2
  exit 1
fi
python3 tool/check_google_config.py
python3 tool/check_start_billing.py
bash tool/check_start.sh
bundle_version="$(python3 -c "import re; print(re.search(r'^version:\\s*(\\S+)', open('pubspec.yaml').read(), re.M).group(1).replace('+', '-'))")"
bilga_jdk="${JAVA_HOME:-}"
if [[ -x "$HOME/Downloads/android-studio/jbr/bin/java" ]]; then bilga_jdk="$HOME/Downloads/android-studio/jbr"; fi
bilga_opts='-Dorg.gradle.jvmargs="-Xmx2G -XX:MaxMetaspaceSize=768m -XX:ReservedCodeCacheSize=256m -Dfile.encoding=UTF-8" -Dorg.gradle.workers.max=1 -Dorg.gradle.parallel=false'
if [[ -n "$bilga_jdk" ]]; then bilga_opts="$bilga_opts -Dorg.gradle.java.home=$bilga_jdk"; fi
bilga_sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}}"
bilga_env=("GRADLE_OPTS=$bilga_opts")
if [[ -x "$bilga_sdk/build-tools/36.0.0/aapt2" ]]; then
  bilga_env+=("ORG_GRADLE_PROJECT_android.aapt2FromMavenOverride=$bilga_sdk/build-tools/36.0.0/aapt2")
fi
env "${bilga_env[@]}" flutter build appbundle --release --obfuscate --split-debug-info="release-symbols/$bundle_version" --dart-define-from-file=google_config.json --dart-define-from-file=billing_config.json
printf '\nAAB: build/app/outputs/bundle/release/app-release.aab\n'
printf 'Play Google ulanishi: GOOGLE_PLAY_TUZATISH.md ni bajaring.\n'
printf 'Bu buyruq Play Console ga hech narsa yuklamadi. Qurilmadagi sinovlar ham kerak.\n'
