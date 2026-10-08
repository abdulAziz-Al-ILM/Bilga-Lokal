# Hozirgi paket: 1.0.0+5

Shablonlar va joriy tekshiruvlar: SHABLONLAR.md. Quyidagi natijalar avvalgi build 4 tarixidir; build 5 Flutter testlari bu muhitda bajarilmagan.

# Bilga 1.0.0+4 — tekshiruv natijasi

2026-09-06. Bu yangilanish avvalgi 1.0.0+2 yoki 1.0.0+3 kod paketi ustiga o‘rnatiladi.

## Qo‘shilgan

- Bosh ekranda faqat bepul Notes va To Do. Profil alohida tugma bilan ochiladi.
- 43 til, barcha tillarda 112 ta matn. Arab, fors, urdu va ibroniy tillarida o‘ngdan chapga yo‘nalish.
- Forest, Emerald, Ruby, Ocean, Amethyst, Amber, Mono: 7 palitra, har birida och/tungi/tizim rejimi.
- Mahalliy ism va avatar, saqlanadigan til/mavzu sozlamalari.
- Notes sevimlilari, arxiv, teglar; qidiruv teglarni ham qamraydi. Mavjud autosave va tarix saqlandi.
- To Do tavsifi, muhimlik, ixtiyoriy muddat, bajarilgan vaqt, qidiruv, papkalar va savat. Savatdan alohida yoki papka bilan tiklash, tasdiqlab butunlay o‘chirish.
- Qurilmadagi PIN/biometriya orqali ilova qulfi; fon holatidan qaytganda qayta ochish talab qilinadi. Android’da qulf yoqilganida ekran tasvirini olish cheklanadi.
- Parolli AES-GCM-256 zaxira. Har nusxaga tasodifiy salt/nonce, PBKDF2-SHA256 600 000 iteratsiya. Parol telefonda saqlanmaydi. Og‘ir shifrlash alohida isolate’da.
- Shifrlangan fayl eksport/importi; Google hisobini ulash, Drive appDataFolder’ga nusxa yozish, qayta yuklab tekshirish va tiklash kodi.
- Import eski ma’lumotlarni almashtirmaydi; IDlar qayta nomlanadi va alohida papkalarga qo‘shiladi. Xato yuz bersa, ikkala bazadagi import bitta transaction bilan bekor qilinadi. Aynan bir nusxani qayta import qilish takroriy qator yaratmaydi.
- Notes schema 7→8; To Do 5→6. Package ID va bazalar fayl nomlari saqlangan.

## Avvalgi build 3 da bajarilgan tekshiruvlar

Muhit: Flutter 3.47.2, Dart 3.13.2, Linux. Flutter vositasi va ochiq paketlar tayyorlangach, loyiha bog‘liqliklari offline hal qilindi.

- Dart analyzer: **No issues found** — xato, warning va info yo‘q.
- Flutter test runner: **23/23 test PASS**.
- Shundan 13 tasi haqiqiy vaqtinchalik SQLite fayllarida: Notes v1–v7 migratsiyalari, tarix/tahrir rollback, diskdan qayta ochish, ota papkasiz yozuv tiklash, To Do migratsiyasi/sikl/ID himoyasi, savat guruhlari, ikkala bazadagi import rollback va takroriy import.
- 5 ta Notes/widget testi: bepul bosh ekran, autosave/chiqishda saqlash, disk xatosida matnni saqlab qolish, sekin yozish navbati, sessiya tarixi.
- 3 ta til/profil testi: barcha kataloglarning to‘liqligi, 43 locale’da ekran qurilishi va RTL, 7 palitraning och/tungi holati, sozlamalar saqlanishi, profildagi til/mavzu/zaxira boshqaruvlari.
- 2 ta shifrlash testi: Unicode va satr bo‘shliqlari bilan encrypt/decrypt, noto‘g‘ri parol, buzilgan autentifikatsiya belgisi, noto‘g‘ri KDF parametri va qisqa parol rad etilishi.
- `python3 tool/check_schema.py`: **12/12 PASS**. Haqiqiy CREATE/ALTER SQL Python SQLite’da ham ishlatildi; eski qiymatlar va yangi schema tengligi tekshirildi.
- `python3 tool/check_catalogs.py`: **43 × 112** matn; yo‘q kalit yoki bo‘sh tarjima yo‘q.
- Android XML va shell yordamchilari sintaksisi tekshirildi.
- O‘rnatish yordamchisi avvalgi paket nusxasiga qo‘llash, qayta o‘rnatish va foydalanuvchi o‘zgartirgan fayl bo‘lganda hech narsani almashtirmay to‘xtash holatlarida tekshirildi.

