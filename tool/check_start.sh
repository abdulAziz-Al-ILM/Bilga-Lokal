#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
flutter pub get
python3 tool/check_schema.py
python3 tool/check_catalogs.py
dart tool/check_agent_rules.dart
dart tool/check_private_rules.dart
dart tool/check_habit_plan.dart
# Analyze Bilga and the plugin runtime; the vendor example is a separate app.
flutter analyze --no-fatal-infos --no-fatal-warnings lib test integration_test tool
flutter test --concurrency=1
