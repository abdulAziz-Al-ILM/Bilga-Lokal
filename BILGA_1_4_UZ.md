# Bilga 1.4.0 — yengil yangilanish

Bu paket avval o‘rnatilgan Bilga Private 1.3.0 loyihasi uchun. Kod, yo‘riqnoma va tekshiruvlar bor; tayyor APK yo‘q. APK quyidagi buyruq bilan sizdagi Android SDK orqali yig‘iladi.

## O‘rnatish

Android Studio va emulyatorni oddiy usulda yoping. Telefon/planshetdagi Bilga ilovasini o‘chirmang, ma’lumotlarini tozalamang. Agar ilova ochilsa, Sozlamalardan parolli `.bilga2` zaxira eksport qiling. Installer kompyuterdagi kodni zaxiralaydi, telefon ma’lumotlarini zaxiralamaydi.

```bash
cd ~/Downloads
unzip bilga-1.4.0.zip
cd bilga-1.4.0
python3 install.py ~/StudioProjects/bilga --check
python3 install.py ~/StudioProjects/bilga
cd ~/StudioProjects/bilga
bash tool/check_start.sh
```

`check_start.sh` muvaffaqiyatli yakunlangach:

```bash
bash tool/build_test_apk.sh
```

APK: `~/StudioProjects/bilga/build/app/outputs/apk/debug/app-debug.apk`.
Bu universal Android APK: ARM32, ARM64 va x86_64. Android 8+ talab etiladi. Unda sinov uchun pullik funksiyalar ochiq. Uni Play Console’ga yuklamang.

APK’ni planshetga fayl sifatida ko‘chiring va o‘rnating. Oldingi nusxaning imzosi mos kelmasa, ma’lumotli ilovani o‘chirib yubormang: avval zaxira talab qilinadi. Debug va Play orqali o‘rnatilgan nusxalarning imzolari odatda farq qiladi.

Installer `TO‘XTATILDI` desa, fayllarni majburan almashtirmang. U kompyuteringizda keyinroq tahrirlangan kodni himoya qiladi; xabarni yuboring. `flutter clean`, barcha keshlarni o‘chirish yoki SDK’ni qayta yuklash bu o‘rnatishning qismi emas.

## Nima o‘zgardi

| Bo‘lim | Yangi yoki tuzatilgan ish |
|---|---|
| Saqlash | SQLCipher ochilishidagi natija qaytaruvchi PRAGMA to‘g‘rilandi. Odat, moliya, tajriba, kitob va havola tahrirlari yozuv muvaffaqiyatli saqlanmaguncha yopilmaydi. Xato bo‘lsa matn formada qoladi. |
| Odatlar — bepul | Hafta kunlarini tanlash, butun sonli miqdor/maqsad/birlik, boshlashga turtki, kichik qadam, shaxsiy sabab, qisman natija, izoh, tanaffus, 28 kunlik ko‘rinish, istalgan oldingi kunni tahrirlash, arxiv va biriktirmalar. Rejasiz kun ketma-ketlikni buzmaydi. Tanaffus bajarilgan kun hisoblanmaydi. Jadval o‘zgarishining tarixi saqlanadi. |
| Pul daftari | Alohida valyutali daftarlar; kirim/chiqim, qarz/qaytarish, qolgan qarz, alohida oylar uchun budjet, kirim va xarajat hisobotlari, budjet qoldig‘i, qidirish, ko‘proq yozuvni ochish va CSV. Hisob butun kichik pul birliklarida yuritiladi. Bank, karta ulash, o‘tkazma yo‘q. |
| Tajribalar | Birinchi saqlashdayoq voqea, his-tuyg‘u, saboq va keyingi qadamni kiritish. Ish, hayot, hislar, shukronalik, ruhiy hayot va saboq bo‘yicha ajratish. Matn bo‘yicha qidirish. Biriktirmalar saqlanadi. |
| Kitoblar | Boblar, reja/qahramonlar, tartiblash, eski tahrirni tiklash, o‘chirilgan bobni qaytarish, shrift o‘lchami tanlanadigan o‘qish oynasi va bob xatcho‘pi. TXT/EPUB eksporti saqlanadi. |
| Notes va to-do | Oldingi papkalar, qidirish, shablonlar, tahrirlar, savat, vazifa muddatlari va ustuvorliklar saqlanadi. Shaxsiy matn maydonlarida klaviaturaga o‘rganish/takliflarni o‘chirish so‘rovi beriladi. |
| Musiqa | Oldingi fon ijrosi saqlanadi; 15/30/60/90 daqiqadan keyin to‘xtatish. Ovoz balandligi har siljishda diskka yozilmaydi. Muhit rasmlari cheklangan o‘lchamda dekodlanadi. |
| Google | Debug yig‘ish Google Web client ID’siz boshlanmaydi. Kirish, ruxsat, tarmoq, xizmat uzilishi xatolari farqlanadi. Bu Google Cloud va Play sertifikatlarini avtomatik ro‘yxatdan o‘tkazmaydi. |
| Yengillik | Oddiy yig‘ishda katta model/llama native plagini yo‘q. Til kataloglari kerak bo‘lganda yuklanadi. Yig‘ishda 1 Gradle worker va 2 GB Java heap limiti qo‘llanadi; bu butun kompyuter RAM limiti emas. Testlar bittadan bajariladi. |

