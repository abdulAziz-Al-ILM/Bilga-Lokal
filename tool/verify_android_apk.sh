#!/usr/bin/env bash
# Read-only validation: Gradle success alone does not detect corrupt ZIP data.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/android_env.sh"
bilga_apk="${1:-build/app/outputs/flutter-apk/app-debug.apk}"
unzip -tq "$bilga_apk"
bilga_apksigner="$(printf '%s\n' "$ANDROID_HOME"/build-tools/*/apksigner | sort -V | tail -n 1)"
if [[ ! -x "$bilga_apksigner" ]]; then
  echo "Android SDK build-tools/apksigner topilmadi: $ANDROID_HOME" >&2
  exit 1
fi
"$bilga_apksigner" verify --verbose --print-certs "$bilga_apk"
sha256sum "$bilga_apk"
