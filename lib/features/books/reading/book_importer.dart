import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../attachments/attachment_store.dart';
import '../../private_space/record_store.dart';
import '../book_library.dart';
import 'reading_data.dart';
import 'reading_store.dart';
import 'text_document.dart';

class ImportCandidate {
  final File file;
  final String name, hash, format;
  final int size;
  final Map<String, dynamic> index;
  final int? pages;
  final Uint8List? cover;
  ImportCandidate(
    this.file,
    this.name,
    this.hash,
    this.format,
    this.size,
    this.index, {
    this.pages,
    this.cover,
  });
  Future<void> close() async {
    if (await file.parent.exists()) await file.parent.delete(recursive: true);
  }
}

class BookImporter {
  final ReadingStore store;
  BookImporter(this.store);
  static Future<List<Map<String, dynamic>>> pick() async =>
      (await Attachments.bridge.invokeListMethod('pickBook') ?? [])
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList();
  Future<Directory> previewDirectory() async => Directory(
    '${(store.previewRoot ?? await getTemporaryDirectory()).path}/private-preview/books',
  ).create(recursive: true);
  Future<ImportCandidate> prepare(
    Stream<List<int>> stream,
    String filename,
  ) async {
    final dir = await (await previewDirectory()).createTemp('import-');
    final file = File('${dir.path}/source');
    final sink = file.openWrite();
    var count = 0;
    try {
      await for (final b in stream) {
        count += b.length;
        if (count > Attachments.maxFile) {
          throw const FormatException('book_large');
        }
        sink.add(b);
      }
      await sink.flush();
      await sink.close();
      if (count < 1) throw const FormatException('book_empty');
      final hash = (await sha256.bind(file.openRead()).first).toString();
      final prefix = await file
          .openRead(0, count.clamp(0, 2048))
          .fold<List<int>>([], (a, b) => a..addAll(b));
      final asciiPrefix = latin1.decode(prefix);
      String format;
      if (asciiPrefix.contains('%PDF-')) {
        format = 'pdf';
      } else if (prefix.length >= 4 && prefix[0] == 0x50 && prefix[1] == 0x4b) {
        format = 'epub';
      } else if (asciiPrefix.contains('FictionBook')) {
        format = 'fb2';
      } else if (RegExp(
        r'<(?:!doctype\s+html|html|head|body)[\s>]',
        caseSensitive: false,
      ).hasMatch(asciiPrefix)) {
        format = 'html';
      } else if ({
        'txt',
        'text',
      }.contains(p.extension(filename).replaceFirst('.', '').toLowerCase())) {
        format = 'txt';
      } else {
        throw const FormatException('book_unsupported');
      }
      Map<String, dynamic> index = {'v': 1, 'format': format};
      int? pages;
      Uint8List? cover;
      if (format == 'pdf') {
        await pdfrxFlutterInitialize();
        final doc = await PdfDocument.openFile(
          file.path,
          passwordProvider: () => null,
        );
        try {
          if (doc.isEncrypted) throw const FormatException('book_encrypted');
          pages = doc.pages.length;
          if (pages < 1 || pages > 1000000) {
            throw const FormatException('book_pdf');
          }
          final page = doc.pages.first;
          final rendered = await page.render(
            fullWidth: 320,
            fullHeight: (320 * page.height / page.width).clamp(1, 1200),
          );
          if (rendered != null) {
            try {
              final image = await rendered.createImage();
              try {
                cover = (await image.toByteData(format: ui.ImageByteFormat.png))
                    ?.buffer
                    .asUint8List();
              } finally {
                image.dispose();
              }
            } finally {
              rendered.dispose();
            }
          }
        } finally {
          await doc.dispose();
        }
      } else {
        index = await TextDocument.inspect(file.path, format);
        cover = index.remove('cover') as Uint8List?;
      }
      final name = p
          .basename(filename)
          .replaceAll(RegExp(r'[\x00-\x1f]'), '')
          .trim();
      return ImportCandidate(
        file,
        name.isEmpty
            ? 'Book.$format'
            : name.substring(0, name.length.clamp(0, 200)),
        hash,
        format,
        count,
        index,
        pages: pages,
        cover: cover,
      );
    } catch (_) {
      await sink.close();
      if (await dir.exists()) await dir.delete(recursive: true);
      rethrow;
    }
  }

