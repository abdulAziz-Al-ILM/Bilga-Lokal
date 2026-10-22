# Bilga — loyiha handoff’i

Yangilangan: **2026-10-22**
Repo: **abdulAziz-Al-ILM/Bilga-Lokal** (private), branch: **wip/todo-widget-recovery**.

> Bu hujjat keyingi AI/ishlab chiquvchi uchun joriy holatning asosiy manbasi. Repo faktlari, foydalanuvchi qarorlari va tekshirilmagan joylar alohida ajratiladi. Taxmin bilan “ishlaydi” deb yozilmasin.

## 2026-10-22 — GitHub hosted CI PASS; APK artifact tayyor

Latest run `39814336862`, manual `workflow_dispatch`, private WIP, tested source
`8bf0faff7cc83452a85faa9a451971bd73058af9`, job15m09s — **SUCCESS**:
https://github.com/abdulAziz-Al-ILM/Bilga-Lokal/actions/runs/39814336862
Locked pub get PASS, analyze No issues (13.9s), barcha224 Flutter test PASS,
universal debug APK PASS (build step11m18s), ZIP CRC/APK v2 signature/SHA256 PASS.
Artifact API bitta unexpired artifact'ni tasdiqladi, size293931559 bytes:
https://github.com/abdulAziz-Al-ILM/Bilga-Lokal/actions/runs/39814336862/artifacts/12441708102
Expiry2026-10-29 16:43:19UTC; faqat APK, SHA256SUMS, SOURCE.txt. APK SHA256:
`752a548c7193f9bce219dc91cc43871407b6c52fcd97ef0af9c0f49a6a6206d0`.

Birinchi run'dagi disk full uchun bitta maqsadli CI correction va bitta nazorat
run bajarildi. Faqat disposable hosted runner SDK'sidan kerakmas NDK27.3/29/30
sdkmanager bilan olindi; required28.2 saqlandi. Setup'dan keyin17GiB, oxirida5.4GiB
bo‘sh qoldi. Hech qaysi run logida Dart/Java SIGSEGV yo‘q. Bu lokal RAM barqarorligi
tasdig‘i emas. Lokal katta build/test, tablet install, foydalanuvchi database/model/
private key/production signing va Core ovozli code o‘zgarishi bajarilmadi. Native
instrumentation/device oqimlari bu CI doirasida tekshirilmagan. Keyingi docs-only
checkpoint APK'ning source SHA'sini o‘zgartirmaydi. Main8871b3a faqat ruxsat berilgan
workflow registration; default main o‘zgarmagan, boshqa main fayllari saqlangan.

## 2026-10-22 — CI ro‘yxatga olindi; test224 PASS, universal build'da runner disk full

Foydalanuvchi main'ga **faqat** `.github/workflows/wip-android-debug.yml` qo‘shishga
aniq ruxsat berdi. Main commit `8871b3ac007ab05402949b3eacd4327340c6913c`, sole
parent `ae7b27c1e4f7ff15f386361ecec109688f7b35e6`; GitHub commit/file list aynan
bitta added workflow'ni tasdiqladi. Boshqa main fayllari/tarixi o‘zgarmadi, default
branch main bo‘lib qoldi. Registration paytida WIP bilan workflow byte-identical; guard manual/private/
exact-WIP, read-only permission, SHA-pinned actions va Bash sintaksisi tekshirildi.
Bu ruxsat boshqa main o‘zgarishlari yoki WIP application merge uchun emas.

Run `39811651782` faqat `workflow_dispatch`, branch WIP, source
`f145cceb7338ea93ff95324f793717dc56565683`:
https://github.com/abdulAziz-Al-ILM/Bilga-Lokal/actions/runs/39811651782
Dependency resolution PASS, analyze No issues (11.5s), barcha224 Flutter test PASS.
APK `:app:stripDebugDebugSymbols` bosqichida `No space left on device` bilan FAIL
(9m45s); setup'dan so‘ng hosted runnerda9.8GiB qolgan. SIGSEGV kuzatilmadi.
Integrity/upload skipped, artifact API0. Bitta maqsadli WIP-only CI fix: faqat
disposable hosted VM'da sdkmanager bilan kerakmas NDK versiyalarini olib tashlash,
required28.2 saqlash; hosted/exactSDK/symlink guard va disk diagnostics. App/ABI/
Gradle/Java versiyalari o‘zgarmaydi. Yagona yangi manual validation yuqorida PASS;
avtomatik retry yo‘q, main workflow registration nusxasiga yana tegilmagan.
Lokal katta build/test, device install va foydalanuvchi data o‘zgarishi yo‘q.
Texnik tafsilot va xavfsiz artifact chegaralari `BILGA_CI.md`da.

## 2026-10-22 — manual WIP CI tayyor; GitHub dispatch hali bloklangan

Foydalanuvchi lokal katta build/testlarni qayta bajarmaslikni buyurdi. Private WIP
uchun `.github/workflows/wip-android-debug.yml` va `BILGA_CI.md` qo‘shildi;
source commit `60f48bd44447c5e87af53ccac872bfc9ab86038f` push/remote tasdiqlangan.
Faqat manual/private/exact-WIP guard, existing Flutter3.47.1/Java21/Android versions,
locked pub get, analyze, Flutter tests, debug APK + CRC/signature/SHA256, allowlisted
7 kunlik artifact. Production signing/secrets, lokal cache/model/data talab qilinmaydi.
YAML/Bash/security static tekshiruvlar va fsck PASS; lokal build/test bajarilmadi.

Bitta `gh workflow run ... --ref wip/todo-widget-recovery` GitHub HTTP404:
`workflow wip-android-debug.yml not found on the default branch`. Default `main`;
GitHub yangi workflow_dispatch uchun default branchda workflow bo‘lishini talab
qiladi. CI/test/APK/artifact hali yo‘q. Main/default setting o‘zgarmadi; foydalanuvchidan
defaultni WIP qilish yoki faqat CI faylini main'ga qo‘shish bo‘yicha ruxsat so‘raldi.
Ruxsatsiz ushbu cheklovni aylanib o‘tmang, push trigger qo‘shmang. Mavjud APK,
qurilma, foydalanuvchi bazalari va Core ovoz funksiyalari o‘zgartirilmadi.

## 2026-10-22 — yangi JVM SIGSEGV; WIP saqlandi, davom ettirish to‘xtadi

Boshlang‘ich lokal/remote WIP `407feea3e4fe1424c283fa66f4c69465e02e48b4` bir xil,
tree clean, repo private, fsck PASS. Bitta cached-engine Todo test PASS (2s), keyingi
18 tegishli Flutter test PASS (14s), analyze No issues (10.8s). Bu RAM barqarorligini
to‘liq tasdiqlamadi: native test APK buildida OpenJDK21.0.12.1 single-use daemon
20:38:05 da, 22s ishlagach, GC Thread#1 ichida SIGSEGV/SEGV_MAPERR bilan quladi.
Frame `G1ParScanThreadState::trim_queue_to_threshold`; lokal ignored crash log
`hs_err_pid17726.log`. Aniq RAM/JVM sabab isbotlanmagan; qayta build yoki versiya/GC
almashtirish bajarilmadi. Native testlar, yangi APK va haqiqiy qurilma sinovi yo‘q.

Source WIP checkpointlar private branchga push qilinib remote SHA tasdiqlandi:
`2ca5c879cca28045dddd74e869fc6b78abda751d` va
`0e8f407fd7f8a83a01ed84221c241e7f88b508f8`.
Widget native preset menyusiga custom entry va nonexported TodoSnoozeActivity
qo‘shildi, widget custom timestamp rad etilishi olib tashlanib mavjud capability /
lock / lease / SQLCipher tranzaksiyasi saqlandi. Spinner input clearFocus bilan
o‘qiladi, future validation bor, deadline yozilmaydi. Tayyor 99216b2 sync qayta
ishlatiladi. **Yangi native kod build/device'da hali tasdiqlanmagan**.

