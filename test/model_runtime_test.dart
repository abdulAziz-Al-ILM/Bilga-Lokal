import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:bilga/features/agent/voice/model_runtime.dart';
import 'package:bilga/features/agent/voice/model_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'voice_model_store_test.dart' as fixtures;

void main() {
  test('STT worker does not transfer caller ports or microphone completers', () async {
    final port = RawReceivePort();
    final recording = Completer<void>();
    final root = await Directory.systemTemp.createTemp('bilga-worker-test-');
    try {
      // Fail native binding deliberately, before opening any model. This proves
      // the worker actually started and returned its own error; sending caller
      // session state would instead fail with "Illegal argument in isolate message".
      final result = recognizeModelInBackground(
        VoiceModel(fixtures.modelJson()),
        root.path,
        Float32List(1600),
        libraryPath: '${root.path}/missing-native-library',
      );
      port.handler = (_) => recording.complete();
      await expectLater(
        result,
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.toString(),
            'native load error',
            allOf(
              contains('Failed to load dynamic library'),
              isNot(contains('Illegal argument in isolate message')),
            ),
          ),
        ),
      );
      port.sendPort.send(null);
      await recording.future;
    } finally {
      port.close();
      await root.delete(recursive: true);
    }
  });
}
