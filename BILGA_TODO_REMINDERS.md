# To-Do muddat holati, eslatmalar va Android vidjeti

## Ma’lumotlar va migratsiya

To-Do SQLCipher bazasi v6 → v7. `todos`, `todo_folders`, eski priority,
`due_at`, trash va timestamps qayta yozilmaydi. Yangi `todo_reminders` jadvali
`todo_id`, `enabled`, `remind_at`, `revision`, `fired` saqlaydi. Standartda eski
yoki yangi vazifaga eslatma yoqilmaydi; editor’dagi kalit bilan tanlanadi.
`remind_at` deadline’dan alohida. Snooze `due_at` va task timestamps’ga tegmaydi.
Bajarish, trash, permanent delete yoki deadline almashtirish trigger orqali
eski reminder avlodini bekor qiladi. Eski UI/import/native event yangi avlodni
tiklay olmaydi. Native snooze/delivery event’lari revision bo‘yicha SQL’ga
transaction’da olinib, shundan keyingina native queue’dan tasdiqlanadi.

Backup portable Notes schema12 saqlanadi; Todo schema7 reminder ta’riflarini ham
olib yuradi, v6 backup’lar qabul qilinadi. Restore yangi task IDs/revision yaratadi,
mavjud vazifalarni almashtirmaydi. O‘tgan reminder restore’da fired bo‘lib,
birdan tarixiy eslatmalar yog‘ilmaydi. Ruxsat/overlay/vidjet sozlamalari va native
kesh device-local, backup qilinmaydi. Eski Notes consent jadvali backup’ga kirmaydi.

## Vaqt va kartochka

Lokal kalendar sanalari bo‘yicha 3+ kun yashil, 2 kun sariq, 1 kun/bugun qizil;
aniq vaqt yetganda overdue qora (dark’da kontrastli kulrang), done/muddatsiz
neytral. Rang border va past kontrastli statik grid’da; ustuvorlik badge’i chiqarildi.
Priority qiymatlari va filtrlari saqlangan. Widget ham shu qoidani Java Time’da
hisoblaydi. Lokal offsetsiz ISO wall time timezone bilan ko‘chadi; `Z`/offset
ko‘rsatilgan eski sana o‘z instant’ini saqlaydi. Kalendar kunlar DST’dagi 23/25
soatlik farqdan ajratilgan. Java Time’da mavjud bo‘lmagan DST vaqti oldinga
normallashadi, overlap’da oldingi offset tanlanadi. Qo‘lda vaqt tanlaganda
qurilma picker’i/lokal timezone ishlatiladi; snooze “ertaga” lokal soatni saqlaydi.

## Reminder va Android

`TodoSync/Host` mavjud Navigator, AppLock/CoreAccessGate ortida. Native kod
SQLCipher’ni ochmaydi va DB/Vault kalitlarini olmaydi. Alohida Android Keystore
AES-256-GCM kaliti bilan atomic `noBackupFilesDir/todo-reminders/state.bin`
mirror/event queue saqlanadi. Plaintext/tarmoq fallback yo‘q. Standartda native
mirror’da ham task sarlavhasi yo‘q; faqat ko‘rsatishga alohida rozilik berilganda
bounded title eksport qilinadi. Description eksport qilinmaydi.

Native `AlarmManager` faqat **bitta navbatdagi** RTC alarm’ni saqlaydi: pending
reminder yoki widget uchun keyingi deadline/yarim tun. Exact ruxsat bo‘lsa
`setExactAndAllowWhileIdle`, aks holda `setAndAllowWhileIdle` ishlaydi. Permission
race’da SecurityException tutib inexact’ga qaytiladi. BOOT_COMPLETED,
USER_UNLOCKED, MY_PACKAGE_REPLACED, TIME_SET, TIMEZONE_CHANGED va exact ruxsat
berilishi qayta scheduling qiladi. Force-stop yoki OEM fon cheklovini chetlab
o‘tmaydi; qayta ochilganda sync tiklanadi. Qurilma qayta yoqilgach private storage
uchun birinchi unlock kerak. Takroriy alarm task’ni fired qilinganidan keyin
qayta notification/overlay yaratmaydi; eski avlod event’i rad qilinadi.

Android 13 POST_NOTIFICATIONS faqat user reminder yoqqanda/sozlamadan so‘raladi.
High importance sound/quiet kanallari alohida, foydalanuvchi channel va DND
sozlamalari hurmat qilinadi. Heads-up yoki aniq yetib kelish kafolatlanmaydi.
Settings’da notification, exact, overlay, battery va channel sahifalariga kirish
bor. O‘chirilgan/bajarilgan vazifaga tegishli notification bekor qilinadi.

