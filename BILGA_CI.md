# WIP Android CI

Local Dart/Java SIGSEGV failures are not retried by this workflow. All compilation
and Flutter tests run on a fresh GitHub-hosted Ubuntu 24.04 runner.

`.github/workflows/wip-android-debug.yml` accepts only `workflow_dispatch`.
Its job requires the private `abdulAziz-Al-ILM/Bilga-Lokal` repository and the
exact `wip/todo-widget-recovery` branch. There are no push, PR, schedule or release
triggers, deployment steps, write permissions or automatic retry loops.

## Environment and checks

- Flutter 3.47.1 / Dart 3.13.1, official framework revision
  `6655482ec06e547f90abf8ae7590466f4415978d`, matching the existing SDK requirement.
  The SDK is fetched from the official Flutter Git repository; bootstrap downloads
  use Flutter's own tooling. No local SDK/cache is uploaded.
- Temurin Java 21; existing Java/Kotlin source target 17 is unchanged.
- Existing Gradle 9.3.1, AGP 9.1.0 and Kotlin 2.4.0 remain unchanged.
  Android platforms 34 (existing plugins) / 36 (Flutter), build-tools 36.0.0 and
  NDK 28.2.13676358 match `ANDROID_BUILD_VALIDATION.md` and FlutterExtension.
- `flutter pub get --enforce-lockfile`, `flutter analyze --no-pub`, all default
  `test/` Flutter tests, and `flutter build apk --debug --no-pub` run once each.
  Tests and APK build still run after an analyzer failure; any failed check keeps
  the overall job failed. There is no test deletion, skip addition or dependency
  upgrade. Device/instrumentation tests are not part of this workflow.
- Existing `tool/verify_android_apk.sh` checks ZIP CRC, APK signature and SHA-256.
  Only a successfully verified APK, `SHA256SUMS` and the source SHA are uploaded.
  An APK artifact alone does not mean every check passed: read the run summary.

## Privacy and signing

No repository secrets, production signing keys or custom tokens are needed.
Checkout uses GitHub's automatic read-only repository token without persisting
credentials. Official GitHub actions are pinned by full commit SHA. No environment
dump, Gradle debug/scan, cache upload or broad workspace artifact upload is used.
No databases, recordings, backups, local models, keystores or SDKs are uploaded.
The runner creates its own disposable debug key. Its APK may have a different
certificate from the tablet's existing APK: **do not uninstall the tablet app or
clear its data to install this artifact**. Existing APKs and devices are untouched.

Artifacts expire after 7 days and require access to this private repository.
GitHub Actions private-repository minutes/storage are subject to account limits;
no billing settings or paid runner configuration are changed.

## Manual operation and GitHub's default-branch requirement

GitHub documents that a new `workflow_dispatch` workflow must exist on the default
branch before it can be manually triggered:
<https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow>.
The repository's default branch is currently `main`. This change adds the workflow
only to WIP and does not change `main`, repository visibility or the default branch.
If GitHub refuses dispatch because the workflow is not registered, owner approval
is required before placing a copy on `main` or changing repository settings. The
WIP-only job guard must remain in place even if registration is later approved.

Once GitHub accepts the workflow, run:

```bash
gh workflow run wip-android-debug.yml \
  --repo abdulAziz-Al-ILM/Bilga-Lokal --ref wip/todo-widget-recovery
gh run list --repo abdulAziz-Al-ILM/Bilga-Lokal \
  --workflow wip-android-debug.yml --branch wip/todo-widget-recovery --limit 5
gh run view RUN_ID --repo abdulAziz-Al-ILM/Bilga-Lokal
gh run download RUN_ID --repo abdulAziz-Al-ILM/Bilga-Lokal \
  --name bilga-wip-debug-SOURCE_SHA --dir /path/to/empty/download-directory
```

Do not automatically rerun a failed run. Inspect its failed step/log once, record
the cause, and make a targeted correction if justified. A blocked dispatch or an
unexecuted check is not a passing build.
