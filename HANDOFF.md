# Bilga — loyiha handoff’i

Yangilangan: **2026-10-08**.
Repo: **abdulAziz-Al-ILM/Bilga-Lokal**. Asosiy branch: **main**.
Tekshirilgan bazaviy commit: `c165c5651d61173cb96ce31f5c4a58028927dada`.

> **Birinchi o‘qiladigan holat:** tekshirilgan commitda faqat 13 baytlik `README.md` (`# Bilga-Lokal`) bor. Flutter ilovasi manbalari bu repoga hali kiritilmagan. Quyidagi mahsulot talablari mavjud implementatsiya degani emas. Kod kelmaguncha “ishlaydi”, “testdan o‘tgan” yoki “release tayyor” degan xulosa chiqarilmasin.

## 1. Hujjatning vazifasi va dalil qoidasi

Bu fayl keyingi AI/ishlab chiquvchi uchun joriy holatning yagona boshlang‘ich manbasi. Har katta o‘zgarishda shu o‘zgarish bilan birga yangilansin.

Ma’lumotlar uch turda yoziladi:
- **Repo faktlari:** bevosita joriy kod, konfiguratsiya yoki CI natijasidan tekshirilgan.
- **Mahsulot talablari:** loyiha egasi bergan yo‘nalish; bajarilganligi kod bilan tasdiqlanishi kerak.
- **Tekshirilmagan:** dalil yo‘q; taxmin bilan to‘ldirilmaydi.

Eski chat, ZIP, boshqa repo yoki kompyuterdagi nusxa bu repo bilan teng deb olinmasin. Ayniqsa alohida `abdulAziz-Al-ILM/Bilga` reposi mavjudligi uning mazmuni shu loyihaning so‘nggi nusxasi ekanini anglatmaydi; ushbu handoff uchun u audit qilinmagan.

## 2. Maqsad va positioning — mahsulot talablari

Bilga — maxfiylikka asoslangan shaxsiy kundalik yordamchi: yozuvlar, vazifalar, odatlar, hayotiy/ish tajribalari, his-tuyg‘u va shukronalik yozuvlari, kitob yozish hamda qo‘lda yuritiladigan pul hisobi.

Asosiy talablar:
- Kundalik asosiy ishlar lokal/offline bajarilishi, telefon resurslari tejalishi.
- Maxfiy yozuvlar va biriktirmalarni himoyalash; mutlaq xavfsizlik va’dasi berilmasligi.
- Notes, to-do, tajriba va boshqa mos yozuvlarga rasm, video, fayl va havola biriktirish; boshqa ilovalardan ulashishni qabul qilish.
- Kartalar orqali bo‘lim tanlash, moslashuvchan ekranlar, ko‘p tillilik (43 til talabi).
- Yetti statik muhit va alohida sokin audio; ilova fonida musiqa.
- Habit tracker bepul bo‘lishi va oddiy bo‘sh sahifadan iborat bo‘lmasligi.
- Pul bo‘limi faqat foydalanuvchi kiritgan moliyaviy qayd/hisobotlar: **bank kartasi ulash yoki pul o‘tkazish emas**.
- Server/API orqali suhbat AI’sini hozir qo‘shish kechiktirilgan. Doimiy mikrofon o‘rniga foydalanuvchi boshlaydigan boshqaruv kerak.
- Telegram/WhatsApp/SMS orqali avtomatik ommaviy tabrik yuborish keyinga qoldirilgan.

## 3. Hozir ishlaydigan funksiyalar

**Bu repo bo‘yicha tasdiqlangan ilova funksiyasi yo‘q:** bajariladigan ilova kodi mavjud emas. Bu foydalanuvchining lokal nusxasi ishlamaydi degani emas; u nusxa ushbu repoda yo‘q.

Kod yuklangach har bo‘lim uchun quyidagi darajalar ajratilsin: kod mavjud / avtomatik test o‘tdi / Android qurilmada sinaldi / Play orqali sinaldi. UI kartasi mavjudligi funksiyaning to‘liq ishlash dalili emas.

