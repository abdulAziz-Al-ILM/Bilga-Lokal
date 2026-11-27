# Advanced Habits and local reminders — active implementation

Existing 22 built-in templates and legacy Habit JSON remain supported. The tracker adds dated weekday/interval/weekly/monthly schedules, pauses, categories, tags, favorites, completed-day goals and an opt-in local reminder time. Basic edits retain advanced metadata. Configuration merges the actual current check-ins in a transaction; dated prior rules and legacy target fallback preserve historical targets. Saved entries keep their original target.

Weekly/monthly streaks count completed periods; daily/interval streaks count scheduled completed days. A partial first/final period requires at most the number of available days. Pauses do not manufacture completions. Shared due logic stops asking for additional days after a quota is satisfied, while retaining a completed day for correction. Planner uses this same policy. Calendar/history editing allows actual past/today check-ins; future days are read-only. Statistics and goal progress come from saved completion data.

Notes capability19 prevents older guarded executables from reopening these payloads. No destructive migration is needed. Portable content17 protects advanced metadata from older importers; Experience-only16 and older supported snapshots remain valid. Backup restores complete Habit metadata and history. Reinstalling a Notes18 binary after a Notes19 owner database is opened is unsafe and must not be used as a workaround.

## Reminder design

Android keeps a separately encrypted, atomic `modules` policy mirror under the existing no-backup store/key. No title, cue, description, note, financial amount or database key crosses the Dart reminder channel. Only opted-in, non-archived Habits publish policy, created date, current/future rule windows and up to400 valid recent completed dates. Quota calculation needs at most the current31-day period. A denied app-lock/access gate prevents reading and publishing. Backup restore and confirmed Habit changes request a serialized refresh.

One AlarmManager wake schedules the next eligible local time; a non-exported receiver can deliver a generic private notification with Flutter closed. Boot, clock/timezone and exact-alarm permission changes reschedule cached policy. Date arithmetic handles interval anchors, long pauses, partial periods and DST gaps/overlaps. Completed days and fulfilled quotas suppress alerts. A persisted delivery key prevents repeating an already-claimed notification. Configuration activation avoids replaying historical times. Removing/disabling/archiving an opted-in source removes its cached policy and outstanding notification after refresh.

Notification navigation queues behind the existing application lock and core-access gate, validates the actual source, and opens its statistics page. Deleted sources are never recreated. Notification/exact-alarm permission and Android background restrictions are visible; permissions are requested only through explicit controls. Android/OEM restrictions may delay an inexact or background alarm. No claim of reboot/Doze/second-device acceptance is made before those tests execute.

## Evidence status

`/tmp/bilga-habit-reminder-focused6.log`:16 focused cases PASS (new mirror privacy/lock/archive tests, quota policy, advanced data/UI, shared search/planner). Pure Java calendar policy PASS (`tool/test_module_reminder_math.py`).43×886 catalog keys, non-voice and9 manifest guards PASS. Full current host suite311 PASS412s; additional real opt-in/time-picker/save/disable UI1 PASS12s (added after full discovery); analyzer8 clean. Secure native Habit cases, actual process-death alarm delivery and ordinary Notes19 Review APK remain pending. These features are not present in the installed2cb48a6 Experiences APK.

The native test runner is guarded to debug `com.ilmmizan.bilga.review`, snapshots/restores its encrypted original reminder mirror, and uses a reserved synthetic Habit policy without creating a personal database record. The delivery script validates manifest/signers before device operations and kills only the Review background process with `am kill`, never force-stops production or changes production data.
