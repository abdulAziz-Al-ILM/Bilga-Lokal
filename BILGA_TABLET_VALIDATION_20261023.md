# Blackview Tab 16 — guarded CI update and widget verification

## Starting evidence

Local and private remote WIP HEAD matched
`4b21e3492bdc119eef853e0f251b659e452c7481`; working tree was clean. Relative to
previous successful CI source `8bf0faff7cc83452a85faa9a451971bd73058af9`, only
`BILGA_CI.md` and `HANDOFF.md` differ. No application or workflow bytes changed.
Main remains `8871b3ac007ab05402949b3eacd4327340c6913c`, default branch `main`.

The explicitly requested fresh manual CI targets starting HEAD `4b21e34`:
<https://github.com/abdulAziz-Al-ILM/Bilga-Lokal/actions/runs/39916149000>.
Analyze and Flutter-test steps have passed; APK build is pending at this checkpoint.
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

For the new APK, download/verify the full artifact digest, ZIP allowlist/CRC,
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

## Device checks — not yet run

- Custom widget time: selected local instant reaches SQL/mirror and schedules one
  replacement alarm, while original deadline remains unchanged.
- Native Done/Snooze: no extra app confirmation on an unlocked/authorized device;
  Done cancels the synthetic reminder, Snooze changes only reminder time.
- Notes: approved preview title/body/tags, consent persists after app close/reopen;
  revoke refreshes the widget and app-owned cache. Leave unrelated grants untouched.

No install/device-flow PASS is claimed at this checkpoint. Existing user data,
private models, Core voice code and main are untouched. Persistent Todo notification
and Habits work remain later stages, after this gate succeeds.