Debug-only DUMP/shell ruxsatli inspector faqat rezerv sinov taskining SQL/mirror
holatini read-only o‘qiydi; u instrumentation kabi app'ni qayta ishga tushirmasdan
alarmni kuzatish uchun, release'da yo‘q. UI probe yangi20261022 sinov nomini taniydi.
Qurilmaga install/data/UI o‘zgarishi bajarilmadi; Tab16 ulanganligi read-only tekshirildi.

Holat va yangi to‘xtash diagnostikasi: `BILGA_PROGRESS_20261022.md`.
Koddan oldindan o‘qilgan 7 kartochka inventari/backlog: `BILGA_CARD_AUDIT_20261022.md`;
bu dastlabki audit, runtime/full audit PASS emas. Doimiy Todo notification va Habits
upgrade boshlanmagan. Core ovozli buyruqlariga va main branchga tegilmadi.

## 2026-10-16 — Recovery tekshiruvi (WIP)

**19:22 — yangi host SIGSEGV sabab tekshiruv to‘xtadi.** Dart 3.13.1 compiler
birinchi test yuklanishida `ScavengerVisitor::VisitPointers / ProcessPromotedList`
ichida SEGV_MAPERR bilan quladi. Bu test assertion xatosi emas; yangi regressiyalar
o‘tmadi. Ketma-ket pipeline'dagi analyze/native build/APK bosqichlari boshlanmadi.
Faqat shu pipeline shell/Dart child to‘xtatildi; boshqa jarayonlar o‘zgartirilmadi.
Oldingi Java G1 SIGSEGV bilan birga host xotira barqarorligi yana noaniq; RAM
muammosi qaytgan deb qat’iy xulosa qilinmaydi. Tests/build'ni cheksiz takrorlamang.

Oxirgi source checkpoint `99216b24a1f88c318e6070a5240d6716f041f20c` private WIP'da
push/remote SHA bilan tasdiqlangan. Undagi cached-engine Notes/Todo ready-handshake
va ikki regression **hali tekshirilmagan, planshetga o‘rnatilmagan**. SQL'dagi yangi
sinov reminder native mirror/alarm'ga cold-start'da o‘tmagani kuzatildi; binding
tayyorligida refresh yetishmasligi haqidagi tuzatish gipotezasi tekshirilishi kerak.

Oxirgi muvaffaqiyatli yig‘ilgan/o‘rnatilgan APK source `7d7f72f`, Flutter build15.1s,
CRC/signature va ikkala DB hash preservation PASS, SHA256
`bd6847c8d3ad5b7c5a7884839cf7a4a3f261330bce574db388d17181e9f88730`.
Undagi native custom date/time oynalari Calculator ustida, Main ochilmasdan
ko‘rindi, lekin tanlangan vaqt SQL'ga saqlanmadi. Sabab bo‘yicha static-only debug
diagnostika tayyor; to‘liq real custom-save va notification action hali PASS emas.
Quyidagi oldingi PASS natijalarni oxirgi 99216b2 kodi uchun tasdiq deb olmang.

To‘xtashdan oldin yagona UI-created recovery vazifasi vidjet Done orqali yakunlandi:
SQL done=1/reminder=null, deadline23:59 o‘zgarmadi, mirror blocked=false, overlay0.
Sinov Notes consent OFF; eski foydalanuvchi grantlari/yozuvlari o‘zgartirilmadi.

Foydalanuvchi apparat muammosi hal bo‘lganini bildirdi. Recovery bazasi:
`67d6990646c36a70b8f21b11a21ca5c843e51fa8`, private WIP branch; main o‘zgarmaydi.
GitHub zaxiralash tartibi `AGENTS.md`da. Eski RAM xatolari davridagi test/build
natijalari joriy reliz tasdig‘i emas. Notes/To-Do/overlay/Core widget theme va
Recent Apps tekshiruvi `BILGA_WIDGET_RECOVERY.md`da qayd etiladi. Core mikrofon
funksiyasi o‘zgartirilmagan.

Recovery kodida Todo DB8 device-local per-task widget consent, native SQLCipher
Done/Snooze, sqlEpoch stale publish himoyasi, auto-on new-task reminder, widget
countdown, 7 palitra/sistem theme bridge va overlay contrast mavjud. Bularning
joriy qurilma natijalari quyida. Notes DB13 saqlanadi.
Notes konfiguratsiyasi key vaqtincha yopiq bo‘lganda o‘chirilmasin yoki defaults
bilan almashtirilmasin. Main singleTask/default affinity, yordamchi handoff'lar
Recents'dan excluded, Main'ga NEW_TASK/CLEAR_TOP/SINGLE_TOP bilan yo‘naltiriladi.

Joriy tekshiruv: full Flutter **223 PASS**, keyingi Notes regression **42 PASS**,
7 palitra/light-dark-system theme focused regression **PASS**, oxirgi analyze
**No issues, 23.8s**. Blackview Tab16 API31 native Todo **41 PASS** (notification
broadcast/content tap va custom snooze deadline separation bilan), Notes **13 PASS**.
Oxirgi Flutter debug APK **PASS, 15.3s**, CRC/v2 signature PASS, SHA256
`c7f58ba4fd2f7379db76ac49a9a421505e9d615e2d81b971fa8bf0019104aac8`.
Install-r oldin/keyin Notes/Todo shifrlangan DB hash'lari aynan saqlangan.

Qurilmada Notes title/body/tags preview, restart'da ON consent saqlanishi,
revoke'da row yo‘qolishi va app cache empty tekshirildi. Boshqa eski grantlar saqlandi.
To-Do widget Done launcher ichida bajarildi; SQL done=1/reminder=null va original
deadline o‘zgarmadi. Widget inline Snooze ham native ishladi. Overlay Calculator
ustida chiqdi; foydalanuvchi dizayn o‘qilishini tasdiqladi. Uning aniqlashtirishiga
ko‘ra eski custom-time/notification-body yo‘li ilovaga olib kirgan. Endi native
date/time dialog va notification inline presets tayyor; yakuniy real oqim tekshiruvi
davom etmoqda. Notes/Todo handoff'dan keyin Recents'da bitta Bilga task kuzatildi.
Core real public background Ocean/dark, Amethyst/light, Amethyst/dark ranglariga
mos yangilandi; foydalanuvchining asl Amethyst/dark tanlovi qaytarildi.

Muhit: 18:34:09 da eski Gradle daemon OpenJDK G1 marking SIGSEGV bilan quladi.
Sabab isbotlanmagan; RAM tuzalganini build natijasidan xulosa qilmang. Yangi native
kodning fresh single-use daemon buildlari keyin muvaffaqiyatli o‘tdi. SDK/JDK/Gradle
versiyalari va GC konfiguratsiyasi o‘zgartirilmadi; crash log lokal/ignored saqlanadi.

## 2026-10-12 — To-Do vaqt holati, reminder, overlay va vidjet

Joriy ish faqat To-Do/reminder/To-Do widget integratsiyasi; avvalgi uncommitted
Notes/teg/STT/trial/build ishlari saqlandi. Tafsilot `BILGA_TODO_REMINDERS.md`.
To-Do SQLCipher **v6 → v7**: alohida `todo_reminders` jadvali, default OFF;
eski task/folder/priority/deadline/timestamps qayta yozilmaydi. Snooze faqat
reminder time’ni suradi. Done/trash/delete/deadline edit eski avlodni trigger
bilan o‘chiradi. Revision + durable native event ack eski event’ni rad qiladi.
Backup Todo7 reminders bilan, eski Todo6 import qabul qilinadi; restore yangi
IDs/revisions bilan, tarixiy reminder’lar birdan chiqmaydi. Notes portable12
va device-local consent13 o‘zgarmadi. Eski editor keyingi completion/folder
move’ni qaytara olmaydi, trash’ni tiklamaydi.

