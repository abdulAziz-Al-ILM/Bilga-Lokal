import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:html/dom.dart' as html;
import 'package:html/parser.dart' as html;
import 'package:path/path.dart' as path;
import 'package:xml/xml.dart';

class BookBlock {
  final String text;
  final bool heading;
  final String? image, anchor;
  const BookBlock(this.text, {this.heading = false, this.image, this.anchor});
  Map<String, dynamic> toMap() => {
    'text': text,
    'heading': heading,
    if (image != null) 'image': image,
    if (anchor != null) 'anchor': anchor,
  };
  factory BookBlock.fromMap(Map<String, dynamic> m) => BookBlock(
    m['text'],
    heading: m['heading'] == true,
    image: m['image'],
    anchor: m['anchor'],
  );
}

class TextDocument {
  static const maxText = 16 * 1024 * 1024,
      maxArchive = 256 * 1024 * 1024,
      maxEntries = 5000;
  static String decode(List<int> b) {
    if (b.length >= 2 &&
        ((b[0] == 0xff && b[1] == 0xfe) || (b[0] == 0xfe && b[1] == 0xff))) {
      if (b.length.isOdd) throw const FormatException('book_encoding');
      final little = b[0] == 0xff, values = <int>[];
      for (var i = 2; i < b.length; i += 2) {
        values.add(little ? b[i] | b[i + 1] << 8 : b[i] << 8 | b[i + 1]);
      }
      for (var i = 0; i < values.length; i++) {
        if (values[i] >= 0xd800 && values[i] <= 0xdbff) {
          if (++i >= values.length ||
              values[i] < 0xdc00 ||
              values[i] > 0xdfff) {
            throw const FormatException('book_encoding');
          }
        } else if (values[i] >= 0xdc00 && values[i] <= 0xdfff) {
          throw const FormatException('book_encoding');
        }
      }
      return String.fromCharCodes(values);
    }
    final s = utf8.decode(b, allowMalformed: false).replaceFirst('\ufeff', '');
    if (s.contains('\u0000') ||
        s.runes.where((n) => n < 32 && !{9, 10, 12, 13}.contains(n)).length >
            2) {
      throw const FormatException('book_encoding');
    }
    return s;
  }

  static String safePath(String name) {
    final decoded = Uri.decodeComponent(name.replaceAll('\\', '/'));
    if (decoded.startsWith('/') ||
        decoded.contains('\u0000') ||
        decoded.split('/').contains('..') ||
        Uri.tryParse(decoded)?.hasScheme == true) {
      throw const FormatException('book_archive_path');
    }
    return path.posix.normalize(decoded);
  }

  static String resolve(String base, String href) {
    final raw = Uri.decodeComponent(
      href.split('#').first.replaceAll('\\', '/'),
    );
    if (raw.startsWith('/') ||
        raw.contains('\u0000') ||
        Uri.tryParse(raw)?.hasScheme == true) {
      throw const FormatException('book_archive_path');
    }
    return safePath(
      path.posix
          .normalize(path.posix.join(path.posix.dirname(base), raw))
          .replaceAll('%', '%25'),
    );
  }

  static List<BookBlock> plain(String text) {
    final out = <BookBlock>[];
    for (final paragraph
        in text
            .replaceAll('\r\n', '\n')
            .replaceAll('\r', '\n')
            .split(RegExp(r'\n\s*\n'))) {
      var s = paragraph.trim();
      while (s.length > 4000) {
        var n = s.lastIndexOf(RegExp(r'\s'), 4000);
        if (n < 1000) n = 4000;
        if (n > 0 &&
            s.codeUnitAt(n - 1) >= 0xd800 &&
            s.codeUnitAt(n - 1) <= 0xdbff) {
          n--;
        }
        out.add(BookBlock(s.substring(0, n)));
        s = s.substring(n).trimLeft();
      }
      if (s.isNotEmpty) out.add(BookBlock(s));
    }
    return out;
  }

