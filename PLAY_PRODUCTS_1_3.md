# Bir martalik Google Play mahsulotlari

Hozirgi relizdagi yangi xarid mahsuloti `bilga_lifetime_unlock`. U 40 kunlik sinovdan keyin bir martalik umrbod huquq beradi. Play narxini Console’dagi amaldagi mahsulot belgilaydi. Quyidagi jadval oldingi versiyalardagi mahsulotlarni tiklash uchun saqlangan.

| ID | Rejalashtirilgan AQSh bazaviy narxi | Mazmun |
|---|---:|---|
| bilga_agent_start | $2.49 | Start buyruqlari |
| bilga_agent_turbo | $4.99 | Lokal Turbo + Start |
| bilga_agent_turbo_upgrade | $2.50 | Start egasiga Turbo qo‘shish |
| bilga_finance | $5.00 | Shaxsiy pul qaydlari va hisobot |

Mahsulotlar bir martalik xarid sifatida sozlanadi. Ilova Play ko‘rsatgan mahalliy narxni chiqaradi. Yangi xaridni yoqish uchun amaldagi mahsulot Console’da faol bo‘lishi kerak.

Start egasiga UI upgrade mahsulotini tanlaydi; upgrade Start receiptsiz huquq bermaydi. Bir xil Google Play akkauntida restore qilinadi. Google kirish/Drive akkaunti xarid akkaunti o‘rnini bosmaydi.

`billing_config.example.json` nusxasini `billing_config.json` qiling. `BILGA_PLAY_LICENSE_KEY` maydonida Play Console’dagi ochiq RSA kaliti, `BILGA_BILLING_VERIFY_URL` maydonida tasdiqlash xizmatining HTTPS manzili va `BILGA_BILLING_VERIFY_KEY` maydonida uning ochiq Ed25519 kaliti bo‘lishi kerak. Xizmatning maxfiy kalitlari serverda qoladi. `bash tool/build_play_bundle.sh` nashr uchun to‘plamni yig‘adi. [Tasdiqlash xizmatini sozlash](backend/purchase_verifier/README.md).

Yangi umrbod xaridni server Google Play orqali tekshiradi va imzolangan tasdiq qaytaradi. Ilova tasdiqni qurilmada tekshiradi va oflayn foydalanish uchun saqlaydi. Qaytarilgan xarid holati Play bilan navbatdagi muvaffaqiyatli tekshiruvda yangilanadi. Tahrirlash huquqi tugasa ham foydalanuvchi o‘z yozuvlarini o‘qishi va eksport qilishi mumkin.

minSdk 26 — Android 8+. Native model uchun birinchi build NDK/CMake yuklashni talab qilishi mumkin. Turbo faqat ARM64. Google sign-in Play App Signing SHA-1 va OAuth sozlamalarini hali talab qiladi.

Privacy/Data safety’da lokal AI, model yuklash, ixtiyoriy Drive/online voice, foydalanuvchi tashqariga eksporti va email feedback aniq ko‘rsatilishi kerak. Lokal-only saqlash va foydalanuvchi tanlagan tashqi amallar bir xil narsa emas.
