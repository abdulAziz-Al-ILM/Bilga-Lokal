# Notes Android bosh ekran vidjeti

## Foydalanish

Android launcher’ning vidjetlar ro‘yxatidan **Notes vidjeti**ni qo‘shing yoki
Bilga → Yozuvlar sahifasidagi vidjet belgisini bosing. Vidjetdagi ⚙ sozlamalarni
ochadi. Har bir nusxa mustaqil ravishda oxirgi yozuvlar, alohida tanlangan
mahkamlangan yozuvlar yoki bitta teg bo‘yicha ishlaydi. Mahkamlash Notes’dagi
sevimlilar holatini o‘zgartirmaydi.

Yozuvni bosish aynan shu yozuv tahrirlagichini ochadi; + yangi yozuvni, qidiruv
belgisi Notes qidiruvini ochadi. Sovuq va qayta kirish intentlari mavjud ilova
qulfi va Core kirish oynalaridan o‘tadi. Trash’dagi yoki mavjud bo‘lmagan yozuv
ochilmaydi. Papka ichidagi yozuvlar ham tanlanadi. Oxirgi/teg manbalarida arxiv
chiqarilmaydi; mahkamlashda uni ataylab tanlash mumkin.

## Maxfiylik qarori

Foydalanuvchi **xavfsiz standart va har bir yozuv uchun alohida tasdiqlash**ni
ma’qullagan. Har bir Notes kartochkasida **Vidjetda ko‘rsatishga ruxsat berish**
kaliti bor; yangi va eski yozuvlar uchun standart **o‘chiq**. Yoqishda launcher
eski nusxalarni saqlashi va ularni o‘chirishni kafolatlab bo‘lmasligi tushuntiriladi.
Ruxsatsiz yozuvlar vidjet manbalaridan butunlay chiqariladi. Vidjet sozlamasida
yozuvni mahkamlashning o‘zi ruxsat bermaydi.

Standart `hidden` rejimida faqat ruxsatli yozuvlarning umumiy label’lari bor;
sarlavha, matn va teg nomlari chiqarilmaydi. `titles` va `preview` rejimlari ham
faqat foydalanuvchi maxfiy emas deb belgilagan yozuvlarni ko‘rsatadi. Sozlamada
launcher matn nusxasini saqlab qolishi mumkinligi aniq aytiladi. Shaxsiy matnni
vidjetga chiqarishga kafolatli xavfsiz usul sifatida ekran qulfiga tayanilmaydi.

Tasdiq ko‘rib chiqilgan ID+sarlavha+matn+teg nomlarining SHA-256 fingerprint’iga
bog‘langan. Notes SQLCipher bazasi **v12 → v13** migratsiyasi alohida
`note_widget_permissions` jadvali va invalidation trigger’larini yaratadi.
Sarlavha/matn/teg o‘zgarsa yoki yozuv trash’ga o‘tsa, tasdiq o‘chadi va yozuv
vidjetdan chiqariladi. Eski matnga qaytish, trash’dan tiklash yoki backup import
ruxsatni qayta yoqmaydi. Bir vaqtda tahrirlangan yozuvga eskirgan tasdiq berilmaydi.
Ruxsat barcha Notes vidjetlariga tegishli; har bir vidjetning hidden/titles/preview
cheklovi alohida saqlanadi. Oldingi per-widget tasdiqlar huquq bermaydi.

Private Space alohida `private_records` jadvalida; vidjet faqat oddiy `notes`,
`folders`, `note_tags`, `note_tag_links` bilan ishlaydi. O‘chirilgan papka
avlodlari ham chiqarilmaydi. App Lock yoqilganida vidjet doim umumiy rejimda.
Native render qurilma qulflanganini tekshiradi va screen-off/user-present
hodisalarida imkon qadar qayta chizadi. Launcher oldin ko‘rsatilgan, tasdiqlangan
**ommaviy** matnni saqlab qolishi mumkin; ushbu cheklov qoladi.

## Saqlash va integratsiya

- `NotesWidgetHost` mavjud Navigator/AppLock/CoreAccessGate ichida intentlarni
  kutadi. `NotesWidgetSync` faqat kirish ruxsat etilgach mavjud SQLCipher
  ulanishidan snapshot oladi. DB kaliti native vidjetga berilmaydi. Ruxsatlar
  shu bazadagi alohida jadvalda, eski yozuv/tarix qatorlari o‘zgartirilmaydi.
- Har bir widget ID uchun sozlama va snapshot
  `Context.noBackupFilesDir/notes-widgets/<id>.bin` faylida AES-256-GCM bilan
  shifrlanadi. Alohida Android Keystore alias: `bilga.notes.widget.v1`.
  AAD widget ID’ni bog‘laydi; API28+ kalit faqat qulf ochiq holatda ishlatiladi.
  Buzilgan/yo‘q/ochilmaydigan kesh faqat umumiy ko‘rinishga qaytadi. Plaintext
  fallback yo‘q. Mavjud Vault/DB/model kalitlari o‘zgartirilmaydi.
