# Release readiness

**IN PROGRESS — DO NOT SUBMIT TO GOOGLE PLAY.**

The source recovery and initial integrated development checkpoint are not a complete commercial release. Consult FEATURE_MATRIX.md, TEST_REPORT.md and KNOWN_LIMITATIONS.md for precise gaps.

Package: `com.ilmmizan.bilga` (preserved). Database files: `bilga.db`, `bilga_todo.db`. Current derived-search upgrade targets: Notes 14 / Tasks 9. Portable backup content versions remain Notes 12 / Tasks 7 with backward-compatible import; search indexes and device-local widget consent are excluded and reconstructed.

Business: 40-day application-managed trial, then one non-consumable lifetime product `bilga_lifetime_unlock`. No subscription or automatic billing. Price must come from Play ProductDetails; $9.99 is a planning reference only. Existing data is not removed at expiry; protected read/export/backup routes remain.

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

Current prerequisite review: [PLAY_POLICY_REVIEW.md](PLAY_POLICY_REVIEW.md), including target API 36, updated Billing 9.1.0, conditional account testing and country availability.

Current policy reference consulted: https://developer.android.com/google/play/billing/integrate (2026-11-09). Purchases must be verified and acknowledged only after completion; pending purchases do not unlock. This reference does not replace final policy review.

Current host verification: **158 Flutter tests PASS**, analyzer no issues, formatting and all 43 locale structures PASS. Details and earlier failures are in TEST_REPORT.md. No current Android artifact is available yet.

No release signing credentials were supplied to this work. Do not generate replacement keys or silently substitute debug artifacts.
