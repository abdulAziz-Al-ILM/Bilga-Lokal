# BILGA — COMPLETE PRODUCT DEVELOPMENT & GLOBAL LAUNCH
## FINAL MASTER IMPLEMENTATION INSTRUCTION

**PROJECT:** Bilga
**COMPANY:** ILM Mizan
**PRIMARY TECHNOLOGY:** Flutter / Dart / Android
**PRIMARY REPOSITORY:** `abdulAziz-Al-ILM/Bilga-Lokal`
**TARGET MARKET:** Worldwide
**MONETIZATION:** 40-day free trial → one-time lifetime purchase
**GLOBAL REFERENCE PRICE:** USD $9.99
**PRICING STRATEGY:** Regional purchasing-power-based pricing
**PRODUCT PHILOSOPHY:** Offline-first, privacy-first, reliable, beautiful, complete.

---

# 1. YOUR ROLE AND MISSION

You are the autonomous engineering team responsible for completing Bilga.

Act simultaneously as:

- Principal Software Architect
- Senior Flutter Engineer
- Android Platform Engineer
- Senior UI/UX Designer
- Database Architect
- Security Engineer
- Quality Assurance Engineer
- Localization Engineer
- Performance Engineer
- Release Engineer
- Product Quality Lead

Your mission is not to create another prototype.

Your mission is to transform Bilga into a fully functional, professionally designed, commercially competitive Android application suitable for worldwide distribution.

**IMPORTANT: IMPLEMENT THE PRODUCT. DO NOT MERELY DESCRIBE HOW TO IMPLEMENT IT.**

The product owner does not want to provide separate instructions for every button, screen, feature, animation, database operation or bug.

You must independently discover and resolve ordinary implementation requirements.

Every implemented feature must work from beginning to end.

A feature is not complete merely because its user interface exists.

The final objective is a reliable, polished and commercially viable application that users will willingly purchase after experiencing it.

---

# 2. PROJECT HISTORY AND SOURCE RECOVERY

Bilga has been developed across multiple computers and repositories.

The current computer is not the original development computer.

Some previous code, assets, documentation or implementation decisions may exist only on the older computer.

Therefore:

**Never assume that the current local working directory contains the complete project history.**

Known GitHub repositories:

### Primary Flutter repository
`abdulAziz-Al-ILM/Bilga-Lokal`

This is the primary production candidate.

### Earlier Android implementation
`abdulAziz-Al-ILM/Bilga`

Contains an earlier Kotlin/Jetpack Compose implementation.

Potentially valuable features include:

- Notes
- Tasks
- Reminders
- Habits or planning concepts
- Personal experience journal
- Local AI architecture
- Biometric locking
- Encrypted backups
- Themes
- Multilingual interfaces

Verify the actual source code rather than relying on descriptions.

### Backup repository
`abdulAziz-Al-ILM/Bilga-Backup`

Inspect for missing implementations, assets, fixes and historical decisions.

### Language-model repository
`abdulAziz-Al-ILM/Bilga-Language-Models`

Inspect for useful model resources, documentation and integration options.

### Recovery procedure

1. Inspect all accessible repositories.
2. Review branches, commits, tags and pull requests.
3. Examine project documentation and specifications.
4. Compare older implementations with the current Flutter application.
5. Identify useful functionality that was lost or not migrated.
6. Reuse existing working code where appropriate.
7. Port valuable Kotlin functionality into Flutter when practical.
8. Identify inaccessible components that may remain on the previous computer.
9. Do not invent or falsely claim recovery of missing files.
10. Proceed using the best available implementation.

Do not replace the current Flutter application with the older Kotlin version.

Do not unnecessarily rewrite functioning systems.

Preserve the established product identity.

---

# 3. NON-NEGOTIABLE COMPATIBILITY REQUIREMENTS

Historical project information:

- Android application ID: `com.ilmmizan.bilga`
- Notes database: `bilga.db`
- To-Do database: `bilga_todo.db`
- Historical Notes schema: version 8
- Historical To-Do schema: version 6
- Historical backup format: version 1

Verify whether newer compatible versions already exist.

Preserve the application ID.

Preserve existing user data.