Ranglar lokal kalendar kunlari/aniq soat: 3+ green,2 yellow,1/today red,overdue
black/dark grey,done/undated neutral. Badge o‘rniga border + static subtle grid.
Java Time/Dart calendar boundaries/DST hisoblangan. Priority qiymatlari saqlangan.
`TodoChanges` barcha muvaffaqiyatli To-Do/backup write’laridan so‘ng sync qiladi.

Native `TodoBridge/Store/Time/Reminders/Receiver/OverlayService/Widget/Handoff`;
Dart `TodoSync/Host`, editor switch/settings/actions, widget config. Native DB
kalitini olmaydi; alohida Keystore AES-GCM + atomic noBackup mirror/events.
Default native title yo‘q, Description hech qachon eksport qilinmaydi. Faqat
explicit title opt-in’da bounded text chiqadi. AppLock/Keyguard redaction saqlanadi.
Bitta next alarm: exact access bo‘lsa exact, aks holda inexact. Reboot/unlock,
package update, time/zone, permission grant reschedule qiladi. Android13 notif
permission faqat user reminder yoqqanda. Sound/quiet high-importance channel,
channel/DND/battery sozlamalari hurmat qilinadi. Notification done/widget checkbox
mavjud gate’dan keyin tasdiqlanadi; snooze gated sheet 5/10/30/60min,tomorrow,
manual. App oldinda reminder bottom sheet.

Overlay default OFF, rationale → Android settings; full-screen/accessibility
bypass yo‘q. Due-time only, TYPE_APPLICATION_OVERLAY, one 45s bounded shortService,
close/presets/done/manual. Qulfda panel chiqmaydi, title default OFF. Background
start cheklansa notification qoladi. Installed non-network matching TTS voice
opt-in; fail/timeout’da signal. Android17 background custom TTS o‘rniga tizim
signal. 43 til JSON va native generated resource’lar; generator
`tool/generate_todo_strings.py`. Widget per-instance today/upcoming/overdue,
private default, progress, create/open/confirm done/config, responsive1–6 rows.

Validation: yakuniy analyze **No issues,13.0s**, oldingi full Flutter **219 PASS,109s**;
keyingi editor/runtime **6 PASS,9s**, mustaqil reminder/deadline testi ham o‘tdi.
Keyingi full urinishlar host SIGSEGV/disk full bilan tugamadi; oxirgi TMPDIR
urinish user interrupt’da 189 PASS bilan to‘xtadi, full PASS hisoblanmaydi.
Foydalanuvchi ko‘rsatmasiga ko‘ra o‘tgan testlar yana takrorlanmadi. Blackview
Tab16 API31 arm64 To-Do native **16 PASS**, Notes native **10 PASS**. Final debug
APK build **PASS,22.3s**, CRC/v2 **PASS**, **321480819 bytes**,
SHA256 `0feaf8246b9906014c91fd9dc6a2d213f962f96846692d54232f2658724fe1c0`.
APK install-r Success. First startup’dan oldin Notes/To-Do on-device DB SHA
update oldidan/keyin aynan saqlandi; raw DB/UI/key eksporti bo‘lmadi.
Actual UI’da overlay/title default OFF, rationale/settings handoff, synthetic
reminder save + single alarm, To-Do widget add/gear/private config save ishladi.
18:03/18:07 Kalkulyator ustida pastki overlay isVisible=true; panel 5min Snooze
ishladi, notification bekor/new alarm; Done aynan synthetic title’li app confirm
ochdi va bajarilgan filtriga o‘tdi. Keyin notification/service0, faqat midnight
widget alarm. Manual snooze ham o‘tdi. Settings kabi himoyalangan UI’da overlay
yashirilishini chetlab o‘tilmadi. Sinov overlay OFF’ga qaytarildi, TTS/title OFF;
synthetic task bajarilgan holda saqlandi. Tafsilot BILGA_TODO_REMINDERS.md.
2026-10-12 yakunida `/tmp` diskida11GB, /home20GB; hech fayl o‘chirilmadi.

SDK/target36 saqlangan, yangi versiya tasodifan o‘rnatilmadi. API32–37 va barcha
OEM/launcher runtime’lari qo‘lda tekshirilgan degani emas; Play Console policy/FGS
release declarations alohida. Mavjud Built-in Kotlin warning’i qoladi. Bir native
build’da Kotlin daemon EOF bo‘ldi, mavjud fallback kompilyatsiya muvaffaqiyatli;
JDK/Gradle versiyalari o‘zgartirilmadi. Loglar `.buildlog/todo-reminders/`.
Uninstall/data clear yoki GitHub push/commit yo‘q.

## 2026-10-12 — Notes kartochkasidan vidjetga ruxsat berish

Joriy mexanizm quyidagi oldingi per-widget tasdiqlashni almashtiradi. Har bir
oddiy Notes kartochkasida **Vidjetda ko‘rsatishga ruxsat berish** switch’i bor;
eski/yangi yozuvlarda **OFF**. ON uchun launcher eski nusxalarni saqlashi va
ularni o‘chirish kafolatlanmasligi haqidagi localized dialog tasdiqlanadi.
Faqat ruxsatli yozuvlar eksport qilinadi; widget source/privacy/pin sozlamalari
mustaqil qoladi, pin ruxsat bermaydi. Barcha 43 til yangilangan.

Notes DB **12 → 13**: alohida `note_widget_permissions(note_id,fingerprint)`
jadvali. Eski note/history/tag qatorlari o‘zgarmaydi; migration hech kimga
avtomatik ruxsat bermaydi. Fingerprint to‘liq sarlavha/matn/teglar bilan bog‘langan.
DB trigger’lari content/tag/trash o‘zgarishida ruxsatni o‘chiradi; revert/restore
qayta yoqmaydi. Teglar o‘zgarmagan favorite/folder update ruxsatni bekor qilmaydi.
Private Space ruxsat ololmaydi. Ruxsatlar device-local, portable backup v12’ga
kiritilmaydi. Ruxsat o‘zgarishi Notes timestamps va history’ga yozilmaydi.

OFF: DB commit’dan keyin native `invalidatePermissions` darhol kutiladi, odatiy
120ms debounce emas. Global `permissionEpoch` oshadi, widget redraw bo‘ladi,
ilova boshqaradigan barcha Notes widget keshlaridagi rows/legacy approvals
tozalanadi (sozlamalar saqlanadi), keyin yangi snapshot olinadi. Eski epoch’dagi
in-flight eksport va oldingi protokol keshining render’i rad qilinadi.
AES-GCM/Keystore/noBackup, AppLock va SQLCipher mexanizmlari saqlangan.
Android launcher o‘zi saqlagan nusxalarni o‘chirish kafolati yo‘q; UI aytadi.

Tekshiruvlar: `flutter analyze` **No issues, 4.3s**; widget+tag **42 PASS**;
full `flutter test --concurrency=1 --reporter expanded` **205 PASS, 88s, exit0**;
Tab16 API31 arm64 native checks **10 PASS**. `flutter build apk --debug`
**PASS, 36s**; ZIP CRC/v2 signature **PASS**. APK **321450143 bytes**,
SHA-256 `6fad8283d76783773dc0cf1bc6a5059d1688cb0d8ac35506398e682ca3f1dc4d`.
`adb install -r` **Success**; first launch’dan oldin Notes/To-Do DB on-device
SHA-256 update’dan avvalgisi bilan bir xil. Uninstall/data clear qilinmagan.

Haqiqiy planshetda sintetik yozuv switch OFF → dialog → ON → widget’da
title/body/tag ko‘rinishi → OFF → `Hozircha bo‘sh` **PASS**. Qo‘shimcha read-only
`NotesWidgetChecks -e verifyEmptySnapshots true` **App-owned widget snapshots
empty: PASS**. Faqat koordinatalar, statik/sintetik label’lar va pass/fail
olindi; shaxsiy DB/UI/kesh mazmuni eksport qilinmadi. Sintetik yozuv va vidjet
qoldirilgan, ruxsat OFF. Boshqa modul ishlariga tegilmagan, commit/push yo‘q.
Loglar `.buildlog/notes-widget-permissions/`; batafsil `BILGA_NOTES_WIDGET.md`.

