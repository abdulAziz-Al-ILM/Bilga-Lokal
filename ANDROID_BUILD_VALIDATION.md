# Android build tekshiruvi — 2026-10-11

## Yakuniy natijalar

| Tekshiruv | Natija |
| --- | --- |
| `flutter doctor -v` | Bajarildi; JDK 21 + standalone SDK topildi, pastdagi 3 warning/error kategoriyasi saqlanadi |
| `flutter analyze` (CPU cheklovisiz) | **PASS**, No issues found, 5.2 soniya |
| `flutter test --reporter expanded` (odatiy parallel) | **FAIL**, 105 PASS; native `flutter_tester` SIGSEGV sabab 6 incomplete holat (jumladan teardown) |
| `taskset -c 1 flutter test --concurrency=1 --reporter expanded` | Avval **110 PASS**; yakuniy takrorlash **FAIL**, 109 PASS + home_layout native SIGSEGV (test va teardown incomplete) |
| `flutter build apk --debug` (CPU cheklovisiz, yangi daemon) | **PASS**, exit 0, 53.3 soniya |
| `bash tool/verify_android_apk.sh` | **PASS**, butun ZIP CRC + APK v2 signature + SHA-256 |

Backup’ga oid oldingi 8 load failure tuzatildi; hech bir test o‘chirilmadi.
Host’da takrorlangan xotira bit buzilishi **software konfiguratsiyasi bilan
to‘liq tuzatildi deb hisoblanmaydi**. Parallel va yakuniy serial test failure’lari
yashirilmaydi. Muvaffaqiyatli build/test urinishlari host’ning barcha
keyingi ishga tushishlari barqarorligini kafolatlamaydi.

## Tiklangan konfiguratsiya va source

- `android/gradle.properties` ichidagi o‘chirilgan
  `/home/abdulaziz/Downloads/android-studio/jbr` manzili olib tashlandi.
  Flutter konfiguratsiyasi mavjud `/usr/lib/jvm/java-21-openjdk-amd64` JDK’ni
  tanlaydi; Android Studio talab qilinmaydi.
