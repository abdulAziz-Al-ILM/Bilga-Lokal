# Bilga 1.4.0 incremental package audit

Sana: 2026-10-08  
Manba: foydalanuvchi taqdim etgan `bilga-1.4.0.zip`.

## Xulosa

Bu ZIP **to‘liq Bilga source emas**. U package README va manifest bo‘yicha **Bilga Private 1.3.0 ustiga o‘rnatiladigan incremental 1.4.0 update**.

Shuning uchun uni repo root’ga full project sifatida import qilish xavfli: bazaviy 1.3.0 dagi o‘zgarmagan fayllar yo‘q.

## Paket faktlari

- version: `1.4.0+9`
- requires: `Bilga Private 1.3.0`
- archive entries: 93
- `pubspec.yaml` mavjud
- 43 ta i18n katalogi mavjud
- selected `lib/`, `test/`, `integration_test/`, `tool/`, `android/app/build.gradle.kts` update fayllari mavjud
- installer va checksum manifest mavjud

## Validation log

`CHECK_RESULTS.txt`:
- Dart analyzer: No issues found
- agent checks: PASS
- private/finance/encryption: 30 PASS
- habit: 19 PASS
- i18n: 43 × 249 structural PASS
- notes migrations: v1–v10 → current PASS
- todo migrations: v1–v5 → current PASS
- installer integrity/idempotency checks: PASS

Not executed in that workspace:
- Android APK build
- full Flutter widget/device test
- real Google sign-in
- Play Billing purchase/restore
- Android SQLCipher real-device integration

## Product-strategy mismatch found

Package contains embedded Agent and old billing products:
- `bilga_agent_start`
- `bilga_agent_turbo`
- `bilga_agent_turbo_upgrade`
- `bilga_finance`

2026-10-08 owner decision supersedes this:
- Bilga Core: 30–40 day trial, then ~$7 one-time lifetime unlock;
- Finance and normal Core capabilities should not remain separate recurring/per-feature product unless owner later changes decision;
- Bilga Agent becomes a separate future application and must not have default access to Bilga Core private DB.

## APK

User also supplied `app-debug.apk` (~207 MB).
It is treated as a debug artifact, not source-of-truth and not a Play release.
Do not commit it to the source repo.