## 2026-10-12 — Notes Android bosh ekran vidjeti (dastlabki bosqich)

Faqat Notes vidjeti qo‘shildi; avvalgi uncommitted teg/STT/trial/build/backup
ishlari saqlandi. To-Do, Habits, Finance va ovozli boshqaruv funksiyalari bu
vazifada o‘zgartirilmadi. Tafsilotlar: `BILGA_NOTES_WIDGET.md`.

`NotesWidget` AppWidgetProvider + native handoff/configure activity, immutable
unique PendingIntent va Flutter `NotesWidgetHost/Sync/Data/ConfigPage` bor.
Har bir nusxa recent / alohida pinned IDs / stable tag ID hamda hidden / titles /
preview rejimiga ega. Yozuvni bosish aynan editor’ni, + create’ni, qidiruv Notes
qidiruvini ochadi. Widget intentlari mavjud AppLock/CoreAccessGate ortida kutadi;
auth yoki SQLCipher DB key’ni native widgetga uzatish yo‘q. DB schema bu vazifada
o‘zgarmadi (oldingi teg vazifasidagi v12 saqlandi). Notes/teg/papka/trash/restore/
backup commit hodisalari snapshot’ni yangilaydi; boshqa collection hodisalari yo‘q.

User **xavfsiz standart va alohida tasdiqlash**ni ma’qulladi. Standart umumiy
label, Private Space hech qachon query qilinmaydi. Faqat ko‘rib chiqilgan va
maxfiy emas deb tasdiqlangan yozuvlar chiqariladi; fingerprint ko‘rsatiladigan
matn/teg o‘zgarsa tasdiqni bekor qiladi. Title tasdig‘i preview huquqini bermaydi.
App Lock yoqilganda widget umumiy bo‘lib qoladi. Per-widget sozlama/tasdiq/snapshot
noBackupFilesDir’da alohida Android Keystore AES-256-GCM kaliti va widget-ID AAD
bilan shifrlanadi; plaintext fallback yo‘q. Config revision eski eksportdan
himoya qiladi. Widget konfiguratsiyasi device-local; note/teg backup saqlanadi.
Launcher oldin chiqarilgan ommaviy matnni saqlashi mumkinligi UI’da ochiq aytilgan;
faqat screen-lock signaliga tayanilmaydi. Kesh o‘chirish faqat tegishli widgetni
olib tashlashda; foydalanuvchi DB/model/key’lariga tegilmaydi.

43 til label va native resource’lar bor; generator
`tool/generate_notes_widget_strings.py`. API31 responsive size variants va old
Android portrait/landscape variantlari, 1–6 ko‘rinadigan yozuv, preview’da eng
ko‘pi 3 teg. Snapshot 12; tanlash/tasdiq 100 bilan cheklangan, qidiruv eski
yozuvlarni topadi. System theme snapshot’da hozircha dark fallback. Scroll yo‘q.

Haqiqiy qurilmada cached audio_service Flutter engine configure activity’ga
qayta ulansa avvalgi editor ko‘rinishi aniqlandi va tuzatildi: yengil native
activity faqat handoff qiladi, bir xil MAIN/LAUNCHER intent bilan MainActivity’ni
ochadi, configure result ResultReceiver bilan qaytariladi. Noyob widget URI
handoff’da qoladi; Dart boshlang‘ich route bo‘lib ketmaydi. Cached engine
resume’da pending intent qayta olinadi, configure route save/cancel’da yopiladi.
Voice/audio service kodi va SDK versiyalari o‘zgartirilmadi.

Yakuniy validation: `flutter analyze` **No issues, 4.6s**;
`flutter test --concurrency=1 --reporter expanded` **197 PASS, exit0, 81s**.
`test/notes_widget_test.dart`da **18 test**: privacy, normal/private/trash/papka/
arxiv filtering, mustaqil configs, pin/tag/rename/delete/restore, bounded Unicode
export, commit/rollback, gate/sync, 43 locale, search, cold/warm/cached engine
navigatsiya, configure cancel, Notes’ni o‘zgartirmaydigan pin, concurrent approval.
`taskset -c 1 flutter build apk --debug` **PASS, 21.1s**. ZIP CRC va Android v2
signature **PASS**. Mavjud plugin Built-in Kotlin migration warning’i qolgan,
build’ni to‘xtatmaydi. APK **321443312 bytes**, SHA-256
`fb75aef8c981718b454ad85233974f45f1fe260386281342a498e60b5e7a3868`.

API31 arm64 Tab16NEU0045423’da `adb install -r` **Success**. Ilovani birinchi
ochishdan oldin Notes va To-Do DB on-device SHA-256 aynan saqlangan. To‘liq DB/UI
va raw error-log eksporti auto-review’da rad etildi; xavfsiz muqobil — on-device
hash, faqat UI koordinatalari/oldindan ma’lum sintetik label’lar va error count —
ishlatildi. Shaxsiy DB, UI matni, ovoz yoki kalit nusxasi kompyuterga olinmadi.
Native instrumentation **8 PASS**: default, ciphertext/readback, ID binding,
tamper refusal, unique/immutable PendingIntent, provider/config handoff metadata.
Faqat reserved sintetik cache IDs tozalangan. Test runner APK ham o‘rnatildi.

Blackview launcher’da qo‘shish, + create, hidden default, alohida non-sensitive
tasdiq bilan pinned preview, kichik/keng resize, title/body/tag display, exact-note
open, body edit’dan keyin avtomatik `Yozuv 1`ga qaytish va Notes search open
**PASS**. Avtomatik klaviatura ochilishi tasdiqlanmagan. Bir nechta nusxa/teg
manbalari avtomatik testda; barcha launcher/43 tilda qo‘lda sinov qilingan emas.
Planshetda bitta Notes vidjeti va `Bilga Widget Test 20261012` / `WidgetTest`
sintetik fixture qoldi; asl yozuvlar o‘zgartirilmadi. Lock-screen nusxalarini
barcha launcherlardan qaytarib olish kafolatlanmaydi, shuning uchun faqat
ommaviy deb alohida tasdiqlangan matn chiqariladi.

Host Dart native compiler avvalgi handoff’da qayd qilingan SIGSEGV’ni ayrim
sinovlarda takrorladi. Faqat regenerable `build/test_cache` `.buildlog`ga
ko‘chirilib qayta yaratilgach standart Flutter analyze/full test/build o‘tdi;
SDK/JDK/Gradle versiyalari va test assertion’lari almashtirilmadi. Loglar
`.buildlog/notes-widget/`. Uninstall/data clear, commit yoki GitHub push yo‘q.

## 2026-10-12 — Notes teg kutubxonasi

Faqat Notes uchun teglar qo‘shildi. Amaldagi Notes/papkalar UI’i
`CollectionPage(CollectionKind.notes)`; shared collection kodidagi yangi teg
query/UI faqat Notes branch’ida. To-Do, Habits, Finance va ovozli boshqaruv
funksiyalari o‘zgartirilmadi; avvalgi uncommitted ishlar saqlandi.

Notes DB schema **11 → 12**: `note_tags` global kutubxona va
`note_tag_links(note_id, tag_id)` alohida many-to-many bog‘lanishlar.
FK cascade, compound PK, normalized unique name va tag→note indeksi bor.
`NoteTagStore` nomlarni trim/whitespace/case va o‘zbek apostroflari bilan
birxillashtiradi; yangi nomlar 1–80 belgi. Bir nom bilan qayta yaratish mavjud
ID’ni tanlaydi, rename collision rad qilinadi. ID rename’da o‘zgarmaydi.
Migration eski `notes.tags` JSON’dan active/trash yozuvlarning bog‘lanishlarini
import qiladi; eski note/folder/history/timestamp qatorlarini qayta yozmaydi.
Tarixiy uzun nomlar migratsiya/import’da saqlanadi. `notes.tags` compatibility
mirror, yangi bog‘lanishlarning asosiy manbasi alohida link jadvali.