Testlar vaqtinchalik bazalarda ishlaydi; foydalanuvchining `bilga.db` va `bilga_todo.db` fayllariga tegmaydi. Linux testlari tizimning `libsqlite3.so.0` kutubxonasidan foydalanadi. Android integratsiya testi shu 13 ta ma’lumot xavfsizligi holatini Android SQLite orqali bajaradi.

## Hali qurilmada tekshirilishi kerak

- **Yangi paket uchun Android APK/AAB yig‘ilmadi va Android integratsiya testlari bu muhitda bajarilmadi.** Avvalgi paket uchun foydalanuvchi yuborgan 10 ta PASS yangi native funksiyalar sinovi o‘rnini bosmaydi.
- Google Cloud/OAuth egasining sozlamalari kiritilmagan. Haqiqiy Google hisobida ulanish, yuklash va yangi qurilmada tiklash sinovi bajarilmagan. GOOGLE_SETUP.md bo‘yicha sozlang.
- Telefonning haqiqiy PIN/biometriya oynasi, fayl tanlash/saqlash provayderi, ilova fon/old holati, katta shrift va klaviatura bilan qo‘lda tekshirish kerak.
- Til kataloglari AI/mashina yordamida tayyorlangan. Barcha tarjimalar ona tili mutaxassisi tomonidan tasdiqlanmagan; avtomatik test semantik tarjima sifatini kafolatlamaydi.
- Drive nusxasi qo‘lda yaratiladi; avtomatik backup yoki uzluksiz sync yo‘q. Mavzu/ism/avatar hozir backupga kirmaydi.
- Mahalliy SQLite maxsus shifrlanmagan. Shifrlangan backup va ilova qulfi mutlaq piratlik himoyasi emas.
- To Do muddati ilova ichida ko‘rsatiladi; telefon bildirishnomasi hali yo‘q. Tajriba/AI/xaridlar bu bosqichga kirmaydi.

Bu **tekshirilgan kod yangilanishi**, Google Play’ga allaqachon chiqarilgan yoki imzolangan tayyor AAB emas.

## Build 4 — Markaziy Osiyo tillari

Qirg‘izcha (ky), tojikcha (tg) va turkmancha (tk) qo‘shildi. O‘zbekcha va qozoqcha avvaldan bor. Ushbu besh til tanlovning boshiga joylashtirildi. Jami 43 til.

Tojik/turkman Material sana-vaqt oynalari, oy va hafta nomlari, matnni nusxalash menyusi moslashtirildi. Kun-oy-yil kiritish formati tekshirildi. Qirg‘izcha standart Flutter lokalizatsiyasidan foydalanadi.

Android interfeysi mo‘ljallangan. Tojik/turkman uchun hozir ishlatilmaydigan ayrim tizim accessibility yorliqlari va iOS Cupertino boshqaruvlari inglizcha asosdan foydalanadi; iOS chiqarishdan oldin alohida lokalizatsiya kerak. Google/biometriya kabi native oynalarning tili telefon tizimiga ham bog‘liq.

Tarjimalar tashqi tarjima xizmatiga yuborilmasdan AI yordamida tayyorlandi. Ona tili mutaxassisi tekshiruvi hali yo‘q. DB schema va zaxira formati bu yangilanishda o‘zgarmadi.

Build 4 tekshiruvi: Dart analyzer — No issues found. Yangilangan til/profil testlari — 5/5 PASS; 43 locale, 7 palitra, regional sana-vaqt oynalari va noto‘g‘ri sanani rad etish qamraldi. Kataloglar — 43 × 112, 261 449 bayt. O‘rnatish yordamchisi build 2 va build 3 ustiga qo‘llash uchun tekshirildi. Avvalgi DB/shifrlash kodlari bu safar o‘zgartirilmadi.
