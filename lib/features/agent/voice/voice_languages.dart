// Central registry: command vocabulary does not imply installed speech models.
enum ReadingIntent { pause, resume, read }

class VoiceLanguage {
  final String locale;
  final List<String> pause, resume, read;
  const VoiceLanguage(this.locale, this.pause, this.resume, this.read);
  List<String> aliases(ReadingIntent intent) => switch (intent) {
    ReadingIntent.pause => pause,
    ReadingIntent.resume => resume,
    ReadingIntent.read => read,
  };
}

const voiceLanguages = <String, VoiceLanguage>{
  'uz': VoiceLanguage(
    'uz-UZ',
    ["to‘xta", "to‘xtat", "to‘xtab tur", "pauza", "o‘qishni to‘xtat"],
    ["davom et", "davom ettir", "o‘qishni davom ettir"],
    ["o‘qib ber", "o‘qi", "yozuvni o‘qib ber"],
  ),
  'kk': VoiceLanguage(
    'kk-KZ',
    ["тоқта", "тоқтат", "кідір"],
    ["жалғастыр", "жалғастыру"],
    ["оқып бер", "оқы"],
  ),
  'ky': VoiceLanguage(
    'ky-KG',
    ["токто", "токтот", "тыным"],
    ["улант", "улантуу"],
    ["окуп бер", "оку"],
  ),
  'tg': VoiceLanguage(
    'tg-TJ',
    ["ист", "истед", "таваққуф"],
    ["идома деҳ", "давом деҳ"],
    ["хон", "хонда деҳ"],
  ),
  'tk': VoiceLanguage('tk-TM', ["dur", "sakla"], ["dowam et", "dowam etdir"], [
    "okap ber",
    "oka",
  ]),
  'en': VoiceLanguage(
    'en-US',
    ["stop", "pause", "stop reading", "pause reading"],
    ["resume", "continue", "continue reading", "resume reading"],
    ["read aloud", "read note", "read notes", "read"],
  ),
  'ru': VoiceLanguage(
    'ru-RU',
    ["стой", "стоп", "остановись", "пауза", "останови чтение"],
    ["продолжай", "продолжить", "продолжи чтение"],
    ["прочитай заметку", "прочитай", "читай"],
  ),
  'tr': VoiceLanguage(
    'tr-TR',
    ["dur", "durdur", "bekle"],
    ["devam et", "sürdür"],
    ["sesli oku", "notu oku", "oku"],
  ),
  'es': VoiceLanguage(
    'es-ES',
    ["para", "detente", "pausa"],
    ["continúa", "continua", "reanuda"],
    ["lee en voz alta", "lee la nota", "lee"],
  ),
  'fr': VoiceLanguage(
    'fr-FR',
    ["arrête", "arrête de lire", "pause"],
    ["continue", "reprends"],
    ["lis à voix haute", "lis la note", "lis"],
  ),
  'de': VoiceLanguage(
    'de-DE',
    ["stopp", "stop", "anhalten", "pause"],
    ["weiter", "fortsetzen", "lies weiter"],
    ["lies vor", "vorlesen", "lies"],
  ),
  'it': VoiceLanguage(
    'it-IT',
    ["fermati", "stop", "pausa"],
    ["continua", "riprendi"],
    ["leggi ad alta voce", "leggi la nota", "leggi"],
  ),
  'pt': VoiceLanguage(
    'pt-BR',
    ["pare", "parar", "pausa"],
    ["continue", "retome", "continuar"],
    ["leia em voz alta", "leia a nota", "leia"],
  ),
  'ar': VoiceLanguage(
    'ar-SA',
    ["توقف", "قف", "توقّف"],
    ["تابع", "استمر", "أكمل"],
    ["اقرأ بصوت عال", "اقرأ الملاحظة", "اقرأ"],
  ),
  'fa': VoiceLanguage(
    'fa-IR',
    ["توقف", "بایست", "صبر کن"],
    ["ادامه بده", "ادامه"],
    ["بلند بخوان", "یادداشت را بخوان", "بخوان"],
  ),
  'ur': VoiceLanguage(
    'ur-PK',
    ["رکو", "رک جاؤ", "توقف"],
    ["جاری رکھو", "دوبارہ شروع کرو"],
    ["بلند آواز میں پڑھو", "نوٹ پڑھو", "پڑھو"],
  ),
  'hi': VoiceLanguage(
    'hi-IN',
    ["रुको", "रुक जाओ", "बंद करो"],
    ["जारी रखो", "आगे पढ़ो"],
    ["ज़ोर से पढ़ो", "नोट पढ़ो", "पढ़ो"],
  ),
  'bn': VoiceLanguage(
    'bn-BD',
    ["থামো", "থামুন", "বিরতি"],
    ["চালিয়ে যাও", "আবার শুরু করো"],
    ["জোরে পড়ো", "নোট পড়ো", "পড়ো"],
  ),
  'zh': VoiceLanguage('zh-CN', ["停止", "停下", "暂停"], ["继续", "继续阅读", "恢复"], [
    "朗读笔记",
    "朗读",
    "读一下",
  ]),
  'ja': VoiceLanguage('ja-JP', ["止めて", "停止", "一時停止"], ["続けて", "再開", "読み続けて"], [
    "読み上げて",
    "ノートを読んで",
    "読んで",
  ]),
  'ko': VoiceLanguage(
    'ko-KR',
    ["멈춰", "정지", "일시 정지"],
    ["계속해", "다시 시작", "계속 읽어"],
    ["소리 내어 읽어", "메모 읽어", "읽어 줘"],
  ),
  'id': VoiceLanguage(
    'id-ID',
    ["berhenti", "jeda", "hentikan"],
    ["lanjutkan", "lanjut"],
    ["baca catatan", "bacakan", "baca"],
  ),
  'ms': VoiceLanguage(
    'ms-MY',
    ["berhenti", "jeda", "henti"],
    ["teruskan", "sambung"],
    ["baca nota", "bacakan", "baca"],
  ),
  'vi': VoiceLanguage(
    'vi-VN',
    ["dừng lại", "dừng", "tạm dừng"],
    ["tiếp tục", "đọc tiếp"],
    ["đọc to", "đọc ghi chú", "đọc"],
  ),
  'th': VoiceLanguage(
    'th-TH',
    ["หยุด", "หยุดอ่าน", "พัก"],
    ["อ่านต่อ", "ดำเนินต่อ"],
    ["อ่านออกเสียง", "อ่านบันทึก", "อ่าน"],
  ),
  'uk': VoiceLanguage(
    'uk-UA',
    ["стоп", "зупинись", "пауза"],
    ["продовжуй", "продовжити"],
    ["прочитай нотатку", "прочитай", "читай"],
  ),
  'pl': VoiceLanguage(
    'pl-PL',
    ["stop", "zatrzymaj", "pauza"],
    ["kontynuuj", "wznów"],
    ["czytaj na głos", "przeczytaj notatkę", "czytaj"],
  ),
  'nl': VoiceLanguage(
    'nl-NL',
    ["stop", "pauze", "stop met lezen"],
    ["ga verder", "hervat"],
    ["lees voor", "lees de notitie", "lees"],
  ),
  'sv': VoiceLanguage(
    'sv-SE',
    ["stopp", "pausa", "sluta läsa"],
    ["fortsätt", "återuppta"],
    ["läs högt", "läs anteckningen", "läs"],
  ),
  'nb': VoiceLanguage(
    'nb-NO',
    ["stopp", "pause", "stans"],
    ["fortsett", "gjenoppta"],
    ["les høyt", "les notatet", "les"],
  ),
  'da': VoiceLanguage(
    'da-DK',
    ["stop", "pause", "stands"],
    ["fortsæt", "genoptag"],
    ["læs højt", "læs noten", "læs"],
  ),
  'fi': VoiceLanguage(
    'fi-FI',
    ["pysähdy", "lopeta", "tauko"],
    ["jatka", "jatka lukemista"],
    ["lue ääneen", "lue muistiinpano", "lue"],
  ),
  'cs': VoiceLanguage(
    'cs-CZ',
    ["stop", "zastav", "pauza"],
    ["pokračuj", "obnov"],
    ["čti nahlas", "přečti poznámku", "čti"],
  ),
  'sk': VoiceLanguage(
    'sk-SK',
    ["stop", "zastav", "pauza"],
    ["pokračuj", "obnov"],
    ["čítaj nahlas", "prečítaj poznámku", "čítaj"],
  ),
  'ro': VoiceLanguage(
    'ro-RO',
    ["stop", "oprește", "pauză"],
    ["continuă", "reia"],
    ["citește cu voce tare", "citește nota", "citește"],
  ),
  'hu': VoiceLanguage(
    'hu-HU',
    ["állj", "állítsd le", "szünet"],
    ["folytasd", "folytatás"],
    ["olvasd fel", "olvasd a jegyzetet", "olvass"],
  ),
  'el': VoiceLanguage(
    'el-GR',
    ["σταμάτα", "παύση", "στοπ"],
    ["συνέχισε", "συνέχεια"],
    ["διάβασε δυνατά", "διάβασε τη σημείωση", "διάβασε"],
  ),
  'bg': VoiceLanguage(
    'bg-BG',
    ["стоп", "спри", "пауза"],
    ["продължи", "продължавай"],
    ["прочети бележката", "прочети", "чети"],
  ),
  'he': VoiceLanguage('he-IL', ["עצור", "הפסק", "השהה"], ["המשך", "תמשיך"], [
    "קרא בקול",
    "קרא את ההערה",
    "קרא",
  ]),
  'az': VoiceLanguage(
    'az-AZ',
    ["dayan", "dayandır", "fasilə"],
    ["davam et", "davam elə"],
    ["ucadan oxu", "qeydi oxu", "oxu"],
  ),
  'ka': VoiceLanguage(
    'ka-GE',
    ["გაჩერდი", "შეჩერდი", "პაუზა"],
    ["გააგრძელე", "განაგრძე"],
    ["ხმამაღლა წაიკითხე", "წაიკითხე ჩანაწერი", "წაიკითხე"],
  ),
  'ta': VoiceLanguage(
    'ta-IN',
    ["நிறுத்து", "நிறுத்தவும்", "இடைநிறுத்து"],
    ["தொடரு", "தொடரவும்"],
    ["சத்தமாக படி", "குறிப்பைப் படி", "படி"],
  ),
  'sw': VoiceLanguage(
    'sw-KE',
    ["simama", "acha", "sitisha"],
    ["endelea", "anza tena"],
    ["soma kwa sauti", "soma dokezo", "soma"],
  ),
};