Preserve supported backup formats.

Use explicit versioned database migrations.

Never use destructive migration merely to simplify development.

Never delete existing application databases to resolve a schema problem.

Never silently overwrite user content.

Existing installed versions must be considered during upgrade testing.

Signing-key compatibility must also be respected.

---

# 4. THE FINAL PRODUCT VISION

Bilga is a unified personal productivity, knowledge, memory and life-organization system.

Its purpose is to reduce the need for multiple disconnected applications.

The individual modules must be sufficiently capable to compete with specialized applications.

Reference products include:

**Notes:** Google Keep, UpNote, Obsidian.

**Tasks:** Todoist, TickTick, Microsoft To Do.

**Reminders:** Google Tasks and dedicated reminder applications.

**Habits:** Loop Habit Tracker and comparable products.

**Journaling:** Day One and comparable journals.

**Planning:** Modern daily and weekly planners.

**Personal knowledge:** Lightweight knowledge-management applications.

Study relevant product workflows and interaction patterns when practical.

Do not copy proprietary source code, copyrighted assets or distinctive protected branding.

Bilga must maintain its own visual and functional identity.

Its key competitive advantage should be the seamless integration of personal knowledge, tasks, reminders, habits and daily planning.

## Core principles

1. Offline-first.
2. Privacy-first.
3. No advertisements.
4. No subscription.
5. One lifetime purchase.
6. Full functionality during the free trial.
7. Fast and lightweight.
8. Beautiful and intuitive.
9. Reliable local storage.
10. Optional cloud backup.
11. Global language support.
12. No mandatory account for the core experience.
13. Minimal recurring infrastructure costs.
14. Maintainable architecture.
15. Future compatibility with the ILM Mizan ecosystem.

Avoid unnecessary complexity.

An excellent, reliable implementation is more valuable than hundreds of poorly functioning features.

---

# 5. MODULE A — COMPLETE NOTES APPLICATION

Develop Notes to the standard of a competitive standalone note-taking application.

Implement:

- Create notes.
- Edit notes.
- Delete notes.
- Reliable autosave.
- Rich-text formatting.
- Headings.
- Bold.
- Italic.
- Underline.
- Strikethrough.
- Lists.
- Checklists.
- Links.
- Undo and redo.
- Copy and paste.
- Note duplication.
- Pinning.
- Favorites.
- Archiving.
- Tags.
- Nested folders.
- Move between folders.
- Sorting.
- Filtering.
- Search.
- Full-text search.
- Templates.
- Note creation timestamps.
- Modification timestamps.
- Note history.
- Restore previous versions.
- Trash.
- Restore from trash.
- Permanent deletion.
- Bulk operations.
- Native Android sharing.
- Export.
- Supported file import.
- Image attachments.
- File attachments.
- Attachment lifecycle management.
- Smooth editing of long notes.

Support common real-world note-taking workflows.

Preserve user input during navigation, backgrounding and interruption as reliably as the platform permits.

Avoid data loss from asynchronous save races.

Do not freeze the interface during large edits.

Implement efficient database operations.

Existing working Notes functionality must not regress.

---

# 6. MODULE B — PROFESSIONAL TASK MANAGER

Build a complete task-management application inside Bilga.

Implement:

- Create tasks.
- Edit tasks.
- Complete tasks.
- Reopen completed tasks.
- Delete tasks.
- Restore tasks.
- Task descriptions.
- Priorities.
- Due dates.
- Due times.
- Subtasks.
- Checklists.
- Recurring tasks.
- Daily recurrence.
- Weekly recurrence.
- Monthly recurrence.
- Custom recurrence rules.
- Tags.
- Projects.
- Nested folders.
- Custom lists.
- Sorting.
- Filtering.
- Search.
- Today view.
- Upcoming view.
- Overdue tasks.
- Completed tasks.
- Bulk operations.
- Task duplication.
- Task templates.
- Progress indicators.
- Task reminders.

Recurring tasks must have correct occurrence handling.

Completing one occurrence must not unexpectedly delete or corrupt the entire recurrence series.

Support editing a single occurrence and, where appropriate, the series.

Handle time-zone and calendar edge cases.

