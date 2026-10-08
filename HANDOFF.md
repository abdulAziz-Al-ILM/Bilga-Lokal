# Bilga — loyiha handoff’i

Yangilangan: **2026-10-08**  
Repo: **abdulAziz-Al-ILM/Bilga-Lokal** (private), branch: **main**.

> Bu hujjat keyingi AI/ishlab chiquvchi uchun joriy holatning asosiy manbasi. Repo faktlari, foydalanuvchi qarorlari va tekshirilmagan joylar alohida ajratiladi. Taxmin bilan “ishlaydi” deb yozilmasin.

## 2026-10-08 — yangi to‘liq ZIP va qat’iy offline qarori

Foydalanuvchi `bilga-full-source.zip` yubordi. Bu safar **to‘liq Flutter source** (2003 ta arxiv fayli, `lib/main.dart`, `android/`, `pubspec.yaml`, test va assets mavjud). Avvalgi `bilga-1.4.0.zip` incremental edi; undan farqini saqlang. Ushbu ZIP hali GitHub repo'ga bulk-import qilinmagan, shuning uchun repo source holatini noto‘g‘ri da’vo qilmang.

**Bilga Core uchun qat’iy qaror:**
- Faqat **offline/local AI**; cloud AI, online STT va internet search fallback yo‘q.
- Tarmoqdan yagona maqsadli foydalanish: foydalanuvchi ruxsati bilan Google sign-in/Drive backup va yangi qurilmada restore (billing/Play infratuzilmasi alohida platformaviy masala).
- Lokal yordamchi Bilga ichida notes, tasks, habits va boshqa o‘z yozuvlari bilan ishlaydi; tezlik va maxfiylik asosiy talab.
- O‘qib berish TTS bilan va faqat offline ovoz bilan; mavjud emas deb internetga jim ulanish bo‘lmasin.
- Umumiy AI, boshqa app integratsiyalari va cloud/subscription yordamchi — **kelajakdagi alohida Bilga Agent ilovasi**; Bilga private DB’ga default access berilmaydi.

**Kod auditi topilmalari:**
- `android/app/src/main/res/layout/agent_widget.xml` ichida `android:text="Bilga Agent"` allaqachon mavjud.
- `android/app/src/main/AndroidManifest.xml` receiver label `android:label="Bilga Agent"` allaqachon mavjud.
- Lekin hozirgi widget `com.ilmmizan.bilga.OPEN_AGENT` intent bilan **Core ichidagi** Agent ekranini ochadi: kelajakda alohida Agent app tayyor bo‘lmasdan ushbu widget’ni tashqi appga yo‘naltirmang.
- `lib/features/agent/agent_page.dart` da `onlineVoice` flag hamda `AgentAction.web`, `call`, `sms` kabi core/offline-only qaroriga zid yoki scope tashqarisidagi oqimlar bor. Bularni test va migratsiya bilan ajratish kerak.
- `FlutterTts` mavjud, ammo hozirgi `speak()` helper 3500 belgidan keyin kesadi va foydalanuvchi tanlagan notes’ni to‘liq serial/chunk tarzida o‘qish UX’i audit qilinishi kerak.
- Lokal inference modeli qurilma resurslariga qarab baholansin; offline degani har qanday qurilmada cheksiz erkin LLM suhbatini kafolatlamaydi.

## 1. Eng muhim joriy mahsulot qarori

### Bilga Core — shu ilova
Bilga Core shaxsiy va maxfiy ma’lumotlar uchun **lokal-first/offline-first** ilova bo‘lib qoladi.

Joriy biznes qarori:
- ilova bir marta o‘rnatiladi;
- **30–40 kunlik to‘liq trial** rejalashtiriladi;
- trial tugagach, taxminan **$7 bir martalik lifetime unlock**;
- Bilga Core uchun oylik obuna yo‘q;
- foydalanuvchi unlock qilgach, Core funksiyalaridan foydalanishda davom etadi;
- bug fix, Android compatibility, security va performance yangilanishlari davom etadi;
- katta yangi imkoniyatlarni Core ichiga cheksiz qo‘shib borish rejalashtirilmaydi.

**Aniq Play product ID, trialning 30 yoki 40 kun bo‘lishi va hududiy narxlar hali final qilinmagan.**

