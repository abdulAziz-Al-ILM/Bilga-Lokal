# BILGA — PROFESSIONAL PRODUCT COMPLETION

You are continuing development of Bilga.

Repository: `abdulAziz-Al-ILM/Bilga-Lokal`
Branch: `development/global-launch`
Existing draft PR: `#1`

Read the existing project documentation, inspect the actual source code and preserve all completed work.

## MAIN OBJECTIVE

Notes and Tasks are already relatively mature. Do not unnecessarily rebuild them.

The following four modules are significantly underdeveloped:

1. Habit Tracker
2. Personal Finance
3. Experiences
4. Books and Knowledge Cards

Transform these into professional, feature-rich applications within Bilga.

Each module must be useful enough to compete with specialized applications in its category.

Do not merely add more buttons. Build complete, intuitive user experiences.

## 1. COMPETITOR RESEARCH

Study the actual features, screenshots, navigation, onboarding and interaction patterns of these applications:

**Habits**
- Habitify
- Loop Habit Tracker
- Daylio

**Finance**
- Money Manager
- YNAB

**Experiences**
- Day One
- Daylio

**Books**
- Bookmory
- Readwise

Use official websites, documentation, publicly available screenshots and other legitimate sources.

If internet access is available, retrieve relevant reference screenshots into:

`references/habits/`
`references/finance/`
`references/experiences/`
`references/books/`

Create `references/README.md` identifying each source and its useful design patterns.

If screenshots cannot be downloaded, record their verified URLs and continue implementation.

Do not copy proprietary assets or reproduce competitors' interfaces exactly.

Adapt their strongest workflow principles to Bilga's existing design language.

## 2. HABIT TRACKER

Implement a complete habit management experience.

Required:

- Attractive dashboard.
- Daily and weekly habits.
- Custom schedules.
- Binary and quantitative habits.
- Habit reminders.
- Streaks.
- Calendar history.
- Weekly/monthly statistics.
- Progress charts.
- Custom categories.
- Editing historical records.
- Archiving.
- Search and filtering.
- Backup and restore.

### Built-in habit library

Include ready-to-use habit templates grouped by category:

Health:
- Drink water.
- Walk daily.
- Exercise.
- Sleep on time.

Learning:
- Read books.
- Study mathematics.
- Learn a language.
- Review lessons.

Productivity:
- Plan tomorrow.
- Complete important tasks.
- Reduce distractions.

Personal development:
- Keep a journal.
- Practice reflection.
- Develop a new skill.

Templates must be customizable.

Selecting a template opens a prefilled creation form. Nothing is permanently added without confirmation.

## 3. PERSONAL FINANCE

Complete the existing Finance system.

Preserve verified account, transaction-history and reporting functionality.

Add:

- Full category management.
- Category hierarchies.
- Monthly budgets.
- Budget warnings.
- Savings goals.
- Progress tracking.
- Recurring transactions.
- Debt deadlines.
- Debt reminders.
- Financial planning.
- Improved reports.
- Useful dashboard summaries.

### Built-in finance categories

Expenses:
- Food.
- Transport.
- Housing.
- Utilities.
- Internet.
- Education.
- Health.
- Shopping.
- Entertainment.
- Other.

Income:
- Salary.
- Business.
- Freelance.
- Gifts.
- Other.

Provide a guided first-use setup for:

1. Choosing a primary currency.
2. Creating a cash or bank account record.
3. Entering an opening balance.
4. Recording the first expense.
5. Creating the first budget.
6. Viewing the first report.

Do not create fictional financial transactions or balances.

All real financial records must originate from explicit user input.

Use exact monetary arithmetic.

## 4. EXPERIENCES

Build a sophisticated personal experience and learning journal.

Include:

- Attractive timeline.
- Calendar navigation.
- Custom categories.
- Tags.
- Favorites.
- Attachments.
- Entry history.
- Search.
- Reflection statistics where meaningful.
- Connections to tasks and notes.

### Built-in experience templates

Provide:

1. Daily reflection.
2. Lesson learned.
3. Successful experiment.
4. Failed experiment.
5. Important decision.
6. Work experience.
7. Study experience.
8. Personal achievement.
9. Problem-solving experience.
10. Weekly review.

For example, the "Failed experiment" template should contain:

- What was the objective?
- What did I try?
- What happened?
- Why might it have failed?
- What evidence supports that conclusion?
- What will I change next time?

These must be editable templates, not compulsory questionnaires.

Allow users to create their own templates.

Enable conversion of follow-up actions into Tasks.

## 5. BOOKS AND KNOWLEDGE CARDS

Develop a complete reading and knowledge-management system.

Required:

- Personal book library.
- Book covers.
- Author and metadata.
- Reading status.
- Custom shelves.
- Reading progress.
- Reading sessions.
- Calendar.
- Reading statistics.
- Quotes.
- Highlights.
- Notes.
- Knowledge cards.
- Question-answer flashcards.
- Review scheduling.
- Search and filtering.
- Export.
- Backup.