## 4. Monetizatsiya — kelishilgan model, repo implementatsiyasi emas

| Paket | Mahsulot talabi | Repo/Play tasdig‘i |
|---|---|---|
| Start yordamchi | $2.49; oddiy lokal buyruqlar | Billing kodi, product ID va sotuv holati tekshirilmagan |
| Pul daftari | $5; qo‘lda yuritiladigan hisob/hisobot | Billing kodi, product ID va sotuv holati tekshirilmagan |
| Habit tracker | Bepul | Kod yo‘q |
| Turbo lokal AI | Oldin $4.99 taklif qilingan; yengil versiya yo‘nalishidan keyingi joriy holati aniqlanishi kerak | Sotuvda yoki implementatsiya qilingan deb yozilmasin |

Bir martalik xarid/obuna turi, qolgan bo‘limlarning paywall holati, hududiy narxlar, purchase restore/refund ishlovi va Play mahsulotlari manba kod hamda Console bilan tekshirilishi kerak. Chatdagi narx Play’da mahsulot yaratilganini anglatmaydi. Sinov rejimi release’da huquqlarni ochib yubormasligi tekshirilsin.

## 5. Arxitektura va fayllar xaritasi

Tekshirilgan commitdagi to‘liq daraxt: faqat `README.md`; GitHub recursive tree natijasi `truncated: false`.

| Fayl/papka | Joriy vazifa/holat |
|---|---|
| `README.md` | Faqat repo nomi |
| `HANDOFF.md` | Ushbu handoff va keyingi ishlar uchun yangilanadigan holat |
| `pubspec.yaml`, `pubspec.lock` | Repoda yo‘q; Flutter/Dart va dependency versiyalari tasdiqlanmagan |
| `lib/` | Repoda yo‘q; sahifalar, store/service va state management xaritasi tuzib bo‘lmaydi |
| `android/` | Repoda yo‘q; application ID, SDK, Gradle, Kotlin, signing va native bridge noma’lum |
| `assets/` | Repoda yo‘q; tarjima, rasm, audio va litsenziyalar audit qilinmagan |
| `test/`, `integration_test/`, `tool/` | Repoda yo‘q; test va build skriptlari mavjud emas |
| `.github/workflows/` | Repoda yo‘q |
| `AGENTS.md` | Tekshirilgan daraxtda yo‘q |

Kod importidan keyin bu jadval haqiqiy fayl nomlari va ularning javobgarligi bilan almashtirilsin. Hozirgi yo‘q papkalar tavsiya etilgan implementatsiya yoki mavjud arxitektura sifatida talqin qilinmasin.

## 6. Package va servislar

Flutter/Android loyiha ekanligi mahsulot kontekstidan ma’lum, lekin repoda paket manifesti yo‘q. Shuning uchun dependency nomi/versiyasi, lokal native AI runtime, audio, database, billing yoki kriptografiya kutubxonasi ishlatilmoqda deb tasdiqlab bo‘lmaydi.

Rejalashtirilgan tashqi integratsiyalar: Google akkaunt/Drive zaxirasi va Google Play to‘lovlari. Server AI hozirgi scope emas. Haqiqiy tarmoq oqimlari, analytics/crash SDK mavjudligi va offline xatti-harakat kodi kelgach tekshirilsin.

## 7. Google login / Drive / backup

**Joriy repo holati: tekshirilmagan; kod va konfiguratsiya namunasi yo‘q.**

Audit quyidagilarni aniqlashi kerak:
- OAuth client turlari, package ID, debug/release/Play imzolari va ularning mosligi.
- Sign-in/out, ruxsat rad etilishi, tarmoq uzilishi va akkaunt almashish oqimlari.
- Drive scope, zaxira joylashuvi/formati, biriktirmalar kirishi yoki kirmasligi.
- Lokal eksport/tiklash, noto‘g‘ri parol va buzilgan faylni rad etish.
- Tiklashdagi atomiklik va mavjud ma’lumotlar saqlanishi.

