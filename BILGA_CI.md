# WIP Android CI

## Tablet-compatible signing without uploading a key — checkpoint

Fresh original runner APK passed full independent hashes and ZIP/signature checks
locally AND its tablet staging SHA matches. The existing matching local debug key
was then used read-only by apksigner to sign **a separate copy**, v2 only. No key
copy/export/base64/upload/secret was made. No Flutter/Gradle rebuild was run.
Local candidate signer matches installed38ecfe02…663bd6d; all779 uncompressed ZIP
entries have identical SHA-256 to the known CI-built original. Candidate size
293937033, SHA-256 `9a01ddd6a8f77df800627b2c4214ecc3cdd3e87b3147dc1715b9be506e7a36d8`.
This is a new signed file; the original3c34795f… APK remains unchanged.

Manual `verify_candidate_release` mode skips the entire Flutter build/test job.
A separate hosted verifier downloads the fixed known CI original and the private
candidate draft, checks the successful source run, both server/full Python/native
hashes, ZIP CRC/signature, expected installed certificate and each payload entry.
It uploads only final checksums/public verification metadata. The candidate must
target original app source5ee550e and remain an unpublished private draft.
The recovery verifier deliberately accepts only this exact original/source/draft
name; future source upgrades require reviewing those pins. It executes no app
build code and never reads signing keys. Eight small local safety tests PASS;
independent runner result and final tablet staging are pending at this checkpoint.

This local-sign/remote-verify path replaces the need for a GitHub signing secret
for this delivery. The optional secret design below remains disabled and requires
separate explicit approval if ever used.

## Fresh private draft delivery PASS — 2026-10-23

