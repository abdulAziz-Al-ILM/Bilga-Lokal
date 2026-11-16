import 'dart:convert';
import 'dart:io';

import 'package:bilga/features/books/reading/book_importer.dart';
import 'package:bilga/features/books/reading/reading_store.dart';
import 'package:bilga/features/books/reading/reading_links.dart';
import 'package:bilga/features/habits/habit_templates.dart';
import 'package:bilga/features/books/reading/reading_data.dart';
import 'package:bilga/features/books/reading/text_document.dart';
import 'package:bilga/features/private_space/record_store.dart';
import 'package:bilga/features/backup/backup_store.dart';
import 'package:bilga/features/backup/media_backup.dart';
import 'package:bilga/features/notes/note_database.dart';
import 'package:bilga/features/todo/todo_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:pdfrx/pdfrx.dart';

import 'reading_fixtures.dart';

void registerReadingDataCases({
  Future<Directory> Function()? createDirectory,
  bool secure = false,
}) {
  late Directory dir;
  late Database notes, tasks;
  late ReadingStore store;
  late BookImporter importer;
  setUp(() async {
    dir =
        await (createDirectory?.call() ??
            Directory.systemTemp.createTemp('bilga-reader-test-'));
    Pdfrx.cacheDirectoryPath = dir.path;
    notes = await NoteDatabase.openAt('${dir.path}/notes.db', secure: secure);
    tasks = await TodoDatabase.openAt('${dir.path}/tasks.db', secure: secure);
    store = ReadingStore(
      records: RecordStore(database: notes),
      vault: FixtureBookVault(Directory('${dir.path}/vault')),
      previewRoot: dir,
    );
    importer = BookImporter(store);
  });
  tearDown(() async {
    await notes.close();
    await tasks.close();
    await dir.delete(recursive: true);
  });
  test('TXT import is encrypted and atomic, no mandatory metadata, independent progress and relink preserve annotations', () async {
    final candidate = await importer.prepare(
      Stream.value(utf8.encode('Original Bilga text.\n\nSecond paragraph.')),
      'No author.txt',
    );
    final book = await importer.commit(candidate, allowed: () => true);
    expect(book.data['title'], 'No author');
    final source = (await store.one(book.id, 'source'))!;
    final rendered = await importer.materialize(source);
    expect(await rendered.readAsString(), contains('Second paragraph'));
    final disk = await File('${dir.path}/vault/${source.data['hash']}')
        .readAsBytes();
    expect(utf8.decode(disk.take(8).toList()), 'BILGAC02');
    expect(
      disk,
      isNot(containsAllInOrder(utf8.encode('Original Bilga text.'))),
    );
    final location = {
      'kind': 'text',
      'section': 'text',
      'block': 1,
      'offset': 0,
    };
    await store.progress(book.id, location, .5);
    final mark = await store.put(book.id, 'bookmark', {
      'v': 1,
      'location': location,
      'text': '',
      'note': 'Here',
    });
    await importer.commit(candidate, replacing: source, allowed: () => true);
    expect((await store.one(book.id, 'bookmark'))!.id, mark.id);
    expect((await store.one(book.id, 'progress'))!.data['location'], location);
    expect((await store.records.all('book')).length, 1);
    expect((await store.duplicates(candidate.hash)).single['id'], book.id);
    expect((await store.records.get(book.id)).revision, book.revision);
    final other = await importer.prepare(
      Stream.value(utf8.encode('Different text')),
      'other.txt',
    );
    await expectLater(
      importer.commit(
        other,
        replacing: await store.one(book.id, 'source'),
        allowed: () => true,
      ),
      throwsFormatException,
    );
    await other.close();
    await rendered.parent.delete(recursive: true);
    await candidate.close();
  });
  test('PDF native engine imports a 500-page textbook lazily and textless pages render', () async {
    final c = await importer.prepare(
      Stream.value(fixturePdf(pages: 500)),
      'textbook.dat',
    );
    expect(c.format, 'pdf');
    expect(c.pages, 500);
    expect(c.cover, isNotEmpty);
    final b = await importer.commit(c, allowed: () => true);
    await store.progress(b.id, {
      'kind': 'pdf',
      'page': 154,
      'zoom': 1.5,
      'y': .25,
    }, 154 / 500);
    expect((await store.one(b.id, 'progress'))!.data['location']['page'], 154);
    final scan = await importer.prepare(
      Stream.value(fixturePdf(scanned: true)),
      'no-embedded-text.pdf',
    );
    expect(scan.pages, 3);
    expect(scan.cover, isNotEmpty);
    await scan.close();
    await c.close();
  });
  test('EPUB detects content despite wrong extension; chapters, Unicode and sanitization survive import', () async {
    final c = await importer.prepare(Stream.value(fixtureEpub()), 'wrong.dat');
    expect(c.format, 'epub');
    expect(c.index['title'], 'Original Bilga EPUB');
    expect(c.index['sections'], hasLength(2));
    final blocks = await TextDocument.section(
      c.file.path,
      'epub',
      'OEBPS/text/one.xhtml',
    );
    expect(blocks.map((b) => b.text).join(), isNot(contains('BAD SCRIPT')));
    final rtl = await TextDocument.section(
      c.file.path,
      'epub',
      'OEBPS/text/two.xhtml',
    );
    expect(rtl.map((b) => b.text).join(), contains('مرحبا'));
    expect(
      TextDocument.resolve('OEBPS/text/one.xhtml', '../images/a.png'),
      'OEBPS/images/a.png',
    );
    expect(
      () => TextDocument.resolve('OEBPS/a', '../../outside'),
      throwsFormatException,
    );
    await c.close();
  });
  test('EPUB navigation resolves Unicode chapter anchors; local FTS handles case and punctuation safely', () async {
    final c = await importer.prepare(
      Stream.value(fixtureEpub(navigation: true)),
      'nav.epub',
    );
    expect(
      (c.index['toc'] as List).single['title'],
      'Second chapter from navigation',
    );
    expect((c.index['toc'] as List).single['key'], 'OEBPS/text/two.xhtml');
    expect((c.index['toc'] as List).single['block'], 0);
    final b = await importer.commit(c, allowed: () => true);
    await store.put(b.id, 'card', {
      'v': 1,
      'type': 'idea',
      'front': 'ПАМЯТЬ ЎЗБЕКЧА',
      'back': 'Review',
      'explanation': '',
      'tags': <String>[],
      'box': 0,
      'reviews': 0,
      'due': '2020-01-01T00:00:00Z',
    });
    expect(await store.rows(b.id, 'card', query: 'память'), hasLength(1));
    expect(await store.rows(b.id, 'card', query: '" OR * -'), isEmpty);
    await c.close();
  });
  test('Import rejects malformed archives, traversal, DRM, unknown binary and unsafe encodings without database rows', () async {
    for (final bytes in [
      fixtureEpub(extraPath: '../escape.txt'),
      fixtureEpub(drm: true),
      [80, 75, 3, 4, 0, 0],
      [0, 1, 2, 3],
    ]) {
      await expectLater(
        importer.prepare(Stream.value(bytes), 'bad.epub'),
        throwsA(anything),
      );
    }
    await expectLater(
      importer.prepare(Stream.value([0xff, 0, 0x81]), 'bad.txt'),
      throwsFormatException,
    );
    expect(await store.records.all('book'), isEmpty);
    expect(
      TextDocument.decode([0xff, 0xfe, 65, 0, 0x3d, 0xd8, 0, 0xde]),
      'A😀',
    );
    expect(
      () => TextDocument.decode([0xff, 0xfe, 0, 0xdc]),
      throwsFormatException,
    );
    final chunks = TextDocument.plain('😀' * 10000);
    expect(chunks.every((c) => c.text.length <= 4000), isTrue);
    expect(chunks.map((c) => c.text).join(), '😀' * 10000);
  });
  test('Fresh access check prevents partial import; CAS prevents stale mark overwrites', () async {
    final c = await importer.prepare(
      Stream.value(utf8.encode('Text')),
      'read.txt',
    );
    var checks = 0;
    await expectLater(
      importer.commit(c, allowed: () => ++checks < 2),
      throwsStateError,
    );
    expect(await store.records.all('book'), isEmpty);
    expect(await notes.query('book_reading'), isEmpty);
    final b = await importer.commit(c, allowed: () => true);
    final data = {
      'v': 1,
      'location': {'kind': 'text', 'section': 'text', 'block': 0, 'offset': 0},
      'text': '',
      'note': 'First',
    };
    final old = await store.put(b.id, 'bookmark', data);
    await store.put(b.id, 'bookmark', {
      ...data,
      'note': 'Saved',
    }, previous: old);
    await expectLater(
      store.put(b.id, 'bookmark', {...data, 'note': 'Stale'}, previous: old),
      throwsStateError,
    );
    expect((await store.one(b.id, 'bookmark'))!.data['note'], 'Saved');
    await c.close();
  });
  test('Flashcard review is atomic, immutable, overdue-aware and uses calendar-day intervals', () async {
    final c = await importer.prepare(
      Stream.value(utf8.encode('Text')),
      'read.txt',
    );
    final b = await importer.commit(c, allowed: () => true);
    final card = {
      'v': 1,
      'type': 'question',
      'front': 'Why?',
      'back': 'Because.',
      'explanation': '',
      'tags': <String>[],
      'box': 0,
      'reviews': 0,
      'due': '2020-01-01T00:00:00.000Z',
    };
    final row = await store.put(b.id, 'card', card);
    final now = DateTime(2026, 11, 15, 23, 50);
    expect(await store.due(b.id, at: now), hasLength(1));
    await store.review(row, 2, at: now);
    final changed = (await store.one(b.id, 'card'))!;
    expect(changed.data['box'], 1);
    expect(changed.data['reviews'], 1);
    expect(
      DateTime.parse(changed.data['due']).toLocal(),
      DateTime(2026, 11, 17),
    );
    expect(await store.due(b.id, at: now), isEmpty);
    await expectLater(store.review(row, 3, at: now), throwsStateError);
    final history = (await store.one(b.id, 'review'))!;
    expect(history.data['front'], 'Why?');
    expect(history.data['back'], 'Because.');
    await expectLater(store.remove(history), throwsStateError);
    await expectLater(
      store.put(b.id, 'review', history.data, previous: history),
      throwsStateError,
    );
    expect(await store.rows(b.id, 'review'), hasLength(1));
    await c.close();
  });
  test('Versioned metadata and full encrypted backup preserve reading rows, media and restored locators idempotently', () async {
    final c = await importer.prepare(Stream.value(fixtureEpub()), 'owned.epub');
    final b = await importer.commit(c, allowed: () => true);
    await store.progress(b.id, {
      'kind': 'text',
      'section': 'OEBPS/text/two.xhtml',
      'block': 1,
      'offset': 0,
    }, .75);
    await store.put(b.id, 'session', {
      'v': 1,
      'day': '2026-11-15',
      'start': '2026-11-14T23:59:00Z',
      'end': '2026-11-15T00:00:00Z',
      'seconds': 60,
    });
    await store.put(b.id, 'settings', {
      'v': 1,
      'font': 22.0,
      'line': 1.8,
      'margin': 32.0,
      'theme': 'sepia',
      'family': 'serif',
    });
    final locator = {
      'kind': 'text',
      'section': 'OEBPS/text/two.xhtml',
      'block': 1,
      'offset': 0,
    };
    for (final kind in ['bookmark', 'highlight', 'annotation']) {
      await store.put(b.id, kind, {
        'v': 1,
        'location': locator,
        'text': kind == 'highlight' ? 'مرحبا' : '',
        'note': 'Original $kind',
        if (kind == 'highlight') 'color': 'blue',
        if (kind == 'highlight') 'end': 5,
      });
    }
    final question = await store.put(b.id, 'card', {
      'v': 1,
      'type': 'question',
      'front': 'How do I remember an idea?',
      'back': 'Explain and review.',
      'explanation': 'Original explanation',
      'tags': ['Learning'],
      'location': locator,
      'box': 0,
      'reviews': 0,
      'due': '2020-01-01T00:00:00Z',
    });
    await store.review(question, 2, at: DateTime(2026, 11, 15));
    final backup = BackupStore(notesDb: notes, todoDb: tasks);
    final snapshot = await backup.snapshot();
    expect(snapshot['notesSchema'], 15);
    BackupStore.validate(snapshot);
    final encoded = await MediaBackup.encode(
      snapshot,
      'reading-fixture-password',
      vault: store.vault,
    ).expand((b) => b).toList();
    final restoredVault = FixtureBookVault(
      Directory('${dir.path}/restored-vault'),
    );
    final decoded = await MediaBackup.decode(
      Stream.value(encoded),
      'reading-fixture-password',
      vault: restoredVault,
    );
    expect(await backup.restore(decoded, 'Restored reading'), isTrue);
    expect(await backup.restore(decoded, 'Again'), isFalse);
    final books = await store.records.all('book');
    expect(books, hasLength(2));
    final restored = books.firstWhere((r) => r.id != b.id);
    final rs = (await store.one(restored.id, 'source'))!;
    final actual = await BookImporter(
      ReadingStore(
        records: store.records,
        vault: restoredVault,
        previewRoot: dir,
      ),
    ).materialize(rs);
    expect(await actual.readAsBytes(), await c.file.readAsBytes());
    expect(
      (await store.one(restored.id, 'progress'))!.data['location']['section'],
      'OEBPS/text/two.xhtml',
    );
    for (final kind in ['bookmark', 'highlight', 'annotation']) {
      final restoredMark = (await store.one(restored.id, kind))!;
      expect(restoredMark.data['note'], 'Original $kind');
      expect(restoredMark.data['location'], locator);
    }
    expect((await store.one(restored.id, 'settings'))!.data['theme'], 'sepia');
    final restoredQuestion = (await store.one(restored.id, 'card'))!;
    final restoredHistory = (await store.one(restored.id, 'review'))!;
    expect(restoredQuestion.data['front'], 'How do I remember an idea?');
    expect(restoredQuestion.data['reviews'], 1);
    expect(restoredHistory.data['card'], restoredQuestion.id);
    expect(restoredHistory.data['back'], 'Explain and review.');
    expect(
      await store.rows(restored.id, 'card', query: 'remember'),
      hasLength(1),
    );
    expect((await store.activity()).single['day'], '2026-11-15');
    final downgrade = jsonDecode(jsonEncode(snapshot)) as Map<String, dynamic>;
    downgrade['notesSchema'] = 14;
    expect(() => BackupStore.validate(downgrade), throwsFormatException);
    await actual.parent.delete(recursive: true);
    await c.close();
  });
  test('Cross-module confirmed links are idempotent and backup remaps targets and origins', () async {
    final c = await importer.prepare(
      Stream.value(utf8.encode('Original text')),
      'read.txt',
    );
    final b = await importer.commit(c, allowed: () => true);
    final card = await store.put(b.id, 'card', {
      'v': 1,
      'type': 'idea',
      'front': 'An idea',
      'back': 'Original thought',
      'explanation': '',
      'tags': <String>[],
      'box': 0,
      'reviews': 0,
      'due': '2020-01-01T00:00:00Z',
    });
    final links = ReadingLinks(store, todos: tasks);
    for (final kind in ['note', 'todo', 'habit', 'experience']) {
      final first = await links.create(
        book: b.id,
        origin: card.id,
        kind: kind,
        title: 'Read and apply',
        body: 'Remember this',
        due: DateTime(2026, 11, 20),
        allowed: () => true,
        plan: habitTemplates.firstWhere((t) => t.id == 'read').plan((s) => s),
      );
      final second = await links.create(
        book: b.id,
        origin: card.id,
        kind: kind,
        title: 'Retry must reuse target',
        body: 'Retry',
        allowed: () => true,
      );
      expect(first.id, second.id);
      expect(first.data['target'], second.data['target']);
      expect(second.data['state'], 'ready');
    }
    expect(await notes.query('notes'), hasLength(1));
    expect(await tasks.query('todos'), hasLength(1));
    expect((await tasks.query('todos')).single['description'], 'Remember this');
    expect(await notes.query('habits'), hasLength(1));
    final backup = BackupStore(notesDb: notes, todoDb: tasks);
    final snapshot = await backup.snapshot();
    await backup.restore(snapshot, 'Linked reading');
    final copy = (await store.records.all('book'))
        .firstWhere((r) => r.id != b.id);
    final restoredCard = (await store.one(copy.id, 'card'))!;
    for (final row in await store.rows(copy.id, 'link')) {
      expect(row.data['origin'], restoredCard.id);
      expect(
        row.data['target'],
        isNot(
          (await links.existing(
            b.id,
            card.id,
            row.data['targetKind'],
          ))!.data['target'],
        ),
      );
      final table = switch (row.data['targetKind']) {
        'note' => 'notes',
        'todo' => 'todos',
        'habit' => 'habits',
        _ => 'private_records',
      };
      expect(
        await (table == 'todos' ? tasks : notes).query(
          table,
          where: 'id=?',
          whereArgs: [row.data['target']],
        ),
        hasLength(1),
      );
    }
    await c.close();
  });
  test('Notes v16 migrates to v18 additively and preserves legacy book/history byte for byte', () async {
    final original = await store.records.save('book', {
      'title': 'Legacy',
      'characters': 'Kept',
      'bookmark': 0,
      'chapters': [
        {'title': 'Old', 'body': 'Private history', 'versions': <dynamic>[]},
      ],
    });
    final before = await notes.query('private_records');
    await notes.execute('DROP TABLE module_data');
    await notes.execute('DROP TABLE book_reading');
    await notes.execute('PRAGMA user_version=16');
    await notes.close();
    notes = await NoteDatabase.openAt('${dir.path}/notes.db', secure: secure);
    store = ReadingStore(
      records: RecordStore(database: notes),
      vault: store.vault,
      previewRoot: dir,
    );
    expect(await notes.query('private_records'), before);
    expect((await store.records.get(original.id)).data['characters'], 'Kept');
    expect(await notes.query('book_reading'), isEmpty);
    expect(await notes.getVersion(), 18);
  });
  test('Strict normalized data rejects future versions and malformed highlight geometry', () {
    final p = {
      'v': 1,
      'location': {'kind': 'pdf', 'page': 1},
      'text': 't',
      'note': '',
      'rects': [
        [1, 0, 100, 20, 80],
      ],
    };
    ReadingData.validate('highlight', p);
    for (final bad in [
      {...p, 'v': 2},
      {...p, 'v': 1.0},
      {
        ...p,
        'rects': [
          [1, 20, 80, 0, 100],
        ],
      },
      {
        ...p,
        'rects': [
          ['page', 0, 1, 2, 3],
        ],
      },
    ]) {
      expect(
        () => ReadingData.validate('highlight', bad),
        throwsFormatException,
      );
    }
  });
}
