# Blackview Tab 16 — data-preserving update and real UI validation

## Installed build and preservation

Private unpublished draft421646821, tablet-debug.apk,293937033 bytes.
APK SHA-256 `9a01ddd6a8f77df800627b2c4214ecc3cdd3e87b3147dc1715b9be506e7a36d8`.
Signer `38ecfe0234e465924812ba3ee84ef838557a1d03d53713bd7a6d76478663bd6d`.
Private server digest, fresh local Python/native SHA and signature checks PASS;
installed package/USB device confirmed. `adb install -r`: **Success**.
Before first app launch, on-device Notes/Todo main database and all their present
sidecar file hashes were identical before/after install. UID unchanged. Database
contents, encryption keys and raw personal settings were not copied out. Private
hash manifests/logs/APKs stay ignored locally, never committed. No uninstall,
pm clear, reset or production signing/key upload.

Application source was built/tested in CI39926382854 from5ee550e (analyze,224
Flutter tests, APK PASS), separately locally signed, and independently validated
by CI39930640049 (signature, hashes,779 payload entries,8 safety tests PASS).
No local Flutter/Gradle build or repeated full test suite was needed here.

## Real UI evidence so far

- Created one new reserved synthetic task through the widget's + editor. Selecting
  a complete date/time switched reminder OFF to ON automatically. Saved deadline
  was24 October20:09; device timezone Asia/Tashkent. Existing tasks were not edited.
- Widget configuration exposed per-task consent; only the new fixture was granted.
  Existing grants were left unchanged. Approved real title appeared in launcher.
- Widget Snooze→5 minutes worked inline. Main did not open; Calculator/launcher
  task checks distinguish foreground state. Exactly one next native alarm existed.
- Widget Snooze→Other time opened native picker. First automation displayed20:17
  while the spinner retained20:24: test driver used ACTION_SET_TEXT without focus.
  This is recorded as an unsuccessful initial check, not an app-flow PASS.
  The source probe now focuses each input before setting text, allowing the
  application's clearFocus/save path to commit it normally. Focused selection
  20:18 matched the single alarm exactly; the old20:24 alarm was replaced.
- Cold startup initially had no alarm at the first3-second observation. That was
  premature bootstrap sampling: a single reminder notification was actually
  created at selected20:18:00 +79ms. Reopening the exact fixture editor showed
  reminder23 October20:18, while deadline remained24 October20:09. Thus custom
  time persisted in the normal encrypted database across process restart.
- Real20:22 reminder rendered APPLICATION_OVERLAY above foreground AOSP Calculator,
  frame[180,1438][1020,1937], surface present, synthetic title and all action/preset
  controls visible. Public runtime theme values yield text contrast14.34:1 and
  primary-button contrast7.67:1. No screenshots/user screens were exported.
  A later button attempt found no overlay; it was not marked PASS. A single
  bounded timing-controlled run is used to test the action while the panel exists.
- The bounded run clicked overlay Snooze→5 minutes successfully above Calculator.
  Its first immediate post-click alarm sample preceded async SQL completion and
  failed the timing assertion; no app action was replayed. A subsequent single
  completion observation confirmed one alarm at20:31:06.652 (five minutes after
  the20:26 action), Calculator still foreground, reminder901/overlay902 notification
  counts both0. This app-flow PASS is distinct from the premature harness assertion.
- Reopened Todo widget configuration after cold restart: the new fixture grant
  remained ON; pre-existing grants were unchanged. Widget Done then completed only
  this fixture with one click, without opening Main or a confirmation dialog.
  Launcher stayed foreground; fixture displayed Done. The20:31 reminder vanished;
  only the widget's next-midnight alarm remained, as expected.

## Remaining checks at this checkpoint

Notes preview/tags and Notes permission persistence, and final Recent Apps checks
are pending. This intermediate document is not a
claim those flows passed. A small self-targeted test-only UI package was compiled
from the Java probe, without Flutter/Gradle; it cannot read Bilga databases and
exports only static/synthetic accessibility labels. Test helper/source changes do
not alter the installed application's779 payload entries. No Habits/Finance/Core
feature code or main changes are part of this task.
