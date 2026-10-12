// Validates the downloaded release assets and exercises the same local runtime.
// Does not change Android review flags, sign a catalog or install into the app.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:bilga/features/agent/voice/model_runtime.dart';

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln(
      'Usage: dart run tool/smoke_uzbek_voice.dart release-directory',
    );
    exitCode = 64;
    return;
  }
  final draft = jsonDecode(
    await File(p.join(args[0], 'catalog.draft.json')).readAsString(),
  ) as Map;
  final model = (draft['models'] as List).single as Map;
  final paths = <String, String>{};
  for (final entry in model['files'] as List) {
    final file = File(p.join(args[0], 'assets', entry['asset'] as String));
    if (await file.length() != entry['bytes'] ||
        (await sha256.bind(file.openRead()).first).toString() !=
            entry['sha256']) {
      throw StateError('Asset verification rejected: ${entry["asset"]}');
    }
    paths[entry['path'] as String] = file.path;
  }
  final watch = Stopwatch()..start();
  final result = recognizeStreamingTransducer(
    encoder: paths['encoder.onnx']!,
    decoder: paths['decoder.onnx']!,
    joiner: paths['joiner.onnx']!,
    tokens: paths['tokens.txt']!,
    samples: Float32List(32000),
  );
  if (result.trim().isNotEmpty) {
    throw StateError('Silence hallucination: $result');
  }
  stdout.writeln(
    'PASS: pinned Uzbek model loaded and decoded silence locally in ${watch.elapsedMilliseconds} ms. Not an accuracy or Android qualification test.',
  );
}
