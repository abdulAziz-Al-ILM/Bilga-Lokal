import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:bilga/features/notes/note_database.dart';
import 'package:bilga/features/todo/todo_database.dart';
import 'package:bilga/features/private_space/record_store.dart';
import 'package:bilga/features/experiences/experience_store.dart';
import 'package:bilga/features/experiences/experience_links.dart';
import 'package:bilga/features/experiences/experience_model.dart';
import 'package:bilga/features/modules/module_data.dart';
import 'package:bilga/features/backup/backup_store.dart';

void registerExperienceDataCases({
  Future<Directory> Function()? createDirectory,
  bool secure = false,
}) {
  late Directory dir;
  late Database notes, tasks;
  late RecordStore records;
  late ExperienceStore store;
  setUp(() async {
    dir =
        await (createDirectory?.call() ??
            Directory.systemTemp.createTemp('bilga-experience-'));
    notes = await NoteDatabase.openAt('${dir.path}/notes.db', secure: secure);
    tasks = await TodoDatabase.openAt('${dir.path}/tasks.db', secure: secure);
    records = RecordStore(database: notes);
    store = ExperienceStore(records: records);
  });
  tearDown(() async {
    await notes.close();
    await tasks.close();
    await dir.delete(recursive: true);
  });
  test('Experience saves are atomic, history immutable and stale saves cannot overwrite later revisions', () async {
    final original = await records.save('experience', {
      'title': 'First',
      'body': 'Actual first words',
      'category': 'life',
    });
    final second = await records.save('experience', {
      ...original.data,
      'title': 'Second',
      'body': 'Changed words',
    }, previous: original);
    await expectLater(
      records.save('experience', {
        ...original.data,
        'title': 'Stale',
      }, previous: original),
      throwsStateError,
    );
    expect((await store.history(original.id)).map((r) => r['entry_revision']), [
      2,
      1,
    ]);
    final immutable = (await notes.query(
      'module_data',
      where: 'owner=?',
      whereArgs: [original.id],
    )).first;
    await expectLater(
      notes.update(
        'module_data',
        {'payload': '{}'},
        where: 'id=?',
        whereArgs: [immutable['id']],
      ),
      throwsA(isA<DatabaseException>()),
    );
    await expectLater(
      notes.delete('module_data', where: 'id=?', whereArgs: [immutable['id']]),
      throwsA(isA<DatabaseException>()),
    );
    final old = (await store.history(original.id)).last;
    final restored = await store.restore(second, old);
    expect(restored.revision, 3);
    expect(restored.data, original.data);
    expect((await store.history(original.id)).map((r) => r['entry_revision']), [
      3,
      2,
      1,
    ]);
    final actual = await notes.query(
      'module_data',
      where: 'owner=?',
      whereArgs: [original.id],
    );
    expect(
      ModuleData.decode(actual.first)['snapshot']['body'],
      'Actual first words',
    );
    final other = await records.save('experience', {
      'title': 'Other',
      'category': 'life',
    });
    await expectLater(
      store.restore(other, {...old, 'owner': other.id}),
      throwsStateError,
    );
    expect((await records.get(second.id)).data['title'], 'First');
  });
  test('Experience dates, calendar, exact tags/favorites and Unicode FTS use actual saved content', () async {
    final cat = await store.addCategory('Learning');
    await records.save('experience', {
      'title': 'Compare methods',
      'experienceVersion': 1,
      'mode': 'experiment',
      'date': '2024-02-29',
      'category': cat,
      'tags': ['C++', 'o‘qish'],
      'favorite': true,
      'status': 'completed',
      'hypothesis': 'Original Ёлка experiment',
      'conclusions': 'Observed the actual result',
    });
    await records.save('experience', {
      'title': 'Daily reflection',
      'date': '2024-03-01',
      'category': 'life',
      'body': 'No invented lessons',
    });
    expect(
      (await store.page(
        query: 'ёлка',
        category: cat,
        tag: 'C++',
        favorites: true,
        status: 'completed',
      )).single['title'],
      'Compare methods',
    );
    expect(await store.page(tag: 'C'), isEmpty);
    expect(await store.page(query: 'xylophone OR ("'), isEmpty);
    expect(await store.month(DateTime(2024, 2)), {'2024-02-29': 1});
    expect(
      (await store.page(from: '2024-02-29', until: '2024-03-01')).length,
      1,
    );
    expect(await store.summary(), {
      'total': 2,
      'completed': 1,
      'reflections': 1,
      'experiments': 1,
      'days': 2,
    });
    expect(await store.tags(), containsAll(['C++', 'o‘qish']));
    expect(ExperienceModel.date('2024-02-30'), isFalse);
  });
  test('Interrupted follow-up task creation resumes original draft exactly once and guards access', () async {
    final e = await records.save('experience', {
      'title': 'Try once',
      'next': 'One actual next step',
    });
    final links = ExperienceLinks(store, tasks: tasks);
    var checks = 0;
    await expectLater(
      links.task(
        e,
        title: 'Original followup',
        body: 'Original source',
        due: DateTime(2030, 1, 1),
        allowed: () => ++checks <= 2,
      ),
      throwsStateError,
    );
    expect(await tasks.query('todos'), isEmpty);
    expect(
      ModuleData.decode((await links.all(e.id)).single)['state'],
      'pending',
    );
    final id = await links.task(
      e,
      title: 'Changed retry text',
      body: 'Do not replace saved draft',
      allowed: () => true,
    );
    expect(
      await links.task(e, title: 'Again', body: 'Again', allowed: () => true),
      id,
    );
    final task = (await tasks.query('todos')).single;
    expect(task['title'], 'Original followup');
    expect(task['description'], 'Original source');
    expect(task['due_at'], startsWith('2030-01-01'));
    expect(ModuleData.decode((await links.all(e.id)).single)['state'], 'ready');
    await expectLater(
      links.task(e, title: 'No', body: 'No', allowed: () => false),
      throwsStateError,
    );
  });
  test('Categories, history and stable links survive portable backup with consistent ID remapping', () async {
    final cat = await store.addCategory('My learning');
    final e = await records.save('experience', {
      'title': 'Record',
      'category': cat,
      'date': '2026-11-16',
      'tags': ['learning'],
      'body': 'First',
    });
    final v2 = await records.save('experience', {
      ...e.data,
      'body': 'Second',
    }, previous: e);
    final book = await records.save('book', {
      'title': 'Book',
      'chapters': [],
      'characters': '',
    });
    final links = ExperienceLinks(store, tasks: tasks);
    await links.attach(e.id, 'book', book.id, allowed: () => true);
    await links.attach(e.id, 'book', book.id, allowed: () => true);
    await links.task(
      v2,
      title: 'Next task',
      body: 'Source details',
      allowed: () => true,
    );
    expect(await links.all(e.id), hasLength(2));
    final backup = BackupStore(notesDb: notes, todoDb: tasks),
        snapshot = await BackupStore(notesDb: notes, todoDb: tasks).snapshot();
    expect(snapshot['notesSchema'], 16);
    BackupStore.validate(snapshot);
    expect(await backup.restore(snapshot, 'Restored'), isTrue);
    expect(await backup.restore(snapshot, 'Restored'), isFalse);
    final restored = (await records.all('experience'))
        .singleWhere((r) => r.id != e.id);
    expect(restored.data['category'], isNot(cat));
    expect(
      (await store.categories())[restored.data['category']],
      'My learning',
    );
    final history = await store.history(restored.id);
    expect(history, hasLength(2));
    final old = (await notes.query(
      'module_data',
      where: 'id=?',
      whereArgs: [history.last['id']],
    )).single;
    expect(
      ModuleData.decode(old)['snapshot']['category'],
      restored.data['category'],
    );
    final linked = await links.all(restored.id);
    expect(linked, hasLength(2));
    final restoredBook =
        ModuleData.decode(
              linked.singleWhere(
                (r) => ModuleData.decode(r)['targetKind'] == 'book',
              ),
            )['target']
            as String;
    await links.attach(restored.id, 'book', restoredBook, allowed: () => true);
    expect(await links.all(restored.id), hasLength(2));
    for (final link in linked) {
      final d = ModuleData.decode(link);
      expect(d['target'], startsWith('restore:'));
      if (d['targetKind'] == 'todo') {
        expect(
          await tasks.query('todos', where: 'id=?', whereArgs: [d['target']]),
          hasLength(1),
        );
      } else {
        expect((await records.get(d['target'])).kind, 'book');
      }
    }
    final damaged = jsonDecode(jsonEncode(snapshot)) as Map<String, dynamic>;
    damaged['data']['module_data'][0]['owner'] = 'nonexistent';
    expect(() => BackupStore.validate(damaged), throwsFormatException);
  });
  test('Invalid experiment fields and unsupported versions never create records or history', () async {
    for (final data in [
      {'title': 'Invalid', 'date': '2026-02-30'},
      {
        'title': 'Invalid',
        'tags': ['a', 'a'],
      },
      {'title': 'Invalid', 'mode': 'fake'},
      {'title': 'Invalid', 'experienceVersion': 2},
      {'title': 'Invalid', 'method': 3},
    ]) {
      await expectLater(
        records.save('experience', data),
        throwsFormatException,
      );
    }
    expect(await records.all('experience'), isEmpty);
    expect(await notes.query('module_data'), isEmpty);
  });
  test('v17 upgrade retains legacy payload bytes and starts history at actual current revision', () async {
    final path = '${dir.path}/legacy.db',
        payload = jsonEncode({
          'title': 'Legacy',
          'body': 'Unmodified original \u202bنص',
          'category': 'life',
        });
    final old = await openDatabase(
      path,
      version: 17,
      onCreate: (d, v) async {
        await NoteDatabase.createRecords(d);
        await d.insert('private_records', {
          'id': 'legacy',
          'kind': 'experience',
          'payload': payload,
          'revision': 7,
          'created_at': '2020-01-01T00:00:00Z',
          'updated_at': '2026-01-01T00:00:00Z',
        });
      },
    );
    await old.close();
    final upgraded = await NoteDatabase.openAt(path);
    try {
      expect(
        (await upgraded.query('private_records')).single['payload'],
        payload,
      );
      expect(await upgraded.getVersion(), 19);
      final history = (await upgraded.query('module_data')).single;
      expect(ModuleData.decode(history)['entryRevision'], 7);
      expect(ModuleData.decode(history)['snapshot']['body'], contains('نص'));
    } finally {
      await upgraded.close();
    }
  });
}