Create/edit’da bitta ixcham teg tanlash dialogi: search/create, ko‘p tanlash,
rename va tasdiqlangan global delete. Edit chip’dagi × faqat yozuvdan ajratadi.
Kutubxona rename/delete darhol global saqlanadi; tanlash dialogini cancel qilish
bu amallarni bekor qilmaydi. Global delete yozuvlarni o‘chirmaydi. Kartochkalarda
gorizontal ixcham chip’lar, chip bosilganda barcha papkalar va arxivdagi active
yozuvlar ko‘rinadi; trash chiqarilmaydi. Teg filtri mavjud favorites/archive
filtrlari bilan birga ishlaydi; qidiruv teg nomlarini ham tekshiradi.
43 til JSON’ida teg label, name hint, duplicate/invalid va delete confirm bor.

Note va link yozish bitta transaction’da. Global rename/delete active va trash
mirror’larini yangilaydi; stale editor ID’lari o‘chirilgan tegni qayta yaratmaydi.
Soft trash/restore link’larni saqlaydi, permanent note/folder delete link’larni
tozalaydi, foydalanilmagan teglar kutubxonada qoladi. Versiya tarixi avvalgidek
title/body uchun; teg-only edit tarix qo‘shmaydi va versiya restore joriy teglarni
saqlaydi. Backup endi notesSchema12 kutubxona/link’larni ham olib yuradi;
8–11 backup import JSON teglardan foydalanadi. Import mavjud bir xil nomli teg
ID’lariga birlashtiradi, mavjud yozuvlarni almashtirmaydi; invalid reference yoki
duplicate canonical name yozishdan avval rad qilinadi. Mavjud atomic restore
transaction va idempotent import marker saqlandi.

Yakuniy validation: `flutter analyze` **No issues, 5.9s**;
`flutter test --concurrency=1 --reporter expanded` **179 PASS, exit0, 79s**.
Yangi `test/notes_tags_test.dart`da **16 test**: v11 migration, concurrent
duplicate, rename collision, stale ID, detach/delete, folder/note trash/restore,
history, global filter/search, legacy/new backup, rollback, 43 locale label’lari,
picker CRUD, card tap va create/edit autosave. Create sinovi bazani yopib qayta
ochgach teg IDs va folder saqlanganini tekshiradi. Birinchi full run’da yangi
create UI testi async picker natijasi kelishidan oldin autosave soatini surgan;
test endi chip ko‘ringanini kutadi, keyin debounce/SQLite yozuvini kutadi.
Product tekshiruvi yoki assertion o‘chirilmadi; yakuniy full run to‘liq o‘tdi.

`taskset -c 1 flutter build apk --debug` **PASS, exit0, 36.1s**.
Mavjud pluginlarning kelajakdagi built-in Kotlin migratsiyasi warning’i bor,
hozirgi build’ni to‘xtatmaydi; Notes vazifasida Gradle/pluginlar o‘zgartirilmadi.
APK: `build/app/outputs/flutter-apk/app-debug.apk`, **321415647 bytes**.
ZIP CRC va Android **v2 signature PASS**. SHA-256:
`77ecb4f5ff4c924e5e7b0059ae7772b421b3e430fb6c5f1ff94e1982a09faa2f`.
Loglar: `.buildlog/notes-tags/{analyze,flutter-test,build-apk,apk-verify}.log`.

Sinovlar faqat disposable test bazalarida bajarildi. Foydalanuvchi bazasi,
planshetdagi ilova/model va maxfiy kalitlarga tegilmadi; uninstall/data clear,
commit va GitHub push bajarilmadi. Qurilmada yangi teg UI’i hali sinov qilinmadi.

## 2026-10-12 — Uzbek offline STT isolate initialization tuzatildi

User bildirgan `~/bilga-voice-error.log` 0 bytes edi. Ulangan API31/arm64
planshetda faqat Bilga PID logcat’i `.buildlog/voice-init-fix/tablet-live.log`ga
local yozildi; log buffer/app data/model o‘chirilmadi. RECORD_AUDIO granted;
AudioRecord 16kHz PCM ishga tushgan. Optional noise suppressor mavjud emasligi
capture’ni to‘xtatmagan. Modelning barcha 8 fayli release size/SHA’siga mos;
cached catalog/provenance published imzolangan envelope bilan aynan bir xil.
O‘rnatilgan APK SHA oldingi verified APK bilan mos. APK ichidagi arm64 Sherpa va
ONNX library’lar Gradle stripped native output bilan mos.

Haqiqiy sabab `OfflineVoice.listen` ichidagi inline `Isolate.run` closure async
mikrofon sessiyasining `_AsyncCompleter`ini ham capture qilgan. Real signed model
+ fake microphone integration test OLD code’da aniq
`Illegal argument in isolate message: object is unsendable ... _AsyncCompleter`
bilan yiqildi, ONNX init/decoder’ga yetib bormagan. Agent page generic catch xatoni
“Offline ovoz xizmati ishlamadi” qilib yashirgan. English system STT bu isolate
yo‘lidan foydalanmagani sabab ishlagan. Android original log exception’ni o‘zi
ko‘rsatmaydi (catch swallow); exact exception lokal full listen regression’da
isbotlandi, native logda mic capture tasdiqlandi.

`model_runtime.dart`dagi alohida `recognizeModelInBackground` worker’ni faqat
validated model, dir, PCM bilan yaratadi; recorder/completer/platform context
uzatilmaydi. Local TTS worker ham shu xavfsiz scope’ga ajratildi. Private audio,
recognized text/notes yoki raw exception’ni logga yozmaydigan stage/type diagnostic
qo‘shildi. SHA-256, Ed25519, license/ABI gates, model download va offline-only
qarori o‘zgarmadi. Model/key/release yangilanishi talab qilinmaydi.

`flutter analyze` **No issues, 4.4s**; full `flutter test --concurrency=1`
**163 PASS, exit0, 57s**. Opt-in real native full listen test OLD FAIL → FIXED
**1 PASS (~5s)**, no network requests during recognition; default worker regression
caller port/completer uzatilmasligini va native failure to‘g‘ri qaytishini tekshiradi.
Opt-in: `tool/voice_models/local_listen_test.dart` (Linux package LD_LIBRARY_PATH va
`BILGA_VOICE_LOCAL_TEST=true`); mavjud public assets local fake HTTP bilan sig/hash
tekshirilib disposable private root’ga o‘rnatiladi, so‘ng o‘chirib tozalanadi.
Bu sinov app-owned original model/data’ni o‘chirmaydi.

`flutter build apk --debug` **exit0, 95.9s** (CPU1 affinity); APK ZIP CRC va
Android v2 signature **PASS**. `build/app/outputs/flutter-apk/app-debug.apk`,
**293634246 bytes**, SHA-256
`d5dc783fe392d5027f6a1bc5abd5a44030ab4b0fe1655d01fc3750002b5e91d2`.
`adb install -r` **Success**: mavjud planshet app ustiga update; uninstall/data
clear bajarilmadi. Modelning barcha 8 fayli update’dan keyin yana SHA bilan
tekshirilib PRESERVED ekanligi tasdiqlandi. Yangilangan app logcat’i
`.buildlog/voice-init-fix/tablet-fixed-live.log`da. Planshetda real user microphone
sinovi **PASS**: 12:31:37.792 `STT worker starting` → 12:31:41.711
`STT decode completed` (~3.9s). User “Sinov qildim — xato chiqmayapti” deb tasdiqladi.
APK file-offset/proc-map solishtirishi arm64 **libonnxruntime.so 6 segment** va
**libsherpa-onnx-c-api.so 4 segment** real jarayonda yuklanganini tasdiqladi;
cxx-api bu C-API yo‘lida kerak emas va yuklanmagan. Native kutubxonalar APK’dan
bevosita mmap qilinadi, map’da alohida .so nomi ko‘rinmasligi xato emas. Vendor
`ro.hardware.chipname` property warning’idan keyin decode tugagan, fatal emas.
Ikki diagnostic logcat yozuvi sinov tugagach to‘xtatildi. Model qayta yuklanmadi;
user notes/audio serverga yuborilmadi. Bu startup/microphone decode sinovi, har bir
buyruq to‘g‘ri tanilishini yoki barcha tillarni sertifikatlamaydi.
GitHub push/publication, private key yoki app DB o‘zgarishi bajarilmadi. Avvalgi
preview accuracy/low-memory cheklovlari alohida saqlanadi; startup fix ularni hal
qilgan degani emas. Batafsil: `BILGA_OFFLINE_VOICE.md`.

