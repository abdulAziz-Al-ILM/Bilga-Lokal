import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const languages = <String, String>{
  'uz': 'O‘zbek',
  'kk': 'Қазақша',
  'ky': 'Кыргызча',
  'tg': 'Тоҷикӣ',
  'tk': 'Türkmençe',
  'en': 'English',
  'ru': 'Русский',
  'tr': 'Türkçe',
  'es': 'Español',
  'fr': 'Français',
  'de': 'Deutsch',
  'it': 'Italiano',
  'pt': 'Português',
  'ar': 'العربية',
  'fa': 'فارسی',
  'ur': 'اردو',
  'hi': 'हिन्दी',
  'bn': 'বাংলা',
  'zh': '中文',
  'ja': '日本語',
  'ko': '한국어',
  'id': 'Bahasa Indonesia',
  'ms': 'Bahasa Melayu',
  'vi': 'Tiếng Việt',
  'th': 'ไทย',
  'uk': 'Українська',
  'pl': 'Polski',
  'nl': 'Nederlands',
  'sv': 'Svenska',
  'nb': 'Norsk',
  'da': 'Dansk',
  'fi': 'Suomi',
  'cs': 'Čeština',
  'sk': 'Slovenčina',
  'ro': 'Română',
  'hu': 'Magyar',
  'el': 'Ελληνικά',
  'bg': 'Български',
  'he': 'עברית',
  'az': 'Azərbaycanca',
  'ka': 'ქართული',
  'ta': 'தமிழ்',
  'sw': 'Kiswahili',
};

class Strings {
  static final Map<String, Map<String, String>> catalogs = {};
  static Future<void> load({String code = 'en'}) async {
    for (final language in {'en', code}) {
      if (catalogs.containsKey(language) || !languages.containsKey(language)) {
        continue;
      }
      catalogs[language] = Map<String, String>.from(
        jsonDecode(await rootBundle.loadString('assets/i18n/$language.json'))
            as Map,
      );
    }
  }

  static String get(String code, String key) =>
      catalogs[code]?[key] ?? catalogs['en']?[key] ?? key;
}

extension Translate on BuildContext {
  String tr(String key) =>
      Strings.get(Localizations.localeOf(this).languageCode, key);
}
