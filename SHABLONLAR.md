# Bilga 1.0.0+5 — shablonlar

Bu ZIP — kod paketi. Play Console’ga yuklanadigan fayl **app-release.aab** bo‘ladi.

## O‘rnatish

ZIP’ni `~/Downloads/bilga-shablonlar-v5` papkasiga oching. `install_update.py` shu papkada turishi kerak.

```bash
python3 ~/Downloads/bilga-shablonlar-v5/install_update.py ~/StudioProjects/bilga
cd ~/StudioProjects/bilga
bash tool/check_free_release.sh
```

O‘rnatuvchi o‘zgarishlarni tekshiradi, eski kodlarni alohida papkaga saqlaydi va mahalliy o‘zgartirilgan fayl bo‘lsa to‘xtaydi. `google_config.json`, imzolash kalitlari va telefon ma’lumotlarini almashtirmaydi. Kod zaxirasi telefon bazasining zaxirasi emas.

Tekshiruv muvaffaqiyatli tugagach, emulatorni oching:

```bash
flutter run -d emulator-5554 --dart-define-from-file=google_config.json
```

## Qanday ishlaydi

Notes yoki To Do → **+ → Shablonlar**. Shablonni tanlang, namunani ko‘ring va **Shablondan yaratish**ni bosing. Bekor qilish hech qanday yozuv yaratmaydi.

- Notes: Kundalik, Dars konspekti, Uchrashuv qaydlari, G‘oya, Kitob qaydlari.
- To Do: Kunlik reja, Haftalik reja, Xaridlar ro‘yxati, Imtihonga tayyorgarlik, Safarga tayyorgarlik.
- Notes shabloni hozirgi papkada oddiy tahrirlanadigan yozuv yaratadi.
- To Do shabloni hozirgi papka ichida yangi papka va uchta mustaqil vazifa yaratadi. Vazifalarni o‘zgartirish, qo‘shish, bajarilgan belgilash va savatga yuborish mumkin.
- Sanalar avtomatik belgilanmaydi. Kerak bo‘lsa har vazifada o‘zingiz tanlang; hozir muddati bildirishnoma yubormaydi.
- 43 tilda 34 tadan yangi matn. O‘zbek, qozoq, qirg‘iz, tojik va turkman tillari kiritilgan. Tarjimalar barcha tillarda ona tili mutaxassisi tomonidan tekshirilmagan.
- Har yaratishda yangi nusxa olinadi. Til yoki shablon yangilanishi allaqachon yaratilgan yozuvlarni o‘zgartirmaydi.
- Notes bazasi 8, To Do bazasi 6 va backup formati 1 saqlangan. Shablon natijalari mavjud oddiy yozuvlar singari zaxiraga kiradi.

## Hozir bajarilgan tekshiruv

- `python3 tool/check_catalogs.py`: 43 × 146 matn, to‘liq kalitlar.
- `python3 tool/check_schema.py`: Notes v1–v7, To Do v1–v5 dan hozirgi bazaga o‘tish va avvalgi ma’lumotni saqlash tekshiruvlari o‘tdi.
- O‘rnatuvchi: build 4 dan yangilash, takroriy ishga tushirish, konflikt paytida o‘zgartirmaslik, Google konfiguratsiyasini saqlash tekshirildi.
- `test/template_test.dart`: tarjimalar, alohida nusxalar, papka, transaction rollback, muddat yo‘qligi, oldindan ko‘rish va bekor qilish testlari qo‘shildi.
- **Bu muhitda Flutter SDK va Android SDK yo‘q. Yangi Dart kodi analyzer, Flutter test va APK yig‘ilishidan hali o‘tmagan.** Avvalgi versiyaning PASS natijalari bu versiyaning natijasi emas. Yuqoridagi tekshiruv buyrug‘i foydalanuvchi kompyuterida bajarilishi kerak.

## Play’dan oldingi qolgan ishlar

1. Analyzer/testlar va haqiqiy Android qurilmadagi shablon yaratish/tahrirlash sinovi.
2. Google hisobiga kirish, Drive zaxira va boshqa test qurilmada tiklash. So‘ng Play App Signing sertifikati SHA-1 bilan OAuth Android client’ni ham sozlash.
3. Google Branding’dagi yetishmayotgan haqiqiy sayt/maxfiylik ma’lumotlari va kerakli nashr/verifikatsiya sozlamalari. Hozirgi Testing rejimini hammaga ochiq deb hisoblamang.
4. Upload keystore va `android/key.properties` — CHIQARISH.md.
5. `bash tool/build_play_bundle.sh` → `build/app/outputs/bundle/release/app-release.aab`.
6. Play Console’da Data safety, maxfiylik siyosatining ommaviy URL’i, ekran rasmlari va akkauntga qo‘llanadigan sinov talablari.

2023-11-13 dan keyin ochilgan personal Play akkauntlari uchun 12 tester kamida 14 kun uzluksiz yopiq sinovda qatnashishi, keyin production ruxsati so‘ralishi kerak. Bu Google OAuth test users ro‘yxatidan alohida.

Manbalar:
- https://docs.flutter.dev/deployment/android
- https://support.google.com/googleplay/android-developer/answer/14151465
- https://developers.google.com/identity/protocols/oauth2/production-readiness/brand-verification
