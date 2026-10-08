# Validation — 2026-10-01

Source package, not a release-certified application.

Executed here:
- Standalone Dart 3.13.4 static analysis against Flutter 3.44.0 framework source and resolved package APIs: no issues found. Runtime Flutter tool was not executed.
- 30 pure Dart finance and streaming AES-GCM checks: exact money units; localized digits; precision rejection; date validation; bounded sums; debt direction/overpayment; expense-only reports; CSV formula escaping; multi-frame Unicode round trip; wrong key; corruption; truncation; trailing bytes; authenticated empty stream.
- 14 existing pure Dart Start command / habit date rules checks.
- SQLite schema migration checks using SQL extracted from the actual Dart source: Notes versions 1–9 and To-do versions 1–5 to current, preserving representative old rows.
- 43 translation catalogs with equal 225 keys. This checks coverage, not translation quality; many new long messages intentionally fall back to English.

Installer validation passed: package hash checks, read-only preflight, refusal of changed user files, damaged package files and symlinks, idempotent repeated install, preserved pubspec.lock/unrelated files, and complete backup of replaced code. Both original source and updated 1.2 + test-fix baseline passed the installer test harness.

NOT executed here:
- Flutter widget/unit test suite on a running Flutter engine.
- Android Gradle/NDK/C++ compilation or release AAB generation.
- Android SQLCipher migration, Keystore, device file provider, share intents, media playback, local model inference, speech, or Google Play purchases on hardware.
- Google OAuth/Drive success or real payment verification.

The included `integration_test/private_device_test.dart` is a real-device migration check to run with Flutter. `BILGA_1_3_UZ.md` contains the remaining steps. Previous workspace results cannot substitute for tests of this recovered source tree. No claims of security certification, guaranteed device performance, or maintenance-free operation are made.