  static List<BookBlock> markup(String text, {String base = ''}) {
    final doc = html.parse(text), out = <BookBlock>[];
    for (final e in doc.querySelectorAll(
      'script,style,iframe,object,embed,audio,video,noscript',
    )) {
      e.remove();
    }
    final buffer = StringBuffer();
    String? anchor;
    void flush({bool heading = false}) {
      final s = buffer.toString().replaceAll(RegExp(r'[ \t\r\n]+'), ' ').trim();
      buffer.clear();
      for (final b in plain(s)) {
        out.add(BookBlock(b.text, heading: heading, anchor: anchor));
        anchor = null;
      }
    }

    void visit(html.Node n) {
      if (n is html.Text) {
        buffer.write(n.text);
        return;
      }
      if (n is! html.Element) return;
      final tag = n.localName ?? '';
      final block = {
        'p',
        'div',
        'section',
        'article',
        'li',
        'blockquote',
        'h1',
        'h2',
        'h3',
        'h4',
        'h5',
        'h6',
        'pre',
        'tr',
      }.contains(tag);
      if (block || n.id.isNotEmpty) flush();
      if (n.id.isNotEmpty) {
        anchor = n.id.substring(0, n.id.length.clamp(0, 512));
      }
      if (tag == 'br') buffer.write('\n');
      if (tag == 'img') {
        flush();
        final src = n.attributes['src'] ?? '';
        if (src.isNotEmpty &&
            !src.startsWith('data:') &&
            !src.startsWith('//') &&
            Uri.tryParse(src)?.hasScheme == false) {
          out.add(
            BookBlock(
              n.attributes['alt'] ?? '',
              image: resolve(base, src),
              anchor: anchor,
            ),
          );
        }
      } else {
        for (final c in n.nodes) {
          visit(c);
        }
      }
      if (block) flush(heading: tag.startsWith('h') && tag.length == 2);
    }

    visit(doc.body ?? doc.documentElement!);
    flush();
    return out;
  }