### Bilga Agent — Bilga Core ichida EMAS
Avvalgi package’da agent/Start/Turbo kodlari mavjud, lekin **2026-10-08 dagi yangi mahsulot qarori ularni Bilga Core’dan ajratishni talab qiladi**.

Kelajakdagi **Bilga Agent alohida ilova** bo‘ladi:
- boshqa ilovalar va xizmatlar bilan integratsiya;
- voice/STT + intent router;
- AI kerak bo‘lganda LLM;
- scheduled/background actions;
- cloud/server kerak bo‘lsa faqat Agent tomonida;
- ehtimol oylik subscription.

**Privacy chegarasi:** Bilga Agent Bilga Core’ning private database’iga avtomatik kira olmaydi. Alohida app, storage, permission va imkon qadar alohida data boundary saqlanadi. Kelajakda integratsiya kerak bo‘lsa, foydalanuvchi aniq obyektni alohida ulash/eksport orqali ruxsat beradi.

Shuning uchun eski quyidagi monetizatsiya qarorlari **superseded**:
- `bilga_agent_start` $2.49;
- `bilga_finance` $5;
- Turbo uchun alohida Bilga ichidagi sotuv.

Kodda ular hali uchrashi mumkin; bu joriy mahsulot strategiyasi emas.

## 2. 2026-10-08 da olingan source paket

Foydalanuvchi **`bilga-1.4.0.zip`** paketini berdi.

Muhim fakt:
- bu **to‘liq Flutter source emas**;
- paketning o‘z README’si bo‘yicha u **Bilga Private 1.3.0 ustiga qo‘yiladigan 1.4.0 incremental update**;
- manifest: **1.4.0+9**;
- requirement: **Bilga Private 1.3.0**;
- package 93 ta entry’dan iborat;
- unda faqat qo‘shilgan/yangilangan fayllar bor;
- demak undan yolg‘iz o‘zi reproducible full app repo tiklab bo‘lmaydi.

Shu sabab hozirgi asosiy blocker: **eng so‘nggi to‘liq lokal Bilga loyiha papkasini repoga xavfsiz import qilish**.

Package audit tafsilotlari: `SOURCE_PACKAGE_1_4_AUDIT.md`.

## 3. Package’dan tekshirilgan texnik faktlar

### Versiya va SDK
`pubspec.yaml`:
- app: **Bilga 1.4.0+9**
- Dart SDK: **^3.13.1**

### Asosiy dependencies
Package’da quyidagilar ko‘rinadi:
- `shared_preferences ^2.5.5`
- `sqflite ^2.4.3`
- `sqflite_sqlcipher 3.4.1`
- `crypto ^3.0.6`
- `cryptography ^2.8.1`
- `path_provider ^2.1.5`
- `archive ^4.0.7`
- `google_sign_in ^7.2.0`
- `http ^1.5.0`
- `file_picker ^10.3.7`
- `local_auth ^2.3.0`
- `video_player ^2.10.1`
- `audio_service ^0.18.18`
- `just_audio ^0.10.5`
- `audio_session ^0.2.2`
- `flutter_tts ^4.2.3`
- `url_launcher ^6.3.2`
- `in_app_purchase ^3.2.3`
- `in_app_purchase_android ^0.4.0`

Dev:
- `sqflite_common_ffi ^2.3.6`
- `sqlite3 ^2.9.4`
- `integration_test`
- `flutter_lints ^6.0.0`

### Lokal shifrlash
`lib/core/private_database.dart` SQLCipher orqali secure DB ochadi.
- Android MethodChannel `bilga/vault` dan 64 hex key kutiladi.
- Plain SQLite DB aniqlansa staged SQLCipher migration qilinadi.
- `integrity_check` bajariladi.
- `secure_delete=ON`, `temp_store=MEMORY`.
- Migrationda source/stage/old fayllar ehtiyotkor almashtiriladi.

Bu kod mavjudligi mutlaq xavfsizlik kafolati emas; full Android key storage implementatsiyasi to‘liq source importidan keyin audit qilinadi.

### Google Drive
Package’da `google_sign_in` va Drive `appDataFolder` oqimi bor.
README bo‘yicha:
- package: `com.ilmmizan.bilga`;
- Web OAuth client ID kerak;
- Android OAuth client SHA-1 debug va Play uchun alohida;
- Drive API yoqilishi kerak;
- Play App Signing SHA-1 bilan sinov kerak.

