# Reproducible build and acceptance workflow

This branch is a development checkpoint, not a release candidate. Finish FEATURE_MATRIX.md before production acceptance.

## Toolchain

Use official Flutter **3.47.8**, Git revision **737ba8f885dc774b53b442759999a312c9461e4e**, with bundled Dart **3.13.7**; Java **21**; Android platform **36**, build-tools **36.0.0**, NDK **28.2.13676358**. The project retains its checked-in Gradle wrapper and plugin versions. The CI workflow pins checkout, Java setup and artifact actions by commit.

```sh
flutter --version
flutter doctor -v
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test
python3 tool/check_catalogs.py
python3 tool/test_play_manifest.py
flutter analyze --no-pub
flutter test --no-pub --concurrency=2 --reporter expanded
flutter build apk --debug --no-pub
bash tool/verify_android_apk.sh
"$ANDROID_HOME/cmdline-tools/latest/bin/apkanalyzer" manifest print build/app/outputs/flutter-apk/app-debug.apk > /tmp/bilga-manifest.xml
python3 tool/verify_play_manifest.py /tmp/bilga-manifest.xml
```

If a sandbox blocks the analyzer's normal cache or loopback test socket, grant those environment capabilities rather than treating the resulting harness failure as a passing test. Do not change HOME or import private SDK/signing material into CI.

Expected debug artifact: `build/app/outputs/flutter-apk/app-debug.apk`. CI uses a disposable debug signer; this does not establish upgrade signing compatibility with an installed copy. Never uninstall an existing app or clear its data to bypass an incompatible signature.

## Purchase/Drive configuration

Copy `billing_config.example.json` to ignored `billing_config.json`. Its values are **public** verification configuration, not private signing/service-account credentials. The lifetime product ID is fixed in source as `bilga_lifetime_unlock`; configure that one non-consumable product in Console. The secure-verifier backend still needs implementation and a real Google Play verification integration; setting an arbitrary URL does not make purchases valid.

The license key is Google's RSA public licensing key; the verifier key is an Ed25519 public verification key. Private signing seeds and Play service-account credentials belong outside the APK and repository. No service deployment or recurring expenditure is authorized by these instructions.

Google Drive is optional. Existing GOOGLE_SETUP.md explains OAuth/Drive setup; verify its instructions against the final signing identity and current APIs. A public Web OAuth client ID can be passed as `BILGA_GOOGLE_WEB_CLIENT_ID`. Current media-bearing Drive backup remains incomplete and must not be advertised as working.

## Release artifacts

Use the existing authorized signing key through ignored `android/key.properties`. No replacement signing key and no debug-key fallback are permitted. Once feature, security, purchase and device acceptance are complete:

```sh
flutter build apk --release --no-pub --dart-define-from-file=billing_config.json
flutter build appbundle --release --no-pub --dart-define-from-file=billing_config.json
```

Expected release outputs: `build/app/outputs/flutter-apk/app-release.apk` and `build/app/outputs/bundle/release/app-release.aab`. Record exact commit, toolchain, configuration identifiers (not secrets), artifact SHA-256 and signer certificates. Verify the release APK manifest as well. These commands have not produced signed release artifacts in this checkpoint.

## Required acceptance environments

- An isolated legacy-database fixture for every supported schema and a separate upgraded current dataset; compare records, note history, tasks, habits, relationships and attachment digests. Never experiment destructively on a user's installed data.
- Android devices covering the supported minimum/current API levels, ordinary RAM/storage and restrictive battery behavior. Exercise actual reminder permissions, notifications/actions, reboot/update/timezone recovery and app lock/background transitions.
- Licensed Play test accounts on the actual signed testing-track build: pending/cancelled/completed payment, acknowledgement retry, restore after reinstall on an isolated test device, refunds/revocations and offline verified access.
- Clean second-device encrypted backup/restore with realistic generated text/media; wrong passwords, tampering, interruption, rollback and duplicate imports. Verify Drive separately when media support is finished.
- Large-font, RTL, small-phone/tablet and screen-reader journeys through every reachable control. CI host widget tests supplement these, not replace them.

Keep the exact evidence and failures in TEST_REPORT.md and RELEASE_READINESS.md. Publishing, final country prices and changes to signing identity require separate owner approval.