Notification’dagi **Bajarildi** app’ni ochib, mavjud lock’dan keyin tasdiqlaydi;
**Kechiktirish** gated bottom sheet ochadi. 5/10/30/60 daqiqa, ertaga va manual
future vaqt bor. Vidjet completion ham xuddi shu himoyadan o‘tadi. App oldinda
bo‘lsa reminder pastki Material sheet’da keladi. Native intentlar faqat ID/action,
immutable va alohida URI’li; title/body intentga yozilmaydi. Handoff bir xil
MAIN/LAUNCHER intent’dan foydalanib cached audio_service Flutter engine bilan
mos ishlaydi. Eski editor keyingi completion yoki folder move’ni ortga qaytarmaydi.

## Ixtiyoriy overlay va offline ovoz

Overlay standart OFF. User yoqqanda 43 tilda sabab tushuntirilib Android
SYSTEM_ALERT_WINDOW sahifasiga o‘tiladi; startup’da so‘ralmaydi. Faqat haqiqiy
due reminder, ruxsat va foreground-start sharoiti mos bo‘lsa
TYPE_APPLICATION_OVERLAY yaratiladi. Background exact alarm exemption’dan
foydalaniladi; inexact/background cheklovida oddiy action notification qoladi.
SYSTEM_ALERT_WINDOW’ning o‘zi Android15+ FGS exemption deb qabul qilinmaydi.

Panel shortService ichida, START_NOT_STICKY, eng ko‘pi 45s, bir dona, dismiss,
done, snooze presets va manual action’ga ega. Ekranning qolganini bosish mumkin;
NOT_FOCUSABLE/NOT_TOUCH_MODAL, FLAG_SECURE, obscured-touch filtering ishlatiladi.
Screen-off/app’ga qaytish/dismiss/snooze’da yopiladi. Qulfda panel umuman chiqmaydi.
Title standart OFF; faqat user alohida maxfiylik ogohlantirishini tasdiqlaganda
ko‘rsatiladi. Launcher oldin chiqarilgan nusxalarni saqlashi mumkinligi ochiq
aytiladi; ularni barcha launcherlardan kafolatli o‘chirish da’vosi yo‘q.
Bir nechta reminder bir vaqtda kelsa, yangi panel oldingi panelni almashtiradi;
oldingi speech/taymerlar bekor qilinadi va kechikkan TTS callback avlod bilan
tekshiriladi.

Tovush sozlanadi, offline TTS opt-in. Faqat mos locale’dagi installed,
`isNetworkConnectionRequired=false` voice tanlanadi; cloud/STT/audio upload yo‘q.
TTS init/voice/speak xatosi yoki timeout’da notification signaliga qaytiladi,
foydalanuvchiga ovoz xatosi chiqarilmaydi. Murojaat matni 60 belgi bilan cheklangan;
TTS faqat umumiy eslatmani aytadi, task matnini o‘qimaydi. Service ovoz-only bo‘lsa
eng ko‘pi 15s. Android17 fon audio cheklovida custom background TTS ishlatilmaydi,
tizim notification signaliga qaytiladi. Volume/DND’ni majburan o‘zgartirish yo‘q.

## To-Do vidjeti

Har bir nusxada bugungi / yaqin 3 kalendar kun va overdue / faqat overdue manbasi
va title opt-in mustaqil. Default generic `Vazifa N`; due vaqt va done/umumiy
progress bor. + create, row exact editor, checkbox gated completion, gear config.
API31 responsive sizes va eski portrait/landscape layout; 1–6 kartochka.
Kichikda sana matni yashiriladi, rang border/grid saqlanadi. Notes vidjeti,
teglar va boshqa modullar o‘zgartirilmaydi. AppLock yoqilganida tashqi title
chiqarilmaydi; keyguard ham native render’da tekshiriladi. Android host eski
snapshot’i haqida yuqoridagi cheklov amal qiladi.

## Tekshirish va cheklovlar

2026-10-12: yakuniy `flutter analyze` **No issues, 13.0s**. Oldingi to‘liq
Flutter sinovi **219 PASS** (109s); keyingi editor/runtime sinovi **6 PASS**
(9s), jumladan deadline o‘zgarganda mustaqil reminder saqlanishi.
Yangi testlar v6 migration, trigger/rollback/FK, snooze/deadline ajralishi,
backup v6/v7, calendar transitions, 43 locale, native mirror privacy, event ack,
real editor switch, stale editor va AppLock completion’ni tekshiradi.
Blackview Tab16 API31 arm64 native To-Do **16 PASS**, Notes **10 PASS**:
DST spring/fall, offset/invalid time, early/duplicate refusal, event data,
widget filtering/progress input, encrypted readback/tamper, immutable unique
PendingIntent, home-only provider metadata va full-screen permission yo‘qligi.

Keyingi to‘liq takroriy urinishlar host tester SIGSEGV va vaqtincha disk to‘lishi
sabab tugamadi; bo‘sh loyiha diskidagi TMPDIR bilan oxirgi urinish foydalanuvchi
turn’ni uzganida 189 PASS holatida qolgan. Bu oxirgi urinish to‘liq PASS deb
hisoblanmaydi. Foydalanuvchi ko‘rsatmasiga ko‘ra o‘tgan testlar yana takrorlanmadi.
18:00 dagi tekshiruvda `/tmp` joylashgan diskda 11 GB, `/home`da 20 GB bo‘sh;
hech qanday fayl o‘chirilmadi. Host runtime barqarorligi tuzaldi degan da’vo yo‘q.

