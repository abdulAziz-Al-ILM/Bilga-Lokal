# Bilga Core: 40 kunlik sinov va bir martalik litsenziya

2026-10-11. Commit/push bajarilmadi. Maxfiy yoki release signing kalitlari o‘zgartirilmadi.

## Bloklanish sababi

Oldingi kodda trial yo‘q edi. `AgentAccess.has()` faqat eski Start/Turbo/Finance
xaridlarini ochardi. Kalitsiz/sideload debug build’da mahsulot topilmaganda
`xUnavailable` → “Hozir mavjud emas — Google Playni tekshiring” chiqardi;
yordamchi buyruqlari `access.allowed == false` sabab o‘chirilardi. Notes bosh
sahifasi uchun avval global Play gate yo‘q edi; planshetdagi aynan qaysi ekran
ko‘ringani bu hostdan tekshirilmagan.

Yana bir xato: muvaffaqiyatli deb qaytgan bo‘sh/partial restore javobi barcha
cached receipt’larni o‘chirardi. Bu refund yoki haqiqiy bekor qilish dalili emas.

## Joriy ishlash

- Birinchi ishga tushishda 40 × 24 soatlik trial **Billing’ni kutmasdan** private
  storage’da boshlanadi. Boshlanish, hisoblangan vaqt va introduction holati
  yangilanishda/restart’da saqlanadi; qayta yozilib yangi 40 kun berilmaydi.
- Birinchi ochilishda 40 kun, bir martalik umrbod xarid va obuna yo‘qligi
  tushuntiriladi. “Boshlash” holati muvaffaqiyatli saqlangach oyna yopiladi.
- Core, notes, tasks, habits, moliya va boshqa asosiy imkoniyatlar trial’da ochiq.
  Oldindan deferred bo‘lgan Turbo trial orqali ishlayotgandek ko‘rsatilmaydi.
- Billing outage, product yo‘qligi, bekor/pending xarid yoki tekshirish xatosi
  faol trial’ni yoki allaqachon tasdiqlangan xaridni bekor qilmaydi.
- Trial tugaganda barcha app route’lari ustida lifetime purchase oynasi chiqadi.
  Amaldagi editor/navigation mounted qoladi; DB va fayllar o‘chirilmaydi.
  Profil/zaxira/eksportga kirish mavjud AppLock himoyasi ichida qoladi.
- Haqiqiy Google-imzoli eski Start/Turbo/Finance egalariga Core access saqlanadi
  (grandfather migration). Upgrade yolg‘iz o‘zi Start/Core huquqini bermaydi.
  `bilga.agent.receipt` va `bilga.receipt.<legacy ID>` kalitlari saqlanadi.
- Trial huquqi va haqiqiy xarid `entitled/corePurchased` alohida holatlardir.
  Trial yoki debug hech qachon `owned` to‘plamiga xarid qo‘shmaydi.

## Trial storage va vaqt

`TrialBridge.kt` trial uchun alohida Android Keystore AES-256-GCM kaliti va
`noBackupFilesDir/core-trial-v1` AtomicFile ishlatadi. Notes vault kalitiga tegmaydi.
Buzilgan/olib tashlangan fayl yoki yo‘qolgan kalit avtomatik yangi trial bermaydi;
xabar, qayta tekshirish va data eksporti mavjud. Native write eski boshlanish/
installation/acknowledgement qiymatlarini qaytarishga ruxsat bermaydi.

Wall-clock high-water va `SystemClock.elapsedRealtime()` (sleep bilan) ishlatiladi.
Bir boot ichida sanani orqaga surish qolgan vaqtni oshirmaydi. Boot o‘zgargach
sana oldingi maksimumdan 5 daqiqadan ko‘p orqada bo‘lsa, avtomatik sana/vaqtni
rostlash so‘raladi. Sana oldinga surilib muddat tugasa, keyin orqaga qaytarish
trial’ni tiriltirmaydi. Foreground minute timer va resume’da qayta hisoblanadi.

