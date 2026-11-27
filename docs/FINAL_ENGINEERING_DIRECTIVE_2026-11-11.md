# BILGA — COMPLETE THE PRODUCT
## FINAL ENGINEERING EXECUTION DIRECTIVE

We are now entering Bilga's final product-completion phase.

**This is an implementation order, not a request for another development plan.**

The owner wants substantial progress toward completing the full application today, November 11, 2026.

Prioritize actual implementation, automated testing, Android tablet verification and delivery of a usable review APK.

Do not sacrifice data integrity or falsely declare unfinished features complete to meet this target.

## 1. RESUME EXISTING WORK

Repository:
`abdulAziz-Al-ILM/Bilga-Lokal`

Development branch:
`development/global-launch`

Existing draft PR:
`#1`

First inspect the current Git state, working tree and latest commits.

Read:

- `docs/FINAL_PRODUCT_SPEC.md`
- `docs/IMPLEMENTATION_STATUS.md`
- `docs/FEATURE_MATRIX.md`
- `docs/ENGINEERING_REPORT.md`
- `docs/KNOWN_LIMITATIONS.md`
- `docs/TABLET_TEST_REPORT.md`

The previous checkpoint already included:

- Rich-text Notes functionality.
- Recurring tasks.
- Subtasks.
- Offline search.
- Today planning.
- Backup recovery.
- Trial and billing infrastructure.
- Android tablet testing.
- 191 passing Flutter tests.

Verify the current implementation and preserve everything that already works.

Do not unnecessarily repeat completed work.

## 2. FINAL PRODUCT STRUCTURE

Bilga must contain SIX fully developed core modules:

1. NOTES — Yozuvlar.
2. TASKS — Vazifalar.
3. HABITS — Odatlar.
4. FINANCE — Pul hisobi.
5. EXPERIENCES — Tajribalar.
6. BOOKS — Kitob kartochkalari.

Each module must function like a professional standalone application.

The six modules must also integrate into one coherent system.

Do not implement superficial feature demonstrations.

Complete all essential workflows, navigation, persistence, validation, recovery, filtering, search, statistics and user interactions.

---

# MODULE 1 — NOTES

Complete the existing rich-text Notes implementation.

Required capabilities:

- Rich-text editor.
- Headings and formatting.
- Lists and checklists.
- Images and attachments.
- Unlimited nested folders.
- Tags.
- Favorites and pinned notes.
- Archive and trash.
- Search and filtering.
- Note templates.
- Undo/redo.
- Reliable autosave.
- Version history.
- Restore previous versions.
- Sharing and exporting.
- Links between notes.
- Links to other Bilga modules.
- High-quality tablet and phone editing.

Fix remaining issues rather than replacing functional code.

Test large notes, rapid edits, backgrounding, storage errors and recovery.

# MODULE 2 — TASKS

Finish the existing task-management system.

Required capabilities:

- Tasks and subtasks.
- Projects and nested task lists.
- Priorities.
- Deadlines.
- Recurring tasks.
- Flexible recurrence rules.
- Task tags.
- Checklists.
- Task templates.
- Today, upcoming and overdue views.
- Calendar-based organization.
- Sorting and filtering.
- Bulk actions.
- Task duplication.
- Complete task-history semantics.
- Reminders.
- Snooze.
- Notification actions.
- Trash and restoration.
- Progress tracking.

Preserve correct recurrence behavior.

Test Android notification scheduling and task completion on the connected tablet.

# MODULE 3 — HABITS

Develop a complete habit-tracking application.

Include:

- Daily habits.
- Weekly habits.
- Custom schedules.
- Yes/no completion.
- Quantitative targets.
- Habit categories.
- Habit reminders.
- Streak tracking.
- Completion calendar.
- Weekly/monthly statistics.
- Progress visualization.
- Historical editing.
- Missed-day handling.
- Habit archiving.
- Search and filtering.
- Backup and restoration.

All calculations must be accurate.

Avoid misleading progress statistics.

Make the habit interface motivating, elegant and easy to use.

# MODULE 4 — PERSONAL FINANCE

Develop a complete offline-first personal finance manager.

This is a core module, not an optional add-on.

Required capabilities:

### Transactions

- Record income.
- Record expenses.
- Edit transactions.
- Delete transactions.
- Transaction history.
- Transaction search.
- Categories and subcategories.
- Custom categories.
- Notes and attachments.
- Transaction dates.
- Recurring transactions.

### Accounts

- Cash accounts.
- Bank/card account records.
- Multiple accounts.
- Transfers between accounts.
- Opening balances.
- Current balances.
- Balance reconciliation.

Accounts are locally maintained records, not actual bank integrations.

