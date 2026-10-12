// Explicit opt-in release acceptance; never part of the default offline suite.
// Uses the app's real downloader and pinned key with a disposable private folder.
import 'dart:io';

import 'package:bilga/features/agent/voice/model_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Published Uzbek preview installs with actual signature and file hashes',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'bilga-public-release-',
      );
      final store = VoiceModelStore(root);
      try {
        await store.refresh();
        final model = store.catalog!.models.single;
        expect(model.languages, ['uz']);
        expect(model.preview, isTrue);
        expect(model.engine, 'streaming_transducer');
        await store.install(model, sdk: 31, abis: ['arm64-v8a']);
        expect(await store.verifyInstalled(model), isTrue);
        final reopened = VoiceModelStore(root);
        await reopened
            .loadCached(); // Signed local provenance, no network request.
        expect(
          await reopened.find('uz-UZ', 'stt', 31, ['arm64-v8a']),
          isNotNull,
        );
        expect(await reopened.find('uz-UZ', 'tts', 31, ['arm64-v8a']), isNull);
        expect(await reopened.storageBytes(), greaterThan(94000000));
        reopened.dispose();
      } finally {
        store.dispose();
        await root.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 8)),
    skip: !const bool.fromEnvironment('BILGA_VOICE_LIVE_TEST'),
  );
}
