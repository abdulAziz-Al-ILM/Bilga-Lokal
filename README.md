# Bilga 1.0.0+5

Avval SHABLONLAR.md ni o‘qing: 10 ta shablon, o‘rnatish, joriy tekshiruvlar va Play oldidan qolgan ishlar.

# Bilga — bepul Notes va To Do

Flutter / Android ilovasi. Asosiy bo‘limlar akkauntsiz, internetsiz ishlaydi. Google hisobi faqat foydalanuvchi tanlagan Drive zaxirasi uchun kerak.

- O‘rnatish va nashr: **CHIQARISH.md**.
- Google Drive sozlash: **GOOGLE_SETUP.md**.
- Sinov natijalari va cheklovlar: **TEKSHIRUV.md**.

```bash
bash tool/check_free_release.sh
flutter test integration_test/data_safety_test.dart -d emulator-5554
flutter run -d emulator-5554
```

Google ulangan build uchun `flutter run` buyrug‘iga `--dart-define-from-file=google_config.json` qo‘shiladi.

`lib/core`: til, mavzu, sozlamalar va ilova qulfi.
`lib/features/collections`: Notes va To Do ro‘yxatlari, papkalar va savat.
`lib/features/notes`, `lib/features/todo`: model, SQLite migratsiyalari, tahrirlagichlar.
`lib/features/backup`: shifrlash, import, Google Drive.
`assets/i18n`: 43 tilning matnlari.

Notes schema 8, To Do schema 6. Package ID va baza fayl nomlarini almashtirmang. Migratsiyasiz bazani o‘chirib yaratish mumkin emas. Eski ma’lumotni saqlash sinovlari keyingi o‘zgarishlarda ham ishlatiladi.

43 til AI/mashina yordamida tayyorlangan; barcha tillar ona tili mutaxassisi tomonidan tekshirilmagan. Tajriba, AI agent va pullik bo‘limlar keyingi bosqichga qoldirilgan.
