import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

Uint8List u32(int n) => Uint8List(4)..buffer.asByteData().setUint32(0, n);
int read32(List<int> b) =>
    Uint8List.fromList(b).buffer.asByteData().getUint32(0);

class ByteReader {
  final StreamIterator<List<int>> iterator;
  List<int> current = [];
  int offset = 0;
  ByteReader(Stream<List<int>> stream) : iterator = StreamIterator(stream);
  Future<List<int>> read(int n) async {
    if (n < 0 || n > 32 * 1024 * 1024) throw const FormatException('length');
    final out = BytesBuilder();
    while (n > 0) {
      if (offset == current.length) {
        if (!await iterator.moveNext()) {
          throw const FormatException('truncated');
        }
        current = iterator.current;
        offset = 0;
        continue;
      }
      final end = min(current.length, offset + n);
      out.add(current.sublist(offset, end));
      n -= end - offset;
      offset = end;
    }
    return out.takeBytes();
  }

  Stream<List<int>> take(int n) async* {
    while (n > 0) {
      final k = min(n, 65536);
      yield await read(k);
      n -= k;
    }
  }

  Stream<List<int>> remaining() async* {
    if (offset < current.length) {
      yield current.sublist(offset);
      offset = current.length;
    }
    while (await iterator.moveNext()) {
      yield iterator.current;
    }
  }

  Future<bool> get ended async {
    if (offset < current.length) return false;
    while (await iterator.moveNext()) {
      if (iterator.current.isNotEmpty) return false;
    }
    return true;
  }

  Future<void> close() => iterator.cancel();
}

class ChunkVault {
  static final aes = AesGcm.with256bits();
  static Stream<List<int>> encrypt(
    Stream<List<int>> source,
    SecretKey key,
  ) async* {
    final random = Random.secure();
    final prefix = List.generate(8, (_) => random.nextInt(256));
    final header = [...ascii.encode('BILGAC02'), ...prefix];
    yield header;
    var counter = 0;
    var buf = BytesBuilder();
    Future<List<int>> seal(List<int> b) async {
      if (counter >= 0xffffffff) throw StateError('counter');
      final box = await aes.encrypt(
        b,
        secretKey: key,
        nonce: [...prefix, ...u32(counter++)],
        aad: header,
      );
      return [...u32(b.length), ...box.cipherText, ...box.mac.bytes];
    }

    await for (final chunk in source) {
      var i = 0;
      while (i < chunk.length) {
        final n = min(1048576 - buf.length, chunk.length - i);
        buf.add(chunk.sublist(i, i + n));
        i += n;
        if (buf.length == 1048576) yield await seal(buf.takeBytes());
      }
    }
    if (buf.length > 0) yield await seal(buf.takeBytes());
    yield await seal([]);
  }

  static Stream<List<int>> decrypt(
    Stream<List<int>> source,
    SecretKey key,
  ) async* {
    final reader = ByteReader(source);
    try {
      final header = await reader.read(16);
      if (ascii.decode(header.sublist(0, 8)) != 'BILGAC02') {
        throw const FormatException('header');
      }
      var counter = 0;
      while (true) {
        final n = read32(await reader.read(4));
        if (n > 1048576 || counter >= 0xffffffff) {
          throw const FormatException('frame');
        }
        final b = await reader.read(n), tag = await reader.read(16);
        final clear = await aes.decrypt(
          SecretBox(
            b,
            nonce: [...header.sublist(8), ...u32(counter++)],
            mac: Mac(tag),
          ),
          secretKey: key,
          aad: header,
        );
        if (n == 0) {
          if (!await reader.ended) throw const FormatException('trailing');
          break;
        }
        yield clear;
      }
    } finally {
      await reader.close();
    }
  }
}