## Yordamchi va narxlar

Start — lokal buyruqlar yordamchisi: yozuv/vazifa/odat yaratish, izlash, o‘qish/tahrirlash, musiqa, tasdiqdan keyin brauzer yoki telefon/SMS oynasini ochish. U erkin suhbat quradigan LLM emas. Ovoz tugma bosilganda ishlaydi; doimiy eshitish yo‘q. Offline nutqni tanish Android 12+ va qurilmaning o‘rnatilgan til xizmatiga bog‘liq. Matnli buyruqlar internet talab qilmaydi. Ixtiyoriy online ovoz tanlansa, Android nutq xizmati ovozni tashqariga yuborishi mumkin; maxfiy ishlashda uni yoqmang.

- Start mahsuloti: `bilga_agent_start`, taklif qilingan narx $2.49, bir martalik.
- Pul daftari: `bilga_finance`, taklif qilingan narx $5.00, bir martalik.
- Odatlar, yozuvlar, vazifalar, tajribalar va kitoblar: bepul.
- Narx/valyuta Google Play’dan olinadi. Kod Console’da mahsulot yoki narx yaratmaydi. Xarid va tiklash haqiqiy Play test akkauntida tekshirilishi kerak.

Turbo kodi `optional/turbo` ichida saqlangan. Oddiy 1.4.0 yig‘ishda katta model yo‘q va Turbo sotuvga taklif qilinmaydi. Oldingi Turbo huquqi Start huquqi sifatida tan olinadi. `tool/enable_turbo.py` faqat ishlab chiquvchi uchun: katta modulni qaytaradi va `flutter pub get` talab qiladi. Qurilmadagi model sinovi va alohida tekshiruvsiz uni sotuvga chiqarmang. Bu versiyada server/API AI qo‘shilmadi.

## Google kirishi uchun haqiqiy talablar

1. `google_config.json` ichida shu Cloud loyihasining **Web application** OAuth client ID’si turishi kerak. Client secret mobil ilovaga kiritilmaydi.
2. Cloud’da Android OAuth client: package `com.ilmmizan.bilga`, mos imzolash sertifikatining SHA-1’i. Debug sinovi va Play nusxasining SHA-1’i har xil bo‘lishi mumkin.
3. Play orqali kelgan nusxa uchun Play Console’dagi **App signing certificate** SHA-1 ishlatiladi; upload certificate’ni adashtirmang.
4. Shu Cloud loyihasida Drive API yoqilgan bo‘lishi; OAuth test holatida bo‘lsa, sinov emaili test foydalanuvchilar ro‘yxatida bo‘lishi kerak.
5. Qurilmada Google Play xizmatlari va haqiqiy Google akkaunt bo‘lishi kerak. Play servisiz planshetda lokal funksiyalar ishlaydi, Google kirishini kafolatlab bo‘lmaydi.