The user must be able to manage an entire personal or professional workflow without needing another task application.

---

# 7. MODULE C — RELIABLE REMINDERS

Implement a complete reminder system.

A due-date label without actual notifications is not sufficient.

Required capabilities:

- One-time reminders.
- Repeating reminders.
- Custom schedules.
- Reminder notifications.
- Reminder editing.
- Reminder cancellation.
- Snooze.
- Mark as completed.
- Reminder history.
- Reminder links to notes.
- Reminder links to tasks.
- Correct notification navigation.
- Reboot-aware scheduling.
- App-update-aware scheduling.
- Time-zone handling.
- Notification permission handling.
- Android battery restriction awareness.
- Clear notification settings.

Use appropriate modern Android APIs.

Respect exact-alarm restrictions and Google Play policies.

Do not request unnecessary permissions.

Explain unavoidable operating-system restrictions honestly.

Do not claim that a notification is guaranteed to arrive at an exact time when Android restrictions may prevent that.

Test actual notification behavior where device access is available.

---

# 8. MODULE D — HABIT TRACKER

Build a genuinely useful habit-tracking module.

Implement:

- Create habits.
- Edit habits.
- Delete habits.
- Archive habits.
- Daily habits.
- Weekly habits.
- Custom schedules.
- Yes/no habits.
- Quantity-based habits.
- Flexible targets.
- Completion history.
- Calendar view.
- Statistics.
- Streaks.
- Progress visualization.
- Missed-day handling.
- Historical entry editing.
- Optional reminders.
- Habit categories.
- Clear progress reports.

Use correct and documented statistical calculations.

Avoid misleading streak calculations.

The module should encourage sustainable improvement without manipulative notifications or artificial pressure.

---

# 9. MODULE E — JOURNAL AND PERSONAL EXPERIENCE

Build a personal journaling system.

Include:

- Daily entries.
- Free-form entries.
- Work journal.
- Study journal.
- Life journal.
- Soul/reflection journal.
- Custom categories.
- Tags.
- Search.
- Calendar navigation.
- Templates.
- Optional mood tracking.
- Attachments.
- Editing.
- Entry history.
- Deletion.
- Export.
- Backup.
- Privacy protection.

Journal entries must remain private by default.

Do not create a public social network in this release.

If the older implementation contains a future experience-sharing mechanism, preserve the concept in documentation without activating public sharing.

Public sharing requires separate product-owner approval.

---

# 10. MODULE F — DAILY AND WEEKLY PLANNING

Create an integrated personal planning system.

Required features:

- Today dashboard.
- Weekly overview.
- Upcoming tasks.
- Upcoming reminders.
- Habit progress.
- Quick notes.
- Quick task creation.
- Priorities.
- Completed activities.
- Overdue items.
- Useful daily summaries.

The home screen must be immediately useful.

Users should quickly understand their current commitments.

Do not duplicate the same underlying task across multiple independent databases simply to display it in different views.

Use stable identifiers and shared relationships.

Provide clear navigation into original items.

---

# 11. MODULE G — UNIFIED SEARCH

Build a fast search system across Bilga.

Searchable content:

- Notes.
- Tasks.
- Journal entries.
- Habits.
- Tags.
- Folders.
- Relevant linked content.

Requirements:

- Full-text search where appropriate.
- Relevant results.
- Search filters.
- Content previews.
- Fast navigation.
- Proper handling of archived content.
- Proper handling of deleted content.
- Efficient database indexing.
- Good performance with thousands of records.

Search should function without internet.

---

# 12. MODULE H — INTELLIGENT TEXT ASSISTANCE

Voice commands are explicitly excluded from this release.

Do not implement:

- Speech recognition.
- Voice activation.
- Microphone-based commands.
- Text-to-speech.
- Voice cloning.

However, preserve architectural compatibility for future voice support.

Inspect the existing local AI implementations.

Evaluate whether useful local text-based assistance can be provided responsibly.

Potential capabilities:

- Search personal knowledge.
- Answer questions about stored notes.
- Summarize selected text.
- Identify related notes.
- Extract potential tasks.
- Help organize information.

Requirements:

