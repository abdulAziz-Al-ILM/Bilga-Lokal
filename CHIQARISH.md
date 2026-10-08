# Bilga: bepul Notes + To Do, 1.0.0+5

Bu paket bepul Notes va To Do, profil, 43 til, 7 mavzu hamda shifrlangan zaxira funksiyalarini qo‘shadi. Bajarilgan tekshiruvlar va qolgan cheklovlar TEKSHIRUV.md’da. Google hisobini ulash uchun GOOGLE_SETUP.md’dagi egaga tegishli sozlamalar kerak.

## 1. Kodlarni o‘rnatish

ZIP’ni Downloads ichida **bilga-shablonlar-v5** nomli alohida papkaga oching. Mavjud StudioProjects/bilga papkangizni o‘chirmang. Kompyuter terminalida:

```bash
python3 ~/Downloads/bilga-shablonlar-v5/install_update.py ~/StudioProjects/bilga
cd ~/StudioProjects/bilga
bash tool/check_free_release.sh
```

Agar ZIP ichidagi fayllar yana ichki papkaga tushgan bo‘lsa, install_update.py turgan yo‘lni ishlating. Yordamchi faqat o‘zgargan fayllarni ko‘chiradi va avvalgilarni StudioProjects ichidagi alohida zaxira papkaga saqlaydi. Yuborgan kodingizdan keyin biror fayl o‘zgargan bo‘lsa, hech narsani almashtirmasdan ro‘yxatini chiqaradi. Shu ro‘yxatni yuboring.

`flutter pub get` yangi SDK paketlari uchun pubspec.lock’ni yangilaydi. Flutter SDK talabi sizdagi kabi ^3.13.1 qoldirilgan; hozir ishlayotgan SDK’ni shoshilib almashtirish kerak emas. Analyzer xatolari jarayonni to‘xtatadi; avvaldan bor info va warninglar ko‘rsatiladi, ammo skriptni to‘xtatmaydi. Ularni ham ko‘zdan kechiring.

## 2. Mavjud telefondagi sinov ma’lumotini saqlash

Ilovani o‘chirish, uning xotirasini tozalash yoki emulatorda Wipe Data qilish kerak emas. Kod zaxirasi telefondagi bazani saqlamaydi.

Hozir o‘rnatilgan debug ilovaning bazasini o‘rnatishdan oldin nusxalash uchun:

```bash
adb devices
bash tool/backup_debug_data.sh DEVICE_ID
```

DEVICE_ID o‘rniga ro‘yxatdagi, masalan emulator-5554, qiymatni yozing. Bu yordamchi faqat debug qurilma uchun; ilovadagi foydalanuvchi zaxiralash funksiyasi emas. Chiqqan TAR fayl shifrlanmagan, uni shaxsiy doimiy joyga saqlang. U databases papkasini, shu jumladan SQLite yordamchi fayllarini oladi.

## 3. Qurilmada tekshirish

Android Studio’da emulatorni oching yoki telefonni USB debugging bilan ulang:

```bash
flutter devices
flutter test integration_test/data_safety_test.dart -d DEVICE_ID
flutter run -d DEVICE_ID
```

Integratsiya testlari alohida vaqtinchalik bazalarda ishlaydi; odatiy bilga.db va bilga_todo.db’ga murojaat qilmaydi. Test tugagach `flutter run` odatiy interfeysni qaytaradi.

Qo‘lda tekshiring:

- Eski Notes, papkalar, tarix va To Do vazifalari joyidami?
- Yangi yozuv yozing, bir soniya kuting: “Saqlandi” chiqsin. Darhol orqaga chiqib, qayta oching.
- Tez yozing, ilovani orqa fonga o‘tkazing va qayting. Saqlangan matn qolishi kerak. Majburan o‘chirilganda hali diskka yozilmagan oxirgi belgilarni mutlaq kafolatlab bo‘lmaydi.
- Yozuvni tahrirlang, boshqa papkaga ko‘chiring, tarixdan qaytaring.
- Bitta yozuvni alohida savatga yuboring, keyin papkani savatga yuborib tiklang. Avval o‘chirilgan yozuv savatda qolsin.
- To Do: yaratish, tahrirlash, sanasini o‘zgartirish, bajarilgan belgilash, papkaga kirish, o‘chirish tasdig‘i.
- Kichik ekran, katta shrift, klaviatura va haqiqiy telefonda ishlash. Emulatorning o‘zi yetarli emas.

