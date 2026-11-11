import 'dart:io';

import 'package:bilga/features/backup/backup_store.dart';
import 'package:bilga/features/collections/collection_repository.dart';

import 'package:bilga/features/notes/folder_model.dart';
import 'package:bilga/features/notes/folder_service.dart';
import 'package:bilga/features/notes/note_database.dart';
import 'package:bilga/features/notes/note_model.dart';
import 'package:bilga/features/notes/note_service.dart';
import 'package:bilga/features/todo/todo_database.dart';
import 'package:bilga/features/todo/todo_folder_model.dart';
import 'package:bilga/features/todo/todo_folder_service.dart';
import 'package:bilga/features/todo/todo_model.dart';
import 'package:bilga/features/todo/todo_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

final stamp = DateTime(2026, 9, 6);
Note note(String id, {String? folderId}) => Note(
  id: id,
  title: id,
  body: 'matn',
  folderId: folderId,
  createdAt: stamp,
  updatedAt: stamp,
);
Folder folder(String id, {String? parent}) => Folder(
  id: id,
  name: id,
  parentId: parent,
  createdAt: stamp,
  updatedAt: stamp,
);

void safetyTest(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (tester) async {
    await tester.runAsync(() => body(tester));
  });
}

void registerDataSafetyTests() {
  late Directory sandbox;
  final opened = <Database>[];
  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('bilga-safety-');
  });
  tearDown(() async {
    for (final db in opened.reversed) {
      if (db.isOpen) await db.close();
    }
    opened.clear();
    await sandbox.delete(recursive: true);
  });

  for (var version = 1; version <= 10; version++) {
    safetyTest('Notes v$version upgrades without losing rows', (tester) async {
      final path = p.join(sandbox.path, 'notes.db');
      final old = await openDatabase(
        path,
        version: version,
        onCreate: (db, _) async {
          if (version >= 10) await NoteDatabase.createRecords(db);
          if (version >= 9) await NoteDatabase.createHabits(db);
          await db.execute(
            'CREATE TABLE notes (id TEXT PRIMARY KEY, title TEXT NOT NULL, '
            'body TEXT NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL'
            '${version >= 2 ? ', is_deleted INTEGER NOT NULL DEFAULT 0' : ''}'
            '${version >= 5 ? ', folder_id TEXT' : ''}'
            '${version >= 7 ? ', trash_batch TEXT' : ''}'
            '${version >= 8 ? ", is_favorite INTEGER NOT NULL DEFAULT 0, is_archived INTEGER NOT NULL DEFAULT 0, tags TEXT NOT NULL DEFAULT '[]'" : ''})',
          );
          if (version >= 3) {
            await db.execute(
              'CREATE TABLE note_versions (version_id INTEGER PRIMARY KEY AUTOINCREMENT, '
              'note_id TEXT NOT NULL, title TEXT NOT NULL, body TEXT NOT NULL, created_at TEXT NOT NULL)',
            );
            await db.insert('note_versions', {
              'note_id': 'saved',
              'title': 'tarix',
              'body': 'eski',
              'created_at': stamp.toIso8601String(),
            });
          }
          if (version >= 4) {
            await db.execute(
              'CREATE TABLE folders (id TEXT PRIMARY KEY, name TEXT NOT NULL, '
              'parent_id TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL'
              '${version >= 6 ? ', is_deleted INTEGER NOT NULL DEFAULT 0' : ''}'
              '${version >= 7 ? ', trash_batch TEXT' : ''})',
            );
            final row = folder('parent').toMap();
            if (version < 6) row.remove('is_deleted');
            await db.insert('folders', row);
          }
          final row = note(
            'saved',
            folderId: version >= 5 ? 'parent' : null,
          ).toMap();
          row.remove('rich_body');
          if (version < 8) {
            row.remove('is_favorite');
            row.remove('is_archived');
            row.remove('tags');
          } else {
            row['is_favorite'] = 1;
            row['tags'] = '["saved-tag"]';
          }
          if (version < 2) row.remove('is_deleted');
          if (version < 5) row.remove('folder_id');
          await db.insert('notes', row);
        },
      );
      await old.close();
      final db = await NoteDatabase.openAt(path);
      opened.add(db);
      expect(await db.getVersion(), 16);
      expect(await db.query('habits'), isEmpty);
      final rows = await db.query('notes');
      expect(rows.single['body'], 'matn');
      expect(rows.single['id'], 'saved');
      expect(rows.single['trash_batch'], isNull);
      if (version == 8) {
        expect(rows.single['is_favorite'], 1);
        expect(rows.single['tags'], '["saved-tag"]');
      }
      if (version >= 5) expect(rows.single['folder_id'], 'parent');
      if (version >= 3) {
        expect((await db.query('note_versions')).single['body'], 'eski');
      }
      expect(
        (await db.rawQuery('PRAGMA integrity_check')).single.values.single,
        'ok',
      );
    });
  }

  safetyTest(
    'Folder restore does not resurrect an independently deleted note or subtree',
    (tester) async {
      final db = await NoteDatabase.openAt(p.join(sandbox.path, 'notes.db'));
      opened.add(db);
      final folders = FolderService(database: db);
      final notes = NoteService(database: db);
      await folders.addFolder(folder('parent'));
      await folders.addFolder(folder('child', parent: 'parent'));
      await notes.addNote(note('earlier', folderId: 'parent'));
      await notes.addNote(note('active', folderId: 'parent'));
      await notes.addNote(note('child-note', folderId: 'child'));
      await notes.moveToTrash(note('earlier', folderId: 'parent'));
      await folders.moveFolderTreeToTrash(folder('child', parent: 'parent'));
      await folders.moveFolderTreeToTrash(folder('parent'));
      await folders.restoreFolderTree(folder('parent'));
      expect((await notes.getNotesByFolder('parent')).map((n) => n.id), [
        'active',
      ]);
      expect((await notes.getDeletedNotes()).map((n) => n.id), ['earlier']);
      expect((await folders.getDeletedRootFolders()).map((f) => f.id), [
        'child',
      ]);
      await folders.restoreFolderTree(folder('child', parent: 'parent'));
      expect((await notes.getNotesByFolder('child')).single.id, 'child-note');
    },
  );

  safetyTest(
    'Edit and history commit together, and a failed write rolls both back',
    (tester) async {
      final db = await NoteDatabase.openAt(p.join(sandbox.path, 'notes.db'));
      opened.add(db);
      final notes = NoteService(database: db);
      final folders = FolderService(database: db);
      await folders.addFolder(folder('destination'));
      await notes.addNote(note('saved'));
      await notes.moveNoteToFolder(
        note('saved').copyWith(body: 'moved text'),
        'destination',
      );
      expect((await notes.getNoteVersions('saved')).single.body, 'matn');
      await db.execute(
        "CREATE TRIGGER fail_update BEFORE UPDATE ON notes BEGIN SELECT RAISE(ABORT, 'disk failure'); END",
      );
      await expectLater(
        notes.updateNote(note('saved').copyWith(body: 'must fail')),
        throwsA(anything),
      );
      expect(
        (await notes.getNotesByFolder('destination')).single.body,
        'moved text',
      );
      expect((await notes.getNoteVersions('saved')).length, 1);
      await db.execute('DROP TRIGGER fail_update');
      await db.close();
      final reopened = await NoteDatabase.openAt(
        p.join(sandbox.path, 'notes.db'),
      );
      opened.add(reopened);
      expect(
        (await NoteService(database: reopened).getNotesByFolder('destination'))
            .single
            .body,
        'moved text',
      );
    },
  );

  safetyTest(
    'Restoring a note with a deleted parent makes it accessible at root',
    (tester) async {
      final db = await NoteDatabase.openAt(p.join(sandbox.path, 'notes.db'));
      opened.add(db);
      final notes = NoteService(database: db);
      final folders = FolderService(database: db);
      await folders.addFolder(folder('parent'));
      await notes.addNote(note('saved', folderId: 'parent'));
      await folders.moveFolderTreeToTrash(folder('parent'));
      await notes.restoreNote(note('saved', folderId: 'parent'));
      expect((await notes.getNotes()).single.id, 'saved');
      expect((await notes.getNotes()).single.folderId, isNull);
    },
  );

  safetyTest(
    'To Do v1 upgrades and refuses folder cycles or deletion with contents',
    (tester) async {
      final path = p.join(sandbox.path, 'todos.db');
      final old = await openDatabase(
        path,
        version: 1,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE todos (id TEXT PRIMARY KEY, title TEXT NOT NULL, '
            'is_done INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL, updated_at TEXT NOT NULL)',
          );
          await db.insert('todos', {
            'id': 'original',
            'title': 'vazifa',
            'is_done': 1,
            'created_at': stamp.toIso8601String(),
            'updated_at': stamp.toIso8601String(),
          });
        },
      );
      await old.close();
      final db = await TodoDatabase.openAt(path);
      opened.add(db);
      final service = TodoService(database: db);
      expect((await service.getRootTodos()).single.isDone, isTrue);
      final folders = TodoFolderService(database: db);
      final parent = TodoFolder(
        id: 'p',
        name: 'p',
        createdAt: stamp,
        updatedAt: stamp,
      );
      final child = TodoFolder(
        id: 'c',
        name: 'c',
        parentId: 'p',
        createdAt: stamp,
        updatedAt: stamp,
      );
      await folders.addFolder(parent);
      await folders.addFolder(child);
      await expectLater(folders.moveFolder(parent, 'c'), throwsStateError);
      await expectLater(folders.deleteFolder('p'), throwsStateError);
      final task = Todo(
        id: 't',
        title: 'task',
        folderId: 'c',
        isDone: false,
        createdAt: stamp,
        updatedAt: stamp,
      );
      await service.addTodo(task);
      await expectLater(folders.deleteFolder('c'), throwsStateError);
      await expectLater(
        service.addTodo(task.copyWith(title: 'collision')),
        throwsA(anything),
      );
      expect((await service.getTodosByFolder('c')).single.title, 'task');
    },
  );

  safetyTest('To Do trash restores its batch, preserving earlier deletions', (
    tester,
  ) async {
    final db = await TodoDatabase.openAt(p.join(sandbox.path, 'todos.db'));
    opened.add(db);
    final repo = CollectionRepository(CollectionKind.todos, provided: db);
    await repo.createFolder('parent', null);
    final parent = (await repo.activeFolders()).single['id'] as String;
    for (final id in ['earlier', 'active']) {
      await TodoService(database: db).addTodo(
        Todo(
          id: id,
          title: id,
          folderId: parent,
          isDone: false,
          createdAt: stamp,
          updatedAt: stamp,
        ),
      );
    }
    await repo.trash('earlier');
    await repo.trash(parent, folder: true);
    expect((await repo.load(trash: true)).folders.length, 1);
    await repo.restore(parent, folder: true);
    expect((await repo.load(folderId: parent)).items.single['id'], 'active');
    expect((await repo.load(trash: true)).items.single['id'], 'earlier');
    await repo.removeForever('earlier');
    expect((await db.query('todos')).single['id'], 'active');
  });

  safetyTest('Backup restore is atomic, preserves data and is repeatable', (
    tester,
  ) async {
    final n = await NoteDatabase.openAt(p.join(sandbox.path, 'notes.db'));
    opened.add(n);
    final t = await TodoDatabase.openAt(p.join(sandbox.path, 'todos.db'));
    opened.add(t);
    await NoteService(database: n)
        .addNote(note('existing').copyWith(isFavorite: true, tags: ['ish']));
    await NoteService(database: n).updateNote(
      note('existing')
          .copyWith(body: 'new body', isFavorite: true, tags: ['ish']),
    );
    await TodoService(database: t).addTodo(
      Todo(
        id: 'task',
        title: 'task',
        isDone: false,
        createdAt: stamp,
        updatedAt: stamp,
      ),
    );
    final store = BackupStore(notesDb: n, todoDb: t);
    final payload = await store.snapshot();
    await t.execute(
      "CREATE TRIGGER fail_import BEFORE INSERT ON todos BEGIN SELECT RAISE(ABORT, 'failure'); END",
    );
    await expectLater(store.restore(payload, 'Restored'), throwsA(anything));
    expect((await n.query('notes')).length, 1);
    expect(await n.query('folders'), isEmpty);
    expect(await t.query('todo_folders'), isEmpty);
    await t.execute('DROP TRIGGER fail_import');
    expect(await store.restore(payload, 'Restored'), isTrue);
    expect((await n.query('notes')).length, 2);
    expect((await t.query('todos')).length, 2);
    expect(await store.restore(payload, 'Again'), isFalse);
    expect((await n.query('notes')).length, 2);
    final invalid = {...payload, 'version': 999};
    await expectLater(store.restore(invalid, 'Bad'), throwsFormatException);
    expect((await n.query('notes')).length, 2);
  });
}
