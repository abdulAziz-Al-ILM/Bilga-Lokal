# Bilga

Offline-first Flutter/Android productivity app by ILM Mizan.

Current authoritative scope: [final product specification](docs/FINAL_PRODUCT_SPEC.md).
Business model: **40 days free, then one lifetime purchase. No subscription or ads.**
Existing data remains readable and exportable after trial expiry. The same features apply in all purchase regions; the app displays the localized price returned by Google Play.

**Development in progress; not release ready.** [Feature status](docs/FEATURE_MATRIX.md), [test evidence](docs/TEST_REPORT.md), [limitations](docs/KNOWN_LIMITATIONS.md), [continuation checkpoint](docs/IMPLEMENTATION_STATUS.md), [source recovery](docs/SOURCE_RECOVERY.md), [release requirements](docs/RELEASE_READINESS.md).

```sh
flutter pub get
dart format lib test
flutter analyze
flutter test --concurrency=2
flutter build apk --debug
```

Flutter 3.47.8, Dart >=3.13.1; Android min API 26. Preserve `com.ilmmizan.bilga`, `bilga.db`, `bilga_todo.db` and existing signing identity. Migrations are additive. Never delete databases to fix a schema error. Release builds require existing signing configuration in ignored `android/key.properties`; no debug-key fallback.

43 locale catalogs and seven palettes are retained. Translation coverage does not imply native-language validation. Google account is optional and used only for explicitly requested Drive backups. Text assistance uses local search with source references; speech features are outside this release scope.

Root historical handoffs describe earlier prototypes/decisions; the master spec and current docs above take precedence.