  static Future<Map<String, dynamic>> inspect(String filename, String format) =>
      Isolate.run(() => _inspect(filename, format));
  static Map<String, dynamic> _inspect(String filename, String format) {
    if (format == 'epub') {
      final z = _Zip(filename);
      try {
        final container = XmlDocument.parse(z.text('META-INF/container.xml'));
        final root = container.descendants
            .whereType<XmlElement>()
            .firstWhere((n) => n.name.local == 'rootfile')
            .getAttribute('full-path');
        if (root == null) throw const FormatException('book_epub');
        final opf = safePath(root), pkg = XmlDocument.parse(z.text(opf));
        if (z.files.containsKey('META-INF/rights.xml') ||
            z.files.containsKey('license.lcpl')) {
          throw const FormatException('book_drm');
        }
        if (z.files.containsKey('META-INF/encryption.xml')) {
          final encrypted = XmlDocument.parse(
            z.text('META-INF/encryption.xml'),
          );
          for (final n in encrypted.descendants.whereType<XmlElement>().where(
            (n) => n.name.local == 'EncryptionMethod',
          )) {
            if (!{
              'http://www.idpf.org/2008/embedding',
              'http://ns.adobe.com/pdf/enc#RC',
            }.contains(n.getAttribute('Algorithm'))) {
              throw const FormatException('book_drm');
            }
          }
        }
        final items = <String, XmlElement>{
          for (final n in pkg.descendants.whereType<XmlElement>().where(
            (n) => n.name.local == 'item',
          ))
            n.getAttribute('id') ?? '': n,
        };
        final sections = <Map<String, dynamic>>[];
        var total = 0;
        for (final n in pkg.descendants.whereType<XmlElement>().where(
          (n) => n.name.local == 'itemref' && n.getAttribute('linear') != 'no',
        )) {
          final item = items[n.getAttribute('idref')];
          if (item == null ||
              !{
                'application/xhtml+xml',
                'text/html',
              }.contains(item.getAttribute('media-type'))) {
            throw const FormatException('book_epub_content');
          }
          final key = resolve(opf, item.getAttribute('href') ?? '');
          final text = z.text(key), blocks = markup(text, base: key);
          final chars = blocks.fold<int>(0, (sum, b) => sum + b.text.length);
          final title =
              html.parse(text).querySelector('h1,h2,title')?.text.trim() ?? '';
          sections.add({
            'key': key,
            'title': title.isEmpty
                ? '${sections.length + 1}'
                : title.substring(0, title.length.clamp(0, 200)),
            'chars': chars,
            'blocks': blocks.length,
            'anchors': {
              for (var i = 0; i < blocks.length && i < 20000; i++)
                if (blocks[i].anchor != null) blocks[i].anchor!: i,
            },
          });
          total += chars;
          if (sections.length > 2000) throw const FormatException('book_large');
        }
        if (sections.isEmpty) throw const FormatException('book_epub');
        String meta(String name) =>
            pkg.descendants
                .whereType<XmlElement>()
                .where((n) => n.name.local == name)
                .firstOrNull
                ?.innerText
                .trim() ??
            '';
        String? cover;
        for (final item in items.values) {
          if ((item.getAttribute('properties') ?? '')
              .split(' ')
              .contains('cover-image')) {
            cover = resolve(opf, item.getAttribute('href') ?? '');
          }
        }
        final coverId = pkg.descendants
            .whereType<XmlElement>()
            .where(
              (n) =>
                  n.name.local == 'meta' && n.getAttribute('name') == 'cover',
            )
            .firstOrNull
            ?.getAttribute('content');
        if (cover == null && items[coverId] != null) {
          cover = resolve(opf, items[coverId]!.getAttribute('href') ?? '');
        }
        final toc = <Map<String, dynamic>>[];
        void destination(String base, String href, String title) {
          if (toc.length >= 2000 ||
              title.trim().isEmpty ||
              href.startsWith('//') ||
              Uri.tryParse(href)?.hasScheme == true) {
            return;
          }
          final key = resolve(base, href);
          final section = sections.where((s) => s['key'] == key).firstOrNull;
          if (section == null) return;
          final fragment = href.contains('#')
              ? Uri.decodeComponent(href.substring(href.indexOf('#') + 1))
              : '';
          toc.add({
            'title': title.trim().substring(
              0,
              title.trim().length.clamp(0, 200),
            ),
            'key': key,
            'block': (section['anchors'] as Map)[fragment] ?? 0,
          });
        }

        final nav = items.values
            .where(
              (n) => (n.getAttribute('properties') ?? '')
                  .split(' ')
                  .contains('nav'),
            )
            .firstOrNull;
        if (nav != null) {
          final key = resolve(opf, nav.getAttribute('href') ?? '');
          final doc = html.parse(z.text(key));
          final nodes = doc.querySelectorAll('nav');
          final root =
              nodes
                  .where(
                    (n) =>
                        n.attributes['epub:type'] == 'toc' ||
                        n.attributes['role'] == 'doc-toc',
                  )
                  .firstOrNull ??
              nodes.firstOrNull;
          for (final a
              in root?.querySelectorAll('a[href]') ?? <html.Element>[]) {
            destination(key, a.attributes['href']!, a.text);
          }
        }
        if (toc.isEmpty) {
          final ncx = items.values
              .where(
                (n) =>
                    n.getAttribute('media-type') == 'application/x-dtbncx+xml',
              )
              .firstOrNull;
          if (ncx != null) {
            final key = resolve(opf, ncx.getAttribute('href') ?? '');
            final doc = XmlDocument.parse(z.text(key));
            for (final point in doc.descendants.whereType<XmlElement>().where(
              (n) => n.name.local == 'navPoint',
            )) {
              final label =
                  point.childElements
                      .where((n) => n.name.local == 'navLabel')
                      .firstOrNull
                      ?.innerText ??
                  '';
              final src = point.childElements
                  .where((n) => n.name.local == 'content')
                  .firstOrNull
                  ?.getAttribute('src');
              if (src != null) destination(key, src, label);
            }
          }
        }
        return {
          'v': 1,
          'format': format,
          'title': meta('title'),
          'author': meta('creator'),
          'language': meta('language'),
          'publisher': meta('publisher'),
          'sections': sections,
          'toc': toc,
          'chars': total,
          if (cover != null &&
              z.files.containsKey(cover) &&
              z.files[cover]!.size < 4 * 1024 * 1024)
            'cover': z.bytes(cover),
          'limitations': 'Reflowed text and local images; scripts, embedded media and publisher CSS are not executed.',
        };
      } finally {
        z.close();
      }
    }
    final f = File(filename);
    if (f.lengthSync() > maxText) {
      throw const FormatException('book_large_text');
    }
    final text = decode(f.readAsBytesSync());
    List<BookBlock> blocks;
    String title = '', author = '';
    if (format == 'fb2') {
      final xml = XmlDocument.parse(text);
      if (xml.rootElement.name.local != 'FictionBook') {
        throw const FormatException('book_format');
      }
      title =
          xml.descendants
              .whereType<XmlElement>()
              .where((n) => n.name.local == 'book-title')
              .firstOrNull
              ?.innerText ??
          '';
      author =
          xml.descendants
              .whereType<XmlElement>()
              .where((n) => n.name.local == 'author')
              .firstOrNull
              ?.innerText ??
          '';
      blocks = [
        for (final n in xml.descendants.whereType<XmlElement>().where(
          (n) => {'p', 'subtitle'}.contains(n.name.local),
        ))
          ...plain(n.innerText),
      ];
    } else {
      blocks = format == 'html' ? markup(text) : plain(text);
    }
    if (blocks.isEmpty) throw const FormatException('book_empty');
    return {
      'v': 1,
      'format': format,
      'title': title,
      'author': author,
      'sections': [
        {
          'key': 'text',
          'title': title,
          'chars': blocks.fold<int>(0, (s, b) => s + b.text.length),
          'blocks': blocks.length,
        },
      ],
      'chars': blocks.fold<int>(0, (s, b) => s + b.text.length),
    };
  }

