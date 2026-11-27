import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:bilga/core/chunk_vault.dart';
import 'package:bilga/features/books/reading/book_vault.dart';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart' show SecretKey;

/// Isolated encrypted synthetic content: never uses AppBookVault or owner keys.
class FixtureBookVault implements BookVault {
  final Directory directory;
  final key = SecretKey(List.generate(32, (i) => i));
  FixtureBookVault(this.directory);
  @override
  Stream<List<int>> read(String id) =>
      ChunkVault.decrypt(File('${directory.path}/$id').openRead(), key);
  @override
  Future<(String, int)> write(
    Stream<List<int>> bytes, {
    String? expected,
    int? size,
  }) async {
    await directory.create(recursive: true);
    final temporary = File(
      '${directory.path}/temp-${DateTime.now().microsecondsSinceEpoch}',
    );
    var count = 0;
    final hashSink = AccuHash();
    Stream<List<int>> observed() async* {
      await for (final b in bytes) {
        count += b.length;
        hashSink.add(b);
        yield b;
      }
    }

    final output = temporary.openWrite();
    try {
      await output.addStream(ChunkVault.encrypt(observed(), key));
    } finally {
      await output.close();
    }
    final digest = hashSink.close();
    if ((expected != null && expected != digest) ||
        (size != null && size != count)) {
      await temporary.delete();
      throw const FormatException('hash');
    }
    await temporary.rename('${directory.path}/$digest');
    return (digest, count);
  }
}

class AccuHash {
  AccuHash() : this._(DigestResult());

  // The conversion closes its result sink when the digest is final.
  AccuHash._(this._result) : _sink = sha256.startChunkedConversion(_result);

  final DigestResult _result;
  final ByteConversionSink _sink;

  void add(List<int> b) => _sink.add(b);
  String close() {
    _sink.close();
    return _result.digest.toString();
  }
}

class DigestResult implements Sink<Digest> {
  Digest? digest;
  @override
  void add(Digest value) {
    digest = value;
  }

  @override
  void close() {}
}

List<int> fixtureEpub({
  String? extraPath,
  bool drm = false,
  bool navigation = false,
}) {
  final a = Archive();
  void add(String path, String text) {
    final b = utf8.encode(text);
    a.addFile(ArchiveFile(path, b.length, b));
  }

  add('mimetype', 'application/epub+zip');
  add(
    'META-INF/container.xml',
    '<container><rootfiles><rootfile full-path="OEBPS/package.opf"/></rootfiles></container>',
  );
  add(
    'OEBPS/package.opf',
    '''<package xmlns:dc="http://purl.org/dc/elements/1.1/"><metadata><dc:title>Original Bilga EPUB</dc:title><dc:creator>Bilga fixture</dc:creator><dc:language>en</dc:language></metadata><manifest>${navigation ? '<item id="nav" href="nav.xhtml" properties="nav" media-type="application/xhtml+xml"/>' : ''}<item id="one" href="text/one.xhtml" media-type="application/xhtml+xml"/><item id="two" href="text/two.xhtml" media-type="application/xhtml+xml"/></manifest><spine><itemref idref="one"/><itemref idref="two"/></spine></package>''',
  );
  add(
    'OEBPS/text/one.xhtml',
    '<html><body><h1>First chapter</h1><p>Original synthetic reading passage for Bilga.</p><p>Quote to remember.</p><script>BAD SCRIPT</script></body></html>',
  );
  add(
    'OEBPS/text/two.xhtml',
    '<html dir="rtl"><body><h1 id="arabic">فصل دوم</h1><p>مرحبا بالعالم. O‘zbek матн.</p></body></html>',
  );
  if (navigation) {
    add(
      'OEBPS/nav.xhtml',
      '<html><body><nav epub:type="toc"><a href="text/two.xhtml#arabic">Second chapter from navigation</a></nav></body></html>',
    );
  }
  if (extraPath != null) add(extraPath, 'unsafe');
  if (drm) add('META-INF/rights.xml', '<rights/>');
  return ZipEncoder().encode(a);
}

/// Original generated text PDF: zero downloaded or proprietary content.
List<int> fixturePdf({int pages = 3, bool scanned = false}) {
  final objects = <String>[
    '<< /Type /Catalog /Pages 2 0 R >>',
    '',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
  ];
  final ids = <int>[];
  for (var i = 1; i <= pages; i++) {
    final page = objects.length + 1, content = page + 1;
    ids.add(page);
    objects.add(
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 400 600] /Resources << /Font << /F1 3 0 R >> >> /Contents $content 0 R >>',
    );
    final commands = scanned
        ? '0.8 g 20 20 360 560 re f'
        : 'BT /F1 18 Tf 40 530 Td (Bilga original page $i) Tj 0 -35 Td (Remember this synthetic passage.) Tj ET';
    objects.add(
      '<< /Length ${ascii.encode(commands).length} >>\nstream\n$commands\nendstream',
    );
  }
  objects[1] =
      '<< /Type /Pages /Kids [${ids.map((i) => '$i 0 R').join(' ')}] /Count $pages >>';
  final out = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[0];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(out.length);
    out.write('${i + 1} 0 obj\n${objects[i]}\nendobj\n');
  }
  final xref = out.length;
  out.write('xref\n0 ${objects.length + 1}\n0000000000 65535 f \n');
  for (final n in offsets.skip(1)) {
    out.write('${n.toString().padLeft(10, '0')} 00000 n \n');
  }
  out.write(
    'trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n',
  );
  return ascii.encode(out.toString());
}
