import 'dart:convert';
import 'dart:io';

import 'package:bilga/features/attachments/attachment_store.dart';
import 'package:bilga/features/backup/backup_store.dart';
import 'package:bilga/features/books/book_library.dart';
import 'package:bilga/features/books/book_library_store.dart';
import 'package:bilga/features/notes/note_database.dart';
import 'package:bilga/features/private_space/record_store.dart';
import 'package:bilga/features/search/search_repository.dart';
import 'package:bilga/features/todo/todo_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

void registerBookLibraryDataTests({
  Future<Directory> Function()? createDirectory,
  bool secure = false,
}) {
  late Directory dir;
  late Database notes, tasks;
  late RecordStore records;
  late BookLibraryStore books;
  Map<String, dynamic> legacy(String title) => {
    'title': title,
    'characters': 'Original characters',
    'bookmark': 1,
    'chapters': [
      {
        'title': 'One',
        'body': 'Complete old chapter',
        'versions': [
          {
            'title': 'Earlier title',
            'body': 'Earlier body',
            'date': '2020-01-01',
          },
        ],
      },
      {'title': 'Two', 'body': 'Second chapter', 'versions': <dynamic>[]},
    ],
  };
  Map<String, dynamic> sample(String title) =>
      BookLibrary.update(legacy(title), {
        'author': 'Толстой',
        'description': 'Private annotation',
        'status': 'reading',
        'pages': 250,
        'currentPage': 42,
        'tags': ['Study'],
        'shelves': ["Reader's shelf"],
        'categories': ['Literature'],
        'favorite': true,
        'isbn': '9780306406157',
        'rating': 4,
      });
  setUp(() async {
    dir =
        await (createDirectory?.call() ??
            Directory.systemTemp.createTemp('bilga-book-data-'));
    notes = await NoteDatabase.openAt('${dir.path}/notes.db', secure: secure);
    tasks = await TodoDatabase.openAt('${dir.path}/tasks.db', secure: secure);
    records = RecordStore(database: notes);
    books = BookLibraryStore(records: records);
  });
  tearDown(() async {
    await notes.close();
    await tasks.close();
    await dir.delete(recursive: true);
  });
  test('Book library reads legacy rows without changes; metadata preserves chapter history and bookmark across reopen', () async {
    final original = await records.save('book', legacy('Legacy book'));
    final before = await notes.query('private_records');
    final rows = await books.page();
    expect(rows.single.status, 'unspecified');
    expect(rows.single.author, '');
    expect(rows.single.pages, isNull);
    expect(await notes.query('private_records'), before);
    final changed = await records.save(
      'book',
      BookLibrary.update(original.data, {
        'author': 'Saved author',
        'status': 'reading',
        'pages': 300,
        'currentPage': 60,
      }),
      previous: original,
    );
    await notes.close();
    notes = await NoteDatabase.openAt('${dir.path}/notes.db', secure: secure);
    records = RecordStore(database: notes);
    books = BookLibraryStore(records: records);
    final loaded = await books.load(changed.id);
    expect(loaded.data['chapters'], original.data['chapters']);
    expect(loaded.data['bookmark'], 1);
    expect(BookLibrary.metadata(loaded.data)['currentPage'], 60);
    expect(loaded.revision, changed.revision);
  });
  test('Book metadata search, filters and independent favorites are transactional and handle literal shelf names', () async {
    final alpha = await records.save('book', sample('Alpha'));
    final beta = await records.save(
      'book',
      BookLibrary.update(legacy('Beta'), {
        'author': 'Another',
        'status': 'planned',
        'shelves': ['Home'],
      }),
    );
    expect((await books.page(query: 'Толст')).single.id, alpha.id);
    expect((await books.page(query: '978030')).single.id, alpha.id);
    expect(
      (await books.page(status: 'reading', favoritesOnly: true)).single.id,
      alpha.id,
    );
    expect(
      (await books.page(
        shelf: "Reader's shelf",
        tag: 'Study',
        category: 'Literature',
      )).single.id,
      alpha.id,
    );
    expect(await books.page(shelf: "x' OR 1=1 --"), isEmpty);
    expect(
      (await books.filters())['shelves'],
      containsAll(['Home', "Reader's shelf"]),
    );
    final hits = await SearchRepository(
      notesDb: notes,
      todoDb: tasks,
    ).search('Толст', kind: 'book');
    expect(hits.single.preview, contains('Толстой'));
    expect(hits.single.preview, contains('Private annotation'));
    await records.save(
      'book',
      BookLibrary.update(alpha.data, {'favorite': false}),
      previous: alpha,
    );
    expect(await books.page(favoritesOnly: true), isEmpty);
    expect((await books.load(beta.id)).data['chapters'], beta.data['chapters']);
  });
  test('Thin paged books retain deterministic ordering without returning chapter payloads', () async {
    for (var index = 0; index < 121; index++) {
      await records.save(
        'book',
        BookLibrary.update(
          {
            'title': 'Book ${index.toString().padLeft(3, '0')}',
            'chapters': <dynamic>[],
            'characters': '',
          },
          {
            'author': 'Author ${index % 5}',
            'status': index.isEven ? 'reading' : 'planned',
          },
        ),
      );
    }
    final large = legacy('Book 121');
    large['chapters'][0]['body'] = 'Long chapter content ' * 10000;
    await records.save(
      'book',
      sample('Book 121')..['chapters'] = large['chapters'],
    );
    final first = await books.page(sort: 'title', limit: 50),
        second = await books.page(sort: 'title', offset: 50, limit: 50),
        last = await books.page(sort: 'title', offset: 100, limit: 50);
    expect(first, hasLength(50));
    expect(second, hasLength(50));
    expect(last, hasLength(22));
    final all = [...first, ...second, ...last];
    expect(all.map((book) => book.id).toSet(), hasLength(122));
    expect(all.first.title, 'Book 000');
    expect(all.last.title, 'Book 121');
    expect(all.last.chapters, 2);
    expect(all.last.description.length, lessThanOrEqualTo(241));
    expect(await books.page(query: 'Long chapter'), hasLength(1));
    await expectLater(books.page(limit: 101), throwsArgumentError);
  });
  test('Failed or stale metadata updates leave full book content, source search and revisions intact', () async {
    final first = await records.save('book', sample('Keep book'));
    await notes.execute(
      "CREATE TRIGGER fail_book BEFORE UPDATE ON private_records WHEN NEW.kind='book' BEGIN SELECT RAISE(ABORT,'synthetic book write failure'); END",
    );
    await expectLater(
      records.save(
        'book',
        BookLibrary.update(first.data, {'author': 'Ghostauthor'}),
        previous: first,
      ),
      throwsA(anything),
    );
    expect((await books.load(first.id)).data, first.data);
    expect(await books.page(query: 'Ghostauthor'), isEmpty);
    await notes.execute('DROP TRIGGER fail_book');
    final saved = await records.save(
      'book',
      BookLibrary.update(first.data, {'status': 'paused'}),
      previous: first,
    );
    await expectLater(
      records.save(
        'book',
        BookLibrary.update(first.data, {'status': 'completed'}),
        previous: first,
      ),
      throwsStateError,
    );
    expect((await books.load(first.id)).revision, saved.revision);
    expect(
      (await books.load(first.id)).data['chapters'],
      first.data['chapters'],
    );
  });
  test('Portable book metadata/labels/history merge is idempotent and rejects future library versions before writes', () async {
    final original = await records.save('book', sample('Portable book'));
    final payload = await BackupStore(notesDb: notes, todoDb: tasks).snapshot();
    final targetNotes = await NoteDatabase.openAt(
      '${dir.path}/target-notes.db',
      secure: secure,
    );
    final targetTasks = await TodoDatabase.openAt(
      '${dir.path}/target-tasks.db',
      secure: secure,
    );
    try {
      final backup = BackupStore(notesDb: targetNotes, todoDb: targetTasks);
      expect(await backup.restore(payload, 'Imported'), true);
      final imported = (await RecordStore(database: targetNotes).all('book'))
          .single;
      expect(imported.data['library'], original.data['library']);
      expect(imported.data['chapters'], original.data['chapters']);
      expect(imported.data['bookmark'], 1);
      expect(await backup.restore(payload, 'Again'), false);
      final bad = jsonDecode(jsonEncode(payload)) as Map<String, dynamic>;
      final row = (bad['data']['private_records'] as List).single as Map;
      final value =
          jsonDecode(row['payload'] as String) as Map<String, dynamic>;
      value['libraryVersion'] = 2;
      row['payload'] = jsonEncode(value);
      await expectLater(backup.restore(bad, 'Invalid'), throwsFormatException);
      expect(
        await RecordStore(database: targetNotes).all('book'),
        hasLength(1),
      );
    } finally {
      await targetNotes.close();
      await targetTasks.close();
    }
  });
  test('Injected attachment stores select only the chosen book and preserve changed links on stale removal', () async {
    final first = await records.save('book', legacy('First'));
    final second = await records.save('book', legacy('Second'));
    await Attachments.text(
      'book',
      first.id,
      'First private link',
      store: records,
    );
    await Attachments.text(
      'book',
      second.id,
      'Second private link',
      store: records,
    );
    final link = (await Attachments.all(
      'book',
      first.id,
      store: records,
    )).single;
    expect(link.data['text'], 'First private link');
    final changed = await records.save('attachment', {
      ...link.data,
      'text': 'Updated first link',
    }, previous: link);
    await expectLater(
      Attachments.remove(link, store: records),
      throwsStateError,
    );
    expect(
      (await Attachments.all('book', first.id, store: records)).single.revision,
      changed.revision,
    );
    await Attachments.remove(changed, store: records);
    expect(await Attachments.all('book', first.id, store: records), isEmpty);
    expect(
      (await Attachments.all(
        'book',
        second.id,
        store: records,
      )).single.data['text'],
      'Second private link',
    );
  });
}