Backup upload qilingach qayta download qilinib byte-by-byte tekshiriladigan kod mavjud.

## 4. 1.4 package’da ko‘rinadigan funksiyalar

Package README bo‘yicha quyidagi imkoniyatlar mavjud yoki yangilangan deb ko‘rsatilgan; full source va device auditidan keyin darajalari aniq belgilanadi.

### Notes / To-do
- papkalar;
- qidirish;
- shablonlar;
- tahrirlar;
- savat;
- task deadline va priority;
- private text fieldlarda keyboard learning/suggestion’ni o‘chirish so‘rovi.

### Habit
- hafta kunlari;
- target/miqdor/birlik;
- trigger, small step, personal reason;
- partial progress;
- izoh;
- pause;
- 28 kunlik ko‘rinish;
- oldingi kunni tahrirlash;
- archive;
- attachments;
- schedule-history.

### Finance
- valyutali ledger;
- kirim/chiqim;
- qarz/qaytarish;
- qolgan qarz;
- oylik budget;
- report;
- search;
- CSV export;
- bank/karta ulash va pul o‘tkazish yo‘q.

**Joriy mahsulot qaroriga ko‘ra Finance Bilga Core unlock ichida bo‘lishi rejalashtiriladi; eski alohida $5 paywall qarori superseded.**

### Experiences / private records
- voqea;
- his-tuyg‘u;
- saboq;
- keyingi qadam;
- ish/hayot/hislar/shukronalik/ruhiy hayot/saboq kategoriyalari;
- qidirish;
- attachments.

### Book
- chapters;
- reja/qahramonlar;
- reorder;
- eski tahrirni tiklash;
- deleted chapter restore;
- reader font size;
- bookmark;
- TXT/EPUB export.

### Attachments/share
- rasm, video, fayl, havola;
- boshqa ilovalardan share qabul qilish.

### Ambience/audio
- fon audio;
- 15/30/60/90 daqiqalik sleep timer;
- volume write optimizatsiyasi;
- scene image decode limit.

### Localization
Validation log:
- **43 language × 249 strings**
- structural catalog check passed;
- bu lingvistik/native-speaker review degani emas.

## 5. Eski Agent kodi haqida

Package ichida:
- `lib/features/agent/agent_access.dart`
- `lib/features/agent/agent_hub.dart`
- `lib/features/agent/turbo_engine.dart`
- `lib/features/agent/turbo_page.dart`
- `optional/turbo/`

bor.

`agent_access.dart` eski Play product ID’larini o‘z ichiga oladi:
- `bilga_agent_start`
- `bilga_agent_turbo`
- `bilga_agent_turbo_upgrade`
- `bilga_finance`

Bu kod **legacy/in-transition** deb qaralsin. Bilga Core’ni release qilishdan oldin:
1. Agent UI/route/billing Bilga Core’dan chiqarilishi;
2. Finance alohida paywall bo‘lsa olib tashlanishi yoki yangi lifetime Core entitlement’ga moslashtirilishi;
3. eski purchase receipt’larni yo‘qotib yubormaslik uchun migration/compatibility qarori ishlab chiqilishi;
4. trial + lifetime unlock uchun yangi billing model yozilishi;
5. Agent source alohida kelajak repo/app’ga ko‘chirilishi mumkin.

## 6. Validation evidence — package ichidagi real log

`CHECK_RESULTS.txt` quyidagilarni qayd etadi:

- standalone Dart analyzer: **No issues found**
- agent grammar checks: PASS
- private/finance/encryption checks: **30 PASS**
- habit checks: **19 PASS**
- i18n structural: **43 × 249 PASS**
- note schema migration: **v1 → current ... v10 → current PASS**
- todo schema migration: **v1 → current ... v5 → current PASS**
- installer:
  - preflight PASS
  - backup creation PASS
  - checksum PASS
  - idempotent rerun PASS
  - unknown user edit rejection PASS
  - corrupt package rejection PASS

Lekin package o‘zi aniq aytadi:
- Android APK build bu validation workspace’da bajarilmagan;
- Flutter widget test to‘liq bajarilmagan;
- Google login real qurilmada tekshirilmagan;
- Play Billing real Play test accountda tekshirilmagan;
- Android SQLCipher integration real device’da tekshirilmagan.