Eski Notes v6 savatida qaysi yozuv qaysi o‘chirishga tegishli ekanligi saqlanmagan. Shu sabab eski savat papkasi tiklanganda uning avvalgi o‘chirilgan yozuvlari savatda alohida qolishi mumkin; ularni alohida tiklash mumkin. Yangi o‘chirishlarda papka bilan birga o‘chirilgan tarkib birga tiklanadi.

## 4. Imzolash kaliti

Ilova identifikatori: **com.ilmmizan.bilga**. Uni keyingi yangilanishlarda almashtirmang.

Agar bu ilova uchun oldin release/upload kaliti yaratgan bo‘lsangiz, o‘shani ishlating. Birinchi marta bo‘lsa:

```bash
mkdir -p ~/bilga-keys
keytool -genkey -v -keystore ~/bilga-keys/upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

`keytool` topilmasa, Android Studio JBR papkasidagi keytool ishlatiladi, masalan:
`~/Downloads/android-studio/jbr/bin/keytool`.

`android/key.properties.example` faylidan `android/key.properties` nusxa yarating. Parollar va keystore’ning to‘liq yo‘lini o‘z kompyuteringizda to‘ldiring. Haqiqiy key.properties yoki .jks faylni chatga/GitHub’ga yubormang. Kalit va parolni xavfsiz zaxiralang.

Debug va release imzolari turlicha. Release APK debug ilovaning ustiga o‘rnashmasligi mumkin. Buni ilovani o‘chirib hal qilishga shoshilmang: oldin ma’lumot nusxasi kerak. Play App Signing ishlating; keyingi do‘kon yangilanishlarida o‘sha ilova va imzolash zanjiri saqlanadi.

## 5. Play faylini yig‘ish

Avval GOOGLE_SETUP.md bo‘yicha Google Drive’ni sozlang va ikki qurilmada zaxira/tiklashni tekshiring.

```bash
bash tool/build_play_bundle.sh
```

Natija: `build/app/outputs/bundle/release/app-release.aab`.

Skript Play’ga yubormaydi va Android integratsiya testlari bajarilganini o‘zi tekshirmaydi. 3-bosqichni alohida yakunlang. Obfuscation kodni tahlil qilishni qiyinlashtiradi, mutlaq himoya bermaydi; release-symbols papkasini ushbu AAB bilan birga shaxsiy arxivda saqlang. Debug kaliti bilan release chiqarish bloklangan.

## 6. Play Console’da yakunlanadigan ishlar

- Ilova bepul. Hozir xaridlar, reklama va AI yo‘q.
- Developer akkaunt/verifikatsiya va kerakli test trekini tayyorlash.
- Bilga uchun sodda yozuv + belgi ikonkasi qo‘shildi: release/bilga-icon-512.png. Telefonning o‘zidan yangi screenshots olish va feature graphic tayyorlash qolgan.
- Ilova tavsifi, qo‘llab-quvvatlash manzili, ommaviy privacy policy URL’i.
- Data safety, content rating, target audience va ads deklaratsiyasini haqiqiy funksiyalarga qarab to‘ldirish. Dasturchi aloqa ma’lumotlarini taxminan yozmang.
- AAB’ni avval sinov trekiga yuklash, Play ko‘rsatgan muammolarni ko‘rib chiqish.

2023-yil 13-noyabrdan keyin ochilgan yangi **personal** akkauntlarga kamida 12 tester 14 kun uzluksiz opted-in bo‘ladigan yopiq sinov talabi qo‘llanadi. Shundan so‘ng production ruxsati so‘raladi; bu avtomatik tasdiq emas. Akkauntingizga shu talab tushsa, bugun ommaviy chiqarishning iloji yo‘q, lekin sinovni boshlash mumkin.

Rasmiy manbalar (2026-09-06 tekshirildi):
- https://support.google.com/googleplay/android-developer/answer/14151465?hl=en
- https://docs.flutter.dev/deployment/android
- https://developer.android.com/studio/publish/app-signing

## 7. Keyingi yangilanishlar

- Bitta ilova va package ID saqlanadi. Hozir bepul bo‘lgan Notes/To Do keyin pullik qilib qulflanmaydi.
- `pubspec.yaml` dagi +4 — build raqami. Keyingi yuklashda +5 yoki Play’dagi eng katta raqamdan yuqorisini ishlating. Versiya nomi va DB schema versiyasi boshqa-boshqa narsalar.
- Notes bazasi hozir v8, fayl nomi bilga.db. To Do v6, bilga_todo.db. Hozir ikkalasi alohida saqlanadi.
- Har bir DB o‘zgarishi `onUpgrade` migratsiyasi bilan yoziladi; mavjud bazani o‘chirib yaratish yoki downgrade qilish ishlatilmaydi. Barcha avvalgi versiyalardan o‘tish sinovi saqlanadi.
- Notes v8 ga o‘tgach, eski v7 kodga oddiy qaytish ishlamasligi mumkin. Tuzatishni yangi versiya bilan oldinga chiqaring; bazani o‘chirmang.
- Pullik bo‘limlar keyin alohida xizmatlar sifatida, xaridlarni qayta tiklash imkoniyati bilan qo‘shiladi.

## Yangi imkoniyatlar va chegaralari

- Notes: ichma-ich papkalar, qidirish, avtomatik saqlash, tarix, sevimlilar, arxiv, teglar va savat.
- To Do: tavsif, muhimlik, ixtiyoriy muddat, bajarilgan holati, papkalar, qidirish va savat. Muddat — ekrandagi hisob; ilova yopiq paytda bildirishnoma hali yo‘q.
- Profil: mahalliy ism/avatar, 43 til, 7 rang palitrasi, och/tungi/tizim mavzusi, qurilma PIN/biometriyasi orqali ilova qulfi.
- Backup: parolli AES-GCM fayl eksport/importi, Google Drive’da qo‘lda nusxa yaratish/tiklash. Import mavjud ma’lumotni almashtirmaydi, alohida tiklangan papkalarga qo‘shadi. Bitta nusxani qayta import qilish takroriy yozuv yaratmaydi.
- Parol kamida 12 belgi; uni ilova saqlamaydi yoki qayta tiklab bermaydi. Yangi telefonda shu parol kerak. Drive orqali tiklashda shu Google hisobi ham kerak. Fayl orqali importda fayl va parol yetadi.
- Mahalliy SQLite bazasi maxsus shifrlanmagan. Ilova qulfi, zaxira shifrlashi va piratlikka qarshi himoya uch xil masala. Kod obfuscation mutlaq piratlik himoyasi emas.
- Zaxira hajmi: ochiq JSON 16 MiB gacha, shifrlangan fayl 32 MiB gacha. Profilning mavzu/til sozlamalari hozir zaxiraga qo‘shilmaydi; yozuvlar, vazifalar, papkalar, savat va tarix qo‘shiladi.
- Google Drive serverga uzluksiz sinxronlash emas; “Zaxira yaratish” tugmasi bosilgandagi nusxa. Avtomatik nusxa yaratish hali yo‘q.
- O‘zbekcha matnlar qo‘lda yozilgan; qolgan tillarda AI/mashina yordamidagi tarjima ishlatilgan. Barcha tillar ona tili mutaxassisi tomonidan tekshirilmagan.
- Tajriba, AI, habit tracker, ovozli agent va pullik xaridlar bu nashrga kiritilmagan.

43 tilning faqat matn fayllari kichik. Google, fayl tanlash, biometriya kabi funksiyalar va qurilmadagi shriftlar yakuniy ilova hajmiga alohida ta’sir qiladi; APK hajmi faqat tarjima hajmi bilan o‘lchanmaydi.

Android avtomatik tizim zaxirasi va to‘g‘ridan-to‘g‘ri ma’lumot ko‘chirish uchun chiqarib tashlash qoidalari qo‘shildi. Telefon almashtirishda Bilga ichidagi shifrlangan eksport yoki Drive nusxasidan foydalaning. Manba: https://developer.android.com/identity/data/autobackup

Keyingi backup formatini o‘zgartirganda eski `bilga-backup`/`bilga-data` version 1 fayllarini o‘qish yo‘lini saqlang va yangi formatga o‘tkazish testini qo‘shing. DB schema raqami, backup format raqami va Play build raqami mustaqil. Kelajakdagi ustunlar sabab eski zaxiralarni shunchaki rad etish to‘g‘ri yangilanish yo‘li emas.