Google yoki Play Console holati repo kodining o‘zi bilan tasdiqlanmaydi. Handoff’ga parol, token, client secret yoki signing private key kiritilmasin.

## 8. Security va anti-piracy

**Repoda implementatsiya yo‘q; amaldagi himoya tasdiqlanmagan.**

Kod kelgach alohida tekshirilsin:
- Database/fayl shifrlash, kalit yaratish va himoyalash, backup kriptografiyasi.
- App lock, ekran himoyasi, loglarda maxfiy matn chiqmasligi.
- Import/share fayllari chegaralari va vaqtinchalik plaintext fayllar hayot sikli.
- Ovozning qurilmada yoki tashqarida qayta ishlanishi va ruxsat oqimi.
- Play xaridi tekshiruvi, kesh huquqlar, offline ishlash, refund/revoke va debug bypass.
- Server yo‘qligidagi anti-piracy cheklovlari; obfuscation yoki lokal imzo tekshiruvi mutlaq himoya deb taqdim etilmasin.

Mavjud foydalanuvchi bazasi yoki kalitini o‘chirish migratsiya/saqlash xatosini tuzatish usuli bo‘lmasin.

## 9. Database / schema / migration

Repoda database kodi va migration fixture yo‘q. **Schema versiyasi noma’lum**; eski chatdagi versiya bu repoga ko‘chirilmadi.

Kod kelgach: barcha bazalar nomi va versiyasi, jadval/indekslar, upgrade yo‘llari, eski nusxalar bilan moslik, attachment bog‘lanishlari, backup format versiyasi va rollback/recovery tekshirilsin. Migration testlari eski real formatdagi fixture va Unicode ma’lumotlarini saqlashni tekshirsin. Faqat yangi bo‘sh bazani yaratish testi yetarli emas.

## 10. Build / test holati va ma’lum muammolar

2026-10-08 GitHub tekshiruvi:
- `main` bazaviy commit yuqorida ko‘rsatilgan.
- GitHub Actions natijasi: `total_count: 0`.
- Testlar bu repo uchun ishga tushirilmagan; executable source yo‘q.
- APK/AAB yig‘ilgani yoki qurilmada ishlagani bu repo uchun tasdiqlanmagan.
- Handoff tayyorlashda ilova kodi yoki dependency o‘zgartirilmagan.

**Asosiy blocker:** haqiqiy so‘nggi loyiha manbasi repoga kiritilmagan.
**Texnik qarz:** reproducible build konfiguratsiyasi, lockfile, testlar, CI, secret exclusion va amaldagi fayllar xaritasi mavjud emas.
**Tasdiqlangan ilova buglari:** bu commitdan aniqlab bo‘lmaydi. Avvalgi lokal nusxadagi xatolar qayta tekshirilmasdan joriy repo bugi deb belgilanmasin.

## 11. Oxirgi o‘zgarishlar

- Repo boshlang‘ich holati o‘qildi: README va yagona `main` branch.
- Manba va CI yo‘qligi tekshirildi.
- Ushbu `HANDOFF.md` qo‘shildi. Bu funksional app update yoki oldingi ZIP’larni import qilish emas.

## 12. Dizayn qarorlari — mahsulot sababi

- **Offline/maxfiylik:** shaxsiy sirlar va kundalik yozuvlar uchun foydalanuvchi nazorati.
- **Yengillik:** katta model va doimiy fon ishini avtomatik yoqmaslik; real qurilmada o‘lchash.
- **Qo‘lda moliyaviy qayd:** server/bank integratsiyasiz foydali hisob-kitob.
- **Bepul odatlar:** kundalik foydalanish uchun bazaviy imkoniyat.
- **Modulli pullik yordamchi:** mavjud va isbotlangan imkoniyat uchun haq olish; kelajak AI’sini mavjud deb sotmaslik.
- **Tekshirilgan holatni yozish:** keyingi AI eski va yangi nusxalarni adashtirmasligi.