1. No unauthorized external transfer of personal data.
2. No fabricated personal facts.
3. Clear source references where answers use stored content.
4. Clear disclosure of limitations.
5. Confirmation before modifying user data.
6. No silent deletion.
7. No mandatory model download.
8. No unacceptable performance degradation.
9. No mandatory external AI subscription.

A keyword search engine must not be falsely described as a full generative AI model.

If high-quality offline language-model integration is not viable for this release, prioritize a reliable search-based assistant and preserve an extensible AI interface.

Do not let unavailable AI infrastructure prevent the rest of Bilga from becoming production-ready.

---

# 13. CROSS-MODULE INTEGRATION

Bilga's modules must operate as a coherent system.

Implement:

- Convert note content into a task.
- Link a note to a task.
- Create reminders from tasks.
- Link journal entries to tasks.
- Connect habits with daily planning.
- Show related information in the Today dashboard.
- Navigate directly to linked content.
- Preserve relationships during backup and restore.

Avoid data duplication.

Avoid inconsistent completion states.

Maintain referential integrity.

A change in one module must not silently corrupt another.

---

# 14. GLOBAL UI/UX REQUIREMENTS

Bilga must have premium-quality visual design.

Create a consistent design system.

Cover:

- Typography.
- Spacing.
- Navigation.
- Icons.
- Buttons.
- Forms.
- Dialogs.
- Cards.
- Lists.
- Empty states.
- Loading states.
- Error messages.
- Confirmation messages.
- Animations.
- Accessibility.
- Responsive layouts.

Preserve and improve the existing seven visual palettes.

Support:

- Light mode.
- Dark mode.
- System mode.

Make navigation intuitive.

Avoid unnecessary taps.

Support one-handed usage.

Support small phones and tablets.

Support large accessibility font sizes.

Prevent keyboard overlap.

Prevent text overflow.

Prevent accidental duplicate actions.

Use subtle animations that do not negatively affect battery usage.

Every screen must feel like part of the same application.

Never leave decorative controls that appear functional but do nothing.

---

# 15. INTERNATIONALIZATION — WORLDWIDE RELEASE

Bilga targets the global market from its first public release.

Preserve the existing 43-language localization architecture.

Prioritize translation quality for:

1. Uzbek.
2. English.
3. Russian.
4. Kyrgyz.
5. Kazakh.
6. Tajik.
7. Turkmen.

Preserve the other supported languages.

Required:

- No hardcoded user-facing strings.
- Localized dialogs.
- Localized validation.
- Localized error messages.
- Correct plural forms.
- Correct date formatting.
- Correct time formatting.
- RTL support.
- Accessible localized interface labels.
- Localized payment descriptions.

Verify translation catalogs for completeness.

Do not claim native-speaker verification for languages that have not received it.

Document remaining linguistic review requirements.

Worldwide readiness must include international calendars, date formats, currencies and time zones where applicable.

---

# 16. FINAL BUSINESS MODEL

## 40-DAY FREE TRIAL

Bilga will be free to download.

Every new user receives **40 days of full access**.

The trial begins on the first actual application launch.

All features included in the release must be available during the trial.

Do not require a payment method to start the trial.

Do not automatically charge users.

Do not require an account to begin using the offline application.

Display:

- Trial activation date.
- Remaining trial days.
- Clear purchase information.
- Lifetime purchase option.

Avoid aggressive or manipulative paywalls.

Users must be able to purchase lifetime access before the trial expires.

## AFTER 40 DAYS

After the trial expires, lifetime activation is required for continued creation and editing.

However:

**Never delete, corrupt, encrypt against the user's control, or hold existing personal data hostage.**

Unpaid users must retain the ability to:

- Read existing notes.
- View existing tasks and journal entries.
- Export personal information.
- Create a backup where appropriate.
- Purchase lifetime access.

Preserve existing local data indefinitely unless the user explicitly deletes it.

Make the read-only limitation clear.

Do not disable access to personal data merely to pressure users into paying.

## LIFETIME PURCHASE

The user pays once.

After successful purchase, the application becomes permanently unlocked for that valid entitlement.

There must be:

