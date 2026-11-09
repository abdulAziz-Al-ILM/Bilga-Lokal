# Known limitations

Overall product is IN PROGRESS. The master spec acceptance criteria are not yet met.

1. Notes editor is plain text. Rich formatting, dedicated checklist controls and full file import workflows remain required.
2. Tasks have no occurrence-safe recurrence, subtasks or projects yet. Prebuilt checklist templates exist; custom task templates remain incomplete.
3. Android task reminders were recovered, but current-branch notification delivery/reboot/device tests have not run. Standalone, habit and note reminders are incomplete. Android permissions and battery policies can delay delivery.
4. Journal still needs custom categories, calendar navigation, mood tracking and durable entry-history management. Public sharing remains disabled.
5. Planning uses original tasks and habits. A separate reminder timeline and durable note/task/journal relationships are not yet implemented. Large planner datasets have not been profiled.
6. FTS4 uses unicode61 token-prefix matching, ordered by recency. It is not semantic search or generative AI. Language-specific stemming, CJK segmentation, relevance ranking and tag-library-only result rows need improvement. Archived results require explicit inclusion; trashed content is excluded.
7. New purchases retain the recovered signed server-grant requirement. A Play product, public licensing key, HTTPS verifier and Ed25519 public key must be configured and the verifier must exist. No service is deployed and no financial infrastructure is activated. Trial works independently of Play availability. Real purchases are unverified.
8. Completely offline devices cannot learn of new refunds. Verified cached grants work offline; signed revocation is applied on later verification. Reinstall/clear-data cannot be reliably distinguished from first install without identity or tracking. No fingerprinting is used.
9. Read-only access uses a separate data browser, preserving the covered editor/navigation stack. Full access to historical deleted items remains through backups; the read-only browser excludes trash. Backup import requires active access and an explicitly confirmed merge; replacing existing records is not offered.
10. Local encrypted media backups are supported, but Drive currently declines media-bearing backups rather than silently omitting attachments. Streaming media to Drive remains required.
11. Existing device credential/biometric lock is retained. A separate app-specific PIN is not implemented. Database/attachment encryption depends on Android Keystore; uninstall/key loss requires a prior portable backup.
12. New UI translations in seven priority languages are drafts. New strings in other supported catalogs use English pending translation. Existing hardcoded startText UI still needs a full audit. Native-speaker verification has not occurred.
13. No current-branch APK/AAB, performance benchmark, native device run or full interaction audit is certified. Signing keys were not replaced or copied.
