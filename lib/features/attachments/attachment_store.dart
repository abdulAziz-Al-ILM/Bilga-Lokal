import 'dart:io';

import 'package:crypto/crypto.dart' as hash;
import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/chunk_vault.dart';
import '../../core/private_database.dart';
import '../private_space/record_store.dart';

class _Digest implements Sink<hash.Digest> {
  String? value;
  @override
  void add(hash.Digest d) {
    value = d.toString();
  }

  @override
  void close() {}
}

class Attachments {
  static const bridge = MethodChannel('bilga/files');
  static const maxFile = 1024 * 1024 * 1024;
  static Future<SecretKey> key() async {
    final s = await PrivateDatabase.key();
    return SecretKey([
      for (var i = 0; i < s.length; i += 2)
        int.parse(s.substring(i, i + 2), radix: 16),
    ]);
  }

  static Future<Directory> directory() async =>
      Directory('${(await getApplicationSupportDirectory()).path}/vault-media')
          .create(recursive: true);
  static Future<File> file(String id) async {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(id)) {
      throw const FormatException('blob');
    }
    return File('${(await directory()).path}/$id.bvault');
  }

  static Stream<List<int>> read(String id) async* {
    yield* ChunkVault.decrypt((await file(id)).openRead(), await key());
  }

  static Future<(String, int)> write(
    Stream<List<int>> stream, {
    String? expected,
    int? size,
  }) async {
    final tmp = File('${(await directory()).path}/${localId()}.part');
    final digest = _Digest(), sink = tmp.openWrite();
    final hasher = hash.sha256.startChunkedConversion(digest);
    var count = 0;
    Stream<List<int>> checked() async* {
      await for (final b in stream) {
        count += b.length;
        if (count > maxFile) throw const FormatException('file_large');
        hasher.add(b);
        yield b;
      }
      hasher.close();
    }

    try {
      await sink.addStream(ChunkVault.encrypt(checked(), await key()));
      await sink.flush();
      await sink.close();
      final id = digest.value!;
      if ((expected != null && expected != id) ||
          (size != null && size != count)) {
        throw const FormatException('file_hash');
      }
      await tmp.rename((await file(id)).path);
      return (id, count);
    } finally {
      await sink.close();
      if (await tmp.exists()) await tmp.delete();
    }
  }

  static Stream<List<int>> uriStream(String uri) async* {
    final token = await bridge.invokeMethod<String>('openRead', {'uri': uri});
    try {
      while (true) {
        final b = await bridge.invokeMethod<Uint8List>('read', {
          'token': token,
        });
        if (b == null || b.isEmpty) break;
        yield b;
      }
    } finally {
      await bridge.invokeMethod<void>('close', {'token': token});
    }
  }

  static Future<void> writeUri(String uri, Stream<List<int>> data) async {
    final t = await bridge.invokeMethod<String>('openWrite', {'uri': uri});
    try {
      await for (final b in data) {
        for (var i = 0; i < b.length; i += 65536) {
          await bridge.invokeMethod<void>('write', {
            'token': t,
            'bytes': Uint8List.fromList(
              b.sublist(i, (i + 65536).clamp(0, b.length)),
            ),
          });
        }
      }
    } finally {
      await bridge.invokeMethod<void>('close', {'token': t});
    }
  }

  static Future<List<Map<String, dynamic>>> pick() async =>
      (await bridge.invokeListMethod('pick') ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
  static Future<List<PrivateRecord>> all(String kind, String owner) async =>
      (await RecordStore().all('attachment'))
          .where((r) => r.data['ownerKind'] == kind && r.data['owner'] == owner)
          .toList();
  static Future<void> add(
    String kind,
    String owner,
    Map<String, dynamic> item,
  ) async {
    if ((item['size'] ?? 0) > maxFile) {
      throw const FormatException('file_large');
    }
    final f = await write(uriStream(item['uri']));
    await RecordStore().save('attachment', {
      'title': '${item['name'] ?? 'File'}',
      'ownerKind': kind,
      'owner': owner,
      'blob': f.$1,
      'size': f.$2,
      'mime': item['mime'] ?? 'application/octet-stream',
    });
  }

  static Future<void> text(String kind, String owner, String text) async {
    if (text.trim().isEmpty) return;
    await RecordStore().save('attachment', {
      'title': text.substring(0, text.length.clamp(0, 200)),
      'ownerKind': kind,
      'owner': owner,
      'text': text,
      'size': 0,
    });
  }

  static Future<void> remove(PrivateRecord r) async {
    await RecordStore().remove(r);
    final id = r.data['blob'];
    if (id is String &&
        !(await RecordStore().all('attachment'))
            .any((a) => a.data['blob'] == id)) {
      final f = await file(id);
      if (await f.exists()) await f.delete();
    }
  }

  static Future<void> export(
    String name,
    String mime,
    Stream<List<int>> bytes,
  ) async {
    final uri = await bridge.invokeMethod<String>('create', {
      'name': name,
      'mime': mime,
    });
    if (uri != null) await writeUri(uri, bytes);
  }

  static Future<void> clearPreviews() async {
    final d = Directory(
      '${(await getTemporaryDirectory()).path}/private-preview',
    );
    if (await d.exists()) await d.delete(recursive: true);
  }
}
