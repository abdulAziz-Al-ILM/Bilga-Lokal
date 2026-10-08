# Bilga — Google Drive ulanishi

Bu qadamlar loyiha egasining Google Cloud hisobida bir marta bajariladi. Kodning o‘zi haqiqiy Google OAuth identifikatorini yarata olmaydi. Notes, To Do, mavzu, til va faylga zaxiralash Google sozlanmasdan ishlaydi.

1. Google Cloud Console’da Bilga uchun loyiha yarating yoki mavjud loyihani tanlang. Google Drive API’ni yoqing.
2. Google Auth Platform’da ilova nomi, yordam uchun emailingiz va auditoriyani sozlang. Testing rejimida o‘zingiz ishlatadigan Google hisobini test foydalanuvchilariga qo‘shing.
3. OAuth client yarating: Android, package name `com.ilmmizan.bilga`, tegishli imzolash sertifikatining SHA-1 qiymati.
4. Debug SHA-1 ni olish uchun loyiha terminalida:

```bash
cd ~/StudioProjects/bilga/android
./gradlew signingReport
```

`debug` variantining SHA1 qiymatini oling. Play orqali o‘rnatilgan versiya uchun Play Console’dagi **App signing key certificate** SHA-1 bilan ham Android OAuth client yarating. Upload key va App signing key bir xil bo‘lishi shart emas. Bir xil Google Cloud loyihasidan foydalaning.

5. Shu loyihada **Web application** turidagi OAuth client ham yarating. Uning Client ID qiymati kerak; Client secret ilovaga kiritilmaydi.
6. Loyiha ildizida `google_config.json` yarating:

```json
{
  "BILGA_GOOGLE_WEB_CLIENT_ID": "BU_YERGA_WEB_CLIENT_ID.apps.googleusercontent.com"
}
```

7. Ilovani to‘liq qayta ishga tushiring (hot reload yetmaydi):

```bash
cd ~/StudioProjects/bilga
flutter run -d emulator-5554 --dart-define-from-file=google_config.json
```

8. Profil → Google hisobini ulash → Zaxira yaratish. Kamida 12 belgili zaxira parolini tanlang va xavfsiz joyga yozib qo‘ying. Boshqa test qurilmada aynan shu Google hisobi va zaxira paroli bilan tiklashni tekshiring. Asosiy qurilmadagi ilovani bu sinov uchun o‘chirmang.

Ilova faqat `drive.appdata` doirasini so‘raydi. Zaxira Drive’dagi Bilga uchun ajratilgan yashirin `appDataFolder` ichiga yoziladi; oddiy Drive fayllaringiz o‘qilmaydi. Bu hisobdagi barcha fayllarga ruxsat emas. Profilning “Hisobdan uzish” tugmasi ulanish ruxsatini bekor qiladi, mahalliy yozuvlarni o‘chirmaydi.

Hozir zaxira qo‘lda yaratiladi. Parol saqlanmaydi, avtomatik zaxiralash hali yo‘q. Har bir nusxa alohida saqlanadi, oxirgi 50 tasi tiklash ro‘yxatida ko‘rsatiladi. Eski nusxalar avtomatik o‘chirilmaydi. Drive sig‘imi tugasa, amal xato bilan tugaydi; mahalliy yozuvlar saqlanib qoladi.

Yuklashdan keyin fayl qayta yuklab olinib, baytlari solishtiriladi. Shundan keyingina muvaffaqiyat ko‘rsatiladi. Internet uzilsa yoki tekshiruv tugamasa, muvaffaqiyat deb ko‘rsatilmaydi; Drive’da yuklangan nusxa qolgan bo‘lishi mumkin.

Nashrdan oldin OAuth auditoriyasi/production sozlamalarini tugating va Play’dan o‘rnatilgan imzolangan versiyada ham ulang, zaxiralang va tiklang. Bu paketda haqiqiy Google hisobida sinov bajarilgani da’vo qilinmaydi.

Rasmiy manbalar:
- https://pub.dev/packages/google_sign_in_android
- https://developers.google.com/workspace/drive/api/guides/appdata