  static Future<List<BookBlock>> section(
    String filename,
    String format,
    String key,
  ) async {
    final data = await Isolate.run(() {
      if (format == 'epub') {
        final z = _Zip(filename);
        try {
          return markup(
            z.text(safePath(key)),
            base: key,
          ).map((b) => b.toMap()).toList();
        } finally {
          z.close();
        }
      }
      final f = File(filename);
      if (f.lengthSync() > maxText) {
        throw const FormatException('book_large_text');
      }
      final s = decode(f.readAsBytesSync());
      final blocks = format == 'html'
          ? markup(s)
          : format == 'fb2'
          ? [
              for (final n
                  in XmlDocument.parse(s).descendants
                      .whereType<XmlElement>()
                      .where((n) => {'p', 'subtitle'}.contains(n.name.local)))
                ...plain(n.innerText),
            ]
          : plain(s);
      return blocks.map((b) => b.toMap()).toList();
    });
    return data.map(BookBlock.fromMap).toList();
  }

  static Future<Uint8List> image(String filename, String key) =>
      Isolate.run(() {
        final z = _Zip(filename);
        try {
          final f = z.files[safePath(key)];
          if (f == null || f.size > 4 * 1024 * 1024) {
            throw const FormatException('book_image');
          }
          return z.bytes(key);
        } finally {
          z.close();
        }
      });
}