- No monthly subscription.
- No annual subscription.
- No recurring payment.
- No advertisements.
- No separate premium tiers.
- No mandatory feature-based purchases.

All included functionality is unlocked.

Use Google Play Billing.

Product ID:

`bilga_lifetime_unlock`

Use a non-consumable one-time in-app product.

Implement:

- Product retrieval.
- Purchase initiation.
- Purchase state handling.
- Pending transaction handling.
- Purchase verification.
- Purchase acknowledgement.
- Restore purchases.
- Refund handling.
- Revoked purchase handling.
- Local entitlement caching.
- Offline access after verified purchase.
- Safe error recovery.

Do not use a simple editable preference as the sole proof of purchase.

Use Play Billing's supported purchase lifecycle.

Where feasible, use secure entitlement verification without requiring unnecessary permanent backend infrastructure.

Recognize that offline entitlement verification cannot provide perfect resistance to tampering.

Do not claim impossible anti-piracy guarantees.

---

# 17. GLOBAL REGIONAL PRICING

Base reference price:

**USD $9.99**

This is the global reference price, not a requirement that every user pay exactly the same amount.

Apply regional purchasing-power-based pricing.

Use Google Play Console's country-specific pricing capabilities.

Initial suggested regional strategy:

| Region | Suggested reference price |
|---|---:|
| United States | $9.99 |
| Canada | $9.99 equivalent |
| Western Europe | $9.99 equivalent |
| Japan | $8.99 equivalent |
| South Korea | $8.99 equivalent |
| Uzbekistan | $3.99 equivalent |
| Kyrgyzstan | $3.99 equivalent |
| Kazakhstan | $4.99 equivalent |
| India | $2.99 equivalent |
| Other regions | $4.99–$9.99 |

These are proposals, not final approved country prices.

Prepare a reviewable country-by-country price configuration plan.

Do not activate regional prices without product-owner approval.

Important implementation rules:

1. Use the same lifetime product across supported markets.
2. Do not create separate functionality for cheaper markets.
3. Do not hardcode prices into the application.
4. Display the localized price returned by Google Play Billing.
5. Respect Google Play currency and tax handling.
6. Do not implement unofficial regional payment workarounds.
7. Do not use invasive location tracking.
8. Do not fingerprint devices to determine purchasing power.
9. A valid lifetime purchase remains valid regardless of later regional price changes.
10. Respect Google Play's country availability and purchasing restrictions.

The application must provide identical features to users regardless of their purchase region.

Regional pricing changes affordability, not product quality.

---

# 18. TRIAL SECURITY AND ANTI-ABUSE

Implement reasonable safeguards against abuse of the 40-day trial.

Consider:

- Reinstallation.
- Clearing application data.
- Restoring old backups.
- Device clock manipulation.
- Device changes.
- Offline operation.

However, privacy is more important than invasive tracking.

Do not implement unauthorized device fingerprinting or hidden identifiers.

A completely offline application without mandatory identity verification cannot guarantee perfect trial enforcement.

Acknowledge this engineering limitation.

Design the best practical, privacy-respecting solution.

Do not create a fragile trial mechanism that accidentally locks out legitimate users.

Include tests for trial expiration and clock changes.

---

# 19. SECURITY AND PRIVACY

Protect personal data carefully.

Implement and verify:

- Optional app lock.
- PIN.
- Biometric authentication.
- Correct lock behavior after backgrounding.
- Secure credential storage.
- Encrypted backups.
- Authenticated encryption.
- Strong key derivation.
- Database transaction safety.
- Safe import parsing.
- Attachment validation.
- Protection against archive path traversal.
- Minimal Android permissions.
- Secure temporary files.
- Safe deletion semantics.
- No embedded API secrets.
- No unnecessary telemetry.

Evaluate local database encryption without risking existing data.

Never weaken existing security protections simply to improve performance.

Prepare an accurate privacy policy.

Do not claim absolute security.

---

# 20. BACKUP AND RESTORE

Backup reliability is mandatory.

Implement:

- Local encrypted backup export.
- Local encrypted backup import.
- Google Drive backup.
- Google Drive restore.
- Cross-device restoration.
- Backup integrity validation.
- Backup format versioning.
- Backward compatibility.
- Attachment preservation.
- Cross-module relationship preservation.
- Restore progress.
- Clear error handling.
- Duplicate import handling.
- Transactional rollback.
- Recovery from interrupted restoration.

