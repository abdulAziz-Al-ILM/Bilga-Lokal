Continue developing Bilga from the existing `development/global-launch` branch and draft PR #1.

Read all existing project documentation, especially:

- `docs/FINAL_PRODUCT_SPEC.md`
- `docs/IMPLEMENTATION_STATUS.md`
- `docs/FEATURE_MATRIX.md`
- `docs/ENGINEERING_REPORT.md`
- `docs/KNOWN_LIMITATIONS.md`
- `docs/RELEASE_READINESS.md`

## NEW DEVELOPMENT INSTRUCTIONS

The product owner has connected an Android tablet to this computer via USB and enabled USB debugging.

You are authorized to use this tablet for development testing, subject to the data-safety restrictions below.

Your current objective is to complete every required non-voice functionality, verify the application on the actual tablet, and prepare a polished build for the product owner's personal review.

### 1. COMPLETE ALL REMAINING FUNCTIONALITY

Continue implementing everything required by `FINAL_PRODUCT_SPEC.md`.

Prioritize:

1. Professional rich-text Notes editor.
2. Recurring tasks, subtasks, projects and custom templates.
3. Complete reminders and notifications.
4. Complete habit tracking.
5. Journal history, calendar and categories.
6. Durable relationships between notes, tasks, habits and journal entries.
7. Unified planning and search improvements.
8. Reliable attachments and media backups.
9. Application security, PIN and biometric functionality.
10. Complete 40-day trial and lifetime purchase architecture.
11. Purchase verification backend implementation.
12. Localization, accessibility and UI/UX improvements.
13. Full interaction and regression testing.

Make every required feature functional from beginning to end.

Do not leave placeholder buttons or incomplete workflows.

### 2. USE THE CONNECTED ANDROID TABLET

First run:

`adb devices -l`

Identify the connected Android device.

If authorization is required, report it and wait for the device owner to approve the USB debugging prompt.

Inspect the Android version, device capabilities and existing Bilga installation.

**DATA SAFETY IS CRITICAL.**

Before installing or updating Bilga:

- Check whether Bilga is already installed.
- Inspect the current application package and signing compatibility.
- Do not uninstall the existing application.
- Do not clear its storage.
- Do not factory reset the tablet.
- Do not run destructive ADB operations.
- Do not overwrite or reset existing user data.
- Do not assume a Git repository backup protects Android application data.

If the tablet contains an existing Bilga installation and the test APK cannot safely update it, use an isolated emulator or another safe test environment.

Do not remove the installed application to bypass a signature mismatch.

Use the tablet for non-destructive tests whenever possible.

Run Android integration and UI tests against isolated test data.

Verify:

- Application launch.
- Navigation.
- Notes creation and editing.
- Tasks.
- Notifications.
- Habits.
- Journal.
- Search.
- Backup.
- Themes.
- Languages.
- App lock.
- Lifecycle handling.
- Screen rotation.
- Keyboard behavior.
- Performance.

Use native Android tooling, ADB, logcat, Flutter integration tests and UI automation where appropriate.

Do not claim that a feature was physically tested unless it actually ran on the device.

### 3. VOICE FUNCTIONALITY IS EXPLICITLY DEFERRED

DO NOT implement voice commands now.

DO NOT add microphone permissions.

DO NOT add speech recognition.

DO NOT add voice activation.

DO NOT implement voice AI.

Complete all non-voice functionality first.

Preserve a modular architecture that supports future voice integration.

Voice functionality will be considered only after the product owner personally reviews and approves the completed non-voice application.

### 4. PRODUCT OWNER ACCEPTANCE GATE

The development process has two distinct approval stages.

**Stage A — Functional Completion**

Implement and test all non-voice features.

Produce a polished Android build suitable for personal review.

Run all available automated tests.

Verify the connected tablet where safe and possible.

Fix defects found during testing.

**Stage B — Owner Review**

After Stage A, provide:

- A working APK.
- A verified feature matrix.
- Test results.
- Tablet testing evidence.
- Known limitations.
- Instructions for reviewing the application.

The product owner will personally use the application and provide feedback.

Do not assume that passing tests constitutes final product approval.

The owner may request changes to UI, functionality, navigation or behavior.

Implement those changes and repeat relevant tests.

**Only after explicit owner approval may voice functionality be added.**

Do not publish to Google Play without separate explicit approval.

### 5. CONTINUE AUTONOMOUSLY

Do not stop after writing another roadmap.

Implement the remaining features.

Make ordinary engineering decisions independently.

Avoid requesting approval for individual buttons, screens or standard technical decisions.

Preserve all existing user data and compatibility.

Continue using `development/global-launch`.

Maintain and update draft PR #1.

Commit and push verified checkpoints.

Update the implementation documentation after each meaningful milestone.

If execution limits interrupt the process, preserve the exact continuation point.

Do not merge into `main`.

Do not publish or activate paid services without authorization.

### 6. FINAL DELIVERABLE

Deliver a complete non-voice Bilga Android application for the owner's review.

Provide:

- APK.
- Feature completion report.
- Test results.
- Connected-tablet verification results.
- Data compatibility verification.
- Remaining external setup requirements.
- Updated GitHub PR.
- Exact instructions for personal acceptance testing.

The goal is to finish the application before the product owner starts reviewing individual details.

**START IMPLEMENTING NOW. DO NOT STOP AT PLANNING.**