class _Zip {
  late final InputFileStream stream;
  late final Map<String, ArchiveFile> files;
  final checksums = <String, int>{};
  _Zip(String filename) {
    if (File(filename).lengthSync() > TextDocument.maxArchive) {
      throw const FormatException('book_large');
    }
    preflight(File(filename));
    stream = InputFileStream(filename);
    try {
      final decoder = ZipDecoder(), archive = decoder.decodeStream(stream);
      if (decoder.directory.fileHeaders.length > TextDocument.maxEntries) {
        throw const FormatException('book_archive_large');
      }
      files = {};
      var total = 0;
      for (final header in decoder.directory.fileHeaders) {
        final key = TextDocument.safePath(header.filename);
        if (files.containsKey(key)) {
          throw const FormatException('book_archive_duplicate');
        }
        final f = archive.find(header.filename)!;
        if (f.isSymbolicLink ||
            f.size > TextDocument.maxText ||
            (total += f.size) > TextDocument.maxArchive) {
          throw const FormatException('book_archive_large');
        }
        files[key] = f;
        checksums[key] = header.crc32;
      }
      if (!files.containsKey('mimetype') ||
          ascii.decode(bytes('mimetype')).trim() != 'application/epub+zip') {
        throw const FormatException('book_format');
      }
    } catch (_) {
      stream.closeSync();
      rethrow;
    }
  }
  // Validate central headers before ZipDecoder can decompress symlink bodies.
  // This also bounds dishonest entry counts before constructing Archive objects.
  static void preflight(File file) {
    final f = file.openSync();
    try {
      final length = f.lengthSync(), n = length < 65557 ? length : 65557;
      f.setPositionSync(length - n);
      final tail = f.readSync(n);
      final view = ByteData.sublistView(tail);
      var e = -1;
      for (var i = n - 22; i >= 0; i--) {
        if (view.getUint32(i, Endian.little) == 0x06054b50 &&
            i + 22 + view.getUint16(i + 20, Endian.little) == n) {
          e = i;
          break;
        }
      }
      if (e < 0) throw const FormatException('book_epub_corrupt');
      final count = view.getUint16(e + 10, Endian.little),
          size = view.getUint32(e + 12, Endian.little),
          offset = view.getUint32(e + 16, Endian.little);
      if (count > TextDocument.maxEntries ||
          size > 8 * 1024 * 1024 ||
          offset + size > length - n + e ||
          view.getUint16(e + 4, Endian.little) != 0 ||
          view.getUint16(e + 6, Endian.little) != 0) {
        throw const FormatException('book_archive_large');
      }
      f.setPositionSync(offset);
      final data = f.readSync(size);
      if (data.length != size) throw const FormatException('book_epub_corrupt');
      final d = ByteData.sublistView(data);
      var pos = 0, entries = 0, expanded = 0;
      while (pos < size) {
        if (pos + 46 > size || d.getUint32(pos, Endian.little) != 0x02014b50) {
          throw const FormatException('book_epub_corrupt');
        }
        final unpacked = d.getUint32(pos + 24, Endian.little),
            name = d.getUint16(pos + 28, Endian.little),
            extra = d.getUint16(pos + 30, Endian.little),
            comment = d.getUint16(pos + 32, Endian.little),
            mode = d.getUint32(pos + 38, Endian.little) >> 16;
        if (++entries > TextDocument.maxEntries ||
            name > 2048 ||
            unpacked > TextDocument.maxText ||
            (expanded += unpacked) > TextDocument.maxArchive ||
            mode & 0xf000 == 0xa000) {
          throw const FormatException('book_archive_large');
        }
        if (d.getUint16(pos + 8, Endian.little) & 1 != 0) {
          throw const FormatException('book_drm');
        }
        pos += 46 + name + extra + comment;
        if (pos > size) throw const FormatException('book_epub_corrupt');
      }
      if (entries != count) throw const FormatException('book_epub_corrupt');
    } finally {
      f.closeSync();
    }
  }

  Uint8List bytes(String key) {
    final f = files[key];
    if (f == null || f.size > TextDocument.maxText) {
      throw const FormatException('book_epub_missing');
    }
    final bytes = f.readBytes();
    if (bytes == null ||
        bytes.length != f.size ||
        getCrc32(bytes) != checksums[key]) {
      throw const FormatException('book_epub_corrupt');
    }
    return bytes;
  }

  String text(String key) => TextDocument.decode(bytes(key));
  void close() => stream.closeSync();
}