Do not initiate real bank transactions.

### Budgets

- Monthly budgets.
- Category budgets.
- Budget progress.
- Overspending indicators.
- Savings targets.
- Financial goals.

### Debts

- Money lent.
- Money borrowed.
- Partial repayments.
- Remaining balances.
- Due dates.
- Optional reminders.
- Debt history.

### Analytics

- Daily expenses.
- Weekly expenses.
- Monthly expenses.
- Income versus expenses.
- Category breakdown.
- Cash-flow charts.
- Spending trends.
- Savings progress.

### Currency support

- UZS.
- USD.
- KGS.
- KZT.
- EUR.
- Other ISO currencies.

Use precise decimal or minor-unit financial arithmetic.

Never use floating-point calculations that introduce monetary rounding errors.

Store the transaction currency explicitly.

Do not silently convert historical amounts.

For currency conversion, require a documented exchange rate, rate date and source or user-supplied rate.

Do not invent exchange rates.

### Security

Financial data must be private by default.

Maintain offline functionality.

Support encrypted portable backups.

Test transaction integrity, transfers, debts, balances and statistical calculations.

The finance module must be suitable for actual daily personal money management.

# MODULE 5 — EXPERIENCES

Develop a professional personal experience and reflection system.

This is more than a simple diary.

Required capabilities:

- Work experiences.
- Study experiences.
- Life experiences.
- Personal reflections.
- Spiritual/reflection category.
- Custom categories.
- Calendar view.
- Timeline.
- Experience titles.
- Detailed descriptions.
- Lessons learned.
- Decisions made.
- Outcomes.
- Tags.
- Attachments.
- Search.
- Templates.
- Entry history.
- Favorites.
- Privacy.
- Export.
- Backup.

Allow users to record:

- What happened?
- What did I learn?
- What worked?
- What failed?
- What should I do differently?
- What action should follow?

Support converting lessons into tasks.

Support linking experiences to relevant notes, habits and books.

Provide meaningful review and reflection tools without inventing AI-generated facts.

Do not activate public experience sharing.

# MODULE 6 — BOOK CARDS AND PERSONAL LIBRARY

Create a professional personal reading and knowledge-management module.

Required capabilities:

### Book library

- Add books manually.
- Book title.
- Author.
- Description.
- Cover image.
- Genre.
- Categories.
- Tags.
- Publication information.
- ISBN when available.
- Reading status.
- Reading start and finish dates.
- Reading progress.
- Ratings.
- Favorites.
- Bookshelves.
- Search and filtering.

### Book cards

Each book should support multiple knowledge cards:

- Quotes.
- Key ideas.
- Definitions.
- Summaries.
- Personal observations.
- Important lessons.
- Questions.
- Actionable insights.
- Page or chapter references.
- Custom card types.

### Reading workflow

- Currently reading.
- Want to read.
- Completed.
- Paused.
- Abandoned.
- Reading progress.
- Reading sessions.
- Reading history.
- Personal reading statistics.

### Knowledge integration

- Convert book insights into Notes.
- Create tasks from book insights.
- Link book ideas to experiences.
- Link related knowledge cards.
- Search across books and cards.
- Export personal notes and cards.
- Backup and restore library records.

### Flashcards

Where appropriate, provide reviewable flashcards with:

- Question/answer mode.
- Card review.
- Basic spaced repetition.
- Review scheduling.
- Review statistics.

Do not implement a misleading or mathematically incorrect spaced-repetition algorithm.

Do not automatically download copyrighted book content.

The book module should help users retain and apply knowledge, not merely maintain a list of titles.

---

# 3. SHARED APPLICATION CAPABILITIES

All six modules must work within one consistent system.

Implement and verify:

- Unified search.
- Cross-module linking.
- Consistent navigation.
- Shared tags where appropriate.
- Shared reminders.
- Shared attachment handling.
- Reliable backup and restoration.
- Import/export.
- Transactional database migrations.
- Consistent themes.
- Global localization.
- Accessibility.
- Offline functionality.
- Proper data ownership and privacy.

Every module must have appropriate empty states, error states and loading behavior.

Every actionable UI element must perform its expected operation.

No placeholder buttons.

No fake success messages.

No incomplete save operations.

# 4. DESIGN QUALITY

Give Bilga a coherent premium-quality interface.

The owner wants the experience of six polished applications within one unified product.

Use consistent typography, spacing, animations, navigation and visual components.

Preserve the seven existing themes.

Support dark and light modes.

Optimize the interface for both Android tablets and phones.

Avoid clutter.

Make common actions effortless.

Do not compromise usability for visual decoration.

# 5. MONETIZATION

Preserve the previously agreed business model:

