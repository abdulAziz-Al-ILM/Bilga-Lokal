// Offline release tool. Never place the Ed25519 seed in the repository.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart' as signing;
import 'package:path/path.dart' as p;

import 'package:bilga/features/agent/voice/model_catalog.dart';

Future<void> main(List<String> args) async {
  if (args.length != 4) {
    stderr.writeln(
      'Usage: dart run tool/sign_voice_catalog.dart payload.json assets-dir seed-file output.json',
    );
    exitCode = 64;
    return;
  }
  final payload =
      jsonDecode(await File(args[0]).readAsString()) as Map<String, dynamic>;
  for (final raw in payload['models'] as List) {
    final model = raw as Map<String, dynamic>;
    for (final entry in model['files'] as List) {
      final file = entry as Map<String, dynamic>;
      final asset = file['asset'] as String;
      if (!RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(asset) ||
          asset == '.' ||
          asset == '..') {
        throw const FormatException('Invalid release asset name');
      }
      final source = File(p.join(args[1], asset));
      final size = await source.length();
      final hash = (await sha256.bind(source.openRead()).first).toString();
      // A pinned upstream manifest must never silently bless replacement data.
      if ((file['bytes'] != null && file['bytes'] != size) ||
          (file['sha256'] != null && file['sha256'] != hash)) {
        throw FormatException('Pinned asset mismatch: $asset');
      }
      file['bytes'] = size;
      file['sha256'] = hash;
    }
  }
  // Optional distribution archives are signed too, but the app still downloads
  // individually hashed data files. An archive must be in the same asset folder.
  for (final raw in payload['artifacts'] as List? ?? []) {
    final artifact = raw as Map<String, dynamic>;
    final asset = artifact['asset'] as String;
    if (!RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(asset) ||
        asset == '.' ||
        asset == '..') {
      throw const FormatException('Invalid distribution asset');
    }
    final file = File(p.join(args[1], asset));
    if (await file.length() != artifact['bytes'] ||
        (await sha256.bind(file.openRead()).first).toString() !=
            artifact['sha256']) {
      throw FormatException('Pinned distribution mismatch: $asset');
    }
  }
  // Reject unreviewed model metadata before opening the external private key.
  for (final raw in payload['models'] as List) {
    VoiceModel(raw as Map<String, dynamic>);
  }
  final seed = base64Decode((await File(args[2]).readAsString()).trim());
  if (seed.length != 32) {
    throw const FormatException('A 32-byte Ed25519 seed is required');
  }
  final algorithm = signing.Ed25519();
  final key = await algorithm.newKeyPairFromSeed(seed);
  final bytes = utf8.encode(jsonEncode(payload));
  final signature = await algorithm.sign(bytes, keyPair: key);
  final envelope = utf8.encode(
    jsonEncode({
      'payload': base64Encode(bytes),
      'signature': base64Encode(signature.bytes),
    }),
  );
  final publicKey = base64Encode((await key.extractPublicKey()).bytes);
  // Apply the same license, format, path, expiry and Android gates as the app.
  await ModelCatalog.verify(envelope, publicKey);
  await File(args[3]).writeAsBytes(envelope, flush: true);
  stdout.writeln(
    'Catalog signed. Public key (BILGA_VOICE_CATALOG_KEY): $publicKey',
  );
}