- Shifrlanmagan UI preferences’da faqat til, ranglar va umumiy yashirish bayrog‘i
  va shaxsiy ma’lumotsiz `permissionEpoch` hisoblagichi bor. Widget sozlamalari
  va yozuv ruxsatlari backup’ga kiritilmaydi; launcher restore yangi xavfsiz
  sozlamadan boshlaydi. Portable Notes/teg/history/trash backup formati v12 qoladi.
- `NotesChanges` faqat muvaffaqiyatli Notes/teg/folder/backup transaction’dan
  keyin signalsiz-payload hodisa beradi. 120 ms debounce snapshot’larni yangilaydi.
  Config revision eski Flutter engine eksporti yangi maxfiylik sozlamasini
  bosib ketishiga yo‘l qo‘ymaydi. Kartochkadagi ruxsat bekor qilinishi debounce’ni
  kutmaydi: DB commit → native epoch oshirish va darhol render → barcha ilova
  boshqaradigan Notes vidjet keshlaridagi rows/legacy approvals’ni tozalash →
  qayta eksport. Source/privacy/pin sozlamalari saqlanadi. Eski epoch bilan
  boshlangan eksport rad qilinadi; eski protokoldagi kesh ham render qilinmaydi.
  Boshqa ruxsatli yozuvlar yangi snapshot’da qaytadi. Launcher o‘zi saqlagan
  eski nusxalarni o‘chirish kafolatlanmaydi; ogohlantirish barcha 43 tilda bor.
  O‘chirilgan vidjet faqat o‘z keshini tozalaydi.
- PendingIntent immutable, explicit activity va widget/action/note ID bilan
  noyob URI’ga ega. Intentga sarlavha yoki matn yozilmaydi. Provider home-screen
  uchun. Yengil native handoff activity barcha bosishlarni bir xil MAIN/LAUNCHER
  intent bilan mavjud MainActivity’ga uzatadi; configure natijasini ResultReceiver
  orqali launcher’ga qaytaradi. URI faqat handoff’da qoladi. Bu audio_service
  qayta ishlatadigan Flutter engine’ni ikkita activity’ga ulash va URI’ni Dart
  boshlang‘ich route sifatida talqin qilish muammolarini oldini oladi. Barcha
  ekranlar mavjud ilova gate’laridan foydalanadi.
- Native vidjet DB’ni ochmaydi va tarmoq ishlatmaydi. Ilova yopiq bo‘lsa oxirgi
  ruxsatli shifrlangan snapshot ishlatiladi; davriy render DB’dan yangi matn
  o‘qimaydi. Ilovadagi Notes o‘zgarishlari commit’dan keyin darhol eksport qilinadi.

## O‘lcham, mavzu va tillar

API31+ `OPTION_APPWIDGET_SIZES` uchun turli RemoteViews variantlari; eski Android
uchun portrait/landscape variantlari bor. Launcher bergan o‘lchamga qarab 1–6
yozuv ko‘rinadi, kichik variantda matn va teglar yashiriladi. Snapshot 12 yozuv,
sozlamadagi mahkamlash 100 yozuv bilan cheklangan; qidiruv eski yozuvlarni
ham topadi. Sarlavha 160, matn 240 Unicode belgigacha, eng ko‘pi 3 teg (har biri
40 belgigacha). Scroll ro‘yxat o‘rniga ixcham kartochkalar ishlatiladi.

Bilga palitrasi va och/to‘q rejimi olinadi. `system` rejimi native snapshot’da
hozircha to‘q rangdan foydalanadi; launcher fonini to‘liq boshqarish mumkin emas.
43 JSON katalogdagi yangi label’lardan Android resurslari yaratiladi:

```sh
python3 tool/generate_notes_widget_strings.py
```

