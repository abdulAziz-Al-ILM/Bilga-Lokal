# Blackview Tab 16 — guarded CI update and widget verification

## Starting evidence

Local and private remote WIP HEAD matched
`4b21e3492bdc119eef853e0f251b659e452c7481`; working tree was clean. Relative to
previous successful CI source `8bf0faff7cc83452a85faa9a451971bd73058af9`, only
`BILGA_CI.md` and `HANDOFF.md` differ. No application or workflow bytes changed.
Main remains `8871b3ac007ab05402949b3eacd4327340c6913c`, default branch `main`.

The explicitly requested fresh manual CI targets starting HEAD `4b21e34`:
<https://github.com/abdulAziz-Al-ILM/Bilga-Lokal/actions/runs/39916149000>.
Locked pub get, analyze (no issues, 14.9s), all224 Flutter tests, APK build and
APK CRC/signature/SHA verification **passed**. Overall run **FAILED** solely at
artifact upload: `Artifact storage quota has been hit. Unable to upload any new
artifacts. Usage is recalculated every 6-12 hours.` No artifact was created.
Built APK SHA was `b509fcd85fb987b2ecec3e29678e6f103bb2cef8277519a7fe2914d0f9b10505`.
No run retry, artifact deletion, billing/visibility/default-branch change was made.
Subsequent documentation-only commits do not change the APK's tested source.

## Signing gate

The installed package is debug `com.ilmmizan.bilga`, version `1.4.0+9`, on API31 /
arm64. Read-only APK/certificate checks found:

| Certificate | SHA-256 |
| --- | --- |
| Installed APK | `38ecfe0234e465924812ba3ee84ef838557a1d03d53713bd7a6d76478663bd6d` |
| Existing local debug key's public certificate | `38ecfe0234e465924812ba3ee84ef838557a1d03d53713bd7a6d76478663bd6d` |
| Previous CI APK from run39814336862 | `a5a196c7e4d7a5258f9a532edcd6d5e9c97be4f7c1ab37ef46b0db3a581cb26b` |

The original CI certificate does **not** match. No installation was attempted.
The old CI certificate was read from its APK v2 signing block using 69,920 bytes
of TLS-authenticated artifact ranges; that CI had already verified its full APK.
The installed APK was pulled and verified with `apksigner`, and `keytool` read only
the existing debug key's public certificate. Private key bytes were not exported.

For any installation candidate, download/verify the full artifact digest, ZIP allowlist/CRC,
SOURCE.txt and APK SHA-256 before using it. Verify its original signature, then
sign a **separate copy** with the matching local debug key. Use an explicit output
path so the original CI APK stays intact. Check the resulting signature/fingerprint
and compare all ZIP entry contents with the original; signing changes the signing
block and resulting APK SHA, not application payload. This is signing only, not a
local Flutter/Gradle build. The private key remains on this computer.

Before `adb install -r`, check package/version/debug flag, certificate equality,
app UID and on-device database/settings hashes. Do not uninstall, clear data,
export encryption keys or copy personal databases to GitHub. Check UID and file
hash preservation immediately after update, then test through the UI using only
reserved synthetic notes/tasks. Record booleans/results, not personal content,
database hashes, private keys or raw preferences in source control.

## Optional future GitHub Actions secret design — not enabled

Local signing avoids uploading the existing debug key. If direct tablet-compatible
CI artifacts are later required, use a dedicated protected environment limited
to the private WIP branch/manual job, after checking account support and obtaining
explicit approval for key upload. Store the debug keystore as a repository or
environment secret (base64 transport; GitHub encrypts secrets), with passwords in
separate secrets. Base64 is encoding, not encryption.

Keep secret variables scoped to a final signing step after tests/build, or a
separate signing job that executes no application/build code. Decode only into a
new mode0600 runner-temp file; disable shell tracing; use env/stdin passwords;
pin the expected public certificate above and fixed debug alias. Missing secrets
or a fingerprint mismatch must fail closed. Upload only APK/public checksums/source
metadata. Remove only the step-created temporary key in a cleanup trap/always step;
never upload it, print it, cache it or use it for release signing. Preserve the
existing manual/private/WIP guards. No secret or workflow change was made here.

References: [Android apksigner](https://developer.android.com/tools/apksigner),
[GitHub Actions secrets](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets).

## STOP — downloaded artifact failed integrity on this host

After the latest build's upload failed, the retained previous APK was considered
because its application/configuration source is identical to starting HEAD4b21e34.
Its archive transfer was resumed into an ignored temporary file. Eight bounded
range streams completed all293931559 bytes, but full integrity verification failed.

| Check | Observed |
| --- | --- |
| Trusted GitHub artifact ZIP SHA-256 | `801289fe64d75b9fa58138666f7ecaaab97d57a64bf5f5c013d17547f127920d` |
| Local Python SHA-256 | `325e60abba810d415eaa11ebca687a4011142150eef53ad7f3ddcefad4685527` |
| Independent native sha256sum | `ccd65746bf2aba50e75487b7952f42272a928616d724d3d09611ed442294b29c` |
| APK entry CRC declared by archive | `8c26a660` |
| Python and native unzip CRC | `6afff20c` — FAIL |

The native hash was taken after the download process exited; diagnostic code did
not modify the archive between these reads. The differing hashes cannot establish
whether RAM, storage/read path or the transfer caused the fault. The archive is
not trusted. A single-bit-location hypothesis was checked against a fresh
server-Content-MD5-verified 4KiB range; that range matched the local bytes, so the
hypothesis was **not confirmed** and no byte repair was performed.

**No signing, install-r, uninstall, pm clear or task/note write was performed.**
Original/local private keys were not exported or uploaded; no GitHub secret was
created. Installed UID/version/update time still matched the start; last update
remained 2026-10-16. Generated APK/ZIP/log/diagnostic files remain ignored locally,
not in Git. `git fsck --full --no-dangling` exited0 before writing this report;
this does not certify the host's RAM or future file operations.

Do not proceed to private-key signing or tablet update on this host until its
transfer/read integrity is reliable, or perform those steps on a stable machine.
The remote previous artifact remains intact. Account artifact-quota resolution
or an explicitly approved alternative is also needed for a fresh downloadable
CI artifact. Existing artifacts and user data were not deleted to bypass either
gate. Persistent notifications/Habits remain unstarted.

## Device checks — blocked, not run

- Custom widget time: selected local instant reaches SQL/mirror and schedules one
  replacement alarm, while original deadline remains unchanged.
- Native Done/Snooze: no extra app confirmation on an unlocked/authorized device;
  Done cancels the synthetic reminder, Snooze changes only reminder time.
- Notes: approved preview title/body/tags, consent persists after app close/reopen;
  revoke refreshes the widget and app-owned cache. Leave unrelated grants untouched.

No install/device-flow PASS is claimed. Existing user data,
private models, Core voice code and main are untouched. Persistent Todo notification
and Habits work remain later stages, after this gate succeeds.