String normalizeVoiceCommand(String input) => input
    .trim()
    .toLowerCase()
    .replaceAll(RegExp('[‘’ʻʼ`´]'), "'")
    .replaceAll(RegExp(r'[.!?。！？]+$'), '')
    .trim();

({ReadingIntent intent, String argument})? parseReadingCommand(
  String input, {
  String preferredLanguage = 'en',
}) {
  final text = normalizeVoiceCommand(input);
  final ordered = [
    if (voiceLanguages.containsKey(preferredLanguage.split('-').first))
      voiceLanguages[preferredLanguage.split('-').first]!,
    ...voiceLanguages.entries
        .where((e) => e.key != preferredLanguage.split('-').first)
        .map((e) => e.value),
  ];
  // Longest phrases first: "read note" must precede "read".
  for (final intent in ReadingIntent.values) {
    final aliases = ordered.expand((l) => l.aliases(intent)).toSet().toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final alias in aliases) {
      final normalized = normalizeVoiceCommand(alias);
      if (text == normalized) return (intent: intent, argument: '');
      if (intent == ReadingIntent.read &&
          (text.startsWith('$normalized ') ||
              text.startsWith('$normalized:'))) {
        return (
          intent: intent,
          argument: input
              .trim()
              .substring(alias.length)
              .replaceFirst(RegExp(r'^\s*:\s*'), '')
              .trim(),
        );
      }
    }
  }
  return null;
}

