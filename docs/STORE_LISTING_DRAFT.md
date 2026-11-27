# Store listing draft — review after acceptance testing

This draft describes Bilga 1.4.0 for the owner’s review. Confirm the purchase flow and Play listing declarations before publishing it.

App name: **Bilga**

## Short descriptions

**English**

> Private notes, tasks, habits, finance, journals and books. Works offline.

**O‘zbekcha**

> Qaydlar, vazifalar, odatlar, moliya, kundalik va kitoblar. Oflayn ishlaydi.

**Русский**

> Заметки, задачи, привычки, финансы, дневник и книги. Работает офлайн.

## English full description

Bilga brings your ideas, commitments and personal reflections into one private space. Capture notes, organize tasks, track habits, manage personal finances, keep a journal, and read EPUB, PDF and TXT books.

Find saved information with offline text search and open the original record. Use the Today view to review due tasks and habit progress, or look ahead at upcoming work. Organize notes and tasks in folders, and use tags, history and trash to manage your notes.

Read aloud in Uzbek, English or Russian. Ask Bilga to read the current screen or use the Read aloud button. In the book reader, it reads the text of the current EPUB or TXT section or the current PDF page. Speech commands and pronunciation depend on the available language services.

Local databases and attachments use encryption. Export your own records or create a password-protected backup. Optional Google Drive backup requires a Google account and internet connection. Use a local backup for attachments.

Try Bilga for 40 days without entering a payment method. After the evaluation, one optional lifetime purchase enables continued creation and editing. There is no subscription, advertising or automatic charge when the trial ends. Reading, exporting and creating personal backups remain available without purchasing.

Prices are shown by Google Play in the supported local currency. Lifetime purchasers receive the same included features in every region. Purchases and purchase restoration require Google Play; ordinary note-taking and organization work offline.

Reminder timing depends on Android permissions, battery restrictions and device settings. Review Bilga's reminder settings for the available options.

## O‘zbekcha to‘liq tavsif

Bilga kundalik ishlaringiz va shaxsiy yozuvlaringizni bir joyga jamlaydi. Qayd yozing, vazifalarni rejalashtiring, odatlarni kuzating, xarajatlarni hisoblang, kundalik yuring hamda EPUB, PDF va TXT kitoblarini o‘qing.

Saqlangan yozuvlarni oflayn qidiring. Bugungi reja, kutilayotgan vazifalar va odatlar natijasini ko‘rib turing. Vazifalar muhimligiga qarab turli ohanglarda eslatiladi.

«O‘qib ber» tugmasini bosing yoki ovozli buyruq bering. Bilga ekrandagi matnni, yozuvni yoki kitobning ochiq qismini o‘zbekcha, inglizcha yoki ruscha o‘qiydi. Ovozli buyruqlar va talaffuz qurilmadagi til xizmatlariga bog‘liq.

Bilga shaxsiy yozuvlarni qurilmada shifrlab saqlaydi. Yozuvlarni eksport qilish yoki parol bilan himoyalangan zaxira nusxasini yaratish mumkin. Ixtiyoriy Google Drive zaxirasi uchun Google hisobi va internet kerak. Biriktirmalar uchun mahalliy zaxiradan foydalaning.

Bilga’ni karta ma’lumotlarini kiritmasdan 40 kun sinab ko‘ring. Keyin yangi yozuv qo‘shish va tahrirlashni bir martalik umrbod xarid orqali davom ettirish mumkin. Mavjud yozuvlarni o‘qish, eksport qilish va zaxiralash ochiq qoladi. Sinov tugaganda avtomatik to‘lov olinmaydi. Narxni Google Play mahalliy valyutada ko‘rsatadi.

## Полное описание на русском

Bilga помогает навести порядок в повседневных делах и личных записях. Ведите заметки и дневник, планируйте задачи, отслеживайте привычки, учитывайте личные расходы и читайте книги в форматах EPUB, PDF и TXT.

Поиск по сохранённым записям работает офлайн. Посмотрите план на сегодня, ближайшие задачи и прогресс привычек. Для задач разной важности предусмотрены разные сигналы напоминаний.

Нажмите «Читать вслух» или произнесите команду. Bilga читает текст открытого экрана, заметку, раздел EPUB или TXT либо текст на текущей странице PDF на узбекском, английском или русском. Распознавание речи и произношение зависят от доступных языковых служб.

Личные записи и вложения хранятся на устройстве в зашифрованном виде. Их можно экспортировать или сохранить в резервной копии с паролем. Для дополнительного резервного копирования в Google Диск нужны аккаунт Google и интернет. Для вложений используйте локальную копию.

Bilga можно использовать бесплатно 40 дней без ввода платёжных данных. Затем создавать и редактировать записи позволяет разовая покупка бессрочного доступа. Чтение, экспорт и резервное копирование сохранённых записей остаются доступны. Автоматического списания нет. Цену в местной валюте показывает Google Play.

## Purchase disclosure for the current closed test

The production descriptions above describe the lifetime purchase model. For the signed 1.4.0+20 closed test, use the copy in `build/play-closed-test/listing`, which says that purchases are disabled for the test. Use the production purchase wording after the Play product and verifier have passed license testing.

## Before publishing

- Verify translations of descriptions and purchase disclosures in supported store languages.
- Review the new phone screenshots in `build/play-closed-test/listing/screenshots`. They show the actual current Flutter routes in a phone-sized test viewport with synthetic content. The Android device release test remains a separate check.
- Use the current icon and [feature graphic](../release/bilga-feature-graphic-1024x500.png) in the listing assets.
- Provide a public owner-approved privacy-policy URL, complete Data Safety/content rating and confirm contact details.
- Confirm Play account, merchant, country, pricing, testing-track and signing requirements in PLAY_POLICY_REVIEW.md.

## 1.4.0 release notes

**O‘zbekcha**

> Bilga ekrandagi matn, qaydlar va kitob sahifalarini ovoz chiqarib o‘qiydi. Vidjet burchaklari yumaloq qilindi. Vazifa eslatmalari muhimlik darajasiga qarab turli ohanglarda chalinadi. Vidjetdan ko‘rsatish ruxsati bekor qilingan vazifalar darhol olib tashlanadi.

**English**

> Read on-screen text, notes and book pages aloud. Widgets have rounded corners, and task reminders use different tones for each priority. Tasks disappear from widgets when their display permission is turned off.

**Русский**

> Читайте вслух текст экрана, заметки и страницы книг. У виджетов появились закруглённые углы, а у напоминаний о задачах разной важности — разные сигналы. Если отключить разрешение на показ задачи, она сразу исчезает из виджета.
