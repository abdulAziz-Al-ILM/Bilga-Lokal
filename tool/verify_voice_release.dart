// Local release audit using the very same signature/policy parser as the app.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:bilga/features/agent/voice/model_catalog.dart';

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    throw ArgumentError(
      'Usage: dart run tool/verify_voice_release.dart asset-directory',
    );
  }
  const source = ModelSource();
  final bytes = await File(p.join(args[0], 'catalog.signed.json'))
      .readAsBytes();
  final catalog = await ModelCatalog.verify(bytes, source.publicKey);
  final envelope = jsonDecode(utf8.decode(bytes)) as Map;
  final payload = jsonDecode(
    utf8.decode(base64Decode(envelope['payload'] as String)),
  ) as Map;
  final entries = [
    for (final model in catalog.models) ...model.files,
    for (final item in payload['artifacts'] as List? ?? [])
      Map<String, dynamic>.from(item as Map),
  ];
  for (final entry in entries) {
    final asset = entry['asset'] as String;
    // Apply the source asset allowlist before accessing local paths.
    source.asset(asset);
    final file = File(p.join(args[0], asset));
    if (await file.length() != entry['bytes'] ||
        (await sha256.bind(file.openRead()).first).toString() !=
            entry['sha256']) {
      throw FormatException('Published asset verification failed: $asset');
    }
  }
  stdout.writeln(
    'PASS: pinned public key, signed catalog revision ${catalog.revision}, ${entries.length} data/archive hashes; ${source.repository}.',
  );
}