### Built-in card templates

Provide:

- Important idea.
- Quote.
- Definition.
- Personal explanation.
- Question and answer.
- Practical lesson.
- Summary.
- Actionable insight.
- Comparison.
- Critical observation.

### Ready-to-use reading workflows

Examples:

- Start reading a book.
- Record today's reading.
- Save an important idea.
- Create a flashcard.
- Review previous cards.
- Finish a book.
- Write a final summary.

Do not populate the user's library with fictional books presented as real records.

Sample content must be clearly marked as a demonstration.

## 6. UNIVERSAL BUILT-IN GUIDE SYSTEM

This is a critical requirement.

Every major module must contain an integrated help and guidance system.

**This is NOT AI.**

Implement a deterministic, automated, interactive tutorial system.

The user must never need another person to explain basic application workflows.

### Required features

Each module must provide:

- "How does this work?"
- "Get started"
- "Create my first item"
- "Explore features"
- "Show me how"
- "Help"

Support interactive guided tours.

### Example: Create a habit

1. User selects "Create my first habit."
2. App opens the correct screen.
3. App visually highlights the relevant control.
4. A small explanation appears.
5. User performs the required action.
6. App detects completion.
7. App advances to the next step.
8. The process continues until the habit is saved.
9. App explains where to track progress.

Implement equivalent workflows for Notes, Tasks, Finance, Experiences and Books.

### Technical requirements

Guides must:

- Highlight actual interface elements.
- Navigate to real screens.
- Detect user actions.
- Advance only when appropriate.
- Support Next, Back, Skip and Exit.
- Work after app restart where appropriate.
- Handle changed layouts.
- Work on Android tablets and phones.
- Support dark mode.
- Support localization.
- Support accessibility.
- Never create records without user confirmation.
- Never require an internet connection.
- Never depend on an AI model.

Use stable widget identifiers and a reusable tutorial engine.

Do not use fake screenshots as tutorials.

Guidance must interact with the real application interface.

## 7. EXPLAIN THE VALUE OF EACH MODULE

A new user must immediately understand:

1. What is this module for?
2. What can I accomplish with it?
3. How do I start?
4. What progress or results can I see?

A large empty screen containing only a `+` button is unacceptable.

Create useful first-run experiences, template galleries and meaningful empty states.

The interface should provide clear starting points without overwhelming the user.

Do not automatically insert large amounts of unwanted sample data into the user's real database.

Use previewable templates and explicitly selectable examples.

## 8. DESIGN

Preserve Bilga's existing visual identity.

Make all four modules feel like parts of the same premium application.

Improve:

- Navigation.
- Information hierarchy.
- Dashboards.
- Empty states.
- Template galleries.
- Forms.
- Statistics.
- Charts.
- Accessibility.
- Tablet layouts.
- Responsive behavior.
- Dark mode.
- Localization.

Avoid childish interfaces, excessive decoration and meaningless animations.

Aim for a clean, sophisticated, highly usable product.

## 9. EXISTING FEATURES AND DATA SAFETY

Preserve:

- Notes.
- Tasks.
- Current databases.
- Existing migrations.
- Backup compatibility.
- Trial architecture.
- Lifetime purchase architecture.
- Package identity.
- Existing user data.

Do not uninstall or clear the production Bilga application.

Use isolated test data.

Keep the current development branch and draft PR.

## 10. TESTING

Implement automated tests for every significant workflow.

Use the connected Android tablet for safe integration tests.

Verify:

- Creating records.
- Editing records.
- Deleting records.
- Restoring records.
- Templates.
- Guided tutorials.
- Search.
- Filtering.
- Statistics.
- Data persistence.
- Backup and restore.
- Navigation.
- Localization.
- Accessibility.
- Small-screen behavior.

Fix failures before considering a feature complete.

Do not mark untested features as verified.

## 11. VOICE CONTROL

Voice control must remain disabled.

Do not add microphone permissions or speech recognition yet.

Voice functionality will be implemented only after the owner reviews and approves the completed non-voice application.

## 12. EXECUTION

Do not stop after writing a plan.

Inspect the current project and begin implementation.

Work systematically through the four modules and the shared tutorial system.

Make ordinary engineering decisions autonomously.

Commit and push verified checkpoints.

Update the existing implementation reports.

Do not merge into main.

Do not publish to Google Play.

Do not activate paid services.

If the full scope exceeds the execution window, preserve exact progress and continue from the next checkpoint.

## FINAL EXPECTATION

Bilga must feel like six complete professional applications combined into one coherent product.

Notes and Tasks are already relatively mature.

Your immediate priority is to bring Habits, Finance, Experiences and Books to the same standard.

Every module must contain meaningful built-in templates and an automated step-by-step help system.

Users should understand the product without external assistance.

**IMPLEMENT THE FEATURES. TEST THEM. FIX THEM. DELIVER A WORKING REVIEW BUILD.**