```sh
source tool/android_env.sh
flutter analyze
flutter test --concurrency=1 --reporter expanded
flutter build apk --debug
./android/gradlew -p android :app:assembleDebugAndroidTest
adb install -r build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk
adb shell am instrument -w -e todoChecks true com.ilmmizan.bilga.test/com.ilmmizan.bilga.NotesWidgetChecks
adb shell am instrument -w com.ilmmizan.bilga.test/com.ilmmizan.bilga.NotesWidgetChecks
```

APK update oldidan/keyin, birinchi startup’dan avval Notes/To-Do DB hash’lari
bir xil. Shaxsiy bazalar, raw UI, kalitlar kompyuterga eksport qilinmagan.
Debug APK CRC/v2 signature tekshiruvi va qurilmaga install -r bajarilgan.
Yakuniy build **PASS, 22.3s**, APK **321480819 bytes**, SHA-256:
`0feaf8246b9906014c91fd9dc6a2d213f962f96846692d54232f2658724fe1c0`.
Loglar `.buildlog/todo-reminders/`. Commit/GitHub push yo‘q.

Haqiqiy planshet sinovi, 2026-10-12:
- To-Do vidjeti launcher’ga qo‘shildi, gear konfiguratsiyasi saqlandi; title OFF.
- Sintetik `Bilga Todo Test 20261012` bilan notification va gated snooze tekshirildi.
  5 daqiqa va qo‘lda vaqt tanlash navbatdagi bitta alarm’ni yangiladi.
- 18:03 va 18:07 da AOSP Kalkulyator ustida `TYPE_APPLICATION_OVERLAY`,
  `BOTTOM CENTER`, `mFrame=[180,1438][1020,1937]`, `isVisible=true` tasdiqlandi.
  Android Settings ustida oyna yaratilgan bo‘lsa-da ko‘rinish tizim tomonidan
  yashirilgan; bu cheklov chetlab o‘tilmadi, notification fallback qoldi.
- Panelning 5 daqiqaga kechiktirish tugmasi panel/notification’ni yopib,
  navbatdagi alarm’ni 18:08:42 ga surdi. So‘ng test uchun editor’da 18:07 tanlandi.
- Panelning Bajarildi tugmasi aynan sintetik task uchun app ichidagi tasdiqni
  ochdi. Tasdiqdan keyin task bajarilgan filtrida ko‘rindi; aktiv To-Do notification
  va overlay service soni 0, task alarm’i bekor, faqat widget midnight alarm’i qoldi.
- Yakuniy APK update oldidan va keyin, startup’dan avval har ikki baza hash’i
  aynan bir xil qoldi. Mavjud user task’lari o‘zgartirilmadi. Sintetik task bajarilgan
  holatda saqlandi, o‘chirilmagan. Sinov uchun yoqilgan overlay OFF’ga qaytarildi;
  TTS va title OFF. Android overlay ruxsati foydalanuvchi boshqaruvida qoladi.

Planshetda sinash: vazifa editor’ida Eslatma kalitini yoqing va kelajak vaqtini
tanlang. Eslatmalar sozlamasida boshqa ilovalar ustida ko‘rsatishni yoqsangiz,
izohdan keyin Android ruxsat sahifasi ochiladi. Kalkulyator kabi oddiy ilovaga
o‘ting; vaqt kelganda panel chiqadi. Bajarildi app ichida tasdiqlanadi, Kechiktirish
deadline’ni o‘zgartirmaydi. Vidjetni launcher’dan yoki To-Do appbar’dan qo‘shib,
har nusxada today/upcoming/overdue manbasini alohida tanlang.

Android12–17 ruxsat/FGS/notification API guard’lari va rasmiy talablar hisobga
olingan; haqiqiy device validation faqat API31, SDK/target36. API32–37 runtime,
barcha launcherlar, OEM reboot/Doze holatlari va 43 til qo‘lda tekshirildi degani
emas. Play Console review/declarations alohida release jarayoni; avtomatik
policy approval da’vosi yo‘q. Full-screen intent, Accessibility yoki boshqa
permission bypass ishlatilmagan.

Rasmiy manbalar (2026-10-12 tekshirildi):
- https://developer.android.com/develop/background-work/services/alarms
- https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start
- https://developer.android.com/develop/background-work/services/fgs/service-types
- https://developer.android.com/develop/ui/compose/notifications/notification-permission
- https://developer.android.com/about/versions/17/behavior-changes-all
- https://developer.android.com/about/versions/17/behavior-changes-17
- https://support.google.com/googleplay/android-developer/answer/16558241