Android uchun standart English va barcha 43 til variantlari bor (`he` → `iw`).
Asosiy rasmiy Android hujjatlari:
[configuration](https://developer.android.com/develop/ui/views/appwidgets/configuration),
[responsive layouts](https://developer.android.com/develop/ui/views/appwidgets/layouts).

## Avtomatik tekshirish

`test/notes_widget_test.dart`: 26 test — xavfsiz default, manbalar, Private Space
va trash/papka/arxiv filtri, bir nechta vidjet, stable teg ID, rename/detach/delete,
fingerprint va Unicode chegaralari, commit/rollback, sync/access gate, 43 til,
eski yozuv qidiruvi, qulflangan sovuq/warm navigatsiya, cached engine resume’da
navbatdagi intentni olish, konfiguratsiyadan avvalgi ekranga qaytish, Notes’ni
o‘zgartirmaydigan mahkamlash, v12→v13 migratsiyasi, kartochkadagi haqiqiy switch
va dialog, eskirgan tasdiqni rad etish, native cache clearing’ni kutish, rollback,
trash/restore/delete, backup orqali ruxsat tiklanmasligi. Ruxsat filtri LIMIT’dan
oldin ishlashi ham tekshiriladi: yangi ruxsatsiz yozuvlar eskilarini siqib chiqarmaydi.

Native device runner sintetik ID/fayllardan foydalanadi, user bazasini o‘qimaydi:

```sh
cd android
source ../tool/android_env.sh
./gradlew :app:assembleDebugAndroidTest
adb install -r ../build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk
adb shell am instrument -w com.ilmmizan.bilga.test/com.ilmmizan.bilga.NotesWidgetChecks
```

10 native tekshiruv: xavfsiz default, ciphertext, Keystore readback, boshqa widget
ID’ga ko‘chirishni rad etish, GCM tampering, PendingIntent ajratilishi, immutable
intent va provider metadata, eski epoch/protokolni rad etish, shifrlangan rows’ni
tozalashda sozlamalarni saqlash. Faqat testning sintetik kesh fayllari tozalanadi.

2026-10-12: `flutter analyze` **No issues (4.3s)**; full Flutter test **205 PASS**.
Notes widget + teg targeted test **42 PASS**. Debug APK build **PASS** (36.0s);
ZIP CRC va Android v2 signature **PASS**.
API31 arm64 Tab16’da APK update **Success**, app ishga tushishidan oldin Notes
va To-Do bazalari SHA-256 aynan saqlangan. DB nusxalari kompyuterga olinmagan.
Haqiqiy qurilmada native tekshiruvlar **10 PASS**. Joriy APK bilan kartochkada
default OFF → ogohlantirishni tasdiqlash → ON → vidjetda sintetik
sarlavha/matn/teg ko‘rinishi → OFF → vidjetda `Hozircha bo‘sh` **PASS**.
Shundan keyingi read-only instrumentation barcha app-owned Notes vidjet
snapshot’larida rows bo‘shligini **PASS** deb tasdiqladi; mazmun eksport qilinmadi:

```sh
adb shell am instrument -w -e verifyEmptySnapshots true \
  com.ilmmizan.bilga.test/com.ilmmizan.bilga.NotesWidgetChecks
```

Oldingi vidjet sinovida Blackview launcher’da qo‘shish, xavfsiz default, + create,
kichik/keng resize, aynan yozuvni ochish va Notes qidiruvini ochish tekshirilgan.
Qidiruv oynasi ochilgan; avtomatik klaviatura chiqishi tasdiqlanmagan. Barcha
launcher/qurilma/tillar qo‘lda tekshirilgan degani emas; ko‘p nusxa va teg
manbalari avtomatik testlarda tekshirilgan. Planshetda `Bilga Widget Test
20261012` / `WidgetTest` sintetik fixture va bitta Notes vidjeti qoldi; asl
yozuvlar o‘zgartirilmadi. GitHub push qilinmagan.

APK: `build/app/outputs/flutter-apk/app-debug.apk`, **321450143 bytes**;
SHA-256 `6fad8283d76783773dc0cf1bc6a5059d1688cb0d8ac35506398e682ca3f1dc4d`.
Joriy ruxsat testlari loglari: `.buildlog/notes-widget-permissions/`;
oldingi vidjet sinovlari: `.buildlog/notes-widget/` (shaxsiy DB/UI nusxalari olinmagan).

## 2026-10-24 — WIP loading recovery (device validation pending)

Starting source/remote94dbf3f, existing Tab16 APK9a01ddd6… was reproduced stuck.
Read-only debug VM metadata (no key/content/context values exported) showed Notes
`_opening` unresolved, SQLCipher bilga.db handle already marked closed, and its
close-lock Future still pending. Todo's retained handle was open/idle. Thus Notes
never reached tag/note/permission loading: the temporary integrity-check connection
was waiting for Android closeDatabase, before its normal connection could open.
No definitive hardware, corruption or plugin-worker-race diagnosis is claimed.

Notes now requests integrity verification on its retained SQLCipher connection,
before configuration/schema migration. It uses the same database/key/schema and
still fails closed on integrity errors. Todo keeps the default existing open path.
Existing Notes migration remnants are retained on this path, not eagerly removed.
Fixed debug phase markers cover native handoff/store, vault/cipher/integrity,
config tags/notes/permissions and sync; no exceptions, SQL, paths, IDs or text log.
Each configuration read has a15-second bound, a localized43-language unavailable
message and explicit retry. Retry reuses the singleton pending database Future,
retains loaded configuration and never treats read failure as permission removal.
The existing AppLock screen supplies in-app authentication; host gating also
prevents the config from starting reads while locked. Native locked/corrupt cache
still fails closed without replacing existing encrypted settings. Production
source and four focused regression tests require validation before claiming PASS.
