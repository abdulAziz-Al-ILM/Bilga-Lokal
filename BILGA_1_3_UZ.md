# Bilga 1.3.0 — kod yangilanishi va sinov

Bu mavjud loyihaga qo‘yiladigan kod paketi. Tayyor AAB yoki real telefonda tasdiqlangan reliz emas. Google konfiguratsiyasi, imzolash kalitlari, mavjud rasm va musiqalar almashtirilmaydi. O‘rnatish fayllari 1.1 manbasi, 1.2 yangilanishi va test-fix1 nusxalarini taniydi; noma’lum o‘zgarishda yozishdan oldin to‘xtaydi.

## O‘rnatish

Avval eski Bilga ichidan parolli zaxira eksport qiling. Parolni saqlang. Telefon bazasi shifrlangan formatga ko‘chadi: eski APKni keyin ustidan qaytarmang. Skriptning kod zaxirasi telefon ma’lumotlarini saqlamaydi.

```bash
cd ~/Downloads
unzip bilga-private-1.3.0.zip
cd bilga-private-1.3.0
python3 install.py ~/StudioProjects/bilga --check
python3 install.py ~/StudioProjects/bilga
cd ~/StudioProjects/bilga
bash tool/check_start.sh
```

Agar mos kelmagan fayllar ro‘yxati chiqsa, ustidan yozmang — natijani yuboring. `pubspec.lock` paketdan yozilmaydi; `flutter pub get` yangilaydi.

Telefonda/emulatorda dastlab debug sinov:

```bash
flutter devices
flutter run --dart-define=BILGA_AGENT_PREVIEW=true
```

Bu faqat debugda pullik bo‘limlarni tekshirish imkonini beradi. Release’da ushbu bayroq huquq bermaydi. Google kirishni tekshirayotganda `--dart-define-from-file=google_config.json`ni ham qo‘shing. Modelni x86 emulatorda sinamang: Turbo ARM64 uchun.

## Qo‘shilganlar

- Aylanadigan kartalar: Notes, vazifalar, bepul odatlar, yordamchi, pul hisobi, tajriba va kitoblar. Muhit karuseli va fon musiqasi saqlangan.
- Pul hisobi: bir valyutali alohida daftarlar, kirim/chiqim, qarz berdim/oldim, qisman qaytarish, oylik xarajat toifalari, oylik budjet va CSV. Bank kartasi ulanmaydi, to‘lov va haqiqiy pul o‘tkazish yo‘q. Hisobot faqat kiritilgan qaydlardan tuziladi. Noto‘g‘ri qayd bekor qilinadi; tarixi ko‘rinadi. Qarz qaytishini qayd qilish uchun qarz satrini bosing. Qarzni bekor qilishdan avval unga tegishli qaytarish qaydlarini bekor qiling.
- Tajriba: ish, hayot, his-tuyg‘u, shukronalik, ruhiyat va saboq; hislar, saboq va keyingi qadam uchun maydonlar. Tajribadan kitob nusxasi yaratiladi.
- Kitob: boblar, tartibini o‘zgartirish, qahramon/reja qaydlari, so‘zlar soni, bobning oxirgi 20 nusxasi, TXT va EPUB eksport. Kitob bo‘limi bu paketda bepul. PDF eksport kiritilmagan.
- Ichkaridan rasm/video/audio/PDF/boshqa fayl, havola yoki matn biriktirish; har fayl 1 GiB gacha, bir tanlovda 20 fayl. Notes, vazifa, odat, tajriba, kitob va pul daftariga 📎 orqali qo‘shiladi. Yangi vazifani avval saqlab, qayta oching; yangi yozuvga kamida nom yoki matn yozing.
- Instagram, YouTube, Telegram va boshqa ilovalardan “Ulashish → Bilga”; bo‘lim va mavjud/yangi yozuv tanlanadi. Tashqi platforma faqat havola yuborsa, havola saqlanadi. Bilga cheklangan videoni havoladan yashirin yuklamaydi. Fayllar nusxalanib shifrlanadi; rasm/video/audio ko‘rish telefon kodekiga bog‘liq, boshqa formatlar eksport orqali ochiladi.
- Sozlamalar → “Taklif va xatolar haqida yozish”: `ilmmizanofficial@gmail.com` uchun xat oynasi. Foydalanuvchi o‘zi yozib yuboradi. Email ilovasi bo‘lmasa manzilni nusxalash mumkin. Shaxsiy qayd/fayl/log avtomatik jo‘natilmaydi.

## Lokal AI

Start: oddiy UZ/EN/RU buyruqlar yordamchisi; erkin suhbat modeli emas. Yozuv/vazifa/odatlar bilan amallar, musiqa, tashqi brauzer, telefon/SMS oynalari. Qo‘ng‘iroq/SMS telefonning o‘z oynasida yakunlanadi. Doimiy mikrofon tinglash yo‘q; bosh ekran vidjeti yordamchini ochadi.

Turbo: Qwen3 4B yoki 8B GGUF modeli, server AI/API ishlatilmaydi. Model alohida yuklanadi, SHA-256 tekshiriladi; keyin internet bo‘lmasa ham suhbat ishlashi kerak. Ishonchli qurilma sinovi hali talab qilinadi.

| Model | Yuklama | Dastlabki talab |
|---|---:|---|
| Qwen3 4B Q4_K_M | 2 497 280 256 bayt | ARM64, Android 8+, 8 GB RAM, 4 GB bo‘sh RAM |
| Qwen3 8B Q4_K_M | 5 027 783 488 bayt | ARM64, Android 8+, 12 GB RAM, 7 GB bo‘sh RAM |