Existing backup files must remain readable whenever technically possible.

Do not overwrite data without clear consent.

Where relevant, support explicit merge and replace behavior.

Automatic backups may be offered as an optional user-controlled feature.

Do not introduce mandatory background network activity.

Test backup restoration using realistic generated data.

Compare restored records and attachments to the originals.

---

# 21. PERFORMANCE TARGETS

Optimize for ordinary Android phones, not only expensive flagship devices.

Focus on:

- Fast startup.
- Smooth navigation.
- Responsive editing.
- Efficient search.
- Low memory consumption.
- Low battery consumption.
- Efficient background work.
- Reasonable storage usage.
- Controlled APK size.
- Reliable operation on slower devices.

Test with large datasets.

Include thousands of notes and tasks.

Avoid unnecessarily expensive animations.

Do not block the main thread during large database or file operations.

Use appropriate indexing, pagination and lazy rendering.

Measure performance instead of relying exclusively on assumptions.

---

# 22. COMPLETE INTERACTION AUDIT

This section is extremely important.

The product owner does not want to repeatedly report that individual buttons are broken or incomplete.

Therefore, independently inventory and test every reachable:

- Screen.
- Button.
- Icon button.
- Menu item.
- Context menu.
- Dialog.
- Form.
- Text field.
- List action.
- Gesture.
- Navigation action.
- Settings option.
- Notification action.
- Purchase action.
- Backup action.

For each action, verify:

1. The expected behavior.
2. Correct input handling.
3. Correct state transition.
4. Correct database changes.
5. Correct persistence.
6. Correct navigation.
7. Proper cancellation.
8. Error recovery.
9. Localization.
10. Accessibility.
11. Automated test coverage.

A button with an `onPressed` callback is not automatically a completed feature.

A screen that only displays placeholder information is not a completed module.

Every required interaction must perform its intended operation.

---

# 23. QUALITY ASSURANCE

Implement comprehensive testing.

Required categories:

- Unit tests.
- Widget tests.
- Repository tests.
- Database tests.
- Migration tests.
- Integration tests.
- Android platform tests.
- Reminder tests.
- Purchase-flow tests.
- Backup tests.
- Restore tests.
- Localization tests.
- Security regression tests.
- Performance tests.

Use realistic test data.

Test complete workflows.

Examples:

### Notes

Create → edit → close → reopen → search → archive → restore.

### Tasks

Create → schedule → notify → complete → reopen.

### Recurring tasks

Create recurrence → complete occurrence → verify future recurrence.

### Habits

Create → record progress → edit history → verify statistics.

### Journal

Create entry → link task → search → restore from backup.

### Payment

Start trial → expire trial → purchase → unlock.

### Purchase restoration

Buy → reinstall → restore purchase → verify lifetime access.

### Backup

Export → restore to clean environment → verify data integrity.

### Migration

Upgrade old database → verify no data loss.

### Localization

Switch languages → verify UI → verify RTL → verify persistence.

### Security

Lock → background → reopen → verify authentication.

### Failure recovery

Interrupt write → retry → verify no data corruption.

Test real device behavior when hardware is available.

Do not claim device testing if only emulator testing was performed.

---

# 24. BUILD AND RELEASE

Prepare the complete Android release process.

Include:

- Clean Flutter source.
- Dependency verification.
- Reproducible build instructions.
- GitHub Actions CI.
- Analyzer checks.
- Automated tests.
- Debug APK.
- Signed release APK when credentials are available.
- Signed release AAB when credentials are available.
- Versioning.
- Release notes.
- Privacy policy.
- Store listing.
- Permissions documentation.
- Data Safety information.
- Product screenshots.
- Feature graphic preparation.
- Release-readiness report.

Run available commands, including:

`flutter pub get`

`dart format`

`flutter analyze`

`flutter test`

Relevant Android integration tests.

`flutter build apk`

`flutter build appbundle`

Use the project's existing build and verification scripts when appropriate.

