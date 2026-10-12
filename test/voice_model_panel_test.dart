import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bilga/core/settings.dart';
import 'package:bilga/features/agent/voice/model_panel.dart';
import 'package:bilga/features/agent/voice/offline_voice.dart';
import 'package:bilga/features/agent/voice/model_store.dart';
import 'package:cryptography/cryptography.dart' as signing;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'voice_model_store_test.dart' as fixtures;

// Real filesystem/crypto operations must use the real event loop, while Flutter
// animation frames use the widget test's fake clock. No download logic is mocked.
class IoVoice extends OfflineVoice {
  final Zone ioZone;
  IoVoice(super.store, this.ioZone);
  @override
  Future<List<String>> downloadMissingModels(String language) {
    final result = Completer<List<String>>();
    ioZone.run(() async {
      try {
        result.complete(await super.downloadMissingModels(language));
      } catch (error, stack) {
        // Marshal failures back to the fake-clock error zone as well.
        result.completeError(error, stack);
      }
    });
    return result.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late Zone ioZone;
  late ModelSource source;
  late List<int> envelope;
  late Map<String, dynamic> model;
  final requests = <http.Request>[];
  final calls = <String>[];
  setUp(() async {
    ioZone = Zone.current;
    AppSettings.instance.language = 'uz';
    root = await Directory.systemTemp.createTemp('bilga-model-panel');
    final key = await signing.Ed25519().newKeyPair();
    source = ModelSource(
      repository: 'owner/models',
      publicKey: base64Encode((await key.extractPublicKey()).bytes),
    );
    model = fixtures.modelJson()
      ..['languages'] = ['uz']
      ..['engine'] = 'streaming_transducer'
      ..['preview'] = true;
    (model['files'] as List).add(<String, Object>{
      ...Map<String, Object>.from((model['files'] as List).first as Map),
      'path': 'joiner.onnx',
      'asset': 'joiner.onnx',
    });
    (model['config'] as Map)['joiner'] = 'joiner.onnx';
    final payload = utf8.encode(
      jsonEncode({
        'schema': 1,
        'revision': 1,
        'expires': '2099-01-01T00:00:00Z',
        'models': [model],
      }),
    );
    envelope = utf8.encode(
      jsonEncode({
        'payload': base64Encode(payload),
        'signature': base64Encode(
          (await signing.Ed25519().sign(payload, keyPair: key)).bytes,
        ),
      }),
    );
    requests.clear();
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(OfflineVoice.channel, (call) async {
          calls.add(call.method);
          if (call.method == 'capabilities') {
            return {
              'sdk': 31,
              'abis': ['arm64-v8a'],
              'stt': 'unavailable',
              'tts': false,
            };
          }
          return null;
        });
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(OfflineVoice.channel, null);
    await root.delete(recursive: true);
  });
  VoiceModelStore makeStore({bool configured = true}) => VoiceModelStore(
    root,
    source: configured
        ? source
        : const ModelSource(repository: '', publicKey: ''),
    clientFactory: () => MockClient((request) async {
      requests.add(request);
      return http.Response.bytes(
        request.url.path.endsWith('catalog.signed.json') ? envelope : [1, 2, 3],
        200,
      );
    }),
  );
  Future<void> settle(WidgetTester tester) async {
    // Let real I/O and fake timers progress until the UI actually finishes.
    for (var i = 0; i < 1000; i++) {
      await tester.pump(const Duration(milliseconds: 10));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      if (i >= 40 &&
          find.byType(LinearProgressIndicator).evaluate().isEmpty &&
          find.textContaining('STT: …').evaluate().isEmpty) {
        break;
      }
    }
    expect(
      find.byType(LinearProgressIndicator),
      findsNothing,
      reason: 'Pending UI. GETs=${requests.map((r) => r.url.path).join(", ")}',
    );
    await tester.pumpAndSettle();
  }

  Future<void> show(WidgetTester tester, VoiceModelStore store) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: VoiceModelPanel(
              voice: IoVoice(store, ioZone),
              language: 'uz-UZ',
              onChanged: () {},
            ),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  testWidgets(
    'Unconfigured build explains missing source and never downloads',
    (tester) async {
      final store = makeStore(configured: false);
      await show(tester, store);
      expect(find.textContaining('ilova yangilanishi kerak'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Yuklab olish'),
            )
            .onPressed,
        isNull,
      );
      expect(find.textContaining('katalogda model yo‘q'), findsNothing);
      expect(requests, isEmpty);
    },
  );
  testWidgets(
    'Download is offered before catalog loading; cancelling sends no GET',
    (tester) async {
      await show(tester, makeStore());
      await tester.tap(find.widgetWithText(FilledButton, 'Yuklab olish'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bekor qilish'));
      await tester.pumpAndSettle();
      expect(requests, isEmpty);
    },
  );
  testWidgets(
    'Consent installs signed STT privately; unavailable TTS stays unavailable',
    (tester) async {
      final store = makeStore();
      await show(tester, store);
      await tester.tap(find.widgetWithText(FilledButton, 'Yuklab olish'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Yuklab olish').last);
      await settle(tester);
      expect(
        find.textContaining('tekshiruvdan o‘tmadi'),
        findsNothing,
        reason: 'GETs: ${requests.map((r) => r.url.path).join(", ")}',
      );
      expect(
        await tester.runAsync(
          () => store.verifyInstalled(store.catalog!.models.single),
        ),
        isTrue,
      );
      expect(
        await tester.runAsync(
          () => store.find('uz-UZ', 'tts', 31, ['arm64-v8a']),
        ),
        isNull,
      );
      expect(find.textContaining('TTS: bu til va qurilma'), findsOneWidget);
      expect(find.textContaining('Sinov modeli:'), findsOneWidget);
      expect(requests.length, 5);
      for (final request in requests) {
        expect(request.method, 'GET');
        expect(request.bodyBytes, isEmpty);
        expect(request.url.host, 'github.com');
        expect(request.headers.keys, isNot(contains('authorization')));
      }
      final reopened = makeStore();
      await tester.runAsync(() => reopened.loadCached());
      expect(
        await tester.runAsync(
          () => reopened.find('uz-UZ', 'stt', 31, ['arm64-v8a']),
        ),
        isNotNull,
      );
      expect(
        requests.length,
        5,
      ); // Offline startup reads signed local provenance.
    },
  );
  testWidgets('Tampered catalog cannot trigger model downloads', (
    tester,
  ) async {
    final data = jsonDecode(utf8.decode(envelope)) as Map;
    data['payload'] = base64Encode(utf8.encode('{}'));
    envelope = utf8.encode(jsonEncode(data));
    final store = makeStore();
    await show(tester, store);
    await tester.tap(find.widgetWithText(FilledButton, 'Yuklab olish'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Yuklab olish').last);
    await settle(tester);
    expect(store.catalog, isNull);
    expect(requests.length, 1);
    expect(find.textContaining('tekshiruvdan o‘tmadi'), findsOneWidget);
  });
  testWidgets(
    'TTS settings do not download; returning refreshes the default engine',
    (tester) async {
      await show(tester, makeStore(configured: false));
      await tester.tap(find.text('Offline ovozni sozlash'));
      await settle(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(tester);
      expect(calls, containsAllInOrder(['ttsSettings', 'refreshTts']));
      expect(requests, isEmpty);
    },
  );
}