/// Conservative script/word hints; ambiguous text keeps the selected language.
/// This is not a statistical language detector and cannot distinguish all Latin
/// languages. Never silently substitute an unrelated voice for a missing pack.
String textLanguage(String text, String preferred) {
  final primary = preferred.split('-').first;
  const scripts = <String, String>{
    'ja': r'[\u3040-\u30ff]',
    'ko': r'[\uac00-\ud7af]',
    'zh': r'[\u4e00-\u9fff]',
    'hi': r'[\u0900-\u097f]',
    'bn': r'[\u0980-\u09ff]',
    'ta': r'[\u0b80-\u0bff]',
    'th': r'[\u0e00-\u0e7f]',
    'ka': r'[\u10a0-\u10ff]',
    'he': r'[\u0590-\u05ff]',
    'el': r'[\u0370-\u03ff]',
  };
  for (final e in scripts.entries) {
    if (RegExp(e.value).hasMatch(text)) return e.key;
  }
  if (RegExp(r'[\u0600-\u06ff]').hasMatch(text)) {
    return {'ar', 'fa', 'ur'}.contains(primary) ? primary : 'ar';
  }
  if (RegExp(r'[\u0400-\u052f]').hasMatch(text)) {
    if (RegExp('[іїєґІЇЄҐ]').hasMatch(text)) return 'uk';
    return {'ru', 'uk', 'bg', 'kk', 'ky', 'tg'}.contains(primary)
        ? primary
        : 'ru';
  }
  final lower = text.toLowerCase();
  if (RegExp(r"[oOgG][‘’ʻʼ']|\b(yozuv|uchun|bilan|salom)\b").hasMatch(lower)) {
    return 'uz';
  }
  if (RegExp(r'\b(the|this|hello|with|please)\b').hasMatch(lower)) return 'en';
  return voiceLanguages.containsKey(primary) ? primary : 'en';
}