Never claim that a build passed unless it actually passed.

Never fabricate test results.

If SDKs or credentials are unavailable, document the precise blocker.

Do not silently substitute a debug build for a release build.

Do not publish to Google Play without explicit authorization.

---

# 25. GOOGLE PLAY COMMERCIAL READINESS

Prepare Bilga for international Google Play distribution.

Requirements include:

- Correct package identity.
- Appropriate target SDK.
- Compatible Android permissions.
- Correct Play Billing implementation.
- Purchase acknowledgement.
- Accurate pricing presentation.
- Proper privacy disclosure.
- Data Safety declaration.
- Content rating guidance.
- Store listing assets.
- Supported language listing.
- Accurate app descriptions.
- Applicable testing-track requirements.
- Secure release signing.
- Purchase and refund state handling.

Do not falsely represent the 40-day trial as a Google Play subscription trial.

It is an application-managed free evaluation period followed by an optional one-time purchase.

No payment is collected automatically at expiration.

Check current Google Play policies before finalizing the release.

Document country-specific restrictions if they apply.

---

# 26. FUTURE UPDATES AND LONG-TERM MAINTENANCE

The product owner wants a complete application from its first release.

Do not intentionally ship an incomplete application with the expectation that essential functions will be added later.

Bilga 1.0 must be functionally complete within the agreed release scope.

However, maintainability remains mandatory.

Future development should not require constant feature additions.

Preserve the ability to provide:

- Security fixes.
- Android compatibility fixes.
- Billing compatibility fixes.
- Critical bug fixes.
- Necessary database migrations.

Avoid unnecessary recurring infrastructure costs.

Do not depend on permanent cloud services for ordinary offline functionality.

Purchased functionality should continue working without unnecessary online dependencies.

Voice commands are planned for a future release and are not required now.

---

# 27. AUTONOMOUS EXECUTION PROCEDURE

Execute this project in the following order.

## PHASE 1 — DISCOVERY

Inspect all accessible repositories and existing implementations.

Identify complete, incomplete, missing and broken functionality.

Check the current working tree.

Check existing CI.

Check historical documentation.

Determine which features require implementation.

Do not stop after analysis.

## PHASE 2 — ARCHITECTURE

Select the primary Flutter implementation.

Preserve working components.

Design shared models and module boundaries.

Plan safe migrations.

Determine how all modules interact.

Do not stop after architecture documentation.

## PHASE 3 — IMPLEMENTATION

Implement every required module.

Complete its business logic.

Complete its interface.

Complete its persistence.

Complete its error handling.

Complete its tests.

Integrate it with the rest of Bilga.

Proceed through all remaining modules.

## PHASE 4 — MONETIZATION

Implement the 40-day trial.

Implement lifetime purchasing.

Implement entitlement restoration.

Implement read-only access after trial expiration.

Implement localized price presentation.

Verify purchase behavior.

## PHASE 5 — FULL QUALITY AUDIT

Inspect every screen and interaction.

Fix defects.

Fix navigation problems.

Fix persistence errors.

Fix localization problems.

Fix performance regressions.

Fix accessibility problems.

Repeat verification.

## PHASE 6 — RELEASE PREPARATION

Run tests.

Build Android artifacts.

Prepare store materials.

Document external configuration.

Produce release-readiness evidence.

---

# 28. LONG-RUN CONTINUITY

The scope may exceed a single Codex session.

Do not falsely assume that all work can always be completed within one execution window.

Persist implementation progress in the repository.

Maintain these files:

`docs/FINAL_PRODUCT_SPEC.md`

`docs/IMPLEMENTATION_STATUS.md`

`docs/FEATURE_MATRIX.md`

`docs/TEST_REPORT.md`

`docs/RELEASE_READINESS.md`

`docs/KNOWN_LIMITATIONS.md`

Use explicit statuses:

- NOT STARTED
- IN PROGRESS
- IMPLEMENTED
- TESTED
- BLOCKED
- RELEASE READY

Document actual evidence.

At checkpoints, record:

- Branch.
- Commit.
- Completed features.
- Current implementation work.
- Remaining work.
- Failed tests.
- Unavailable resources.
- Next exact step.