**Offline client mutlaq ishonchli soat emas.** Root/modifikatsiyalangan APK,
quvvat o‘chiq paytdagi vaqtni soxtalashtirish va storage rollback’ni serversiz
mutlaq to‘sib bo‘lmaydi. Bu tizim anti-tamper’ni mutlaq kafolatlamaydi.

**Uninstall / reinstall:** Android app-private fayllar va Keystore kalitini
uninstall’da o‘chiradi. Bu loyiha privacy sabab AutoBackup’ni ham o‘chirgan.
Shuning uchun sof offline yangi o‘rnatish eski trial bilan bir qurilmadagi
reinstall’ni ishonchli ajrata olmaydi; yangi lokal trial boshlanishi mumkin.
Trial’ni uninstall’dan keyin ham davom ettirish uchun authenticated hisob +
serverdagi start/deadline yoki boshqa ishonchli device-recall xizmati kerak.
Bunday xizmat ushbu repoda/config’da yo‘q va bu ishda deploy qilinmadi.
Notes’ni uninstall qilishdan oldin foydalanuvchi shifrlangan backup olishi kerak.
Play xaridlari o‘sha Play akkauntidan restore qilinadi, yangi installation uchun
server tasdig‘i qayta olinadi. Notes backup hech qachon litsenziya/trial holatini
restore qilib muddatni reset qilmaydi.

## Yangi Core xaridi: production konfiguratsiyasi

`billing_config.example.json` — faqat public konfiguratsiya namunasi:

| Dart define | Ma’nosi |
|---|---|
| `BILGA_CORE_PRODUCT_ID` | Yangi INAPP/non-consumable lifetime ID, default `bilga_core_lifetime`; Console’da yaratilishi kerak |
| `BILGA_PLAY_LICENSE_KEY` | Play Console’ning RSA public licensing key’i |
| `BILGA_BILLING_VERIFY_URL` | Ishonchli o‘zingiz boshqaradigan HTTPS verifier `/verify` |
| `BILGA_BILLING_VERIFY_KEY` | Verifier Ed25519 **public** key (base64, 32 byte) |

Yangi mahsulot ID eski to‘rtta ID’ni almashtirmasligi kerak. Narx Play’dan keladi,
qo‘lda `$7` deb ko‘rsatilmaydi; obuna API’si yoki consumable ishlatilmaydi.
Release preflight ushbu konfiguratsiyani talab qiladi va debug flaglarini rad
etadi. Haqiqiy config/kalitlar tahrirlanmagan. Default debug’da trial ishlaydi;
xarid tugmasi konfiguratsiyasiz o‘chiq va sababini ochiq tushuntiradi.

**Serverning o‘zi bu o‘zgarishda yaratilmagan/deploy qilinmagan.** Client protokoli
va kriptografik tekshiruv tayyor; live purchase ishlaydi deb da’vo qilinmaydi.
Google tavsiyasi: https://developer.android.com/google/play/billing/security

POST JSON:

```json
{"packageName":"com.ilmmizan.bilga","productId":"bilga_core_lifetime","receipt":"<originalJson>","signature":"<Google RSA signature>","installation":"<32 hex chars>"}
```

Backend Google Play Developer API orqali package/product/token va PURCHASED
holatini tekshirishi, token replay/account eligibility’ni boshqarishi, non-consumable
xaridni acknowledge qilishi va refund/RTDN holatini saqlashi kerak. Play service
account credential va Ed25519 private key faqat serverda bo‘ladi, APK ichida emas.
Qayta so‘rovlar idempotent bo‘lsin. Client ham persisted receipt’dan keyin
`completePurchase`ni chaqiradi; acknowledgement xatosi mavjud huquqni o‘chirmaydi.

Javob `{"payload":"<exact UTF-8 JSON string>","signature":"<base64 Ed25519 signature>"}`.
Payload:

```json
{"version":1,"packageName":"com.ilmmizan.bilga","productId":"bilga_core_lifetime","installation":"<same installation>","receiptSha256":"<sha256 exact receipt UTF-8>","entitlement":"lifetime","status":"purchased"}
```

