# Bilga 1.1.0 +6

## Nimalar qo‘shildi

- Siz bergan yashil o‘ram logotipi: bosh sahifa va Android ikonkasida.
- Yonma-yon, bir xil o‘lchamdagi Yozuvlar va Vazifalar kartalari.
- Yetti mavzuga mos alohida harakatsiz manzara va 24 soniyali original yumshoq fon ohanglari. Video ishlatilmaydi, internet talab qilinmaydi.
- Musiqani yoqish/o‘chirish va balandlik boshqaruvi. Dastlab ovoz o‘chiq. Bosh sahifadan chiqqanda, ilova qulflanganda yoki fonda qolganda musiqa to‘xtaydi.
- To‘rtta muhimlik rangi: past yashil, o‘rta ko‘k, yuqori sariq, o‘ta yuqori qizil. Muddati o‘tgan vazifa qora, oq skelet belgisi bilan; bajarilgan vazifa yashil tasdiq belgisi bilan.
- Faqat 4 xil yumshoq miltillash tezligi: 24 soat yoki ko‘proq, 1–24 soat, 1 soatdan kam, muddati o‘tgan. Bajarilgan va muddatsiz vazifalar miltillamaydi.
- Jildlar yonida Barchasi, Bajarilgan, Muddati o‘tgan, 1 soatdan kam, 1 kundan kam bo‘limlari. Filtrlar barcha ichki jildlardan qidiradi; Jildlar bo‘limi eski jild tartibini saqlaydi. “1 kundan kam” bir soatdan kam qolganlarni ham qamraydi. Bajarilgan va kechikkanlar yaqin muddat filtrlariga kirmaydi.
- Yangi boshqaruv matnlari 43 tilga qo‘shildi.

## O‘rnatish

1. Android Studio / terminaldagi `flutter run` ni to‘xtating. ZIPni Downloads ichida oching.
2. Ochilgan `bilga-yangilanish-1.1.0` papkasida terminal ochib:

```bash
python3 install.py ~/StudioProjects/bilga
```

O‘rnatuvchi faqat shu paketdagi o‘zgargan fayllarni yangilaydi. Oldingi nusxalar loyihangiz yonidagi vaqt belgili `bilga-before-1.1.0-...` papkaga saqlanadi. Siz ZIP yuborgandan keyin biror o‘zgartirilayotgan faylni tahrirlagan bo‘lsangiz, uni ustidan yozmay to‘xtaydi.
`google_config.json`, `android/key.properties`, keystore, SDK manzillari va qurilmadagi bazalar paketga kiritilmagan; o‘rnatuvchi ularga tegmaydi.

3. Tekshirib, emulatorda ishga tushiring:

```bash
cd ~/StudioProjects/bilga
flutter pub get
bash tool/check_free_release.sh
flutter run -d emulator-5554 --dart-define-from-file=google_config.json
```

## Shu yerda bajarilgan tekshiruvlar

- Dart 3.13.3 orqali butun lib/test kodining statik tahlili: xato va ogohlantirishsiz.
- 43 tilda 164 ta matn kaliti: to‘liq.
- Note v1–v7 va Todo v1–v5 dan amaldagi bazaga o‘tish tekshiruvlari: o‘tdi.
- Aynan 1 soat/1 kun/muddat tugashi, vaqt zonalari, bajarilganlar, muddatsiz vazifalar va 4 tezlik bo‘yicha bajariladigan Dart sinovi: o‘tdi.
- M4A lar: AAC stereo, har biri 24 soniya; to‘liq dekodlash tekshirildi. Logotip manbasi aynan saqlandi.
- Google release konfiguratsiyasi validatori: mavjud emas, noto‘g‘ri, to‘g‘ri va client secret kiritilgan holatlar tekshirildi.
- O‘rnatuvchi: zaxiralash, o‘zgargan manbani rad etish, takroriy o‘rnatish va qaytarish tekshirildi.

Flutter tool ishga tushganda bu muhitdagi avtomatik tasdiqlash tekshiruvi bulut ichki metadata manziliga so‘rovni rad etdi. Shu sabab bu yerda `flutter test`, Android build va haqiqiy qurilma sinovi bajarilmadi. Yuqoridagi buyruqlar ularni kompyuteringizda bajaradi. Qo‘shilgan `test/todo_presentation_test.dart` jildlar, tahrir, bajarilganlar va harakatni kamaytirish sinovlarini ham qamraydi. O‘rnatishdan keyin test natijasini ko‘rmasdan Play’ga yubormang.

## Telefonda 5 daqiqalik sinov

1. Eski yozuvni oching, bitta yangi yozuv yarating va qayta oching; jildlar, tarix va savat ko‘rinishini tekshiring.
2. To‘rt xil muhimlikdagi vazifa yarating. Ulardan birini kechikkan, birini bajarilgan qiling; rang, skelet va tasdiq belgisi ko‘rinsin.
3. Ichki jilddagi vazifani Barchasi / 1 soatdan kam filtrida toping. Tahrirlab, o‘z jildida qolganini tekshiring.
4. Har bir mavzuni almashtiring: rasm harakatsiz tursin va mos musiqa yangilansin. Yozuvlarga o‘ting, Home tugmasi bilan fonda qoldiring va ekran qulfini tekshiring — ovoz davom etmasin.
5. Ishlayotgan emulatorda Google ulash va Drive zaxirasini tekshiring.

## Play’dagi Google va AAB

**GOOGLE_PLAY_TUZATISH.md** ni bajaring: Play App Signing SHA-1 sertifikatini shu paket nomi uchun Google Cloud’da ro‘yxatga olish kerak bo‘lishi mumkin. Emulatordagi natija Play nusxasini tekshirgan hisoblanmaydi.

```bash
bash tool/build_play_bundle.sh
```

Natija: `build/app/outputs/bundle/release/app-release.aab`. Yangi versiya `1.1.0+6`. Agar Play Console’da 6 yoki undan yuqori version code ishlatilgan bo‘lsa, `pubspec.yaml` dagi +6 ni ishlatilmagan kattaroq raqamga oshiring.

## Orqaga qaytish

O‘rnatish oxirida ko‘rsatilgan zaxira papkasi orqali:

```bash
python3 install.py --restore /home/abdulaziz/StudioProjects/bilga-before-1.1.0-VAQT
```

O‘rnatuvchi yangilanishdan keyin tahrirlangan fayl bo‘lsa, uni ham ustidan yozmay to‘xtaydi. Fayllar qaytarilgandan so‘ng `flutter pub get` bajariladi. Bu kodni qaytaradi; telefondagi ilovani avtomatik almashtirmaydi.