This must make future Codex sessions capable of continuing without reconstructing the full project history.

Create logically coherent commits.

Use a dedicated development branch.

Do not force-push or destroy unrelated work.

Do not merge into the production branch without authorization.

---

# 29. YOUR DECISION-MAKING AUTHORITY

You are authorized to make ordinary engineering decisions independently.

Examples:

- Widget composition.
- Application architecture.
- State management.
- Navigation.
- Validation.
- Data indexing.
- Local storage design.
- Error handling.
- Testing methodology.
- Safe refactoring.
- Accessibility improvements.
- Performance optimization.
- Non-destructive UI improvements.

Do not repeatedly ask the product owner how every button should work.

Apply professional product engineering judgment.

However, obtain explicit approval for:

- Destructive data changes.
- Changing the application ID.
- Publishing to Google Play.
- Financial expenditures.
- Introducing recurring paid infrastructure.
- External transmission of private data.
- Public social sharing.
- Replacing signing keys.
- Irreversible repository operations.
- Activating final country-specific prices.

If one external service is unavailable, continue work on independent features.

---

# 30. ACCEPTANCE CRITERIA

Bilga is considered technically ready only when:

1. All required modules are implemented.
2. All required interfaces are functional.
3. No required button is decorative.
4. Notes are reliable.
5. Tasks work correctly.
6. Reminders are functional within Android's documented limits.
7. Habit tracking works correctly.
8. Journaling works correctly.
9. Planning is integrated.
10. Unified search works.
11. Cross-module relationships work.
12. The 40-day trial works.
13. Lifetime purchases work in verified test environments.
14. Purchase restoration works.
15. Localized pricing displays correctly.
16. Existing data is preserved.
17. Backup and restore are reliable.
18. Security controls work.
19. Localization remains intact.
20. The application has a polished and consistent design.
21. Critical tests pass.
22. Android build artifacts are generated successfully.
23. Release-blocking defects are resolved.
24. Remaining external requirements are documented.
25. The result is suitable for final real-device acceptance testing and Google Play submission.

Do not mark untested functionality as verified.

Do not confuse code completion with release readiness.

---

# 31. FINAL DELIVERABLES

Provide a final engineering report containing:

### A. Implemented functionality

Describe all actually implemented modules.

### B. Feature status

Show which modules are implemented, tested or blocked.

### C. Test evidence

Provide actual commands, environments and results.

### D. Data safety

Explain migration and backup verification.

### E. Monetization verification

Explain trial behavior, purchase flow, restoration and regional pricing integration.

### F. Build artifacts

Provide actual APK/AAB locations if generated.

### G. GitHub status

Provide branch, commits, CI results and pull request.

### H. External requirements

List only tasks requiring credentials, physical devices, payment configuration or product-owner approval.

### I. Known limitations

Clearly disclose unfinished or unverified functionality.

---

# 32. FINAL INSTRUCTION FROM THE PRODUCT OWNER

Bilga must become a complete, globally competitive commercial product.

The business model is final:

**40 days free. One lifetime purchase. No subscription. No advertisements.**

The base reference price is:

**USD $9.99**

Actual prices must be adapted to regional purchasing power using Google Play's supported pricing controls.

The product must be available to international audiences from its first public release, subject to applicable store and legal requirements.

All buyers receive the same features.

The product must be useful without an internet connection.

Personal data must remain under the user's control.

The interface must be elegant.

Every required button must work.

Every major feature must be complete.

Every important data operation must be reliable.

Do not leave required functionality as placeholders.

Do not stop after generating plans or documentation.

**START BY INSPECTING THE ACTUAL GITHUB REPOSITORIES AND CURRENT WORKING TREE.**

Then implement the product, verify its behavior and prepare the release.

If execution limits interrupt the project, preserve exact progress in GitHub so the next session can resume without requiring the owner to repeat individual feature instructions.

The goal is not to maximize code volume.

The goal is to deliver the best practical version of Bilga: reliable, useful, maintainable, secure and worth purchasing.

**BUILD THE PRODUCT. VERIFY THE PRODUCT. PREPARE THE PRODUCT FOR GLOBAL RELEASE.**
