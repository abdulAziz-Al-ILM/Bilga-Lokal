// Opt-in native regression: installed signed public model + fake microphone.
// No personal recordings or network requests; default suite stays self-contained.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:bilga/features/agent/voice/model_store.dart';
import 'package:bilga/features/agent/voice/offline_voice.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:record/record.dart';

class _Microphone extends RecordPlatform {
  bool disposed = false;
  @override
  Future<void> create(String recorderId) async {}
  @override
  Future<bool> hasPermission(String recorderId, {bool request = true}) async =>
      true;
  @override
  Stream<RecordState> onStateChanged(String recorderId) => const Stream.empty();
  @override
  Future<Stream<Uint8List>> startStream(
    String recorderId,
    RecordConfig config,
  ) async {
    expect(config.encoder, AudioEncoder.pcm16bits);
    expect(config.sampleRate, 16000);
    expect(config.numChannels, 1);
    // A bounded local signal activates the microphone path; silence is flushed
    // by the real decoder. The assertion is startup/decoding, not word accuracy.
    final pcm = Uint8List(16000);
    final data = ByteData.sublistView(pcm);
    for (var i = 0; i < pcm.length; i += 2) {
      data.setInt16(i, i % 64 < 32 ? 1000 : -1000, Endian.little);
    }
    return Stream.fromFuture(
      Future.delayed(const Duration(milliseconds: 100), () => pcm),
    );
  }

  @override
  Future<String?> stop(String recorderId) async => null;
  @override
  Future<void> dispose(String recorderId) async {
    disposed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Installed Uzbek STT records and decodes in the actual worker isolate',
    () async {
      final root = await Directory.systemTemp.createTemp('bilga-local-listen-');
      final assets = Directory('.buildlog/voice-release/publish/assets');
      final requests = <String>[];
      final store = VoiceModelStore(
        root,
        clientFactory: () => MockClient((request) async {
          requests.add(request.url.pathSegments.last);
          return http.Response.bytes(
            await File('${assets.path}/${request.url.pathSegments.last}')
                .readAsBytes(),
            200,
          );
        }),
      );
      final microphone = _Microphone();
      final original = RecordPlatform.instance;
      RecordPlatform.instance = microphone;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(OfflineVoice.channel, (call) async {
            if (call.method == 'capabilities') {
              return {
                'sdk': 31,
                'abis': ['arm64-v8a'],
                'stt': 'unavailable',
                'tts': false,
              };
            }
            fail(
              'Downloaded Uzbek model must not call the system speech recognizer',
            );
          });
      try {
        await store.refresh();
        await store.install(
          store.catalog!.models.single,
          sdk: 31,
          abis: ['arm64-v8a'],
        );
        final requestCount = requests.length;
        final voice = OfflineVoice(store);
        expect((await voice.capabilities('uz-UZ')).stt, 'model');
        expect(await voice.listen('uz-UZ'), isA<String>());
        expect(microphone.disposed, isTrue);
        expect(
          requests.length,
          requestCount,
          reason: 'No HTTP during recognition',
        );
      } finally {
        RecordPlatform.instance = original;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(OfflineVoice.channel, null);
        store.dispose();
        await root.delete(recursive: true);
      }
    },
    skip: !const bool.fromEnvironment('BILGA_VOICE_LOCAL_TEST'),
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
