import 'package:flutter/services.dart';

class SpeechBridge {
  static const channel = MethodChannel('bilga/speech');
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
  }) async {
    final result = await channel.invokeMapMethod<String, dynamic>('listen', {
      'language': language,
      'onDevice': onDevice,
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