## 2026-10-11 — Uzbek STT public preview nashr qilindi

Public model release: https://github.com/abdulAziz-Al-ILM/Bilga-Language-Models/releases/tag/voice-models-v1
`gh` auth va ADMIN huquqi tekshirildi. Faqat foydalanuvchi ruxsat bergan model
reposiga 12 ta public asset yuklandi; boshqa repolarga push/commit qilinmadi.
Release **prerelease**: APK/private kod, shaxsiy audio/yozuvlar va private key
public repo yoki release ichiga kiritilmadi.

Alpha Cephei Uzbek 0.60 manba/card Apache-2.0 litsenziyasi va pinned fayllar qayta
tekshirildi. License, NOTICE, original card va signed VALIDATION.md saqlandi.
ZIP `vosk-uz-small-0.60.zip`: **83919183 bytes**, SHA-256
`a3f1ce14f253fc1ccfce62dc5cc55f00545c976f5b2dd0766c87061cb6689bb3`.
Catalog revision **1**, expiry **2027-04-01T00:00:00Z**; 8 flat fayl ham ZIP ham
hash bilan imzolangan. GitHub serveridagi 12 asset size/SHA lokal nusxaga mos.
App ZIP extract qilmaydi, mavjud SHA/resume yordamida flat fayllarni o‘rnatadi.

Alohida Ed25519 seed lokal yaratilgan:
`/home/abdulaziz/.local/share/bilga-model-signing/catalog-ed25519-v1.seed`.
Directory0700/file0600, checkout tashqarisida; qiymati chiqarilmadi, upload yoki
APK build input bo‘lmadi. Owner xavfsiz offline backup olishi kerak; key’ni
qayta yaratmang. APK/billing kalitlariga tegilmadi. Public key:
`ACLVesaFlk6rXZzspz50XGzOPJ06/9tcW8fblcq62dA=`.
`model_release_config.dart` va example config public repo/tag/key bilan ulangan;
oddiy debug build ham endi configured. Explicit empty override downloads’ni yopadi.

Android API31/arm64 real native qualification: public Uzbek nutq 9.576s (bitta
“voz”→“ovoz” xato), 20dB noise, 20s repeated speech va silence ishladi; RSS
183584–185728 KiB. 512MiB **virtual address** limit FAILED native bad_alloc;
physical RAM bilan teng emas. Synthetic “to‘xta/davom et/o‘qib ber” ham NOTO‘G‘RI
aniqlandi. Bular signed review/release izohida ochiq. `androidReviewed:true`
faqat shu sinovdan o‘tgan API31+/arm64 native compatibility doirasi uchun;
universal aniqlik yoki low-memory acceptance emas. `preview:true` panelda qisqa
buyruq xatolari haqida warning beradi. Review/hash/signature/license gates
susaytirilmagan. Real user microphone va boshqa qurilmalar hali acceptance talab
qiladi. **Uzbek TTS kiritilmagan**, STT/TTS alohida ko‘rsatiladi; 43 til registry
saqlandi. No online STT/TTS fallback.

Yakuniy tekshiruvlar: `flutter analyze` **No issues**, 4.8s;
`flutter test --concurrency=1` **162 PASS, exit0**; Python acquisition/security/
archive testlar **7 PASS**. `flutter build apk --debug` **exit0** (CPU1 affinity,
23.3s); final APK CRC va Android v2 signature PASS.
APK `build/app/outputs/flutter-apk/app-debug.apk`: **293634246 bytes**, SHA-256
`2b290c3ee36f8f78872f2eef570067d0dd6fdcc1b38d0d14671463085f72dca4`.
Birinchi APK native-library CRC xatosi sabab karantinga olindi; faqat generated
APK/package cache ajratilib qayta yig‘ildi. Oldingi host hardware/native crash
muammosi butunlay tuzaldi deb hisoblamang. Dastlab test native SIGSEGV/timing
xatosi bo‘lgan; timing harness real state’ni kutishga moslandi va barcha testlar
qayta muvaffaqiyatli bajarildi, testlar o‘chirilmadi.

Public release real downloader testi ham **1 PASS (5m40s)**:
`flutter test tool/voice_models/live_download_test.dart --dart-define=BILGA_VOICE_LIVE_TEST=true`.
App VoiceModelStore actual 8 file download + pinned Ed25519/SHA + offline installed
reload + STT mavjud/TTS yo‘q tekshirildi; disposable storage o‘chirildi. Bu desktop
integratsiya, planshet UI/microphone acceptance hali alohida.

Log/public artifacts/review: `.buildlog/voice-release/`; batafsil
`BILGA_OFFLINE_VOICE.md`. Yangi APK avtomatik o‘rnatilmadi. Planshetda existing app
ustiga update qilib (uninstall/data clear qilmasdan), Core → Uzbek → Yuklab olish
(~89.8MiB), cancel/resume/restart, keyin airplane mode sinovi kerak.

## 2026-10-11 — haqiqiy Uzbek STT va model yuklash tayyorlanishi (oldingi bosqich tarixi)

“Til modeli yo‘q” sababi: joriy APK’da model repository/public key konfiguratsiyasi
bo‘sh; tilni tanlashning o‘zi model o‘rnatmaydi. Public release hali yaratilmagan.
`BILGA_OFFLINE_VOICE.md` endi exact manba, hashlar, format, imzolash/nashr qilish,
kerakli owner harakatlari va qolgan qurilma tekshiruvlarini tushuntiradi.

Alpha Cephei `vosk-model-small-streaming-uz` 0.60, Apache-2.0, pinned HF commit
`e0417cabfbbac4efdc34e7aba367501d126ae79c` tanlandi. To‘rtta model/token fayli,
upstream card, license va notice SHA-256 bilan tayyorlandi, jami 94130583 bytes.
Lock: `tool/voice_models/uzbek_stt.lock.json`; acquisition:
`tool/prepare_uzbek_voice.py`. Lokal assets va unsigned draft:
`.buildlog/voice-models/release/` (Git ignored, APK ichiga qo‘shilmagan).
Model card non-streaming deydi, real ONNX metadata streaming Zipformer2 ekan;
app `streaming_transducer` engine va lokal Sherpa OnlineRecognizer bilan moslandi.
“Online” bu yerda streaming API, network emas. Runtime alohida pure-Dart modulga
ajratildi; Whisper/SenseVoice/VITS saqlandi. 43 til registry’si saqlandi.

Panel boshlang‘ich katalogsiz ham consent bilan “Yuklab olish”ni taklif qiladi;
konfiguratsiyasiz disabled + tushunarli yangilash xabari. STT va TTS mustaqil.
Android TTS settings ochish va qaytganda default engine qayta tekshirilishi qo‘shildi.
Model manager’ning signature/SHA/resume/private-storage himoyalari saqlandi;
signer pinned hash/size farqini qayta hash bilan “tasdiqlab” yubormaydi.

