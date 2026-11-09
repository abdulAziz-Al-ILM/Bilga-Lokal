# Test report — current development branch

Environment: Ubuntu/Linux x64; client date 2026-11-09, Asia/Tashkent. Initial computer had no flutter/dart/Java/Android SDK on PATH. Official Flutter 3.47.8 (737ba8f885dc774b53b442759999a312c9461e4e) is being installed in /tmp for validation. SDK caches are excluded from Git.

Executed so far:

| Command | Result | Scope |
| --- | --- | --- |
| `python3 tool/check_catalogs.py` | PASS, 43 × 308 strings | Structural coverage only; no native-speaker review |
| `python3 tool/check_schema.py` | PASS, Notes v1–v10 / Tasks v1–v5 | Historical static SQL extraction; does not exercise helper-based WIP/search migrations. Runtime tests are required. |
| Relative production import audit | Missing backup imports recovered | Optional source templates are not production package imports |

Pending actual execution:

- `flutter pub get`, `dart format`, `flutter analyze`
- `flutter test test/search_planner_test.dart` plus read-only UI and upgraded-schema tests
- Full `flutter test --concurrency=2`
- Android native instrumentation / actual notification delivery
- `flutter build apk --debug`, release APK and AAB (existing release keys required)

No new Android artifact, real-device test, live purchase, refund, restore-account, Drive or signing compatibility success is claimed. Historical WIP CI results are not current-branch results.