// Availability messages are independent of command vocabulary and engine support.
const voiceAvailabilityMessages = <String, (String, String, String)>{
  'uz': (
    "Offline ovoz mavjud",
    "Bu til uchun offline ovoz mavjud emas",
    "Offline ovoz mavjudligi tekshirilmagan",
  ),
  'kk': (
    "Офлайн дауыс бар",
    "Бұл тілде офлайн дауыс жоқ",
    "Офлайн дауыс тексерілмеген",
  ),
  'ky': (
    "Офлайн үн бар",
    "Бул тилде офлайн үн жок",
    "Офлайн үн текшерилген эмес",
  ),
  'tg': (
    "Овози офлайн дастрас аст",
    "Овози офлайн барои ин забон дастрас нест",
    "Дастрасии овози офлайн санҷида нашудааст",
  ),
  'tk': (
    "Oflayn ses elýeterli",
    "Bu dilde oflayn ses elýeterli däl",
    "Oflayn ses barlanmady",
  ),
  'en': (
    "Offline speech available",
    "Offline speech unavailable for this language",
    "Offline speech availability unverified",
  ),
  'ru': (
    "Офлайн-речь доступна",
    "Офлайн-речь этого языка недоступна",
    "Доступность офлайн-речи не проверена",
  ),
  'tr': (
    "Çevrimdışı ses kullanılabilir",
    "Bu dilde çevrimdışı ses kullanılamıyor",
    "Çevrimdışı ses doğrulanmadı",
  ),
  'es': (
    "Voz sin conexión disponible",
    "Voz sin conexión no disponible para este idioma",
    "Voz sin conexión sin verificar",
  ),
  'fr': (
    "Voix hors ligne disponible",
    "Voix hors ligne indisponible pour cette langue",
    "Voix hors ligne non vérifiée",
  ),
  'de': (
    "Offline-Sprache verfügbar",
    "Offline-Sprache für diese Sprache nicht verfügbar",
    "Offline-Sprache nicht überprüft",
  ),
  'it': (
    "Voce offline disponibile",
    "Voce offline non disponibile per questa lingua",
    "Voce offline non verificata",
  ),
  'pt': (
    "Voz offline disponível",
    "Voz offline indisponível para este idioma",
    "Voz offline não verificada",
  ),
  'ar': (
    "الصوت دون اتصال متاح",
    "الصوت دون اتصال غير متاح لهذه اللغة",
    "لم يتم التحقق من الصوت دون اتصال",
  ),
  'fa': (
    "گفتار آفلاین موجود است",
    "گفتار آفلاین برای این زبان موجود نیست",
    "گفتار آفلاین بررسی نشده است",
  ),
  'ur': (
    "آف لائن آواز دستیاب ہے",
    "اس زبان کے لیے آف لائن آواز دستیاب نہیں",
    "آف لائن آواز کی تصدیق نہیں ہوئی",
  ),
  'hi': (
    "ऑफ़लाइन आवाज़ उपलब्ध है",
    "इस भाषा के लिए ऑफ़लाइन आवाज़ उपलब्ध नहीं है",
    "ऑफ़लाइन आवाज़ की उपलब्धता सत्यापित नहीं है",
  ),
  'bn': (
    "অফলাইন কণ্ঠ উপলব্ধ",
    "এই ভাষায় অফলাইন কণ্ঠ উপলব্ধ নয়",
    "অফলাইন কণ্ঠ যাচাই করা হয়নি",
  ),
  'zh': ("离线语音可用", "此语言的离线语音不可用", "离线语音可用性尚未验证"),
  'ja': ("オフライン音声を利用できます", "この言語のオフライン音声は利用できません", "オフライン音声の利用可否は未確認です"),
  'ko': (
    "오프라인 음성을 사용할 수 있습니다",
    "이 언어의 오프라인 음성을 사용할 수 없습니다",
    "오프라인 음성 사용 가능 여부가 확인되지 않았습니다",
  ),
  'id': (
    "Suara offline tersedia",
    "Suara offline tidak tersedia untuk bahasa ini",
    "Ketersediaan suara offline belum diverifikasi",
  ),
  'ms': (
    "Suara luar talian tersedia",
    "Suara luar talian tidak tersedia untuk bahasa ini",
    "Suara luar talian belum disahkan",
  ),
  'vi': (
    "Có giọng nói ngoại tuyến",
    "Không có giọng nói ngoại tuyến cho ngôn ngữ này",
    "Chưa xác minh giọng nói ngoại tuyến",
  ),
  'th': (
    "มีเสียงออฟไลน์",
    "ไม่มีเสียงออฟไลน์สำหรับภาษานี้",
    "ยังไม่ได้ตรวจสอบเสียงออฟไลน์",
  ),
  'uk': (
    "Офлайн-мовлення доступне",
    "Офлайн-мовлення цією мовою недоступне",
    "Доступність офлайн-мовлення не перевірена",
  ),
  'pl': (
    "Mowa offline jest dostępna",
    "Mowa offline w tym języku jest niedostępna",
    "Dostępność mowy offline niezweryfikowana",
  ),
  'nl': (
    "Offline spraak beschikbaar",
    "Offline spraak niet beschikbaar voor deze taal",
    "Offline spraak niet geverifieerd",
  ),
  'sv': (
    "Offlinetal tillgängligt",
    "Offlinetal saknas för detta språk",
    "Offlinetal har inte verifierats",
  ),
  'nb': (
    "Frakoblet tale er tilgjengelig",
    "Frakoblet tale er ikke tilgjengelig for dette språket",
    "Frakoblet tale er ikke bekreftet",
  ),
  'da': (
    "Offline tale tilgængelig",
    "Offline tale ikke tilgængelig for dette sprog",
    "Offline tale ikke bekræftet",
  ),
  'fi': (
    "Offline-puhe käytettävissä",
    "Offline-puhetta ei ole tälle kielelle",
    "Offline-puhetta ei ole tarkistettu",
  ),
  'cs': (
    "Offline řeč je dostupná",
    "Offline řeč pro tento jazyk není dostupná",
    "Offline řeč nebyla ověřena",
  ),
  'sk': (
    "Offline reč je dostupná",
    "Offline reč pre tento jazyk nie je dostupná",
    "Offline reč nebola overená",
  ),
  'ro': (
    "Voce offline disponibilă",
    "Voce offline indisponibilă pentru această limbă",
    "Voce offline neverificată",
  ),
  'hu': (
    "Offline beszéd elérhető",
    "Ehhez a nyelvhez nem érhető el offline beszéd",
    "Az offline beszéd nincs ellenőrizve",
  ),
  'el': (
    "Διαθέσιμη ομιλία εκτός σύνδεσης",
    "Δεν υπάρχει ομιλία εκτός σύνδεσης για αυτή τη γλώσσα",
    "Η ομιλία εκτός σύνδεσης δεν έχει επαληθευτεί",
  ),
  'bg': (
    "Офлайн речта е налична",
    "Офлайн речта не е налична за този език",
    "Офлайн речта не е проверена",
  ),
  'he': (
    "דיבור לא מקוון זמין",
    "דיבור לא מקוון אינו זמין בשפה זו",
    "זמינות דיבור לא מקוון לא אומתה",
  ),
  'az': (
    "Oflayn səs mövcuddur",
    "Bu dil üçün oflayn səs mövcud deyil",
    "Oflayn səs yoxlanılmayıb",
  ),
  'ka': (
    "ოფლაინ ხმა ხელმისაწვდომია",
    "ამ ენისთვის ოფლაინ ხმა მიუწვდომელია",
    "ოფლაინ ხმა შემოწმებული არ არის",
  ),
  'ta': (
    "ஆஃப்லைன் குரல் கிடைக்கிறது",
    "இந்த மொழிக்கு ஆஃப்லைன் குரல் கிடைக்கவில்லை",
    "ஆஃப்லைன் குரல் சரிபார்க்கப்படவில்லை",
  ),
  'sw': (
    "Sauti ya nje ya mtandao inapatikana",
    "Sauti ya nje ya mtandao haipatikani kwa lugha hii",
    "Sauti ya nje ya mtandao haijathibitishwa",
  ),
};
String voiceAvailabilityText(String language, String state) {
  final words =
      voiceAvailabilityMessages[language.split('-').first] ??
      voiceAvailabilityMessages['en']!;
  return switch (state) {
    'available' || 'model' => words.$1,
    'unknown' => words.$3,
    _ => words.$2,
  };
}
