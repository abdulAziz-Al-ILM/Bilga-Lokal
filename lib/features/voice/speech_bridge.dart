import 'dart:async';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SpeechRecognition {
  final String text;
  final List<String> alternatives;

  const SpeechRecognition(this.text, {this.alternatives = const []});
}

class SpeechBridge {
  static const channel = MethodChannel('bilga/speech');
  static final _events = StreamController<MethodCall>.broadcast();
  static bool _receiving = false;

  static Stream<MethodCall> get events {
    if (!_receiving) {
      _receiving = true;
      channel.setMethodCallHandler((call) async => _events.add(call));
    }
    return _events.stream;
  }

  Future<Map<String, dynamic>> state() async {
    try {
      return {...?await channel.invokeMapMethod<String, dynamic>('state')};
    } on MissingPluginException {
      return {'available': false, 'onDevice': false};
    }
  }

  Future<bool> prefersDeviceRecognizer(String language) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool('bilga.voiceDeviceOnly.$language') ?? true;
  }

  Future<void> setDeviceRecognizerPreference(
    String language,
    bool value,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setBool('bilga.voiceDeviceOnly.$language', value)) {
      throw StateError('settings_write');
    }
  }

  Future<String?> listen({
    required String language,
    required bool onDevice,
    bool followUp = false,
  }) async => (await recognize(
    language: language,
    onDevice: onDevice,
    followUp: followUp,
  ))?.text;

  Future<SpeechRecognition?> recognize({
    required String language,
    required bool onDevice,
    bool followUp = false,
  }) async {
    final result = await channel.invokeMapMethod<String, dynamic>('listen', {
      'language': language,
      'onDevice': onDevice,
      if (followUp) 'followUp': true,
    });
    final primary = result?['text'];
    if (primary is! String || primary.trim().isEmpty) return null;
    final text = primary.trim();
    final alternatives = result?['alternatives'];
    return SpeechRecognition(
      text,
      alternatives: alternatives is List
          ? List.unmodifiable(
              alternatives
                  .whereType<String>()
                  .map((choice) => choice.trim())
                  .where((choice) => choice.isNotEmpty && choice != text)
                  .toSet()
                  .take(2),
            )
          : const [],
    );
  }

  Future<void> stop() => channel.invokeMethod<void>('stop');
  Future<void> cancel() async {
    try {
      await channel.invokeMethod<void>('cancel');
    } on MissingPluginException {
      /* Text remains available on other platforms. */
    }
  }
}

class SpeechOutput {
  static const _channel = MethodChannel('bilga/speech_output');

  static Future<bool> hasNavoiySample() async {
    try {
      return await _channel.invokeMethod<bool>('hasNavoiySample') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> playNavoiySample() =>
      _channel.invokeMethod<void>('playNavoiySample');

  static Future<void> speak(String text, String language, {double rate = 1}) {
    final excerpt = String.fromCharCodes(text.runes.take(1100));
    final prepared = language.split('-').first == 'uz'
        ? _uzbekSpeech(excerpt)
        : excerpt;
    return _channel.invokeMethod<void>('speak', {
      'language': language,
      'text': String.fromCharCodes(prepared.runes.take(1100)),
      'rate': rate,
    });
  }

  static Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (_) {
      // Keep the written answer available if there is no speech engine.
    }
  }
}

// Some offline voices read multi-digit Uzbek amounts one digit at a time.
const _units = [
  'nol',
  'bir',
  'ikki',
  'uch',
  "to'rt",
  'besh',
  'olti',
  'yetti',
  'sakkiz',
  "to'qqiz",
];
const _tens = [
  '',
  "o'n",
  'yigirma',
  "o'ttiz",
  'qirq',
  'ellik',
  'oltmish',
  'yetmish',
  'sakson',
  "to'qson",
];
const _scales = ['', 'ming', 'million', 'milliard', 'trillion', 'kvadrillion'];
const _months = [
  'yanvar',
  'fevral',
  'mart',
  'aprel',
  'may',
  'iyun',
  'iyul',
  'avgust',
  'sentabr',
  'oktabr',
  'noyabr',
  'dekabr',
];

String _spellDigits(String digits) =>
    digits.split('').map((digit) => _units[int.parse(digit)]).join(' ');

String _uzbekInteger(String digits) {
  if (digits.startsWith('0')) return _spellDigits(digits);
  final groups = <String>[];
  for (var end = digits.length, index = 0; end > 0; end -= 3, index++) {
    final group = int.parse(digits.substring(end < 3 ? 0 : end - 3, end));
    if (group == 0) continue;
    final hundreds = group ~/ 100;
    final tens = group ~/ 10 % 10;
    final units = group % 10;
    groups.add(
      [
        if (hundreds > 0) ...[_units[hundreds], 'yuz'],
        if (tens > 0) _tens[tens],
        if (units > 0) _units[units],
        if (index > 0) _scales[index],
      ].join(' '),
    );
  }
  return groups.reversed.join(' ');
}

String _uzbekSpeech(String text) => text
    .replaceAllMapped(RegExp(r'\b(\d{4})-(\d{2})-(\d{2})\b'), (match) {
      final date = DateTime.tryParse(match[0]!);
      if (date == null ||
          date.month != int.parse(match[2]!) ||
          date.day != int.parse(match[3]!)) {
        return match[0]!;
      }
      return '${_uzbekInteger(date.day.toString())} ${_months[date.month - 1]}, '
          '${_uzbekInteger(match[1]!)} yil';
    })
    .replaceAllMapped(
      RegExp(
        r'(?<![\p{L}\p{N}_-])(-?)(\d{1,18})(?:\.(\d{1,12}))?(?![\p{L}\p{N}_-]|\.\d)',
        unicode: true,
      ),
      (match) => [
        if (match[1]!.isNotEmpty) 'minus',
        _uzbekInteger(match[2]!),
        if (match[3] case final fraction?
            when fraction.contains(RegExp(r'[1-9]'))) ...[
          'butun',
          _spellDigits(fraction),
        ],
      ].join(' '),
    )
    .replaceAll(' · ', ', ')
    .replaceAll(' — ', ', ')
    .replaceAllMapped(
      RegExp(r'([^.!?,:;\s])\s*\n+\s*(?=\S)'),
      (match) => '${match[1]}. ',
    );