Faqat haqiqiy server tekshiruvidan keyin `purchased` imzolansin. Faqat ishonchli
refund/revocation dalili bilan `status: revoked` qaytarilsin. Transport xatosi,
bo‘sh purchase list yoki hisob o‘zgarishi revocation emas. Redirect qabul qilinmaydi,
javob hajmi 16 KiB bilan cheklangan, 15 soniya timeout bor. Shaxsiy notes/audio
serverga yuborilmaydi; faqat yuqoridagi billing metadata yuboriladi.

Android avval Google RSA signature + package + product + purchaseState + token’ni
tekshiradi. Keyin client pinned Ed25519 public key bilan server attestation’ni,
receipt hash va installation binding’ni tekshiradi. Ikkala dalilsiz yangi Core
huquqi berilmaydi. Tasdiqlangan lifetime grant offline ishlaydi; bu soxta
“offline unlock” emas. Cache dalili har startup’da yana tekshiriladi.

**Refund cheklovi:** to‘liq offline qurilma yangi refund’ni bila olmaydi. Server
revocation so‘rovida aniqlanadi; eski legacy receipt’lar oldingi offline semantics’ni
saqlaydi. Davriy majburiy online lease qo‘shilmadi. Reinstall/device restore yangi
installation uchun yangi server tasdig‘ini talab qiladi.

## Xavfsiz debug sinov

```bash
bash tool/build_test_apk.sh
BILGA_TRIAL_TEST=expired bash tool/build_test_apk.sh
BILGA_TRIAL_TEST=billing_unavailable bash tool/build_test_apk.sh
```

Yoki `flutter build apk --debug --dart-define=BILGA_TRIAL_TEST=expired`.
Ikkala test scenario uchun ham Dart `kDebugMode` va Android `FLAG_DEBUGGABLE`
kerak. `expired` faqat ko‘rinadigan access’ni cheklaydi (asl trial’ni tugatmaydi);
`billing_unavailable` faqat Play outage’ni simulyatsiya qiladi. Normal build’ga
qaytganda asl start/deadline o‘zgarmaydi. `active`, `unlimited` va eski
`BILGA_AGENT_PREVIEW` pullik huquq ochmaydi. Release/profile’da test flag samarasiz.

## Tekshiruvlar

- `flutter analyze`: **PASS — No issues found**, 4.7s. Oldingi ikki urinishda
  host Dart native SIGSEGV kuzatilgan, keyingi lintlar tuzatilgan.
- `flutter test --concurrency=1 test/trial_state_test.dart test/core_purchase_verifier_test.dart test/agent_access_test.dart`: **40 PASS**, exit 0, ~5s.
- `--dart-define=BILGA_TRIAL_TEST=expired` bilan access testlari: **15 PASS**.
- `--dart-define=BILGA_TRIAL_TEST=billing_unavailable` bilan access testlari: **15 PASS**.
- Umumiy `flutter test --concurrency=1`: **146 PASS, exit 1**, 57s. Native
  FlutterTester segmentation fault sabab `widget_test.dart`dagi autosave,
  storage-failure, slow-autosave, edit-session testlari va teardown incomplete.
  Import/assertion xatosi qayd qilinmagan; umumiy suite green emas.
- `flutter build apk --debug`: **PASS**, exit 0, 37.2s. Mavjud plugin KGP
  compatibility warning qolgan; versiyalar o‘zgartirilmagan.
- `bash tool/verify_android_apk.sh`: **ZIP CRC PASS, APK v2 signature PASS**.
- APK: `build/app/outputs/flutter-apk/app-debug.apk`, **321338152 bytes**.
  SHA-256: `c6be8b70d8f209c5dc6e87ce184f55953b418167dcc966da0bf65daf66629852`.
- Loglar `.buildlog/license-fix/` (gitignored). Dastlabki test urinishlarida ham
  host native SIGSEGV kuzatilgan; barcha urinishlar green deb ko‘rsatilmaydi.
- `git diff --check`, bash syntax va Python syntax tekshiruvlari o‘tgan.
Real planshetning Keystore, soat/reboot, Play test purchase, refund va reinstall
sinovlari bu hostga Android qurilma ulanmagani uchun hali bajarilmagan.
