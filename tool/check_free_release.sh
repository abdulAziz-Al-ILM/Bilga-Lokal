#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
if ! command -v flutter >/dev/null 2>&1; then
  echo 'Flutter terminal PATH ichida topilmadi. Flutter ishlaydigan terminalda ishga tushiring.' >&2
  exit 1
fi
flutter --version
flutter pub get
python3 tool/check_schema.py
python3 tool/check_catalogs.py
dart tool/check_todo_rules.dart
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
printf '\nKod va widget tekshiruvlari tugadi. Qurilmadagi sinov uchun:\n'
printf 'flutter test integration_test/data_safety_test.dart -d DEVICE_ID\n'
printf 'Keyin odatiy ilovani qayta ishga tushiring: flutter run\n'
