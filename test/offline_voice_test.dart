import 'dart:async';
import 'dart:io';

import 'package:bilga/features/agent/voice/model_store.dart';
import 'package:bilga/features/agent/voice/offline_voice.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late OfflineVoice voice;
  final calls = <MethodCall>[];
  late Completer<bool> playback;
  var stt = 'available';
  setUp(() async {
    root = await Directory.systemTemp.createTemp('bilga-voice-channel-test');
    voice = OfflineVoice(VoiceModelStore(root));
    calls.clear();
    playback = Completer<bool>();
    stt = 'available';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(OfflineVoice.channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'capabilities' => {
              'sdk': 35,
              'abis': ['arm64-v8a'],
              'tts': true,
              'stt': stt,
            },
            'speak' => playback.future,
            'listen' => 'resume',
            _ => null,
          };
        });
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(OfflineVoice.channel, null);
    await root.delete(recursive: true);
  });
  test('System audio pause/resume keep the same pending playback', () async {
    final speaking = voice.speak('A private note', 'en-US');
    await Future<void>.delayed(Duration.zero);
    await voice.pause();
    await voice.resume();
    expect(calls.where((c) => c.method == 'speak').length, 1);
    expect(
      calls.map((c) => c.method),
      containsAllInOrder(['speak', 'pause', 'resume']),
    );
    playback.complete(true);
    expect(await speaking, isTrue);
  });
  test(
    'Unavailable local STT never calls a recognizer or downloader',
    () async {
      stt = 'unavailable';
      await expectLater(
        voice.listen('uz-UZ'),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'offline_unavailable',
          ),
        ),
      );
      expect(calls.any((c) => c.method == 'listen'), isFalse);
    },
  );
  test(
    'Unverified STT uses the native offline bridge without an online flag',
    () async {
      stt = 'unknown';
      expect(await voice.listen('en-US'), 'resume');
      final request = calls.singleWhere((c) => c.method == 'listen');
      expect(request.arguments, {'language': 'en-US'});
    },
  );
  test('Stop during preparation prevents stale speech from starting', () async {
    final pending = Completer<Map<String, Object>>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(OfflineVoice.channel, (call) async {
          calls.add(call);
          if (call.method == 'capabilities') return pending.future;
          return null;
        });
    final speaking = voice.speak('Never play this stale text', 'en-US');
    await voice.stop();
    pending.complete({
      'sdk': 35,
      'abis': ['arm64-v8a'],
      'tts': true,
      'stt': 'available',
    });
    expect(await speaking, isFalse);
    expect(calls.any((c) => c.method == 'speak'), isFalse);
  });
}
