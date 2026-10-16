# Bilga work and recovery

Read HANDOFF.md and the documentation for the feature being changed first.
Preserve user data and existing work; do not reset, clean, uninstall or clear databases.

## GitHub backup policy (user authorized, 2026-10-16)

- Work on `wip/todo-widget-recovery` in private `abdulAziz-Al-ILM/Bilga-Lokal`.
- Before large edits or long builds/tests, and after meaningful functional milestones,
  save source changes in a descriptive WIP/checkpoint commit and push this branch.
  Routine backup commits/pushes do not require repeated user approval.
- Inspect status/diff and staged contents before every commit/push. Exclude credentials,
  private signing seeds/keys, tokens, user databases/recordings/backups, APK/AAB/build
  output, caches/temp files and downloaded AI models. Do not force-add ignored paths.
  Public verification keys and model metadata/licenses are source configuration.
- Confirm repository visibility and destination before pushing. Push only the explicit
  WIP branch ref (no tags, other branches or submodules), without force. Verify remote
  branch SHA and GitHub commit existence after pushing.
- On Git corruption or unexpected Git failures, stop and report; do not delete or
  force-repair data. Preserve other local work when changing branches.
- Merging to main, releasing or making the repository public requires prior approval.
- Keep unfinished work labeled WIP; recorded checks are evidence only for the code
  and environment actually tested. Never claim an untested tablet flow succeeded.
