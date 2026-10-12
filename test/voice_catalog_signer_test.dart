import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/sign_voice_catalog.dart' as signer;
import 'voice_model_store_test.dart' as fixtures;

void main() {
  late Directory root;
  late Map<String, dynamic> model;
  List<Map<String, dynamic>> artifacts = [];
  setUp(() async {
    root = await Directory.systemTemp.createTemp('bilga-signer');
    model = fixtures.modelJson();
    artifacts = [];
    for (final f in model['files'] as List) {
      await File('${root.path}/${f["asset"]}').writeAsBytes([1, 2, 3]);
    }
    // Ephemeral test seed only; no production key is read or created.
    await File('${root.path}/test-seed')
        .writeAsString(base64Encode(List.filled(32, 17)));
  });
  tearDown(() => root.delete(recursive: true));
  Future<void> sign() async {
    await File('${root.path}/draft.json').writeAsString(
      jsonEncode({
        'schema': 1,
        'revision': 1,
        'expires': '2099-01-01T00:00:00Z',
        'models': [model],
        'artifacts': artifacts,
      }),
    );
    await signer.main([
      '${root.path}/draft.json',
      root.path,
      '${root.path}/test-seed',
      '${root.path}/catalog.signed.json',
    ]);
  }

  test('Release signing rejects changed pinned bytes', () async {
    await File('${root.path}/encoder.onnx').writeAsBytes([3, 2, 1]);
    await expectLater(sign(), throwsFormatException);
    expect(await File('${root.path}/catalog.signed.json').exists(), isFalse);
  });
  test('Release signing rejects Android-unreviewed draft', () async {
    model['androidReviewed'] = false;
    await expectLater(sign(), throwsFormatException);
    expect(await File('${root.path}/catalog.signed.json').exists(), isFalse);
  });
  test('Release signing rejects tampered distribution archive', () async {
    await File('${root.path}/model.zip').writeAsBytes([9, 9, 9]);
    artifacts = [
      {
        ...Map<String, dynamic>.from((model['files'] as List).first as Map),
        'asset': 'model.zip',
      },
    ];
    await expectLater(sign(), throwsFormatException);
    expect(await File('${root.path}/catalog.signed.json').exists(), isFalse);
  });
}