- Flutter 3.47.1, Dart 3.13.1, OpenJDK 21.0.12.1, Gradle 9.3.1,
  AGP 9.1.0 va Kotlin 2.4.0 versiyalari almashtirilmadi.
  JDK paketining `dpkg -V openjdk-21-jre-headless` tekshiruvi farq topmadi.
  [AGP talablari](https://developer.android.com/build/releases/agp-9-1-0-release-notes)
  Gradle 9.3.1 va kamida JDK 17;
  [Gradle mosligi](https://docs.gradle.org/9.3.1/userguide/compatibility.html)
  JDK 21 bilan ishlashga ruxsat beradi. SIGSEGV oddiy versiya mos kelmasligi
  yoki Java source target 17 sabab bo‘lgan deb da’vo qilinmaydi.
- To‘rtta original backup moduli lokal
  `/home/abdulaziz/StudioProjects/bilga/lib/features/backup/` dan tiklandi:
  `backup_codec.dart`, `backup_store.dart`, `drive_service.dart`,
  `media_backup.dart`. Original va joriy notes/private database source’lari
  `cmp` bilan bir xil ekani tekshirildi. Testlar o‘chirilmadi/o‘zgartirilmadi.
- Analyzer arxivdagi `optional/` va Bilga dependency’si bo‘lmagan mustaqil
  `vendor/` plugin/example paketini app tahlilidan ajratadi. Ilovaning
  `lib/`, `test/`, `integration_test/` va `tool/` fayllari tekshiriladi.

## Android Studio’siz ishlash

Loyiha ildizidagi Bash terminalida:

```bash
source tool/android_env.sh
flutter doctor -v
flutter analyze
flutter test
flutter build apk --debug
bash tool/verify_android_apk.sh
```

Script mavjud `JAVA_HOME`/SDK’ni ishlatadi; Java yo‘li bo‘lmasa system Java’dan
aniqlaydi. SDK platform-tools PATH’da birinchi turadi. VS Code Tasks menyusida
`Bilga: Android doctor` va `Bilga: debug APK` mavjud. Flutter/Dart VS Code
extension’lari oldindan o‘rnatilgan muhitda tekshirildi.
Debug APK task’i build’dan keyin CRC va APK imzosini ham tekshiradi.
`verify_android_apk.sh` read-only; SDK’dagi eng yangi o‘rnatilgan apksigner’ni
tanlaydi, maxfiy kalitlarni o‘qimaydi/o‘zgartirmaydi va yangi versiya yuklamaydi.

SDK: `/home/abdulaziz/Android/Sdk`, command-line tools 23.0,
build-tools 36.0.0, NDK 28.2.13676358. Qo‘shimcha JDK/Android Studio yoki
tasodifiy toolchain versiyalari o‘rnatilmadi.

Doctor’dagi cheklovlar:

- Command-line tools 23.0 `sdkmanager --licenses` uchun
  `Warning: The --licenses option is no longer needed.` qaytaradi.
  Flutter 3.47.1 esa eski `All SDK package licenses accepted.` javobini kutadi;
  shu sabab **license status unknown**. SDK’da license fayli mavjud; bu
  tekshiruv barcha litsenziyalar qabul qilinganini isbotlamaydi. APK build
  Platform 34 uchun `License ... accepted` natijasini alohida tasdiqladi.
- SDK adb bilan birga `/usr/lib/android-sdk/platform-tools/adb` ham o‘rnatilgan.
  Script SDK adb’ni birinchi tanlaydi; boshqa system paket o‘chirilmadi.
- Chrome va Linux desktop build kutubxonalari yo‘q. Ular Android APK uchun
  talab qilinmaydi. Ulangan Android qurilma yo‘q.

## Runtime diagnostikasi va tekshiruvlar

Oldingi Java loglari: `android/hs_err_pid48205.log` (G1 GC),
`android/hs_err_pid50812.log` (Serial GC). Ikkalasi ham SIGSEGV;
heap yetishmasligi haqidagi oddiy Java exception emas. Faqat GC’ni almashtirish
oldingi urinishda yordam bermagan. Hozirgi Gradle tekshiruvi o‘sha JDK’da
Flutter Gradle Kotlin kodini kompilyatsiya qildi, keyin dependency download’da
kutdi; `jcmd Thread.print` SSL download stack’ini ko‘rsatdi.
Oddiy `flutter build apk --debug` yana G1 GC’da SIGSEGV bilan tugadi,
`android/hs_err_pid13165.log` yaratildi (Gradle exit 1, 209 soniya).

Bu tekshiruvda Dart analyzer va test kompilyatori ham SIGSEGV bilan qulagan.
Odatiy `flutter analyze` qayta urinishda ham `MarkingVisitor::VisitPointers`
GC stack’ida yiqildi. Shuning uchun faqat Java yoki Bilga source’ni sabab
deb belgilash uchun dalil yetarli emas. SDK/JDK versiyalarini almashtirish
o‘rniga CPU affinity bilan nazorat sinovlari bajarildi:

| Buyruq | Natija |
| --- | --- |
| `taskset -c 0 flutter analyze` | PASS, No issues found |
| `taskset -c 0,1 flutter analyze` | PASS, No issues found |
| `taskset -c 2,3 flutter analyze` | PASS, No issues found |
| `taskset -c 4,5 flutter analyze` | PASS, No issues found |
| `taskset -c 1 flutter test --concurrency=1 --reporter expanded` | **110 PASS**, 55 soniya |

6,7 / 0–3 / 4–7 CPU sinovlari SIGSEGV bilan tugagan; ular bir vaqtda
bajarilgani sabab aniq nosoz yadroni yoki hardware sababini isbotlamaydi.
8 CPU’dagi kichik (64 MiB) C memory/compute probe xato topmadi. Ammo
**1 GiB probe ketma-ket ikki urinishda bir bit buzilishini aniqladi**:

| Urinish | O‘qilgan qiymat | Kutilgan qiymat | XOR |
| --- | --- | --- | --- |
| 1 (CPU 0, index 12295025) | `c9d2820d61dca536` | `c9d2820f61dca536` | `0x200000000` |
| 2 (CPU 5, index 11549943) | `48f32a6667c78a71` | `48f32a6467c78a71` | `0x200000000` |

Har ikki probe exit 1 qaytardi. C dastur unsigned deterministic pattern’ni
har thread’ning alohida buffer’iga yozib, volatile read bilan solishtiradi;
Java, Dart, Gradle yoki Bilga dependency’larini ishlatmaydi. Buffer’lar jami
1 GiB; disk/user ma’lumotlariga yozmaydi. Source va har ikki log
`.buildlog/android-build-fix/` da saqlangan. JVM’dagi alohida kichik
4-thread GC probe o‘tdi; bu katta workload barqarorligini kafolatlamaydi.
Xato qiymatlarning kutilgan natijalari mustaqil Python integer hisobida ham
tasdiqlandi (ikkalasi ham birinchi round’dagi pattern). Alohida ketma-ket
1 GiB Python mmap memory probe 4 round’da o‘tdi. Xatolar workload’ga bog‘liq;
bir marta muvaffaqiyatli tekshiruv apparat barqarorligini isbotlamaydi.

Bu dalillar **host xotirasi/apparat barqarorligi muammosi**ni kuchli ko‘rsatadi.
Aynan RAM moduli, memory controller yoki CPU ekanini userspace probe bilan
aniq ajratib bo‘lmaydi; mustaqil boot/hardware memory diagnostikasi kerak.
Java/Dart GC buzilgan pointer’ga duch kelishi shu natijaga mos keladi,
lekin har bir crash’ning kelib chiqishi alohida isbotlanmagan.
CPU affinity **vaqtinchalik diagnostik workaround**, apparat tuzatishi emas.
Toolchain versiyalarini tasodifan o‘zgartirish bu topilmani bartaraf etmaydi.

CPU cheklovi bilan diagnostikani qaytarish uchun (`source tool/android_env.sh`
dan so‘ng; bu buyruqlar ham barqarorlikni kafolatlamaydi):

```bash
taskset -c 0,1 flutter analyze
taskset -c 1 flutter test --concurrency=1 --reporter expanded
taskset -c 0,1 flutter build apk --debug
```

Affinity host’ning boshqa jarayonlariga yoki OS sozlamalariga qo‘llanmadi.
Gradle oldindan ishlayotgan boshqa daemon’ni reuse qilsa, uning CPU affinity’si
o‘zgarmaydi; bu sinovda yangi daemon `Cpus_allowed_list: 0-1` bilan tekshirildi.
App/runtime konfiguratsiyasiga `-Xint` yoki GC almashtirish bayroqlari yozilmadi.

110 test ichida database migration, atomic backup rollback, takroriy restore,
habit backup, noto‘g‘ri password/tamper rejection, notes/todo, localization,
offline ovoz va model katalogi tekshiruvlari bor. Oldingi 8 load failure
backup source yo‘qligidan edi; ular endi yuklanib bajariladi.

Build konfiguratsiyasi mavjud pluginlar uchun yetishmagan Android SDK
Platform 34 revision 3’ni rasmiy SDK manager orqali muvaffaqiyatli o‘rnatdi.
`file_picker`, `flutter_tts`, `in_app_purchase_android`, `video_player_android`
uchun eski KGP ishlatilishi haqida future-Flutter warning chiqdi; versiyalar
almashtirilmadi, bu ogohlantirish hozirgi build failure emas.

CPU cheklangan birinchi urinish 1270.7 soniyadan so‘ng batafsil log rejimiga
o‘tish uchun bekor qilindi (exit 143); bu muvaffaqiyatli build emas.
`taskset -c 0,1 flutter build apk --debug -v` qayta urinishda (31 soniya,
exit 1) aniq cache integrity xatosini ko‘rsatdi:
`~/.gradle/caches/9.3.1/transforms/fc55adc9a4cde068651c3384485aa770`.
Uning `instrumented-bundletool-1.16.0.jar` faylida `unzip -tq` ikkita
class uchun **bad CRC** topdi. Original `bundletool-1.16.0.jar` CRC’dan
o‘tdi. Faqat shu transform `/tmp/bilga-gradle-quarantine/` ga ko‘chirildi;
butun cache o‘chirilmadi. Qayta build bu to‘siqdan o‘tdi. Cache buzilishi
oldingi runtime/xotira xatolari bilan mos, lekin kelib chiqishi alohida
isbotlanmagan.

Ikkinchi tayyor transform’da ham CRC xatosi tasdiqlandi:
`771ec701f8d8959fd4ca1b40f8a0888b/instrumented-sdklib-31.11.1.jar`.
Original dependency CRC’dan o‘tdi; faqat buzilgan transform karantinga olindi.
So‘ng **1116 ta tayyor transform JAR CRC tekshiruvidan o‘tdi**. Tugallanmagan
UUID suffix’li vaqtinchalik workspace’lar ushbu yakuniy skanga kiritilmadi.

Ikki CPU’dagi build 736.5 soniyada exit 0 qaytardi, **716 task (505 executed)**,
ammo APK CRC tekshiruvi `assets/flutter_assets/kernel_blob.bin` da xato topdi.
Android original APK va Flutter nusxasining SHA-256’i bir xil edi;
muammo nusxalashda emas. Paketlashdan oldingi ikkala raw kernel faylining
CRC’si `5be98e60`, APK entry’sida kutilgan ham `5be98e60`, lekin o‘qilgani
`bbbd322e` edi. Buzilgan APK diagnostika uchun karantinda saqlandi.

Bir CPU’dagi paketlash qayta urinishida (99.9 soniya, exit 0) ham ayni hash/CRC
qaytdi. Sabab: `compressDebugAssets` oldindan buzilgan
`compressed_assets/.../kernel_blob.bin.jar` ni UP-TO-DATE deb ishlatgan.
Shu **bitta siqilgan asset cache’i** karantinga olinib qayta yaratildi.
Keyingi `taskset -c 1 flutter build apk --debug -v` — **exit 0, 28.3 soniya**.

Yakuniy APK (`build/app/outputs/flutter-apk/app-debug.apk`):

- Hajmi: **293600334 bytes** (taxminan 280 MiB).
- SHA-256: `79c908af25140b9922bf81f7513bd2a028386d1cb96b2bc3b7e2a243c401d0a8`.
- `unzip -tq` — **PASS**, barcha entry CRC’lari to‘g‘ri.
- SDK `apksigner verify --verbose` — **PASS**, v2 signature tekshirildi.
- `verify_android_apk.sh` yaxlit APK’da exit 0, oldingi haqiqiy buzilgan APK’da
  exit 2 qaytardi. Faqat build exit 0 natijasiga tayanish yetarli emasligi
  amalda qayd etildi.

CPU cheklovisiz, yangi daemon bilan `flutter build apk --debug` ham
**exit 0, 53.3 soniya** bilan tugadi. Shu artifact yana CRC/signature/hash
tekshiruvidan o‘tdi; yuqoridagi SHA-256 saqlandi. Keyin CPU cheklovisiz
`flutter analyze` — **exit 0, 5.2 soniya**.

Yakuniy parallel `flutter test --reporter expanded` — **exit 1, 28 soniya**:
105 PASS, `TestDeviceException(Shell subprocess crashed with segmentation
fault.)`, localization/editor persistence uchun 6 incomplete holat
(ulardan biri teardown). Bu backup load/import failure emas; hech qanday
testni o‘chirish yoki expectation’ni susaytirish bilan yashirilmadi.
Avvalgi serial/CPU sinovida barcha 110 test o‘tgan. Ayni serial/CPU profilning
yakuniy takrorlanishida **exit 1, 57 soniya**, 109 PASS va `home_layout_test`
uchun native tester SIGSEGV (1 test + teardown incomplete) qayd etildi.
Demak, CPU affinity ham ishonchli doimiy tuzatish emas. Testlar to‘liq/barqaror
PASS deb belgilanmaydi; yangi assertion/import xatosi bilan aralashtirilmaydi.
Diagnostik loglar lokal `.buildlog/android-build-fix/` ichida saqlanadi,
Git’ga kiritilmaydi. Release signing konfiguratsiyasi va maxfiy kalitlar
o‘zgartirilmadi. Commit/push bajarilmadi.
