import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../core/chunk_vault.dart';
import '../attachments/attachment_store.dart';
import 'backup_codec.dart';
import 'backup_store.dart';

class MediaBackup {
  static Future<SecretKey> derive(String password, List<int> salt) async =>
      SecretKey(
        await Isolate.run(
          () async =>
              (await Pbkdf2(
                    macAlgorithm: Hmac.sha256(),
                    iterations: BackupCodec.rounds,
                    bits: 256,
                  ).deriveKey(
                    secretKey: SecretKey(utf8.encode(password)),
                    nonce: salt,
                  ))
                  .extractBytes(),
        ),
      );
  static Map<String, int> blobs(Map<String, dynamic> p) {
    final r = <String, int>{};
    for (final row in (p['data'] as Map)['private_records'] as List? ?? []) {
      if (row['kind'] != 'attachment') continue;
      final d = jsonDecode(row['payload']);
      if (d['blob'] == null) continue;
      final id = d['blob'] as String, size = d['size'] as int;
      if (r.containsKey(id) && r[id] != size) {
        throw const FormatException('media_manifest');
      }
      r[id] = size;
    }
    return Map.fromEntries(
      r.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }

  static Stream<List<int>> encode(
    Map<String, dynamic> p,
    String password,
  ) async* {
    if (password.runes.length < 12) {
      throw const FormatException('password_short');
    }
    BackupStore.validate(p);
    final json = utf8.encode(jsonEncode(p));
    if (json.length > 16 * 1024 * 1024) {
      throw const FormatException('backup_large');
    }
    Stream<List<int>> content() async* {
      yield u32(json.length);
      yield json;
      for (final e in blobs(p).entries) {
        yield u32(e.value);
        var count = 0;
        await for (final b in Attachments.read(e.key)) {
          count += b.length;
          yield b;
        }
        if (count != e.value) throw const FormatException('size');
      }
    }

    final salt = List.generate(16, (_) => Random.secure().nextInt(256));
    yield [...ascii.encode('BILGAB02'), ...salt];
    yield* ChunkVault.encrypt(content(), await derive(password, salt));
  }

  static Future<Map<String, dynamic>> decode(
    Stream<List<int>> source,
    String password,
  ) async {
    final outer = ByteReader(source);
    try {
      final magic = await outer.read(8);
      if (ascii.decode(magic) != 'BILGAB02') {
        final b = BytesBuilder()..add(magic);
        await for (final chunk in outer.remaining()) {
          if (b.length + chunk.length > BackupCodec.maxBytes) {
            throw const FormatException('backup_large');
          }
          b.add(chunk);
        }
        return await BackupCodec.decrypt(b.takeBytes(), password);
      }
      final salt = await outer.read(16),
          reader = ByteReader(
            ChunkVault.decrypt(outer.remaining(), await derive(password, salt)),
          );
      try {
        final n = read32(await reader.read(4));
        if (n > 16 * 1024 * 1024) throw const FormatException('backup_large');
        final p = jsonDecode(
          utf8.decode(await reader.read(n)),
        ) as Map<String, dynamic>;
        BackupStore.validate(p);
        for (final e in blobs(p).entries) {
          final size = read32(await reader.read(4));
          if (size != e.value || size > Attachments.maxFile) {
            throw const FormatException('media_size');
          }
          await Attachments.write(
            reader.take(size),
            expected: e.key,
            size: size,
          );
        }
        if (!await reader.ended) throw const FormatException('trailing');
        return p;
      } finally {
        await reader.close();
      }
    } finally {
      await outer.close();
    }
  }
}
