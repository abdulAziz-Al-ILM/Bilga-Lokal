import 'settings.dart';

String startText(String uz, String en, String ru) =>
    switch (AppSettings.instance.language) {
      'uz' => uz,
      'ru' => ru,
      _ => en,
    };