Run [39926382854](https://github.com/abdulAziz-Al-ILM/Bilga-Lokal/actions/runs/39926382854)
tested `5ee550e977e905c55e053f2c4fb288f515e33fc1` and completed SUCCESS.
Locked pub get, analyze (no issues,10.9s), all224 Flutter tests, debug APK,
six delivery safety tests, independent Python/unzip CRC, apksigner and independent
Python/native SHA verification passed. No local Flutter/Gradle build/test ran.

[Private UNPUBLISHED draft](https://github.com/abdulAziz-Al-ILM/Bilga-Lokal/releases/tag/untagged-d98aa71e80dbcf0d0311):
release421631112, requested draft tag `wip-debug-39926382854-1`, APK asset668549689,
293931059 bytes. API confirms private repository, draft=true, prerelease=true,
published_at=null and exact WIP target SHA. Four explicit assets uploaded; all
GitHub server sizes/SHA-256 digests match the runner. Actions artifact upload was
intentionally skipped to avoid the diagnosed quota. Nothing was published.

APK SHA-256: `3c34795f6a36af877a3e5ffe8365e15991d5731b16cc7ed0815d78d202fb0f5d`.
Signer SHA-256: `97f2e21a6e5dc77f74ddfe316153be1cca6e8f916de397cd074453bb0fe14e78`.
This differs from the installed debug signer
`38ecfe0234e465924812ba3ee84ef838557a1d03d53713bd7a6d76478663bd6d`.
No update is authorized by a valid ZIP/hash alone. Local/tablet delivery checks
will be recorded below; no signing secret has been uploaded.

## Private draft delivery design, 2026-10-23

The owner requested a private Release-asset alternative after artifact quota
failure. Manual input `private_draft_release=true` skips Actions artifact storage
and uploads exactly APK, SHA256SUMS, SOURCE.txt and BUILD_METADATA.json to a new
**unpublished draft/prerelease** in this private repository. It never publishes,
replaces an asset, changes visibility, modifies main or pushes a Git tag. The
draft targets the exact dispatched WIP SHA and is not marked latest. Drafts do
not expire automatically; owner cleanup is a later explicit operation.

`contents:write` is the minimum repository token permission for Release uploads.
Only the guarded CI job receives this permission; all unspecified permissions
are disabled. Checkout still persists no credentials, and GH_TOKEN is passed
only to the delivery step. This permission can also write repository contents:
only trusted, inspected WIP code may be dispatched. No PAT/custom token or signing
secret is used. Global default remains contents:read. Repository privacy is
rechecked through the API before creating a draft and after uploading it.

The runner verifies original/copy Python and native SHA-256 agreement, unchanged
file stat, independent Python/unzip CRC, apksigner verification and public signer
SHA-256. Upload completion, exact asset allowlist, sizes and GitHub server SHA-256
digests must match every local file. Any mismatch fails closed; no retry, deletion
or byte repair. Six small Python safety tests cover hash disagreement, mutation,
public/wrong repositories and forbidden execution contexts. Actual runner evidence
is recorded above; end-to-end tablet evidence must be checked separately.

```bash
gh workflow run wip-android-debug.yml \
  --repo abdulAziz-Al-ILM/Bilga-Lokal --ref wip/todo-widget-recovery \
  -f private_draft_release=true
```

Never reuse the previously corrupted artifact. Download the fresh raw APK to a
new ignored directory, close/fsync the writer, and compare runner/server SHA,
Python hashlib and sha256sum with stat checks. Any disagreement means STOP, no
signing/install. After local agreement, a copy to a new `/data/local/tmp` directory
may be checked with the tablet's sha256sum without modifying the installed app.
The installed signer must separately match before any `install -r`.

Signing remains the runner's disposable debug key. Uploading the matching local
debug key as an Actions secret requires NEW explicit owner approval. Proposed
procedure: dedicated manual private-WIP signing step/job, locally encrypted secret
upload through `gh secret set` stdin (base64 is only transport encoding), never
CLI arguments/logs/repo/artifacts. Decode to a new runner-temp mode0600 file after
build, check public fingerprint against `38ecfe0234e465924812ba3ee84ef838557a1d03d53713bd7a6d76478663bd6d`,
sign a separate APK, verify and regenerate all SHA metadata, clean up only the
created temporary key. A malicious future workflow with secret access could
exfiltrate the key and impersonate this debug app, so approval must acknowledge
moving signing trust to GitHub/authorized workflow maintainers. No secret has been
created and that signing path is not enabled.

API documentation: [Release creation](https://docs.github.com/en/rest/releases/releases#create-a-release),
[asset digests and permissions](https://docs.github.com/en/rest/releases/assets).

## Latest attempt — build/tests PASS, artifact upload FAIL, 2026-10-23

User-requested latest-starting-HEAD run
<https://github.com/abdulAziz-Al-ILM/Bilga-Lokal/actions/runs/39916149000>
tested WIP source `4b21e3492bdc119eef853e0f251b659e452c7481`. Relative to the prior
passing source, only two documentation files changed. Locked pub get, analyze
(no issues,14.9s), all224 Flutter tests, debug APK build and CRC/signature/SHA
verification passed. APK SHA:
`b509fcd85fb987b2ecec3e29678e6f103bb2cef8277519a7fe2914d0f9b10505`.

Overall run FAILED because GitHub refused artifact creation: `Artifact storage
quota has been hit. Unable to upload any new artifacts. Usage is recalculated
every 6-12 hours.` Artifact API confirmed0. No workflow retry, artifact deletion,
billing change or main modification was made. Tablet signing/update is separately
blocked by local artifact hash/CRC failures; evidence and the unconfigured secret
design are in `BILGA_TABLET_VALIDATION_20261023.md`. No tablet-flow PASS is claimed.

## Previous complete PASS — 2026-10-22

Run <https://github.com/abdulAziz-Al-ILM/Bilga-Lokal/actions/runs/39814336862>
completed successfully in 15m09s. Event: `workflow_dispatch`; branch:
`wip/todo-widget-recovery`; tested source:
`8bf0faff7cc83452a85faa9a451971bd73058af9`.

| Check | Result |
| --- | --- |
| Locked `flutter pub get` | PASS |
| `flutter analyze` | PASS, no issues, 13.9s |
| Flutter tests | All 224 PASS |
| Universal Android debug APK | PASS, build step 11m18s |
| ZIP CRC / APK v2 signature / SHA-256 | PASS |
| APK artifact upload and artifact API | PASS, one unexpired artifact |

Download (private repository login required):
<https://github.com/abdulAziz-Al-ILM/Bilga-Lokal/actions/runs/39814336862/artifacts/12441708102>.
Artifact size: 293,931,559 bytes; expiry: 2026-10-29 16:43:19 UTC. Contents are
`app-debug.apk`, `SHA256SUMS` and `SOURCE.txt` only. APK SHA-256:
`752a548c7193f9bce219dc91cc43871407b6c52fcd97ef0af9c0f49a6a6206d0`.

The SDK manager removed unused hosted NDK packages 27.3.13750724, 29.0.14206865
and 30.0.16248370. Required NDK 28.2.13676358 was installed/preserved. There was
17 GiB free after setup and 5.4 GiB after the job. The first run's diagnosed disk
exhaustion was resolved by this single targeted correction and one manual
validation run. Neither run logged Dart/Java SIGSEGV. No further reruns were needed.

No local build/test, tablet install, database/model/signing-key change or Core
voice-code change occurred. Native instrumentation/device flows were not tested.
Later documentation-only checkpoints do not change this artifact's tested SHA.

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
one file. GitHub confirmed its file list and SHA. At registration the workflow was
byte-identical to WIP's copy. Main's application files/history and WIP's working tree were
preserved. The private repository's default branch remains `main`.

Manual/private/exact-WIP guards, read-only permissions, pinned action SHAs, Bash
syntax and credential patterns were checked before registration. A dispatch on
`main` cannot run the job. The actual manual dispatch selected WIP commit
`f145cceb7338ea93ff95324f793717dc56565683`:
<https://github.com/abdulAziz-Al-ILM/Bilga-Lokal/actions/runs/39811651782>.

The completed run's dependency resolution succeeded; analyze found no issues
(11.5s), and **all 224 Flutter tests passed**. The job failed after 13m43s because
the universal APK's `:app:stripDebugDebugSymbols` task exhausted the hosted runner's
disk: `LLVM ERROR: IO failure on output stream: No space left on device`.
There was 9.8 GiB free after SDK setup. The APK build failed in 9m45s; integrity
verification and upload were skipped, and the artifact API confirmed zero files.
No Dart/Java SIGSEGV was present in this run's log. Native device tests were not run.

One targeted WIP-only CI correction removes unused SDK-managed NDK versions from
the **disposable GitHub-hosted VM**, retaining required NDK 28.2.13676358. It uses
`sdkmanager --uninstall` for detected numeric-version NDK packages only, with
hosted-runner, exact SDK-root and symlink guards. No local SDK/files, unrelated
toolchains, application files, ABI targets or Gradle versions are changed. Disk
usage is printed before/after setup and at job completion. This WIP correction
does not modify the registration copy on `main`; dispatch reads the WIP workflow.
Its successful single manual validation is recorded above; there are no automatic
retry loops.

## Workflow

Local Dart/Java SIGSEGV failures are not retried by this workflow. All compilation
and Flutter tests run on a fresh GitHub-hosted Ubuntu 24.04 runner.

`.github/workflows/wip-android-debug.yml` accepts only `workflow_dispatch`.
Its job requires the private `abdulAziz-Al-ILM/Bilga-Lokal` repository and the
exact `wip/todo-widget-recovery` branch. There are no push, PR, schedule or release
triggers, production deployments or automatic retry loops. The private draft
delivery exception and its job-level contents:write permission are described above.

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
Checkout uses GitHub's automatic repository token without persisting
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
