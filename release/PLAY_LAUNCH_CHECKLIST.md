# Bilga Google Play launch

## Signed Closed Testing package

- [x] Re-audited the existing `build/play-closed-test/bilga-1.4.0-20-closed-testing.aab` with Bundletool, Java signature verification and the release manifest checker.
- [x] Package `com.ilmmizan.bilga`, version name `1.4.0`, version code `20`, minimum Android API `26`, target `36`. The release is non-debuggable and excludes the test-only and instrumentation flags, Review sample and Dart debug kernel.
- [x] The bundle includes `armeabi-v7a`, `arm64-v8a` and `x86_64`. Its configuration requests `PAGE_ALIGNMENT_16K`. All 16 64-bit ELF libraries met the alignment check.
- [x] Bundle SHA-256 `8635031a68a1c1e38319dd1c1cf9817582f6ee922830deb0ba0f54ca85b4c613`.
- [x] The owner supplied the **Upload key certificate** from Play Console. Its SHA-256 `80:5B:C0:38:83:D6:67:C1:CF:F6:4C:58:3D:60:41:EF:CF:45:C9:8D:EC:97:D2:67:0C:0E:0E:F2:D3:D6:BA:29` exactly matches the signed AAB. Play App Signing is in use. The Digital Asset Links fingerprint on the same page is `B9:E8:A4:F3:A8:58:71:E0:D8:FF:E7:54:6C:3F:7C:7D:76:63:0E:08:1B:E0:C9:BD:D1:EC:B3:B4:A5:FF:D3:59`. [Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756)
- [ ] Check the highest code across all tracks in **Test and release → Latest releases and bundles**. If version 20 already exists, verify the existing bundle in Console before reusing it or choosing a higher code. [Inspect app versions](https://support.google.com/googleplay/android-developer/answer/9844279)
- [x] The test build preserves the 40-day trial and disables purchases through the existing purchase gate. The closed-test listing says purchases are disabled. The lifetime product remains `bilga_lifetime_unlock`.
- [x] The focused release checks passed all 14 manifest cases and 17 purchase verifier cases. Real license testing requires the configured Play product and HTTPS verifier.

## Listing and app content

- [x] Uzbek, English and Russian descriptions and release notes are in [Store listing](../docs/STORE_LISTING_DRAFT.md). Copy the test-specific descriptions from `build/play-closed-test/listing`.
- [x] The current brand [512 × 512 icon](bilga-icon-512.png) and [1024 × 500 feature graphic](bilga-feature-graphic-1024x500.png) are ready for the listing. Google Play requires a feature graphic and at least two screenshots. [Preview asset requirements](https://support.google.com/googleplay/android-developer/answer/9866151)
- [x] Three 1080 × 1920 screenshots show the current Home, Notes editor and Books library. The Flutter capture used the real app widgets, packaged fonts and synthetic records in an Android-sized viewport. The images are in `build/play-closed-test/listing/screenshots`. Android device acceptance is separate. The tablet was absent from ADB during this pass.
- [ ] Confirm the public location and publisher details for the [privacy policy](../docs/PRIVACY_POLICY_DRAFT.md). Enter the public URL on the listing and app content pages.
- [ ] Complete App content using the facts below. The account owner confirms the audience age groups, content-rating questionnaire, distribution countries, trader status and legal contact details.

| Console section | Source-verified information for the form |
| --- | --- |
| Ads | Bilga displays no ads. |
| App access | Everyday use and the trial require no Bilga account. First launch includes a trial acknowledgement. Google account sign-in is optional for Drive backup. Explain that reviews can access the 40-day trial without card details and that this closed test has purchases disabled. |
| Financial features | Bilga records personal income, expenses, budgets, goals and debt reminders locally. Transfer entries represent transfers between the user's recorded accounts. Bilga provides no loans, trading or payment transfer services. Google's form includes **Other** for financial support features. [Financial features declaration](https://support.google.com/googleplay/android-developer/answer/13849271) |
| Data Safety | Notes, tasks, habits, journals, financial records, books and attachments reside locally by default. Optional Drive backup sends an encrypted backup of the supported records to the user's Drive after Google authorization. The source uses the private `drive.appdata` scope. Local attachment backup is separate. |
| Voice and audio | `RECORD_AUDIO` is for optional user-started foreground speech recognition. An installed system recognition provider may send speech off-device after disclosure and consent. Device-only recognition uses Android's local API when available. Read aloud uses an offline voice or the bundled speech engine and does not need the microphone. |
| Notifications and foreground services | `POST_NOTIFICATIONS` covers reminders. Users can allow `SCHEDULE_EXACT_ALARM` for precise timing. The app declares user-initiated media playback and a short task-reminder panel service. The reminder panel separately requires overlay permission. A boot receiver reschedules reminders. |
| Billing data | Closed testing has purchases disabled. Before enabling purchases, declare the live verification service's handling of package and product, signed purchase receipt, verification dates and the app's random installation binding. Google Play handles payment. The verifier uses hashed token and receipt digests in its ledger. |

Review the actual off-device flows before saving Data Safety. The installed speech provider's retention follows its own policy, and the live billing host and operator still need confirmation. [Data Safety definitions](https://support.google.com/googleplay/android-developer/answer/10787469)

## Closed Testing and Production

- [ ] Resolve any outstanding release for the selected track. For a draft, open **Releases → Edit release → Discard draft release** to remove changes in that draft. For a release under review or ready to publish, first remove its changes from **Publishing overview**, then discard it from the release summary. [Release states and discard actions](https://support.google.com/googleplay/android-developer/answer/9859348#discard)
- [ ] In **Closed testing → Manage track**, upload the checked AAB and save the release with the appropriate release notes. Complete required Dashboard items and submit the closed test for review.
- [ ] Add real testers to the track and confirm their available Google accounts. Copy the actual opt-in link from the **Testers** section when available. Use `build/play-closed-test/Bilga-testchilarga-xabar.txt` for invitations and instructions. [Closed testing setup](https://support.google.com/googleplay/android-developer/answer/9845334)
- [ ] The Bilga dashboard states that closed testing is required. Verify progress on that account. For affected personal accounts, production access requires at least 12 testers continuously opted in for 14 days and a production-access application. [Testing and production access](https://support.google.com/googleplay/android-developer/answer/14151465)
- [ ] Configure the Play product and an authorized HTTPS verifier. Validate purchase, pending payment, acknowledgement, restore, cancellation/refund and cached access with Google Play license testers. The application displays Play ProductDetails prices. Treat $9.99 as a price reference for the owner's Console selection.
- [ ] After test evidence and final pricing and country checks, get the owner's approval for the public rollout. Confirm the published state in Play Console.
