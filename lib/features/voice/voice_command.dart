import '../finance/ledger.dart' show currencies;

/// Small extensible grammar. Recognized words never execute directly and
/// retrieved personal content is never interpreted as an instruction.
enum VoiceAction {
  note,
  findNotes,
  task,
  reminder,
  completeHabit,
  expense,
  income,
  findFinance,
  experience,
  openBook,
  continueBook,
  card,
  search,
  today,
  pendingHabits,
  lastFriday,
  weeklySpending,
  readFolder,
  unknown,
}

class VoiceCommand {
  final VoiceAction action;
  final String argument;
  const VoiceCommand(this.action, this.argument);
  static String normalize(String input) {
    var value = input.replaceAll(RegExp('[‘’ʻʼ`´]'), "'");
    for (final first in [0x660, 0x6f0, 0x966, 0x9e6]) {
      for (var i = 0; i < 10; i++) {
        value = value.replaceAll(String.fromCharCode(first + i), '$i');
      }
    }
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static VoiceCommand parse(String input) {
    var value = normalize(input);
    value = value
        .replaceFirst(
          RegExp(
            r'^(?:iltimos[, ]+|please[, ]+|пожалуйста[, ]+|bilga[, ]+|menga\s+)',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
    final lower = value.toLowerCase().replaceFirst(RegExp(r'[?.!]+$'), '');
    const questions = <VoiceAction, List<String>>{
      VoiceAction.today: [
        "bugun nima qilishim kerak",
        "bugun nima qilay",
        'what should i do today',
        'что мне делать сегодня',
      ],
      VoiceAction.pendingHabits: [
        "bugun qaysi odatlar bajarilmagan",
        "bugun qaysi odatlarimni bajarmadim",
        'which habits have i not completed today',
        'which habits are left today',
        'какие привычки я не выполнил сегодня',
      ],
      VoiceAction.lastFriday: [
        "o'tgan juma kuni nima yozdim",
        "o'tgan juma nima yozdim",
        'what did i write last friday',
        'что я написал в прошлую пятницу',
      ],
      VoiceAction.weeklySpending: [
        'bu hafta qancha sarfladim',
        'shu hafta qancha sarfladim',
        'how much did i spend this week',
        'сколько я потратил на этой неделе',
      ],
      VoiceAction.continueBook: [
        'continue my book',
        'kitobimni davom ettir',
        'продолжи мою книгу',
      ],
    };
    for (final rule in questions.entries) {
      if (rule.value.contains(lower)) return VoiceCommand(rule.key, '');
    }
    final folder = RegExp(
      r"^(?:read (?:my )?(.+?) folder|(.+?) papkasini o'qib ber|прочитай папку (.+))$",
    ).firstMatch(lower);
    if (folder != null) {
      return VoiceCommand(
        VoiceAction.readFolder,
        (folder[1] ?? folder[2] ?? folder[3])!.trim(),
      );
    }
    const prefixes = <VoiceAction, List<String>>{
      VoiceAction.findFinance: [
        'moliyadan qidir',
        'moliyaviy qaydlarni qidir',
        'xarajatlarni qidir',
        'search finance',
        'find transactions',
        'найди в финансах',
      ],
      VoiceAction.findNotes: [
        'qaydlardan qidir',
        'yozuvlarimdan qidir',
        'yozuvlardan qidir',
        'qaydni top',
        'yozuvni top',
        'yozuvlarni qidir',
        'search notes',
        'find notes',
        'найди заметку',
      ],
      VoiceAction.continueBook: [
        "o'qishni davom ettir",
        "kitobni o'qishni davom ettir",
        'continue reading',
        'resume reading',
        'продолжи чтение',
      ],
      VoiceAction.completeHabit: [
        'odatni bajarildi deb belgilа',
        'odatni bajarildi deb belgila',
        'odatni bajarildi',
        'odatni belgilа',
        'odatni belgila',
        'complete habit',
        'mark habit complete',
        'отметь привычку',
      ],
      VoiceAction.expense: [
        'xarajat yoz',
        'chiqim yoz',
        'xarajat qayd et',
        "xarajat qo'sh",
        'record expense',
        'add expense',
        'запиши расход',
      ],
      VoiceAction.income: [
        'daromad yoz',
        'kirim yoz',
        'daromad qayd et',
        "daromad qo'sh",
        'record income',
        'add income',
        'запиши доход',
      ],
      VoiceAction.experience: [
        'tajriba yoz',
        'tajriba yarat',
        'tajribani qayd et',
        "tajriba qo'sh",
        'create experience',
        'record experience',
        'запиши опыт',
      ],
      VoiceAction.card: [
        'bilim kartasi yarat',
        'bilim kartasini yarat',
        "bilim kartasi qo'sh",
        'savol kartasi yarat',
        'create knowledge card',
        'add knowledge card',
        'создай карточку',
      ],
      VoiceAction.openBook: [
        'kitobni och',
        'kitob och',
        'open book',
        'открой книгу',
      ],
      VoiceAction.reminder: [
        "eslatma qo'y",
        'eslatma yarat',
        'eslatib tur',
        'remind me',
        'set reminder',
        'напомни мне',
      ],
      VoiceAction.task: [
        'vazifa yarat',
        "vazifa qo'sh",
        'vazifa yoz',
        'create task',
        'add task',
        'создай задачу',
      ],
      VoiceAction.note: [
        'qayd yarat',
        'qayd yoz',
        'yozuv yarat',
        "yozuv qo'sh",
        'eslatma yoz',
        'create note',
        'add note',
        'take a note',
        'создай заметку',
      ],
      VoiceAction.search: [
        'maʼlumot qidir',
        "ma'lumot qidir",
        'ma’lumot qidir',
        'bilgadan qidir',
        'search personal information',
        'search my data',
        'найди мои данные',
      ],
    };
    for (final rule in prefixes.entries) {
      for (final prefix in rule.value) {
        if (lower == prefix ||
            lower.startsWith('$prefix ') ||
            lower.startsWith('$prefix:')) {
          return VoiceCommand(
            rule.key,
            value
                .substring(prefix.length)
                .replaceFirst(RegExp(r'^\s*:\s*'), '')
                .trim(),
          );
        }
      }
    }
    const suffixes = <String, VoiceAction>{
      ' deb qayd yoz': VoiceAction.note,
      ' deb yozuv yarat': VoiceAction.note,
      " deb yozib qo'y": VoiceAction.note,
      ' deb vazifa yarat': VoiceAction.task,
      " deb vazifa qo'sh": VoiceAction.task,
      ' deb tajriba yoz': VoiceAction.experience,
      ' tajriba sifatida yoz': VoiceAction.experience,
      ' xarajat yoz': VoiceAction.expense,
      ' xarajat sifatida yoz': VoiceAction.expense,
      ' sarfladim': VoiceAction.expense,
      ' daromad yoz': VoiceAction.income,
      ' daromad sifatida yoz': VoiceAction.income,
      ' kitobini och': VoiceAction.openBook,
      ' kitobni och': VoiceAction.openBook,
      " odatini bajarildi deb belgila": VoiceAction.completeHabit,
      ' odatini bajarildi deb belgilа': VoiceAction.completeHabit,
      ' eslat': VoiceAction.reminder,
      " eslatib qo'y": VoiceAction.reminder,
      ' qaydlardan top': VoiceAction.findNotes,
      ' yozuvni top': VoiceAction.findNotes,
      ' bilgadan qidir': VoiceAction.search,
    };
    for (final rule in suffixes.entries) {
      if (lower.endsWith(rule.key) && value.length > rule.key.length) {
        return VoiceCommand(
          rule.value,
          value.substring(0, value.length - rule.key.length).trim(),
        );
      }
    }
    return VoiceCommand(VoiceAction.unknown, value);
  }
}

class VoiceMoney {
  final String? number, currency;
  final String remainder;
  const VoiceMoney(this.number, this.currency, this.remainder);
  static const units = {
    'nol': 0,
    'bir': 1,
    'ikki': 2,
    'uch': 3,
    "to'rt": 4,
    'besh': 5,
    'olti': 6,
    'yetti': 7,
    'sakkiz': 8,
    "to'qqiz": 9,
    'zero': 0,
    'one': 1,
    'two': 2,
    'three': 3,
    'four': 4,
    'five': 5,
    'six': 6,
    'seven': 7,
    'eight': 8,
    'nine': 9,
    'ноль': 0,
    'один': 1,
    'одна': 1,
    'два': 2,
    'две': 2,
    'три': 3,
    'четыре': 4,
    'пять': 5,
    'шесть': 6,
    'семь': 7,
    'восемь': 8,
    'девять': 9,
  };
  static const tens = {
    "o'n": 10,
    'yigirma': 20,
    "o'ttiz": 30,
    'qirq': 40,
    'ellik': 50,
    'oltmish': 60,
    'yetmish': 70,
    'sakson': 80,
    "to'qson": 90,
    'ten': 10,
    'eleven': 11,
    'twelve': 12,
    'thirteen': 13,
    'fourteen': 14,
    'fifteen': 15,
    'sixteen': 16,
    'seventeen': 17,
    'eighteen': 18,
    'nineteen': 19,
    'twenty': 20,
    'thirty': 30,
    'forty': 40,
    'fifty': 50,
    'sixty': 60,
    'seventy': 70,
    'eighty': 80,
    'ninety': 90,
    'десять': 10,
    'двадцать': 20,
    'тридцать': 30,
    'сорок': 40,
    'пятьдесят': 50,
    'шестьдесят': 60,
    'семьдесят': 70,
    'восемьдесят': 80,
    'девяносто': 90,
  };
  static const hundreds = {
    'yuz': 100,
    'hundred': 100,
    'сто': 100,
    'двести': 200,
    'триста': 300,
    'четыреста': 400,
    'пятьсот': 500,
  };
  static const scales = {
    'ming': 1000,
    'thousand': 1000,
    'тысяч': 1000,
    'тысяча': 1000,
    'тысячи': 1000,
    'million': 1000000,
    'миллион': 1000000,
    'миллионов': 1000000,
  };
  static BigInt? words(List<String> input) {
    if (input.isEmpty || input.length > 24) return null;
    var total = BigInt.zero,
        group = 0,
        previous = 'start',
        lastScale = 1000000001;
    for (final token in input) {
      if (token == 'and' || token == 'va') {
        if (previous == 'start') return null;
        continue;
      }
      if (units.containsKey(token)) {
        if (previous == 'unit' || previous == 'teen') return null;
        group += units[token]!;
        previous = 'unit';
      } else if (tens.containsKey(token)) {
        if (previous == 'unit' || previous == 'ten') return null;
        group += tens[token]!;
        previous = tens[token]! % 10 == 0 ? 'ten' : 'teen';
      } else if (hundreds.containsKey(token)) {
        if (previous != 'start' &&
            !(previous == 'unit' && group >= 1 && group <= 9)) {
          return null;
        }
        final h = hundreds[token]!;
        if (h != 100 && group != 0) return null;
        group = h == 100 ? (group == 0 ? 1 : group) * 100 : h;
        previous = 'hundred';
      } else if (scales.containsKey(token)) {
        final scale = scales[token]!;
        if (scale >= lastScale || previous == 'unit' && group == 0) return null;
        total += BigInt.from(group == 0 ? 1 : group) * BigInt.from(scale);
        group = 0;
        previous = 'start';
        lastScale = scale;
      } else {
        return null;
      }
    }
    return total + BigInt.from(group);
  }

  static VoiceMoney extract(String raw) {
    final text = VoiceCommand.normalize(raw), lower = text.toLowerCase();
    if (RegExp(r"(?:yarim|half|половина|полтора)|[-−]\s*[$€]?\s*\d")
        .hasMatch(lower)) {
      return VoiceMoney(null, null, text);
    }
    final currencyRegex = RegExp(
      "(?<![\\p{L}_])(?:${currencies.keys.join('|')}|dollar|dollars|euro|yevro|rubl|рублей|рубль|долларов|доллар|евро|so'm|som|сум)(?![\\p{L}\\p{N}_])|\\\$",
      caseSensitive: false,
      unicode: true,
    );
    String? code(String token) => currencies.containsKey(token.toUpperCase())
        ? token.toUpperCase()
        : switch (token.toLowerCase()) {
            'usd' ||
            'dollar' ||
            'dollars' ||
            'доллар' ||
            'долларов' ||
            r'$' => 'USD',
            'eur' || 'euro' || 'yevro' || 'евро' => 'EUR',
            'rub' || 'rubl' || 'рубль' || 'рублей' => 'RUB',
            _ => 'UZS',
          };
    final currencyMatches = currencyRegex.allMatches(lower).toList(),
        distinct = currencyMatches.map((m) => code(m[0]!)).toSet();
    if (distinct.length > 1) return VoiceMoney(null, null, text);
    final candidates = <({int start, int end, String number})>[];
    final digit = RegExp(
      r'\d{1,3}(?:[ \u00a0]\d{3})+(?:[.,]\d{1,3})?|\d+(?:[.,]\d{1,3})?',
    );
    for (final m in digit.allMatches(lower)) {
      var end = m.end,
          value = m[0]!
              .replaceAll(RegExp(r'[ \u00a0]'), '')
              .replaceAll(',', '.');
      final scale = RegExp(r'^\s*(ming|million|thousand|тысяч|миллион)(?:\s|$)')
          .firstMatch(lower.substring(end));
      if (scale != null) {
        if (value.contains('.')) {
          return VoiceMoney(null, distinct.firstOrNull, text);
        }
        value = (BigInt.parse(value) * BigInt.from(scales[scale[1]]!))
            .toString();
        end += scale.end;
      }
      candidates.add((start: m.start, end: end, number: value));
    }
    final tokens = RegExp(
      r"[a-zа-яё']+",
      caseSensitive: false,
    ).allMatches(lower).toList();
    for (var i = 0; i < tokens.length; i++) {
      final first = tokens[i], word = first[0]!;
      if (!units.containsKey(word) &&
          !tens.containsKey(word) &&
          !hundreds.containsKey(word) &&
          !scales.containsKey(word)) {
        continue;
      }
      final group = <String>[word];
      var j = i + 1, end = first.end;
      for (; j < tokens.length; j++) {
        final token = tokens[j][0]!;
        if (lower.substring(end, tokens[j].start).trim().isNotEmpty ||
            !(units.containsKey(token) ||
                tens.containsKey(token) ||
                hundreds.containsKey(token) ||
                scales.containsKey(token) ||
                token == 'and' ||
                token == 'va')) {
          break;
        }
        group.add(token);
        end = tokens[j].end;
      }
      i = j - 1;
      if (candidates.any((c) => first.start < c.end && end > c.start)) continue;
      final value = words(group);
      if (value == null) return VoiceMoney(null, distinct.firstOrNull, text);
      candidates.add((start: first.start, end: end, number: value.toString()));
    }
    final chosen = candidates.length == 1 ? candidates.single : null;
    if (chosen == null ||
        chosen.start > 0 &&
            RegExp(r'(?:-|minus|минус)\s*$')
                .hasMatch(lower.substring(0, chosen.start))) {
      return VoiceMoney(null, distinct.firstOrNull, text);
    }
    var remainder = text
        .replaceRange(chosen.start, chosen.end, '')
        .replaceAll(currencyRegex, '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return VoiceMoney(chosen.number, distinct.firstOrNull, remainder);
  }
}

class VoiceWhen {
  final DateTime? date;
  final int? minute;
  final String remainder;
  const VoiceWhen(this.date, this.minute, this.remainder);
  DateTime? get at => date == null || minute == null
      ? null
      : DateTime(
          date!.year,
          date!.month,
          date!.day,
          minute! ~/ 60,
          minute! % 60,
        );
  static VoiceWhen parse(String raw, DateTime now) {
    var text = VoiceCommand.normalize(raw);
    DateTime? date;
    int? minute;
    final explicit = RegExp(r'\b\d{4}-\d{2}-\d{2}\b').firstMatch(text);
    if (explicit != null) {
      final d = DateTime.tryParse(explicit[0]!);
      if (d != null && d.toIso8601String().substring(0, 10) == explicit[0]) {
        date = d;
        text = text.replaceRange(explicit.start, explicit.end, '');
      }
    } else {
      final relative = RegExp(
        r'(?<![\p{L}])(bugun|ertaga|kecha|today|tomorrow|yesterday|сегодня|завтра|вчера)(?![\p{L}])',
        caseSensitive: false,
        unicode: true,
      ).firstMatch(text);
      if (relative != null) {
        final token = relative[0]!.toLowerCase(),
            offset = ['ertaga', 'tomorrow', 'завтра'].contains(token)
                ? 1
                : ['kecha', 'yesterday', 'вчера'].contains(token)
                ? -1
                : 0;
        date = DateTime(now.year, now.month, now.day + offset);
        text = text.replaceRange(relative.start, relative.end, '');
      }
    }
    final clock = RegExp(
      r'(?<![\p{L}])(?:soat|at|в)\s+(\d{1,2})(?::([0-9]{2}))?\s*(am|pm|da)?(?![\p{L}\p{N}])',
      caseSensitive: false,
      unicode: true,
    ).firstMatch(text);
    if (clock != null) {
      var hour = int.parse(clock[1]!);
      final m = int.tryParse(clock[2] ?? '0') ?? 0,
          suffix = clock[3]?.toLowerCase();
      if ((suffix == 'am' || suffix == 'pm') && hour >= 1 && hour <= 12) {
        hour = hour % 12 + (suffix == 'pm' ? 12 : 0);
      }
      if (hour >= 0 && hour <= 23 && m >= 0 && m <= 59) {
        minute = hour * 60 + m;
        text = text.replaceRange(clock.start, clock.end, '');
      }
    }
    return VoiceWhen(date, minute, text.replaceAll(RegExp(r'\s+'), ' ').trim());
  }
}
