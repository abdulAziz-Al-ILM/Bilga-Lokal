// Derive only the public key. The private seed never enters the app or output.
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

Future<void> main(List<String> args) async {
  if (args.length != 2) {
    throw ArgumentError(
      'Usage: dart run tool/voice_catalog_public_key.dart external-seed public-key-output',
    );
  }
  final seed = base64Decode((await File(args[0]).readAsString()).trim());
  if (seed.length != 32) throw const FormatException('Expected 32-byte seed');
  final key = await Ed25519().newKeyPairFromSeed(seed);
  final public = base64Encode((await key.extractPublicKey()).bytes);
  await File(args[1]).writeAsString('$public\n', flush: true);
  stdout.writeln('Ed25519 public key: $public');
}