Shuning uchun PASS loglari foydali dalil, lekin “release tayyor” degani emas.

## 7. APK

Foydalanuvchi `app-debug.apk` ham berdi.
- hajmi taxminan **207 MB**;
- u debug artifact;
- uni source repo’ga commit qilmaslik;
- Play release sifatida ishlatmaslik;
- package README ham test APK’ni Play Console’ga yuklamaslikni aytadi.

APK qaysi exact source commitdan yig‘ilganini hozir isbotlaydigan reproducible provenance yo‘q. Full source importidan keyin yangi APK o‘sha commitdan qayta yig‘ilib hash/commit bilan bog‘lanadi.

## 8. Maxfiylik va security — joriy yo‘nalish

Bilga Core:
- foydalanuvchi private notes/tasks/records’ni lokal saqlashi kerak;
- Agent alohida app bo‘lgani uchun uning Bilga DB’ga default access’i bo‘lmaydi;
- secret/token/keystore/release signing key repo’ga yozilmaydi;
- exported TXT/CSV/EPUB plaintext bo‘lishi mumkinligi UX’da ogohlantirilishi kerak;
- encrypted backup va uning paroli recovery uchun muhim;
- app uninstall/key loss holati alohida test qilinadi;
- logs’da private content chiqmasligi audit qilinadi.

Mutlaq xavfsizlik va’dasi berilmasin.

## 9. Hozirgi repo holati

Repo hozircha **to‘liq app source emas**.
Avvalgi auditda README-only bo‘lgan; HANDOFF qo‘shilgan.
2026-10-08 da incremental 1.4.0 package o‘rganildi, lekin u to‘liq 1.3.0 bazani o‘z ichiga olmaydi.

Shuning uchun package fayllarini repo root’ga ko‘r-ko‘rona yozish **noto‘g‘ri**: bu yetishmayotgan 1.3.0 fayllarni yo‘q deb ko‘rsatib, “full project” degan noto‘g‘ri holat yaratadi.

## 10. Keyingi eng muhim qadamlar

1. **Eng so‘nggi to‘liq lokal loyiha papkasini** topish: odatda `~/StudioProjects/bilga`.
2. Undagi source holati 1.4.0 update qo‘llangan holatmi tekshirish.
3. Source importdan oldin secret scan va `.gitignore`:
   - keystore;
   - passwords/tokens;
   - `google_config.json` ichidagi sensitive material;
   - user DB/backups;
   - build/cache;
   - local.properties.
4. To‘liq source’ni **Bilga-Lokal private repo**ga commit qilish.
5. Repo ichida real file map va architecture audit qilish.
6. Joriy mahsulot qaroriga muvofiq **Bilga Agent’ni Core’dan ajratish**.
7. Eski per-feature billingni **30–40 day trial + ~$7 lifetime Core unlock** modeliga qayta loyihalash.
8. Eski xaridor/receipt compatibility siyosatini tanlash.
9. Analyzer + unit/widget/integration + real Android device test + Play internal test.
10. Google Sign-in/Drive debug va Play signing bilan sinash.
11. Backup/restore va encrypted migration’ni real legacy dataset bilan tekshirish.
12. Release CI va reproducible build.
13. HANDOFF’ni har katta commit bilan yangilash.

## 11. Full source kelgach ishlatiladigan boshlang‘ich komandalar

```bash
cd ~/StudioProjects/bilga
git status --short
flutter --version
flutter doctor -v
flutter pub get
flutter analyze
flutter test --concurrency=1
flutter devices
```

Package ichidagi scriptlar full source’da mavjud bo‘lsa:
```bash
bash tool/check_start.sh
bash tool/build_test_apk.sh
```

Real device integratsiya:
```bash
flutter test integration_test/private_device_test.dart -d QURILMA_ID
```

## 12. Handoff yangilash qoidasi

Har katta o‘zgarishda:
- tekshirilgan commit SHA;
- real code state;
- test command + result;
- ochiq bug/risk;
- product decision;
- billing/privacy migration;
- keyingi 3–10 qadam

yangilansin.

Chatdagi eski qarorlar kod va ushbu hujjatdagi eng yangi mahsulot qaroridan ustun emas.