Model hajmidan kamida 1 GiB ko‘p bo‘sh doimiy xotira kerak. Yuklash uzilsa qisman fayl o‘chadi; resume yo‘q. CPU ishlatiladi, GPU o‘chiq. Xarid tugmasi qurilma benchmarki o‘tgach ochiladi. Talablar taxminiy konservativ chegaralar: apparatdagi o‘lchovsiz tezlik, qizish va batareyaga va’da bermang.

Turbo suhbat, ixtiyoriy tanlangan Notes qaydi, ovozli kiritish/o‘qish, javobdan tasdiqlangan yozuv/vazifa yaratish va brauzer qidiruvini beradi. Tashqi ilovalarni o‘zi boshqarmaydi va qidiruv natijasini avtomatik o‘qimaydi. Pul hisobiga yashirin amal kiritmaydi. Javoblar xato bo‘lishi mumkin.

Yaqin suhbatdan 1800 belgigacha, tanlangan yozuvdan 800 belgigacha; javob 384 tokengacha. Sahifadan chiqishda suhbat tozalanadi. Butun kitob tahlili deb ko‘rsatmang.

Offline ovoz uchun Androidning qurilmada ishlaydigan recognizer’i va o‘rnatilgan til modeli kerak (odatda Android 12+). Topilmasa matn yoziladi. Startda foydalanuvchi alohida yoqadigan online voice bor: bu ovozni telefon speech xizmatiga yuborishi mumkin. TTS faqat tarmoq talab qilmaydigan o‘rnatilgan ovozni tanlaydi. AI hamma tilda bir xil sifatli ishlashi kafolatlanmaydi.

## Maxfiylik

Notes va vazifalar bazasi SQLCipher; kalit Android Keystore bilan o‘raladi. Biriktirmalar AES-256-GCM bilan bo‘laklab shifrlanadi. Ochiq eski baza ko‘chirilgach o‘chiriladi; flash xotiradan fizik izlarni mutlaq yo‘q qilish kafolati yo‘q. Ilovani o‘chirish yoki data’ni tozalash kalitni yo‘qotadi — oldindan eksport qiling.

Ilova qulfini yoqing. Ekran maxfiyligi standart yoqilgan, skrinshotni to‘sadi. Play skrinshotlari uchun vaqtincha o‘chirish mumkin. Keystore kaliti biometrik autentifikatsiyaga bog‘lanmagan; ilova qulfi UI darajasida. Root yoki buzilgan OSga qarshi mutlaq himoya yo‘q.

Media preview yopiq cache’da vaqtinchalik ochiq nusxa ishlatadi; sahifa yopilganda yoki keyingi ishga tushishda tozalanadi. TXT/EPUB/CSV/media eksport ataylab ochiq nusxa chiqaradi va avval ogohlantiradi. Model fayli maxfiy emas, shifrlanmaydi. Suhbat/token nativ loglari o‘chirilgan.

Sozlamalar → Eksport `.bilga2` parolli zaxira yaratadi: qaydlar va barcha biriktirmalar birga. Kamida 12 belgili parol. Eski `.bilga` ham import qilinadi. Tiklash mavjud yozuvlarni o‘chirmaydi, yangi nusxalar qo‘shadi; bir xil zaxira takror tiklanmaydi. Blob tekshiruvi tugamaguncha bazaga yozilmaydi. Noto‘g‘ri importdan qolgan shifrlangan, biriktirilmagan bloblar diskda qolishi mumkin.

Drive hozir faylsiz qaydlar uchun. Biriktirma bo‘lsa lokal to‘liq eksportni so‘raydi; jimgina fayllarni tashlab ketmaydi. Google OAuth/Play SHA-1 sozlash alohida qoladi. Model va xaridlar zaxiraga kirmaydi; model qayta yuklanadi, xarid Play’dan tiklanadi.

## Tillar va tekshiruv

43 tilda asosiy yangi kartalar va biriktirish yorliqlari tarjima qilingan. Yangi uzun izohlar va ichki maydonlarning ko‘pi UZ/EN, boshqalar English fallback. Eski tarjimalar saqlangan. Nativ tarjimon ko‘rigisiz barcha dialoglar to‘liq 43 tilga tarjima qilingan deb aytmang.

`VALIDATION_1_3.md` real bajarilgan tekshiruvlarni ajratadi. Qurilmada quyidagilarni bajaring:

1. `bash tool/check_start.sh` — analyze + barcha Flutter testlari.
2. `flutter test integration_test/private_device_test.dart` — haqiqiy Android SQLCipher migratsiyasi.
3. Eski namunali qaydlar bilan APK yangilash, qayta ochish, app lock va ekran maxfiyligi.
4. Barcha bo‘limlarga rasm, 100 MB video, havola; sovuq/ochiq/qulflangan ilovaga share.
5. `.bilga2` eksport, boshqa sinov qurilmasida import, noto‘g‘ri parol, buzilgan fayl, takroriy import.
6. ARM64 real telefonda 4B/8B: airplane mode, ovoz, stop/chiqish/qayta kirish, issiqlik va RAM.
7. Play internal testing: xarid, cancel/pending, restore, bir akkaunt boshqa telefon, refund.
8. Musiqa ekran o‘chiq va boshqa ilovada; qo‘ng‘iroq/audio focus.
9. Katta shrift, kichik/planshet ekran va RTL tillar.
10. Feedback email oynasi va email ilovasiz nusxalash.

Productionga faqat ushbu tekshiruvlardan keyin. Keyingi 5–6 oy davomida hech qanday tuzatish kerak bo‘lmaydi degan kafolat berilmaydi.