- 40-day full-feature free trial.
- One-time lifetime purchase.
- Global reference price: USD $9.99.
- Regional purchasing-power-based pricing.
- No subscription.
- No advertisements.
- No automatic charges.
- Offline usage after valid lifetime activation.
- Read/export access after trial expiration.

Preserve existing user data.

Finish purchase-verification infrastructure without deploying paid services without authorization.

Do not publish or activate regional prices.

# 6. CONNECTED ANDROID TABLET

The owner has connected an Android tablet with USB debugging enabled.

Inspect:

`adb devices -l`

Use the existing tablet-testing infrastructure.

Previous work used an approved Blackview Tab16 Android tablet.

Verify the current connected device rather than assuming it is the same one.

CRITICAL:

Do not uninstall the production Bilga application.

Do not clear existing application storage.

Do not wipe user data.

Do not replace signing credentials.

Use the isolated Bilga Review application or another verified non-destructive testing strategy.

Build, install and test the new implementation on the tablet.

Use ADB, Android instrumentation tests, Flutter integration tests and logcat as appropriate.

Test the six modules end to end.

Fix defects found during device testing.

# 7. RESOURCE MANAGEMENT

The development computer has 16 GB physical RAM and previously experienced an out-of-memory event that terminated VS Code.

Avoid unnecessary memory pressure.

Do not run multiple expensive Gradle, Flutter and emulator processes concurrently.

Prefer the connected physical tablet over unnecessary simultaneous emulators.

Limit build concurrency where practical.

Monitor memory usage during expensive operations.

Avoid accidental overlapping builds.

Do not sacrifice code or data safety to reduce RAM usage.

# 8. WORK AUTONOMOUSLY

Do not stop after creating another feature matrix.

Do not ask the owner about ordinary UI or implementation details.

Make sensible engineering decisions.

Continue working through the remaining requirements.

For each module:

1. Audit existing implementation.
2. Identify actual gaps.
3. Implement missing functionality.
4. Add automated tests.
5. Run relevant tests.
6. Fix failures.
7. Test on the tablet where practical.
8. Commit verified changes.
9. Update progress documentation.
10. Proceed to the next module.

Maintain the existing development branch and draft PR.

Do not merge into main without approval.

Do not declare the whole application finished if required features remain.

# 9. VOICE CONTROL — FINAL PHASE ONLY

Voice control is planned, but it must NOT distract from completing the six core modules.

The execution order is:

**PHASE A:** Complete all six modules.

**PHASE B:** Test and fix the non-voice application on the Android tablet.

**PHASE C:** Generate a review APK and present actual verification evidence to the owner.

**PHASE D:** The owner personally tests the application and provides feedback.

**PHASE E:** Implement all approved corrections.

**PHASE F:** After explicit owner approval, begin voice-control development.

Voice control must eventually be capable of interacting with all six modules, including:

- Creating notes.
- Searching notes.
- Creating tasks.
- Managing reminders.
- Recording habits.
- Adding financial records with confirmation.
- Recording experiences.
- Searching books.
- Creating book cards.
- Retrieving personal knowledge.

Do not silently execute destructive or financial operations through voice commands.

Keep voice-control architecture modular.

**Do not activate microphone functionality or implement speech recognition until the owner approves Phase F.**

# 10. TODAY'S DELIVERY TARGET

The owner wants the product completed as quickly as possible, targeting November 11, 2026.

Make maximum practical implementation progress toward completing all six modules.

Prioritize working features and verified quality over lengthy explanations.

Do not claim that today's deadline makes unimplemented or untested functionality complete.

If the complete scope cannot be finished within the available execution window, preserve all verified progress and provide the precise remaining work.

Do not lose work between sessions.

Push checkpoints to GitHub.

Keep draft PR #1 updated.

# 11. FINAL ACCEPTANCE

The non-voice application is ready for owner review only when:

- All six required modules have complete primary workflows.
- Critical interactions function correctly.
- Database migrations preserve existing information.
- Cross-module connections work.
- Backup and restore work.
- No known critical data-loss defects remain.
- Flutter analyzer passes.
- Automated regression tests pass.
- Android build succeeds.
- Real-tablet testing is documented.
- A review APK is available.
- Known limitations are clearly disclosed.

The owner, not Codex, makes the final product-acceptance decision.

Do not begin voice implementation before that approval.

## START NOW

Inspect the latest development branch.

Resume from the latest verified checkpoint.

Focus specifically on completing Notes, Tasks, Habits, Finance, Experiences and Books.

Implement real functionality.

Test it.

Fix it.

Produce a working review APK.

**NO MORE PLANNING-ONLY RESPONSES. BUILD BILGA.**