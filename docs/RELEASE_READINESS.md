# Release readiness

**IN PROGRESS — DO NOT SUBMIT TO GOOGLE PLAY.**

The source recovery and initial integrated development checkpoint are not a complete commercial release. Consult FEATURE_MATRIX.md, TEST_REPORT.md and KNOWN_LIMITATIONS.md for precise gaps.

Package: `com.ilmmizan.bilga` (preserved). Database files: `bilga.db`, `bilga_todo.db`. Current derived-search upgrade targets: Notes 15 / Tasks 12. Portable backup content versions remain Notes 13 / Tasks 10 with backward-compatible import; search indexes and device-local widget consent are excluded and reconstructed.

Business: 40-day application-managed trial, then one non-consumable lifetime product `bilga_lifetime_unlock`. No subscription or automatic billing. Price must come from Play ProductDetails; $9.99 is a planning reference only. Existing data is not removed at expiry; protected read/export/backup routes remain.

Latest November 11 template checkpoint: **199 full Flutter tests PASS**, clean analyzer/formatting, **43 × 384** catalog keys and nine manifest/target guards PASS. Tab16/API31 review-only tests pass **36 scenarios**, 42 including hooks, in 222 seconds, including encrypted custom templates and complete template UI routes. Subtask source `42cee8d` passed hosted CI **42796563471**; the newer template milestone CI is pending. The six-module completion and owner acceptance gates remain unmet.

Required before release:

- Finish every required feature and full interaction/localization/accessibility audit.
- Pass full unit/widget/repository/legacy migration/encrypted-media restore/security/performance tests.
- Verify reminders/reboot/timezone/background behavior on real Android devices.
- Configure and license-test Play purchase, pending/cancel, acknowledgement retry, restore, revoked/refunded and offline-cached entitlements.
- Validate optional Drive restore, including media, on clean second device.
- Build reproducible debug APK and existing-key signed release APK/AAB; verify package, manifest, ZIP/signature and hashes.
- Finalize privacy policy, Data Safety, content rating, store listing, screenshots and feature graphic from the actual finished product.
- Recheck current official Play target API, Billing Library deadlines, testing-track/account/country rules at submission time.
- Obtain owner approval for actual publication and final country prices. No prices have been activated.

Prerequisite review: [PLAY_POLICY_REVIEW.md](PLAY_POLICY_REVIEW.md), including target API 36, updated Billing 9.1.0, conditional account testing and country availability.

Policy reference consulted: https://developer.android.com/google/play/billing/integrate (2026-11-09). Purchases must be verified and acknowledged only after completion; pending purchases do not unlock. This reference does not replace final policy review.

Historical November 9 host verification: **158 Flutter tests PASS**, analyzer no issues, formatting and all 43 locale structures PASS. Details and earlier failures are in TEST_REPORT.md. Hosted CI **42668103911 SUCCESS**, validated source `f2bb128ed4d4d6adef20fc28a7595de5d00fee2a`: analyzer no issues, **158 tests PASS**, debug APK build PASS, ZIP integrity PASS, APK v2 signature PASS, merged manifest PASS (package unchanged, target API 36, Billing 9.1.0, no microphone permission).

[Download private debug APK artifact](https://github.com/abdulAziz-Al-ILM/Bilga-Lokal/actions/runs/42668103911/artifacts/13698162381) — archive 211,606,874 bytes; expires **2026-11-16 22:58 Asia/Tashkent**. APK path within the CI artifact: `app-debug.apk`; runner build path: `build/app/outputs/flutter-apk/app-debug.apk`. APK SHA-256: `3ceb34222fc421cd2d9dde65642c63e7f33a8a2f542624fc1151b25c3e7ce4cc`.

This is a disposable-signer debug build, not a signed production release or an upgrade-signing acceptance result. That November 9 CI artifact did not establish release-signing or device acceptance. The newer tablet results are recorded separately above.

No release signing credentials were supplied to this work. Do not generate replacement keys or silently substitute debug artifacts.
