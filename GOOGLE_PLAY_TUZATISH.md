# Emulatorda Google ishlaydi, Play nusxasida ishlamaydi

Bu farq odatda SHA-1 yoki yig‘ilmaga kiritilgan Web client ID bilan bog‘liq. Aniq sababni sizning Play nusxangizni tekshirmasdan tasdiqlab bo‘lmaydi. Drive autentifikatsiya va shifrlash kodi bu yangilanishda o‘zgartirilmadi.

## 1. Play imzosini Google Cloud loyihasiga kiriting

1. Play Console → Bilga → **Test and release → Setup → App signing**. Ayrim interfeyslarda **App integrity → App signing** orqali ochiladi.
2. **App signing key certificate** ichidagi **SHA-1 certificate fingerprint** ni nusxalang. **Upload key certificate** boshqa kalit: Play’dan o‘rnatilgan ilova uchun yuqoridagi app signing sertifikati kerak.
3. Google Cloud → **bilga-507913** → Google Auth Platform → **Clients → Create client**.
4. Application type: **Android**. Name: `Bilga Google Play`.
5. Package name: **com.ilmmizan.bilga**.
6. SHA-1: Play Console’dan olingan app signing SHA-1. Saqlang.
7. Ishlayotgan debug Android client va Web clientni qoldiring. Agar kalit yangilangan bo‘lsa, Play ko‘rsatgan amaldagi eski/yangi app signing sertifikatlarini ham tegishli Android clientlarda ro‘yxatga oling.

Android client ID ni `google_config.json` ga yozmang. U faylda shu Google Cloud loyihasidagi **Web application** client ID qoladi. Client secret kerak emas va ilovaga qo‘shilmaydi.

## 2. Tester Google hisobi va Drive

Google Auth Platform → **Audience**: OAuth hali Testing bo‘lsa, Drive sinovchilari **Test users** ro‘yxatiga kirgan bo‘lishi kerak. Play testerlar ro‘yxati bilan bu ro‘yxat alohida.
Google Cloud → APIs & Services → Library: **Google Drive API** enabled bo‘lsin.

## 3. Yangi AAB va aynan Play nusxasini tekshirish

```bash
cd ~/StudioProjects/bilga
python3 tool/check_google_config.py
bash tool/build_play_bundle.sh
```

Skript uchun Google ulanishi, upload kaliti va xarid tekshiruvi sozlangan bo‘lishi kerak. Paket versiyasi `pubspec.yaml` faylidan olinadi. Fayldagi `+` belgisidan keyingi raqam Play Console’da avval yuklangan eng katta version code’dan yuqori bo‘lishi kerak.

Play Console → Internal testing → Create new release → yangi `build/app/outputs/bundle/release/app-release.aab` → e’lon qiling.
Telefoningizdagi Play Market orqali **Update** qiling. Ilovani o‘chirish shart emas; lokal yozuvlar saqlanadi. Oldindan shifrlangan zaxira nusxa olish tavsiya etiladi.

Sinov: Google akkauntni ulash → kichik yozuv yaratish → Drive’ga zaxiralash → “yuklandi va tekshirildi” natijasini tekshirish. So‘ng zaxira ro‘yxatini ochish. Asosiy telefonda ma’lumotni o‘chirib sinamang.

Agar ishlamasa, qaysi bosqichda to‘xtashi va xabar skrinshoti kerak. Parol, client secret, token yoki keystore yuborish kerak emas.

Rasmiy manbalar (2026-09-18 da tekshirildi):
- [Google Sign-In Android konfiguratsiyasi va SHA xatolari](https://pub.dev/packages/google_sign_in_android)
- [Play App Signing sertifikatlari](https://support.google.com/googleplay/android-developer/answer/9842756?hl=en)