Meta MMS Uzbek va RHVoice Uzbek ovozlari NC litsenziyali — tarqatishga qo‘shilmadi.
eSpeak NG Uzbek (`status testing`), Android engine, GPL3+ alohida offline variant;
planshetda o‘rnatilmagan/tekshirilmagan, VITS model emas. Automatic Uzbek TTS tayyor
deb ko‘rsatilmaydi; tegishli litsenziya/runtime review talab etiladi.

Real model Linux Dart smoke PASS. Ulangan Android API31/arm64 planshetda C API
smoke PASS: 3s silence, empty text, CPU 4.180s, peak RSS 183228 KiB. Test faqat
public model bilan vaqtinchalik `/data/local/tmp`da bajarildi va fayllar o‘chirildi;
user notes/mic/app DB ishlatilmadi. Bu real nutq aniqligi yoki app end-to-end emas.
Draft `androidReviewed:false` saqlanadi; signer/app uni qabul qilmaydi. Owner haqiqiy
Uzbek commands/noise/20s/low-memory acceptance’dan so‘nggina review attestation beradi.
Public repo/tag, tashqarida saqlanadigan Ed25519 model key, signed release va pinned
public config bilan yangi APK hali kerak. Production key yaratilmagan/o‘qilmagan.

Yakuniy validation: `flutter analyze` **No issues found**, 6.0s;
`flutter test --concurrency=1` **159 PASS, exit 0**, 66s (notes/backup/billing ham);
`python3 tool/test_prepare_uzbek_voice.py` **4 PASS**.
`flutter build apk --debug` **exit 0, 27.6s**; APK CRC + v2 signature PASS.
APK: `build/app/outputs/flutter-apk/app-debug.apk`, 321346296 bytes, SHA-256
`be7289c8fa68a5d7a9045e1f95b723092662f2aeee223865b16dea6a115f6cc5`.
Loglar `.buildlog/voice-models/`. APK hozirgi app ustiga o‘rnatilmadi. Oldingi host
memory instability tarixini bu muvaffaqiyatli run hal bo‘lgan deb hisoblamang.
Commit/push, repo/release yaratish yoki shaxsiy ma’lumot yuborish bajarilmadi.

## 2026-10-11 — 40 kunlik trial va Core lifetime litsenziyasi

Joriy foydalanuvchi qarori: **aniq 40 kun**, keyin bir martalik lifetime Core
xaridi, oylik obuna yo‘q. Play product/server hali yo‘q; foydalanuvchi **hozircha
konfiguratsiya tayyor bo‘lsin** deb tasdiqladi. Server/repo yaratilmagan.

Oldingi kod trial’ni amalga oshirmagan: Start/Finance receipt bo‘lmasa funksiyalar
`access.allowed == false` bilan yopilgan, `xUnavailable` Google Play xabarini
chiqargan. Endi Keystore AES-GCM + private AtomicFile trial, clock high-water /
elapsedRealtime, birinchi ochilish tushuntirishi, 40 kun tugash paywall’i bor.
Billing trial/startup’ni kutkazmaydi. Trial va paid ownership alohida.

Asl DB/vault va eski receipt kalitlari o‘zgartirilmadi. Haqiqiy imzoli eski
Start/Turbo/Finance egalariga Core access saqlanadi; upgrade alone huquq bermaydi.
Bo‘sh/partial restore receipt’larni o‘chirmaydi. Paywall’da profil/zaxira/eksport
mavjud, mavjud editor mounted qoladi. Cheksiz debug preview olib tashlandi;
`BILGA_TRIAL_TEST=expired|billing_unavailable` faqat Dart debug + Android debug’da
holatni sinaydi, xarid huquqi bermaydi.

Yangi `bilga_core_lifetime` default ID konfiguratsiyadan o‘zgaradi (legacy ID
bilan almashtirmang). Yangi xarid uchun Google RSA receipt + HTTPS backend’ning
pinned Ed25519 attestation’i talab qilinadi. Public config namunasi va backend
protokoli: **BILGA_LICENSE_TRIAL.md**. Live billing end-to-end tekshirilmagan;
konfiguratsiyasiz xarid tugmasi o‘chiq, trial ishlaydi. Maxfiy kalitlarga tegilmadi.

**Cheklov:** uninstall lokal trial/Keystore’ni yo‘qotadi. Sof offline holatda
reinstall’ni yangi user’dan ishonchli ajratish imkonsiz; qayta trial berilishi
mumkin. Buni to‘liq to‘sadigan authenticated server trial/recall hali yo‘q.
Offline refund ham darhol aniqlanmaydi. Bu cheklovlarni hal bo‘lgan deb yozmang.

Yakuniy `flutter analyze`: **No issues found**, 4.7s. Yangi **40 test PASS**,
`expired` va `billing_unavailable` define bilan har biri **15 test PASS**.
Umumiy serial `flutter test`: **146 PASS, exit 1**; avvaldan kuzatilgan native
FlutterTester SIGSEGV sabab `widget_test.dart`dagi 4 test + teardown incomplete.
Assertion/import xatosi qayd qilinmadi. Birinchi analyzer urinishlari ham native
SIGSEGV bilan yiqilgan, yakuniy analyzer o‘tgan. Host barqarorligi muammosi saqlanadi.
`flutter build apk --debug`: **exit 0, 37.2s**. APK CRC va v2 signature PASS,
321338152 bytes. SHA-256:
`c6be8b70d8f209c5dc6e87ce184f55953b418167dcc966da0bf65daf66629852`.
Artefakt: `build/app/outputs/flutter-apk/app-debug.apk`. Loglar `.buildlog/license-fix/`.
Planshet ulanmagan: native storage/reboot, real Play purchase/refund/reinstall
qurilma sinovlari hali bajarilmagan. Commit/push bajarilmadi.

## 2026-10-11 — Android build va backup source tiklanishi

Keyingi build tekshiruvida original to‘rtta `lib/features/backup/` fayli
`/home/abdulaziz/StudioProjects/bilga/` dan tiklandi. Testlar o‘chirilmadi.
Yakuniy CPU cheklovisiz `flutter analyze` — **No issues found**,
`flutter build apk --debug` — **exit 0, 53.3s**. APK CRC va v2 signature’dan
ham o‘tdi (`build/app/outputs/flutter-apk/app-debug.apk`, ~280 MiB).
App’ga ulanmagan
`optional/` va mustaqil `vendor/` paketlari app analyzer scope’idan ajratildi.

Gradle’dagi o‘chirilgan Android Studio JBR yo‘li olib tashlandi. Mavjud JDK 21,
Gradle 9.3.1, AGP 9.1.0, Kotlin 2.4.0 saqlandi. Standalone SDK/JDK muhiti
`tool/android_env.sh` va VS Code tasklarida tayyorlandi. Build task’i
`tool/verify_android_apk.sh` orqali CRC/signature/hash tekshiradi.
Plugin uchun zarur SDK Platform 34 rasmiy manbadan avtomatik o‘rnatildi.

Oddiy APK build JDK 21 G1 GC SIGSEGV’ini qayta kuzatdi
(`android/hs_err_pid13165.log`). Dart analyzer/kompilyatori ham GC’da qulaydi;
CPU affinity sinovlari yordam beradi. Ammo Java/Dart’dan mustaqil 1 GiB C
memory probe ikki marta **bit 33 buzilishi**ni aniqladi (`XOR=0x200000000`,
exit 1). Host memory/hardware barqarorligi jiddiy gumon ostida; aniq RAM/CPU
sababini boot/hardware diagnostikasi bilan ajratish kerak. CPU affinity
apparatni tuzatmaydi.

Ikkita buzilgan Gradle transform JAR’i (bundletool/sdklib) va bitta compressed
kernel asset cache’i karantinga olinib qayta yaratildi. 1116 tayyor transform
JAR CRC’dan o‘tdi. Birinchi BUILD SUCCESSFUL APK’ning o‘zi ham CRC’da yiqilgan;
shuning uchun exit 0 bilan cheklanilmadi. Yakuniy APK yaxlit.