`GOOGLE_PLAY_TUZATISH.md` oldingi batafsil yo‘riqnomani ham saqlaydi. Google Console’ga ushbu paket bilan hech qanday o‘zgartirish kiritilmadi.

## Qurilmada chiqarishdan oldingi tekshiruv

1. Yangi odat, izoh, qisman natija yarating. Ilovani yoping, qayta oching: hammasi qolishi kerak.
2. Notes/to-do/tajriba/kitob/pul yozuvini kiriting, qayta oching. Kitob bobini tahrirlab eski holatiga qaytaring. Moliyada qarzni qisman qaytaring.
3. Rasm, fayl va video biriktiring; Telegram yoki boshqa ilovadan havola ulashing. Manba platforma faqat havola bersa, Bilga uni video fayli qilib yuklab olmaydi.
4. Parolli `.bilga2` zaxira yarating va tiklang; noto‘g‘ri parol bilan tiklash rad etilishi va mavjud yozuvlar qolishini tekshiring. Biriktirmali zaxira uchun shu format kerak; Drive hozir matnli zaxirani qo‘llaydi.
5. Ekran maxfiyligi va ilova qulfi; fon musiqasi, qo‘ng‘iroq vaqtida ovoz, uyqu taymeri; offline ovoz mavjud bo‘lmasa matnli buyruq.
6. Google kirishi/Drive zaxirasi; Play’dan o‘rnatilgan nusxada Start va pul daftarini sotib olish/tiklash.

Maxsus Android integratsion sinov:

```bash
flutter test integration_test/private_device_test.dart -d QURILMA_ID
```

Bu test alohida vaqtinchalik bazada ishlaydi. `QURILMA_ID` o‘rniga `flutter devices` ko‘rsatgan identifikator qo‘yiladi.

## Muhim chegaralar

Bu paket Play’ga chiqarilgan yoki barcha qurilmalarda sinovdan o‘tgan mahsulot degani emas. Ushbu muhitda Android APK yig‘ish, haqiqiy Google kirishi, xarid, ovoz va Android SQLCipher integratsion sinovi bajarilmagan. Natijalar `VALIDATION_1_4.md` da aniq ajratilgan.

43 til katalogi va asosiy yangi odat/moliya boshqaruvlari bor. Ba’zi batafsil yangi xabarlar hamda Start yordamchisining matnlari UZ/EN/RU; qolgan tillarda ayrim joylar inglizcha. Barcha matnlar ona tili mutaxassisi tomonidan ko‘rib chiqildi deb da’vo qilinmaydi.

Odatlarda avtomatik bildirishnoma, haftalik kvota yoki klinik/psixologik davolash va’dasi yo‘q. Miqdor butun son bilan kiritiladi. Odatning bugungi rejasi o‘zgarsa, o‘zgarish bugundan kuchga kiradi. Kitob/tajriba formasi saqlash xatosida ochiq qoladi, lekin hali saqlanmagan matn operatsion tizim jarayonni majburan o‘ldirsa kafolatli tiklanmaydi. Notes’ning avvalgi avto-saqlashi saqlangan.

Shifrlash va ekran himoyasi mavjud bo‘lsa ham, mutlaq xavfsizlik kafolati berilmaydi. Ilova o‘chirilsa qurilma kaliti yo‘qolishi mumkin; eksport qilingan parolli zaxira va uning paroli zarur. Oddiy TXT/EPUB/CSV eksporti shifrlanmagan nusxa ekanini ilova oldindan bildiradi.

Ilgari kuzatilgan Java/Dart/AAPT2 SIGSEGV yoki kernel qulashining sababini bu kod yangilanishi aniqlab bermaydi. Kompyuter yana tizim darajasida qotsa, qayta-qayta katta build boshlash o‘rniga host diagnostikasi kerak.