  Future<PrivateRecord> commit(
    ImportCandidate c, {
    String? referenceUri,
    ReadingRow? replacing,
    required bool Function() allowed,
  }) async {
    if (!allowed()) throw StateError('access_expired');
    if (replacing != null &&
        (replacing.kind != 'source' ||
            replacing.data['hash'] != c.hash ||
            replacing.data['format'] != c.format)) {
      throw const FormatException('book_changed');
    }
    final existing = replacing == null
        ? null
        : await store.records.get(replacing.book);
    final attachments = <Map<String, dynamic>>[];
    Future<String> blob(
      Stream<List<int>> bytes,
      String role,
      String mime, {
      String? expected,
      int? size,
    }) async {
      final value = await store.vault.write(
        bytes,
        expected: expected,
        size: size,
      );
      attachments.add({
        'title': c.name,
        'ownerKind': 'book',
        'blob': value.$1,
        'size': value.$2,
        'mime': mime,
        'role': role,
      });
      return value.$1;
    }

    if (referenceUri == null) {
      await blob(
        c.file.openRead(),
        'bookSource',
        c.format == 'pdf'
            ? 'application/pdf'
            : c.format == 'epub'
            ? 'application/epub+zip'
            : 'text/plain',
        expected: c.hash,
        size: c.size,
      );
    } else {
      await Attachments.bridge.invokeMethod<void>('persistRead', {
        'uri': referenceUri,
      });
    }
    String? cover, indexBlob;
    if (c.cover != null) {
      cover = await blob(
        Stream.value(c.cover!),
        'bookCover',
        c.cover!.length > 2 && c.cover![0] == 0xff && c.cover![1] == 0xd8
            ? 'image/jpeg'
            : 'image/png',
      );
    }
    if (c.format != 'pdf') {
      final indexBytes = utf8.encode(jsonEncode(c.index));
      if (indexBytes.length > 2 * 1024 * 1024) {
        throw const FormatException('book_large');
      }
      indexBlob = await blob(
        Stream.value(indexBytes),
        'bookIndex',
        'application/json',
      );
    }
    final source = {
      'v': 1,
      'format': c.format,
      'hash': c.hash,
      'size': c.size,
      'filename': c.name,
      'mode': referenceUri == null ? 'managed' : 'reference',
      if (referenceUri == null) 'blob': c.hash,
      'uri': ?referenceUri,
      if (c.pages != null) 'pages': c.pages,
      'cover': ?cover,
      'index': ?indexBlob,
    };
    ReadingData.validate('source', source);
    String bounded(String value, int limit) =>
        value.trim().substring(0, value.trim().length.clamp(0, limit));
    final title = bounded('${c.index['title'] ?? ''}', 200);
    final data = BookLibrary.update(
      {
        'title': title.isEmpty ? p.basenameWithoutExtension(c.name) : title,
        'chapters': <dynamic>[],
        'characters': '',
      },
      {
        'author': bounded('${c.index['author'] ?? ''}', 1000),
        'language': bounded('${c.index['language'] ?? ''}', 200),
        'publisher': bounded('${c.index['publisher'] ?? ''}', 200),
        'pages': c.pages,
        'status': 'planned',
      },
    );
    if ((data['title'] as String).trim().isEmpty) data['title'] = c.name;
    RecordStore.validate('book', data);
    final id = existing?.id ?? localId(),
        stamp = DateTime.now().toUtc().toIso8601String();
    if (!allowed()) throw StateError('access_expired');
    await (await store.db).transaction((txn) async {
      if (existing == null) {
        await txn.insert('private_records', {
          'id': id,
          'kind': 'book',
          'payload': jsonEncode(data),
          'revision': 1,
          'created_at': stamp,
          'updated_at': stamp,
        });
      }
      if (replacing != null) {
        if (await txn.update(
              'book_reading',
              {
                'payload': jsonEncode(source),
                'revision': replacing.revision + 1,
                'updated_at': stamp,
              },
              where: 'id=? AND book_id=? AND revision=?',
              whereArgs: [replacing.id, id, replacing.revision],
            ) !=
            1) {
          throw StateError('reading_changed');
        }
        await txn.delete(
          'private_records',
          where: "kind='attachment' AND json_extract(payload,'\$.ownerKind')='book' AND json_extract(payload,'\$.owner')=? AND json_extract(payload,'\$.role') IN ('bookSource','bookCover','bookIndex')",
          whereArgs: [id],
        );
      }
      for (final a in attachments) {
        a['owner'] = id;
        RecordStore.validate('attachment', a);
        await txn.insert('private_records', {
          'id': localId(),
          'kind': 'attachment',
          'payload': jsonEncode(a),
          'revision': 1,
          'created_at': stamp,
          'updated_at': stamp,
        });
      }
      if (replacing == null) {
        await txn.insert('book_reading', {
          'id': '$id-source',
          'book_id': id,
          'kind': 'source',
          'payload': jsonEncode(source),
          'revision': 1,
          'created_at': stamp,
          'updated_at': stamp,
        });
      }
    });
    return existing ?? PrivateRecord(id, 'book', 1, data);
  }

  Future<File> materialize(ReadingRow source) async {
    final dir = await (await previewDirectory()).createTemp('read-');
    final file = File('${dir.path}/source.${source.data['format']}');
    try {
      final stream = source.data['mode'] == 'managed'
          ? store.vault.read(source.data['hash'])
          : Attachments.uriStream(source.data['uri']);
      final out = file.openWrite();
      var count = 0;
      try {
        await for (final b in stream) {
          count += b.length;
          if (count > Attachments.maxFile) {
            throw const FormatException('book_large');
          }
          out.add(b);
        }
        await out.flush();
      } finally {
        await out.close();
      }
      if (count != source.data['size'] ||
          (await sha256.bind(file.openRead()).first).toString() !=
              source.data['hash']) {
        throw const FormatException('book_changed');
      }
      return file;
    } catch (_) {
      await dir.delete(recursive: true);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> index(ReadingRow source, File file) async {
    if (source.data['index'] is String) {
      final bytes = <int>[];
      await for (final b in store.vault.read(source.data['index'])) {
        if (bytes.length + b.length > 2 * 1024 * 1024) {
          throw const FormatException('book_index');
        }
        bytes.addAll(b);
      }
      final parsed = Map<String, dynamic>.from(jsonDecode(utf8.decode(bytes)));
      if (parsed['v'] != 1 ||
          parsed['format'] != source.data['format'] ||
          parsed['sections'] is! List) {
        throw const FormatException('book_index');
      }
      return parsed;
    }
    return TextDocument.inspect(file.path, source.data['format']);
  }
}