**Testlar barqaror PASS emas:** birinchi CPU 1 + serial urinishda 110 PASS;
yakuniy odatiy parallel urinishda 105 PASS + native tester SIGSEGV sabab
6 incomplete holat (teardown bilan); yakuniy CPU 1 + serial urinishda
109 PASS + home_layout tester SIGSEGV (test va teardown incomplete).
Backup import/load xatolari qaytmadi. Testlar o‘zgartirilmadi; hardware/memory
diagnostikasisiz bu native crash’larni hal bo‘lgan deb belgilamang.
Batafsil joriy natijalar: `ANDROID_BUILD_VALIDATION.md`.
Pastdagi 172 issue / 8 load failure natijalari **tiklashdan oldingi** tarixdir.
Commit/push va maxfiy kalitlarga o‘zgartirish bajarilmadi.

## 2026-10-11 — offline o‘qish, ko‘p tillilik va model boshqaruvi

Tekshirilgan boshlang‘ich commit: `667b62a`. Quyidagi o‘zgarishlar working tree’da;
commit/push bajarilmadi. Ushbu bosqichda Flutter source bor edi, lekin
`lib/features/backup/` yo‘q edi; pastdagi tarixiy “full source” qaydlari barcha
release fayllari to‘liqligini isbotlamaydi.

Amalga oshirilgan:
- `ReadingController`: matnni to‘liq serial bo‘laklash, pauza/davom, eski sessiya
  callbacklarini bekor qilish. Android system TTS va lokal model kichik WAV’ni
  private cache’da yaratadi; MediaPlayer joriy audio pozitsiyasini saqlaydi.
- “To‘xta” pauza qiladi; “davom et” audio pozitsiyasidan davom ettiradi.
  O‘qish vaqtida mikrofonni bosish darhol pauza qiladi, keyin offline buyruq
  tinglanadi. Passive/always-on microphone yo‘q. Bookmark faqat sessiya xotirasida.
- Ilovadagi 43 til uchun markaziy stop/resume/read sinonimlari va offline ovoz
  mavjudligi xabarlari; boshlang‘ich til ilova sozlamasidan olinadi.
  STT tanigan boshqa tildagi buyruqlar ham shu registry orqali tekshiriladi.
- Android bridge faqat `createOnDeviceSpeechRecognizer` ishlatadi. API 33+
  installed til paketlarini so‘raydi; API 31–32 mavjudlikni “tekshirilmagan” deb
  ko‘rsatadi. TTS faqat matching, installed, non-network voice tanlaydi.
  Online speech va unknown-command web fallback olib tashlandi.
- Sherpa ONNX 1.13.8: app-private modellardan Whisper/SenseVoice STT va
  VITS/Piper-compatible TTS, UI’dan alohida isolate’da lokal inference.
- GitHub Releases model manbasi konfiguratsiyadan; repo yoki haqiqiy model
  yaratilmagan/yuklanmagan. Tanlangan tildagi yetishmayotgan STT/TTS explicit
  download consent’dan so‘ng avtomatik olinadi; qo‘lda boshqarish ham mavjud.
- Ed25519 bilan pin qilingan katalog, expiration/revision tekshiruvi,
  fayllarda size/SHA-256, private storage, progress, cancel, Range resume,
  retry, o‘chirish, storage usage. Catalog refresh/install serial himoyalangan.
  Failed update oldingi imzolangan modelni offline restart’da ham saqlaydi.
- Litsenziya allowlist’i va signed maintainer review, Android minSdk/ABI gate.
  Litsenziya/moslik attestatsiyasi real model auditining o‘rnini bosmaydi.
  Model downloader faqat asset GET’larini yuboradi; notes/audio API’si yo‘q.

Batafsil arxitektura, cheklovlar, katalog sxemasi va konfiguratsiya:
`BILGA_OFFLINE_VOICE.md`, `voice_models.example.json`.
Katalogni lokal imzolash: `tool/sign_voice_catalog.dart`.
Private signing seed’ni repoga yozmang.

Validation (2026-10-11):
- `flutter analyze lib/features/agent test/agent_command_test.dart test/offline_reading_test.dart test/offline_voice_test.dart test/voice_model_store_test.dart tool/sign_voice_catalog.dart` — **No issues found**.
- `flutter test test/agent_command_test.dart test/offline_reading_test.dart test/offline_voice_test.dart test/voice_model_store_test.dart --concurrency=1 --reporter expanded` — **69 PASS**.
- `flutter analyze` — **172 issues**, asosiy to‘siqlar: avvaldan yo‘q backup
  importlari, optional/turbo va alohida vendor/example dependencylari.
  Yangi yordamchi modullarida analyzer issue yo‘q.
- `flutter test --concurrency=1 --reporter expanded` — **70 PASS, 8 load failures**;
  backup fayllari yo‘qligi app importlari va umumiy test helper’ini buzmoqda.
  Notes/backup regressiyasi to‘liq tasdiqlanmadi; mavjud persistence testlari ham
  shu yetishmayotgan helper importi sabab yuklanmaydi.
- `flutter build apk --debug` — avvaldan mavjud noto‘g‘ri
  `org.gradle.java.home=/home/abdulaziz/Downloads/android-studio/jbr` sabab fail.
  Java manzilini faqat buyruqda override qilgan Kotlin Gradle sinovlari JVM
  SIGSEGV/daemon crash bilan to‘xtadi; build config o‘zgartirilmadi.
- `OfflineVoiceBridge.kt` + `MainActivity.kt` Android API 36 jar va vaqtinchalik
  Flutter/AudioService bridge stublari bilan alohida Kotlin kompilyatsiya —
  **exit 0**. Bu APK build yoki real Flutter plugin integratsiya sinovi emas.
- Katalog signing tool dummy fixture’da SHA-256 hisoblab, imzolangan katalog
  chiqardi — **PASS**. Fixture haqiqiy ovoz modeli emas.
- `git diff --check` — **PASS**. `adb devices -l` — ulangan qurilma yo‘q.

Ochiq cheklovlar va keyingi qadamlar:
1. Yo‘q backup source fayllarini ishonchli originaldan tiklash; full analyze,
   persistence/backup testlari va APK build’ni qayta bajarish.
2. Alohida model Releases manbasini keyin belgilash; actual modellarni
   litsenziya, til coverage, Android ABI/SDK va RAM bo‘yicha tekshirib imzolash.
   Private key app/server’dan olinmaydi; faqat public key trusted build’da pin qilinadi.
3. Real Android’da airplane mode, qurilmadagi STT/TTS til ro‘yxati, pause/resume,
   foreground mic interruption, background/lock, model install/restart/update,
   low storage va native inference’ni sinash. Hozircha device-validated emas.
4. Til aniqlash conservative sentence/script/word hint’laridir. Bir xil scriptdagi
   aralash tillar uchun qo‘lda til tanlash kerak bo‘lishi mumkin; 43 til registry’si
   43 tilga tayyor STT/TTS bor degani emas. Tarjimalar native-speaker review talab qiladi.

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
- **40 kunlik to‘liq trial** (2026-10-11 dagi aniq qaror va yuqoridagi implementatsiya);
- trial tugagach, taxminan **$7 bir martalik lifetime unlock**;
- Bilga Core uchun oylik obuna yo‘q;
- foydalanuvchi unlock qilgach, Core funksiyalaridan foydalanishda davom etadi;
- bug fix, Android compatibility, security va performance yangilanishlari davom etadi;
- katta yangi imkoniyatlarni Core ichiga cheksiz qo‘shib borish rejalashtirilmaydi.

**Trial 40 kun deb tasdiqlangan. Play product ID va hududiy narxlar hali Console’da sozlanmagan; default/config uchun yuqoridagi 2026-10-11 bo‘limiga qarang.**

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
