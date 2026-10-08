#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Run without Studio/emulator; use the tablet for the actual device test.
python3 tool/check_google_config.py
flutter pub get
bilga_sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}}"
bilga_java="${JAVA_HOME:-}"
if [[ -x "$HOME/Downloads/android-studio/jbr/bin/java" ]]; then
  bilga_java="$HOME/Downloads/android-studio/jbr"
fi
if [[ -z "$bilga_java" || ! -x "$bilga_java/bin/java" ]]; then
  echo 'JAVA_HOME ni JDK o‘rnatilgan papkaga yo‘naltiring.' >&2
  exit 1
fi
bilga_defines="$(python3 - <<'PY'
import base64,json,pathlib
v=json.loads(pathlib.Path('google_config.json').read_text())
v['BILGA_AGENT_PREVIEW']='true'
print(','.join(base64.b64encode(f'{k}={x}'.encode()).decode() for k,x in v.items()))
PY
)"
read -r bilga_name bilga_code < <(python3 -c "import pathlib,re; m=re.search(r'^version:\s*([^+\s]+)\+(\d+)',pathlib.Path('pubspec.yaml').read_text(),re.M); assert m; print(m[1],m[2])")
bilga_args=("-Dorg.gradle.java.home=$bilga_java" '-Dorg.gradle.jvmargs=-Xmx2G -XX:MaxMetaspaceSize=768m -XX:ReservedCodeCacheSize=256m -Dfile.encoding=UTF-8' --max-workers=1 --no-parallel --console=plain)
if [[ -x "$bilga_sdk/build-tools/36.0.0/aapt2" ]]; then
  bilga_args+=("-Pandroid.aapt2FromMavenOverride=$bilga_sdk/build-tools/36.0.0/aapt2")
fi
# All three supported Android CPU architectures; this is not emulator-only.
(cd android && JAVA_HOME="$bilga_java" ./gradlew :app:assembleDebug "${bilga_args[@]}" "-Pbilga.versionName=$bilga_name" "-Pbilga.versionCode=$bilga_code" -Ptarget-platform=android-arm,android-arm64,android-x64 "-Pdart-defines=$bilga_defines")
printf '\nAPK: %s/build/app/outputs/apk/debug/app-debug.apk\n' "$PWD"
printf 'Sinov nusxasi: pullik imkoniyatlar ochiq. Play Console ga yuklamang.\n'
