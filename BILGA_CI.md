# WIP Android CI

## Initial validation — 2026-10-22

Workflow source was committed/pushed as
`60f48bd44447c5e87af53ccac872bfc9ab86038f`; the private remote branch and commit
were verified. YAML structure, every inline Bash script's syntax, manual/private/
WIP guards, read-only permissions, action SHA pins and the three-file artifact
allowlist passed static checks. `git fsck --full` exited successfully (existing
dangling objects were preserved). No local Flutter/Java build or test was run.

One manual dispatch attempt returned:

```text
HTTP 404: workflow wip-android-debug.yml not found on the default branch
```

No CI run, test result or APK artifact existed from that attempt. `main` and the
default-branch setting were left unchanged then. Owner approval was requested to
resolve GitHub's registration requirement; the registration below supersedes
that blocker. Static checks are not a replacement for an actual runner execution.

## Owner-authorized registration — 2026-10-22

The owner explicitly approved adding **only**
`.github/workflows/wip-android-debug.yml` to `main`, without changing the default
branch or merging any WIP application changes. Registration commit
`8871b3ac007ab05402949b3eacd4327340c6913c` has the existing main commit
`ae7b27c1e4f7ff15f386361ecec109688f7b35e6` as its sole parent and adds exactly that
one file. GitHub confirmed its file list and SHA. The workflow is byte-identical
to WIP's copy. Main's application files/history and WIP's working tree were
preserved. The private repository's default branch remains `main`.

Manual/private/exact-WIP guards, read-only permissions, pinned action SHAs, Bash
syntax and credential patterns were checked before registration. A dispatch on
`main` cannot run the job. The actual manual dispatch selected WIP commit
`f145cceb7338ea93ff95324f793717dc56565683`:
<https://github.com/abdulAziz-Al-ILM/Bilga-Lokal/actions/runs/39811651782>.

The run's dependency resolution, analyzer and Flutter-test steps have succeeded.
APK build is still in progress at this checkpoint; no APK/artifact success is
claimed. Final counts and build outcome must be read from the completed run log.

## Workflow

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
The repository's default branch remains `main`. The owner-authorized registration
adds only the workflow file there; application changes remain on WIP. Further
changes to `main` or repository settings require explicit authorization. Keep the
WIP-only job guard in both copies. A WIP workflow correction does not authorize
merging other WIP changes into `main`.

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
