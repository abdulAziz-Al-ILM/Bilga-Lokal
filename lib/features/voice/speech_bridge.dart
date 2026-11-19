import 'dart:async';

import 'package:flutter/services.dart';

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

  Future<String?> listen({
    required String language,
    required bool onDevice,
    bool followUp = false,
  }) async {
    final result = await channel.invokeMapMethod<String, dynamic>('listen', {
      'language': language,
      'onDevice': onDevice,
      if (followUp) 'followUp': true,
    });
    return result?['text'] as String?;
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

  static Future<void> speak(String text, String language, {double rate = 1}) =>
      _channel.invokeMethod<void>('speak', {
        'language': language,
        'text': String.fromCharCodes(text.runes.take(1100)),
        'rate': rate,
      });

  static Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (_) {
      // Keep the written answer available if there is no speech engine.
    }
  }
}