Bular repo ichida bajarilgani tasdiqlangan texnik qarorlar emas; importdan keyin mosligi audit qilinadi.

## 13. Keyingi eng muhim 10 qadam

1. Egasi ishlatayotgan **eng so‘nggi to‘liq lokal loyiha**ni aniqlash; avval kod va foydalanuvchi ma’lumotlarining zaxirasini saqlash.
2. Importdan oldin `.gitignore` va fayllar ro‘yxatini tekshirish: keystore, parol/token, lokal config, foydalanuvchi bazasi, build/cache kiritilmasin; kerakli assetlar tashlab ketilmasin.
3. Tasdiqlangan source’ni shu repoga commit qilish; boshqa repo yoki eski ZIP bilan indamay almashtirmaslik.
4. `pubspec`, Android konfiguratsiyasi va native kodni o‘qib, haqiqiy versiya/dependency/fayllar xaritasini shu hujjatga yozish.
5. Database migration, habit va boshqa yozuvlarni saqlash/qayta ochish, backup/restore testlarini tekshirish va bajarish.
6. Formatter/analyzer/unit/widget test natijalarini commit va buyruq bilan qayd etish; yiqilgan testlarni yashirmasdan tuzatish.
7. Emulyatorsiz APK yig‘ish yo‘lini tekshirish va real planshetda cold start, RAM, fon musiqa, biriktirma va persistence’ni sinash.
8. Google sign-in/Drive’ni debug va Play imzoli nusxalarda alohida sinash; konfiguratsiya bilan runtime xatosini ajratish.
9. Billing/paketlar, sinov bypass’i, privacy/security va tarjimalarni release uchun tekshirish; Play test xarid/tiklashni bajarish.
10. Takrorlanadigan CI/release yo‘lini o‘rnatish; ochiq buglar, test dalillari va keyingi vazifalar bilan HANDOFF’ni yangilash.

## 14. Komandalar

### Hozirgi repo holatini olish va tekshirish

```bash
git clone https://github.com/abdulAziz-Al-ILM/Bilga-Lokal.git
cd Bilga-Lokal
git status --short
git log -1 --oneline
git ls-tree -r --name-only HEAD
```

Repo private; o‘z GitHub autentifikatsiyasi kerak. Mavjud loyiha papkasi ustiga clone yoki reset qilinmasin.

### Faqat to‘liq Flutter source import qilingandan keyin

Quyidagilar boshlang‘ich diagnostika komandalaridir, hozirgi README-only commitda bajarilmaydi. Repo ichidagi kelajak `AGENTS.md`, SDK talabi va tekshirilgan build skriptlari avval o‘qilsin.

```bash
flutter --version
flutter doctor -v
flutter pub get
flutter analyze
flutter test --concurrency=1
flutter devices
```

Loyihaga xos preview/billing/Google `dart-define` talablari aniqlanmaguncha yakuniy `flutter run` yoki release buyrug‘i taxmin qilinmasin. Hozir bu repoda `tool/check_start.sh` yoki `tool/build_test_apk.sh` yo‘q.

## 15. Yangilash tartibi

Har katta o‘zgarishdan keyin:
1. Tekshirish sanasi va manba commitini yangilash.
2. Funksiya/fayl/package/schema o‘zgarishlarini real yo‘llarga bog‘lash.
3. Har test uchun buyruq, muhit, natija va bajarilmagan qismlarni yozish.
4. Tuzatilgan bugni ochiq ro‘yxatdan chiqarish; yangi risk va TODO’ni qo‘shish.
5. Narx yoki dizayn qarori o‘zgarsa talab bilan real implementatsiyani ajratish.
6. Ushbu README-only holatni source importidan so‘ng haqiqiy audit bilan **almashtirish**, ustiga eskirgan tarix yig‘maslik.

Handoff chat transkripti emas. Secretlar, shaxsiy foydalanuvchi yozuvlari va tasdiqsiz “hammasi ishlaydi” xulosalari bu faylga kiritilmaydi.
