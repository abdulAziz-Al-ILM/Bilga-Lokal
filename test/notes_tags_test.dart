import 'support/rich_editor_input.dart';

import 'dart:convert';
import 'dart:io';

import 'package:bilga/core/strings.dart';
import 'package:bilga/features/backup/backup_store.dart';
import 'package:bilga/features/collections/collection_page.dart';
import 'package:bilga/features/collections/collection_repository.dart';
import 'package:bilga/features/notes/note_database.dart';
import 'package:bilga/features/notes/note_editor_page.dart';
import 'package:bilga/features/notes/note_model.dart';
import 'package:bilga/features/notes/note_service.dart';
import 'package:bilga/features/notes/note_tag_picker.dart';
import 'package:bilga/features/notes/note_tag_store.dart';
import 'package:bilga/features/todo/todo_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'database_safety_test.dart' show initializeTestSqlite;

final stamp = DateTime(2026, 10, 12);
Note entry(String id, {String? folder, List<String> tags = const []}) => Note(
  id: id,
  title: id,
  body: 'body $id',
  folderId: folder,
  tags: tags,
  createdAt: stamp,
  updatedAt: stamp,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late Database db;
  late NoteService notes;
  late NoteTagStore tags;
  late CollectionRepository repo;
  final opened = <Database>[];
  Future<Database> open(String name, {bool todo = false}) async {
    final db = todo
        ? await TodoDatabase.openAt('${root.path}/$name')
        : await NoteDatabase.openAt('${root.path}/$name');
    opened.add(db);
    return db;
  }

  Future<void> folder(String id, [String? parent]) => db
      .insert('folders', {
        'id': id,
        'name': id,
        'parent_id': parent,
        'created_at': stamp.toIso8601String(),
        'updated_at': stamp.toIso8601String(),
      })
      .then((_) {});
  Future<Note> saved(String id) async => (await NoteTagStore.hydrate(
    db,
    await db.query('notes', where: 'id = ?', whereArgs: [id]),
  )).map(Note.fromMap).single;
  setUpAll(() async {
    databaseFactory = createDatabaseFactoryFfi(ffiInit: initializeTestSqlite);
    for (final code in languages.keys) {
      await Strings.load(code: code);
    }
  });
  setUp(() async {
    root = await Directory.systemTemp.createTemp('bilga-notes-tags-');
    db = await open('notes.db');
    notes = NoteService(database: db);
    tags = NoteTagStore(db);
    repo = CollectionRepository(CollectionKind.notes, provided: db);
  });
  tearDown(() async {
    for (final db in opened.reversed) {
      if (db.isOpen) await db.close();
    }
    opened.clear();
    await root.delete(recursive: true);
  });

  test('v11 migration preserves original notes, history and folder rows; deduplicates legacy tags', () async {
    final path = '${root.path}/legacy.db';
    final old = await openDatabase(
      path,
      version: 11,
      onCreate: (db, _) async {
        await db.execute(
          "CREATE TABLE notes(id TEXT PRIMARY KEY,title TEXT,body TEXT,folder_id TEXT,created_at TEXT,updated_at TEXT,is_deleted INTEGER DEFAULT 0,is_favorite INTEGER DEFAULT 0,is_archived INTEGER DEFAULT 0,tags TEXT)",
        );
        await db.execute(
          'CREATE TABLE note_versions(version_id INTEGER PRIMARY KEY,note_id TEXT,title TEXT,body TEXT,created_at TEXT)',
        );
        await db.execute(
          'CREATE TABLE folders(id TEXT PRIMARY KEY,name TEXT,parent_id TEXT,created_at TEXT,updated_at TEXT,is_deleted INTEGER DEFAULT 0,trash_batch TEXT)',
        );
        await NoteDatabase.createHabits(db);
        await db.execute(
          "ALTER TABLE habits ADD COLUMN details TEXT NOT NULL DEFAULT '{}'",
        );
        await NoteDatabase.createRecords(db);
        await db.insert(
          'notes',
          entry('a', folder: 'parent', tags: [' Ish ', 'ISH', 'o‘qish']).toMap()
            ..remove('rich_body'),
        );
        await db.insert(
          'notes',
          entry(
            'trash',
            tags: ['ish', "O'QISH"],
          ).copyWith(isDeleted: true).toMap()..remove('rich_body'),
        );
        await db.insert('note_versions', {
          'version_id': 1,
          'note_id': 'a',
          'title': 'old',
          'body': 'old',
          'created_at': stamp.toIso8601String(),
        });
        await db.insert('folders', {
          'id': 'parent',
          'name': 'Parent',
          'created_at': stamp.toIso8601String(),
          'updated_at': stamp.toIso8601String(),
        });
      },
    );
    final before = {
      for (final t in ['notes', 'folders', 'note_versions'])
        t: await old.query(t),
    };
    await old.close();
    final migrated = await NoteDatabase.openAt(path);
    opened.add(migrated);
    expect(await migrated.getVersion(), 18);
    for (final t in before.keys) {
      expect(
        (await migrated.query(t))
            .map((r) => Map<String, Object?>.from(r)..remove('rich_body'))
            .toList(),
        before[t],
      );
    }
    expect((await NoteTagStore(migrated).all()).length, 2);
    expect((await migrated.query('note_tag_links')).length, 4);
    expect((await migrated.rawQuery('PRAGMA foreign_key_check')), isEmpty);
    expect(
      (await migrated.rawQuery('PRAGMA integrity_check')).single.values.single,
      'ok',
    );
  });

  test('Library creation normalizes whitespace, case and Uzbek apostrophes; concurrent duplicates share ID', () async {
    final created = await Future.wait([' Ish ', 'ISH', 'ish'].map(tags.create));
    expect(created.map((t) => t.id).toSet(), hasLength(1));
    expect((await tags.create('O‘qish')).id, (await tags.create("o'QISH")).id);
    expect((await tags.create('Работа')).id, (await tags.create('РАБОТА')).id);
    await expectLater(tags.create('   '), throwsA(isA<TagNameException>()));
    await expectLater(tags.create('x' * 81), throwsA(isA<TagNameException>()));
    expect((await tags.all()).length, 3);
  });

  test('Zero, one and multiple tags; detach keeps the library and folder; no tag-only history', () async {
    await folder('parent');
    await notes.addNote(entry('a', folder: 'parent'));
    expect((await saved('a')).tags, isEmpty);
    await notes.updateNote(
      (await saved('a')).copyWith(tags: ['Ish', 'Shaxsiy', 'ish']),
    );
    expect((await saved('a')).tags, ['Ish', 'Shaxsiy']);
    final first = (await saved('a')).tagIds!.first;
    await notes.updateNote((await saved('a')).copyWith(tagIds: [first]));
    expect((await saved('a')).tags, ['Ish']);
    await notes.updateNote((await saved('a')).copyWith(tagIds: <String>[]));
    expect((await saved('a')).tags, isEmpty);
    expect((await tags.all()).length, 2);
    expect((await saved('a')).folderId, 'parent');
    expect(await notes.getNoteVersions('a'), isEmpty);
  });

  test('Rename is global and atomic, retains IDs, rejects collision and survives stale editor save', () async {
    await notes.addNote(entry('a', tags: ['Ish']));
    await notes.addNote(entry('b', tags: ['Ish']).copyWith(isDeleted: true));
    final stale = await saved('a'), id = (await tags.all()).single.id;
    await tags.rename(id, 'Work');
    expect((await saved('a')).tags, ['Work']);
    expect((await saved('b')).tags, ['Work']);
    expect((await saved('a')).tagIds, [id]);
    await notes.updateNote(stale.copyWith(body: 'new body'));
    expect((await saved('a')).tags, ['Work']);
    await tags.create('Other');
    await expectLater(
      tags.rename(id, 'OTHER'),
      throwsA(isA<TagNameException>()),
    );
    expect((await saved('b')).tags, ['Work']);
    expect(
      jsonDecode(
        (await db.query(
              'notes',
              where: 'id=?',
              whereArgs: ['a'],
            )).single['tags']
            as String,
      ),
      ['Work'],
    );
    expect((await notes.getNoteVersions('a')).single.body, 'body a');
  });

  test('Global delete keeps notes and history; stale IDs never resurrect a deleted tag', () async {
    await notes.addNote(entry('a', tags: ['Ish']));
    await notes.addNote(
      entry('trash', tags: ['Ish']).copyWith(isDeleted: true),
    );
    final stale = await saved('a');
    await tags.delete(stale.tagIds!.single);
    await notes.updateNote(stale.copyWith(body: 'edited'));
    expect(await tags.all(), isEmpty);
    expect((await saved('a')).tags, isEmpty);
    expect((await saved('trash')).tags, isEmpty);
    expect(await db.query('notes'), hasLength(2));
    expect(await notes.getNoteVersions('a'), hasLength(1));
  });

  test('Trash/restore preserves links; version restore preserves current tags; permanent deletion cascades', () async {
    await notes.addNote(entry('a', tags: ['Ish']));
    await notes.updateNote(
      (await saved('a')).copyWith(body: 'second', tags: ['New']),
    );
    final version = (await notes.getNoteVersions('a')).single;
    final restored = await notes.restoreVersion(await saved('a'), version);
    expect(restored.tags, ['New']);
    await notes.moveToTrash(restored);
    expect((await notes.getDeletedNotes()).single.tags, ['New']);
    await notes.restoreNote(await saved('a'));
    expect((await notes.getAllActiveNotes()).single.tags, ['New']);
    await notes.deleteForever('a');
    expect(await db.query('note_tag_links'), isEmpty);
    expect(await tags.all(), hasLength(2));
    expect(await db.query('note_versions'), isEmpty);
  });

  test('Folder trash/restore keeps tags; folder permanent delete cleans all note links', () async {
    await folder('parent');
    await folder('child', 'parent');
    await notes.addNote(entry('a', folder: 'child', tags: ['Ish']));
    await repo.trash('parent', folder: true);
    expect((await saved('a')).tags, ['Ish']);
    await repo.restore('parent', folder: true);
    expect((await saved('a')).folderId, 'child');
    expect((await saved('a')).tags, ['Ish']);
    await repo.trash('parent', folder: true);
    await repo.removeForever('parent', folder: true);
    expect(await db.query('note_tag_links'), isEmpty);
    expect(await tags.all(), hasLength(1));
  });

  test('Tag filter spans every folder and archive, excludes trash; tag search escapes LIKE metacharacters', () async {
    await folder('parent');
    await folder('child', 'parent');
    await notes.addNote(entry('root', tags: ['Работа', '100%_real']));
    await notes.addNote(entry('nested', folder: 'child', tags: ['Работа']));
    await notes.addNote(
      entry(
        'archived',
        folder: 'parent',
        tags: ['Работа'],
      ).copyWith(isArchived: true),
    );
    await notes.addNote(
      entry('trash', tags: ['Работа']).copyWith(isDeleted: true),
    );
    final id = (await tags.all()).singleWhere((t) => t.name == 'Работа').id;
    expect(
      (await repo.load(
        folderId: 'parent',
        tagId: id,
      )).items.map((r) => r['id']).toSet(),
      {'root', 'nested', 'archived'},
    );
    expect((await repo.load(tagId: id)).folders, isEmpty);
    expect(
      (await repo.load(query: 'РАБОТА')).items.map((r) => r['id']).toSet(),
      {'root', 'nested'},
    );
    expect((await repo.load(query: '100%_')).items.single['id'], 'root');
    await repo.move('nested', null);
    expect((await tags.forNote('nested')).single.id, id);
  });

  test('Backup restores library including unused tags, links, trash/history; merges same-name tags without overwriting existing notes', () async {
    await notes.addNote(entry('a', tags: ['Ish']));
    await notes.updateNote((await saved('a')).copyWith(body: 'second'));
    await notes.addNote(
      entry('trash', tags: ['Ish']).copyWith(isDeleted: true),
    );
    await tags.create('Unused');
    final todo = await open('todo.db', todo: true);
    final payload = await BackupStore(notesDb: db, todoDb: todo).snapshot();
    final target = await open('target.db'),
        targetTodo = await open('target-todo.db', todo: true);
    final targetNotes = NoteService(database: target);
    await targetNotes.addNote(entry('existing', tags: ['ISH']));
    final existingId = (await NoteTagStore(target).all()).single.id;
    final backup = BackupStore(notesDb: target, todoDb: targetTodo);
    expect(await backup.restore(payload, 'Imported'), isTrue);
    expect(await backup.restore(payload, 'Again'), isFalse);
    expect((await NoteTagStore(target).all()).length, 2);
    expect(
      (await targetNotes.getAllActiveNotes())
          .firstWhere((n) => n.id == 'existing')
          .body,
      'body existing',
    );
    final imported = (await targetNotes.getAllActiveNotes()).singleWhere(
      (n) => n.id != 'existing',
    );
    expect(imported.tagIds, [existingId]);
    expect((await targetNotes.getDeletedNotes()).single.tagIds, [existingId]);
    expect(await targetNotes.getNoteVersions(imported.id), hasLength(1));
    expect(await target.rawQuery('PRAGMA foreign_key_check'), isEmpty);
  });

  test('Legacy v11 backup imports JSON tags; invalid new relationships reject before writes', () async {
    await notes.addNote(entry('a', tags: ['Ish']));
    final todo = await open('todo.db', todo: true);
    final payload = await BackupStore(notesDb: db, todoDb: todo).snapshot();
    final legacy = jsonDecode(jsonEncode(payload)) as Map<String, dynamic>;
    legacy['notesSchema'] = 11;
    (legacy['data'] as Map).remove('note_tags');
    (legacy['data'] as Map).remove('note_tag_links');
    final target = await open('target.db'),
        targetTodo = await open('target-todo.db', todo: true);
    final backup = BackupStore(notesDb: target, todoDb: targetTodo);
    expect(await backup.restore(legacy, 'Old backup'), isTrue);
    expect(
      (await NoteService(database: target).getAllActiveNotes()).single.tags,
      ['Ish'],
    );
    final bad = jsonDecode(jsonEncode(payload)) as Map<String, dynamic>;
    (bad['data']['note_tag_links'] as List).first['tag_id'] = 'missing';
    await expectLater(backup.restore(bad, 'Bad'), throwsFormatException);
    expect(await target.query('notes'), hasLength(1));
    final duplicate = jsonDecode(jsonEncode(payload)) as Map<String, dynamic>;
    (duplicate['data']['note_tags'] as List).add({
      ...duplicate['data']['note_tags'][0] as Map,
      'id': 'other',
    });
    await expectLater(backup.restore(duplicate, 'Bad'), throwsFormatException);
    expect(await target.query('note_tags'), hasLength(1));
  });

  test(
    'Failed note write rolls back new tags, links and history together',
    () async {
      await notes.addNote(entry('a', tags: ['Ish']));
      await db.execute(
        "CREATE TRIGGER fail_tags BEFORE INSERT ON note_tag_links BEGIN SELECT RAISE(ABORT, 'full'); END",
      );
      await expectLater(
        notes.updateNote(
          (await saved('a')).copyWith(body: 'new', tags: ['New']),
        ),
        throwsA(anything),
      );
      expect((await saved('a')).body, 'body a');
      expect((await saved('a')).tags, ['Ish']);
      expect((await tags.all()).single.name, 'Ish');
      expect(await notes.getNoteVersions('a'), isEmpty);
    },
  );

  test('All 43 locales have explicit tag labels and validation messages', () {
    for (final language in languages.keys) {
      for (final key in [
        'tags',
        'tagName',
        'tagDuplicate',
        'tagNameInvalid',
        'tagDeleteConfirm',
      ]) {
        expect(
          Strings.catalogs[language]![key]?.trim(),
          isNotEmpty,
          reason: '$language/$key',
        );
      }
    }
  });

  Future<void> settleIo(WidgetTester tester, {bool Function()? ready}) async {
    // SQLite FFI replies arrive on real isolate events; alternate real I/O and
    // fake-clock frames instead of spinning pumpAndSettle over a busy indicator.
    var stableFrames = 0;
    for (var i = 0; i < 300; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty &&
          find.byType(LinearProgressIndicator).evaluate().isEmpty &&
          (ready == null || ready())) {
        if (++stableFrames >= 20) return;
      } else {
        stableFrames = 0;
      }
    }
    fail('SQLite UI did not finish loading');
  }

  testWidgets(
    'Picker creates/selects a tag, reuses duplicates, renames and deletes with confirmation',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showNoteTagPicker(context, tags),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await settleIo(tester);
      await tester.enterText(find.byKey(const Key('tag-search')), 'Ish');
      await tester.pump();
      await tester.tap(find.byTooltip('Add'));
      await settleIo(tester);
      expect(find.text('Ish'), findsOneWidget);
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isTrue,
      );
      await tester.enterText(find.byKey(const Key('tag-search')), 'ISH');
      await tester.pump();
      await tester.tap(find.byTooltip('Add'));
      await settleIo(tester);
      expect(find.byType(CheckboxListTile), findsOneWidget);
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Work');
      await tester.tap(find.text('Save').last);
      await settleIo(tester);
      await tester.pump(const Duration(milliseconds: 350));
      await settleIo(tester);
      expect(find.text('Work'), findsOneWidget);
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete permanently'));
      await tester.pumpAndSettle();
      expect(find.text(Strings.get('en', 'tagDeleteConfirm')), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await settleIo(tester);
      expect(find.byType(CheckboxListTile), findsNothing);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Card chip opens global tag results without moving folders', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await folder('child');
      await notes.addNote(entry('root', tags: ['Ish']));
      await notes.addNote(entry('hidden', folder: 'child', tags: ['Ish']));
    });
    await tester.pumpWidget(
      MaterialApp(
        home: CollectionPage(kind: CollectionKind.notes, repository: repo),
      ),
    );
    await settleIo(tester);
    expect(find.text('hidden'), findsNothing);
    await tester.tap(find.text('#Ish'));
    await settleIo(
      tester,
      ready: () => find.text('hidden').evaluate().isNotEmpty,
    );
    expect(find.text('hidden'), findsOneWidget);
    expect(find.text('root'), findsOneWidget);
    await tester.runAsync(() async {
      expect((await saved('hidden')).folderId, 'child');
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'New note saves selected tags and retains its folder after reopening the database',
    (tester) async {
      await tester.runAsync(() async {
        await folder('child');
        await tags.create('Ish');
      });
      await tester.pumpWidget(
        MaterialApp(
          home: NoteEditorPage(folderId: 'child', service: notes),
        ),
      );
      await enterNoteBody(tester, 'New tagged note');
      await tester.tap(find.text('Tags'));
      await settleIo(tester);
      await tester.tap(find.text('Ish'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await settleIo(
        tester,
        ready: () => find.text('#Ish').evaluate().isNotEmpty,
      );
      await tester.pump(const Duration(milliseconds: 750));
      await settleIo(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      await settleIo(tester);
      await tester.runAsync(() async {
        final id = (await db.query('notes')).single['id'] as String;
        await db.close();
        db = await open('notes.db');
        final restored = await saved(id);
        expect(restored.tags, ['Ish']);
        expect(restored.tagIds, hasLength(1));
        expect(restored.body, 'New tagged note');
        expect(restored.folderId, 'child');
        expect(await NoteService(database: db).getNoteVersions(id), isEmpty);
        expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      });
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Editor adds/removes tags and saves body and IDs; tag-only edits preserve history',
    (tester) async {
      late Note original;
      await tester.runAsync(() async {
        await notes.addNote(entry('a', tags: ['Ish']));
        await tags.create('Other');
        original = await saved('a');
      });
      await tester.pumpWidget(
        MaterialApp(
          home: NoteEditorPage(note: original, service: notes),
        ),
      );
      await tester.tap(find.text('Tags'));
      await settleIo(tester);
      await tester.tap(find.text('Other'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await settleIo(tester);
      await tester.pump(const Duration(milliseconds: 750));
      await settleIo(tester);
      await tester.runAsync(() async {
        expect((await saved('a')).tags, ['Ish', 'Other']);
        expect(await notes.getNoteVersions('a'), isEmpty);
      });
      final chip = find.widgetWithText(InputChip, '#Ish');
      tester.widget<InputChip>(chip).onDeleted!();
      await tester.pump(const Duration(milliseconds: 750));
      await settleIo(tester);
      await enterNoteBody(tester, 'Edited text');
      await tester.pump(const Duration(milliseconds: 750));
      await settleIo(tester);
      await tester.runAsync(() async {
        expect((await saved('a')).tags, ['Other']);
        expect((await notes.getNoteVersions('a')).single.body, 'body a');
      });
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
