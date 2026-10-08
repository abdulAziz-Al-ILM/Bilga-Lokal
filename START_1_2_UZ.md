# Bilga Start 1.2.0+7 — sinov uchun kod

Bu paket AAB yoki APK emas. Flutter/Android yig‘ilishi va telefon sinovi hali
bajarilmagan. Uni tekshirmasdan Play production kanaliga yubormang.

## Qo‘shilgan imkoniyatlar

- Bosh sahifada Notes, To-do, Odatlar va Agent kartalari aylanadi. Markazdagi
  karta kattaroq, yonidagilar kichikroq va xiraroq. Muhitlar ham shunday tanlanadi.
- Habit tracker: yaratish, nomini o‘zgartirish, kunlarni belgilash, ketma-ket
  kunlar sanog‘i, tarix va arxiv. Odatlar zaxira fayliga ham kiradi.
- Agent sahifasida o‘zbekcha, inglizcha va ruscha matnli buyruqlar; tugma bilan
  ovoz kiritish va javobni ovozda o‘qish.
- Agent notes/to-do yaratadi, qidiradi, o‘qiydi, tahrirlaydi, vazifani bajarildi
  deb belgilaydi; odat yaratadi va bugungi bajarilishini belgilaydi.
- Internet qidiruvi brauzerni ochadi. Qo‘ng‘iroq telefon raqamini terish oynasini,
  SMS esa raqam va matn bilan SMS ilovasini ochadi. Yakuniy yuborish foydalanuvchida.
- Android bosh ekran vidjeti agentni ochadi. Mikrofon doimiy tinglamaydi.
- Muhit musiqasi boshqa ilovaga o‘tilganda davom etadi; bildirishnomadan
  play/pause/stop boshqariladi. Ilovani majburan to‘xtatish musiqani ham to‘xtatadi.
- Agent uchun Google Play orqali bir martalik Start mahsuloti ulanishi yozilgan.
  Notes, to-do, odatlar va fon musiqasi bepul qoladi.

## Agent chegaralari

Bu dastlabki versiya lokal BUYRUQ yordamchisi. Unga LLM modeli kiritilmagan:
erkin suhbat, har qanday savolga javob, internet sahifalarini o‘qib xulosa qilish,
boshqa ilovalar ekranlarini boshqarish, kontakt nomidan raqam topish hozir yo‘q.
Brauzer qidiruvini ochish — internetdan javobni agentning o‘zi topdi degani emas.
Agent tugmalari tayyor buyruq namunasini ko‘rsatadi. Noma’lum buyruq uchun
internet qidiruvi taklif etiladi. Notes ichidagi matn buyruq sifatida bajarilmaydi.

Matnli buyruqlar internet talab qilmaydi. Lokal ovoz tanish Android 12+ va
qurilmadagi mos speech xizmatiga bog‘liq; barcha telefonlarda va barcha uch tilda
ishlashi kafolatlanmaydi. O‘zbekcha offline paket bo‘lmasligi mumkin. Online
ovoz rejimi faqat foydalanuvchi yoqqanda ishlatiladi va ovoz xizmatiga ma’lumot
uzatilishi mumkin. Ovozda o‘qish o‘rnatilgan TTS dvijogi va tillariga bog‘liq;
bu dvijogning internet ishlatishi uning sozlamalariga bog‘liq.

## O‘rnatish va sinash

1. Telefon ilovasida eski ma’lumotlarni faylga eksport qilib saqlang. Bu
   o‘rnatuvchining kompyuterdagi kod zaxirasidan alohida.
2. ZIP ni Downloads ichiga oching. Terminalda:

```bash
cd ~/Downloads/bilga-start-1.2.0
python3 install.py ~/StudioProjects/bilga --check
python3 install.py ~/StudioProjects/bilga
cd ~/StudioProjects/bilga
bash tool/check_start.sh
```

O‘rnatuvchi ZIP uchun yuborgan kodingiz bilan taqqoslaydi. O‘zgartirilgan
fayl topilsa, HECH NARSA yozmasdan to‘xtaydi. Xabarni yuboring; fayllarni
majburan ustidan yozmang. Bir xil yangilanishni takrorlash zararsiz.
Zaxira papkasi `bilga-before-start-*` deb loyiha yonida yaratiladi.
Musiqa, rasmlar, google_config.json va imzolash kalitlari almashtirilmaydi.

Tekshiruvlar o‘tgach, agentni bepul debug sinash:

```bash
flutter run --debug --dart-define=BILGA_AGENT_PREVIEW=true --dart-define-from-file=google_config.json
```

Debug imzosi telefondagi Play nusxasiga mos kelmasa, o‘rnatish xato berishi
mumkin. Ma’lumotni saqlamasdan eski ilovani o‘chirmang; avval emulator yoki
alohida sinov telefonidan foydalaning.

Vidjet: Android bosh ekranida bo‘sh joyni bosib turing → Widgets → Bilga Agent.
Vidjet agentni ochadi, keyin mikrofon tugmasini bosing. Telefon/AppLock qulfi
saqlanadi. Yangi ruxsat so‘ralganda mikrofon ruxsatini bering.

## Buyruqlar namunasi

