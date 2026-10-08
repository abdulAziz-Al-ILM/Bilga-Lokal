# Bir martalik Google Play mahsulotlari

| ID | Rejalashtirilgan AQSh bazaviy narxi | Mazmun |
|---|---:|---|
| bilga_agent_start | $2.49 | Start buyruqlari |
| bilga_agent_turbo | $4.99 | Lokal Turbo + Start |
| bilga_agent_turbo_upgrade | $2.50 | Start egasiga Turbo qo‘shish |
| bilga_finance | $5.00 | Shaxsiy pul qaydlari va hisobot |

Barchasi INAPP / non-consumable. Obuna emas. Boshqa funksiyalar bepul. Narx Console’da o‘rnatiladi; ilova Play bergan mahalliy narxni chiqaradi. Kod o‘zi mahsulot yaratmaydi, xarid summasini qo‘lda o‘tkazmaydi. Mahsulotlar yoqilmaganida sotib olish ishlamaydi.

Start egasiga UI upgrade mahsulotini tanlaydi; upgrade Start receiptsiz huquq bermaydi. Bir xil Google Play akkauntida restore qilinadi. Google kirish/Drive akkaunti xarid akkaunti o‘rnini bosmaydi.

billing_config.example.json nusxasini billing_config.json qiling. BILGA_PLAY_LICENSE_KEY — Play Console public licensing RSA key; service-account maxfiy kaliti emas. Release buildda preview taqiqlangan. `bash tool/build_play_bundle.sh` AAB yaratadi, Play’ga yuklamaydi.

Receipt imzosi qurilmada tekshiriladi; tasdiqlangan receipt offline saqlanadi. Internetda Play muvaffaqiyatli javob bersa qayta tekshiriladi. Refundni offline darhol bilish va root/o‘zgartirilgan APKda billingni mutlaq himoya qilish serversiz imkonsiz. Huquq yo‘qolishi foydalanuvchining mavjud pul qaydlarini o‘chirmaydi, o‘qish/eksport qoladi.

minSdk 26 — Android 8+. Native model uchun birinchi build NDK/CMake yuklashni talab qilishi mumkin. Turbo faqat ARM64. Google sign-in Play App Signing SHA-1 va OAuth sozlamalarini hali talab qiladi.

Privacy/Data safety’da lokal AI, model yuklash, ixtiyoriy Drive/online voice, foydalanuvchi tashqariga eksporti va email feedback aniq ko‘rsatilishi kerak. Lokal-only saqlash va foydalanuvchi tanlagan tashqi amallar bir xil narsa emas.