| O‘zbekcha | Inglizcha | Ruscha |
| --- | --- | --- |
| yozuv yarat: Kitoblar \| Bugun 20 bet | create note: Books \| Read 20 pages | создай заметку: Книги \| Читать 20 страниц |
| vazifa yarat: Kitob o‘qish | create task: Read a book | создай задачу: Читать книгу |
| yozuvni top: Kitob | find notes: Books | найди заметку: Книги |
| vazifalarim | my tasks | мои задачи |
| vazifani tugat: Kitob | complete task: Read | заверши задачу: Читать |
| odat yarat: Yurish | create habit: Walk | создай привычку: Прогулка |
| odatni bajarildi: Yurish | check habit: Walk | отметь привычку: Прогулка |
| musiqani yoq | play music | включи музыку |
| internetdan qidir: Toshkent ob-havo | search web: Tashkent weather | найди в интернете: погода Ташкент |

Qo‘ng‘iroq: `telefon qil: +998...`; SMS: `sms yubor: +998... | Salom`.
Haqiqiy raqam yozing. Tahrirlash va yaratish oldidan tasdiq ko‘rsatiladi.

## Start uchun $5 narx

Kodning o‘zi Play narxini belgilamaydi. Play Console da bir martalik,
sarflanmaydigan (non-consumable) mahsulot yarating:

- ID: `bilga_agent_start`
- Nomi: `Bilga Agent Start`
- AQSH bazaviy narxi: `USD 5.00`; boshqa valyuta va soliqlar Play sozlamalariga bog‘liq.
- Ilovada narx Play qaytargan mahalliy narx bo‘ladi.

`billing_config.example.json` dan `billing_config.json` nusxa yarating. Play
Console bergan ilovaning Base64 litsenziya PUBLIC KEY qiymatini
`BILGA_PLAY_LICENSE_KEY` ga kiriting. Service-account private key kiritmang.
Keyin `bash tool/build_play_bundle.sh` tekshiradi va release AAB yig‘adi.

Xarid tekshiruvi Androidda Play imzosini, package/product va xarid holatini
tekshiradi. Tasdiqlanmagan yoki pending xarid agentni ochmaydi. Saqlangan
imzolangan chek offline holatda oxirgi tekshiruvdan 7 kun ishlaydi; Restore
purchases orqali qayta tekshiriladi. Muvaffaqiyatli Play tekshiruvi qaytarilgan
xarid uchun huquqni bekor qiladi. Server tarafdagi tekshiruv va real-time refund
xabarlari hali yo‘q; bu kod production darajasidagi firibgarlik himoyasi emas.
Debug preview release yig‘ilishida agentni ochmaydi.

Play internal testda haqiqiy mahsulot va license tester bilan: sotib olish,
bekor qilish, pending, restore, qayta o‘rnatish va refund holatlarini tekshiring.
Bu hisob/mahsulot sozlamalari ushbu paket tomonidan Play Console ga yozilmagan.

## Saqlangan ma’lumotlar

Eski notes/to-do jadvali va fayl nomlari saqlanadi. Notes sxemasi 8 → 9 bo‘lib,
habits jadvali qo‘shiladi. Eski 8-sxemali backup tiklanadi; yangi backup habits
ham saqlaydi. Eski ilova yangi sxemani ocholmasligi mumkin: kodni orqaga
qaytarish telefondagi bazani orqaga qaytarmaydi.
Google Drive/OAuth ulanishi bo‘yicha oldingi muammo bu yangilanishda
tasdiqlangan holda tuzatilmagan; `GOOGLE_PLAY_TUZATISH.md` amalda qoladi.

## Sinov holati

Bu muhitda Dart buyruq/sana tekshiruvlari, Python SQLite migratsiya tekshiruvi,
til kataloglari, XML sintaksisi va o‘rnatuvchi tekshirildi. Aniq hisobot:
`START_VALIDATION.md`.

Flutter SDK ishga tushishidagi muhit metadata so‘rovi avtomatik xavfsizlik
tekshiruvida bloklandi. Cheklov chetlab o‘tilmadi. Shu sabab dependency
resolution, to‘liq Flutter analyze/test, Kotlin/Gradle/AAB, UI render va real
qurilma sinovlari bajarilmagan. Eski pubspec.lock pub get paytida yangilanadi.

Telefonda quyidagilarni tekshiring:
- Eski yozuv/vazifalar ochilishi; yangisini yaratish va qayta ishga tushirish.
- Habits kunlari, arxiv va backup/restore.
- Tor ekran, planshet oynasi va katta shrift bilan kartalar aylanishi.
- Boshqa ilovaga o‘tganda musiqa va notification boshqaruvi.
- Vidjet sovuq/ochiq/qulflangan holatda; mikrofon ruxsati rad etilganda;
  mavjud offline tillar va alohida online rejim.
- Agent tahririda aynan tanlangan yozuv o‘zgarishi; telefon/SMSni bekor qilish.
- Play test xaridlari va yuqoridagi to‘lov holatlari.

Store description, mikrofon/online speech va xaridga oid Data safety javoblarini
amalda ishlaydigan versiyaga moslang. Hali mavjud bo‘lmagan erkin AI funksiyasini
tayyor deb reklama qilmang.
