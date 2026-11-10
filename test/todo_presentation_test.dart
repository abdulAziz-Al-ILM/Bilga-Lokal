import 'dart:io';

import 'package:bilga/features/collections/collection_repository.dart';
import 'package:bilga/features/todo/todo_database.dart';
import 'package:bilga/features/todo/todo_presentation.dart';
import 'package:bilga/features/todo/todo_status_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'database_safety_test.dart' show initializeTestSqlite;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.utc(2026, 9, 18, 12);
  Map<String, Object?> task({
    Duration? left,
    bool done = false,
    int priority = 0,
  }) => {
    'is_done': done ? 1 : 0,
    'priority': priority,
    'due_at': left == null ? null : now.add(left).toIso8601String(),
  };
  test(
    'Deadline colors use local calendar dates and ignore persisted priority',
    () {
      final local = DateTime(2026, 9, 18, 23, 59);
      Map<String, Object?> due(int days) => {
        'due_at': DateTime(2026, 9, 18 + days, 23, 59, 30).toIso8601String(),
      };
      for (var p = 0; p < 4; p++) {
        expect(
          todoColor({...due(3), 'priority': p}, local),
          const Color(0xFF32A66A),
        );
      }
      expect(todoColor(due(2), local), const Color(0xFFE5B82F));
      expect(todoColor(due(1), local), const Color(0xFFE45458));
      expect(todoColor(due(0), local), const Color(0xFFE45458));
      expect(
        todoColor({'due_at': local.toIso8601String()}, local),
        const Color(0xFF17191C),
      );
      expect(
        todoColor({...due(-1), 'is_done': 1}, local),
        const Color(0xFF9AA2AD),
      );
      expect(todoColor({}, local), const Color(0xFF9AA2AD));
      expect(todoColor(due(-1), local, dark: true), const Color(0xFF6B727E));
    },
  );
  test('Exactly four pulse rates with explicit deadline boundaries', () {
    expect(todoPulseMilliseconds(task(), now), 0);
    expect(
      todoPulseMilliseconds(
        task(left: const Duration(days: 2), done: true),
        now,
      ),
      0,
    );
    expect(
      todoPulseMilliseconds(task(left: const Duration(days: 1)), now),
      3200,
    );
    expect(
      todoPulseMilliseconds(task(left: const Duration(hours: 23)), now),
      2200,
    );
    expect(
      todoPulseMilliseconds(task(left: const Duration(hours: 1)), now),
      2200,
    );
    expect(
      todoPulseMilliseconds(task(left: const Duration(minutes: 59)), now),
      1400,
    );
    expect(todoPulseMilliseconds(task(left: Duration.zero), now), 800);
    expect(
      todoPulseMilliseconds(task(left: const Duration(days: -20)), now),
      800,
    );
  });
  test('Time filters exclude completed, missing and expired deadlines', () {
    final soon = task(left: const Duration(minutes: 30));
    expect(matchesTodoFilter(soon, 'todoHour', now), isTrue);
    expect(matchesTodoFilter(soon, 'todoDay', now), isTrue);
    expect(
      matchesTodoFilter(task(left: const Duration(hours: 1)), 'todoHour', now),
      isFalse,
    );
    expect(
      matchesTodoFilter(task(left: const Duration(days: 1)), 'todoDay', now),
      isFalse,
    );
    for (final t in [
      task(),
      task(left: Duration.zero),
      task(left: const Duration(minutes: -1)),
      task(left: const Duration(minutes: 5), done: true),
    ]) {
      expect(matchesTodoFilter(t, 'todoHour', now), isFalse);
      expect(matchesTodoFilter(t, 'todoDay', now), isFalse);
    }
    expect(
      matchesTodoFilter(
        soon,
        'todoOverdue',
        now.add(const Duration(minutes: 30)),
      ),
      isTrue,
    );
    expect(matchesTodoFilter(task(done: true), 'todoDone', now), isTrue);
    expect(matchesTodoFilter(task(), 'todoDone', now), isFalse);
    expect(todoIsOverdue({'due_at': 'invalid'}, now), isFalse);
    expect(
      matchesTodoFilter(
        {'due_at': '2026-09-18T17:30:00+05:00'},
        'todoHour',
        now,
      ),
      isTrue,
    );
  });
  test('Smart folders include nested tasks; edits preserve their parent and trash stays excluded', () async {
    databaseFactory = createDatabaseFactoryFfi(ffiInit: initializeTestSqlite);
    final dir = await Directory.systemTemp.createTemp('bilga-smart-folders-');
    final db = await TodoDatabase.openAt('${dir.path}/todos.db');
    try {
      final repo = CollectionRepository(CollectionKind.todos, provided: db);
      for (final id in ['outer', 'inner']) {
        await db.insert('todo_folders', {
          'id': id,
          'name': id,
          'parent_id': id == 'inner' ? 'outer' : null,
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        });
      }
      for (final id in ['root', 'nested', 'deleted']) {
        await db.insert('todos', {
          'id': id,
          'title': id,
          'folder_id': id == 'root' ? null : 'inner',
          ...task(left: const Duration(minutes: 30)),
          'is_deleted': id == 'deleted' ? 1 : 0,
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        });
      }
      expect((await repo.load()).items.map((r) => r['id']), ['root']);
      expect(
        (await repo.load(folderId: 'outer')).folders.single['id'],
        'inner',
      );
      final smart = await repo.load(folderId: 'outer', filter: 'todoHour');
      expect(smart.folders, isEmpty);
      expect(smart.items.map((r) => r['id']).toSet(), {'root', 'nested'});
      expect(
        smart.items.every((r) => matchesTodoFilter(r, 'todoHour', now)),
        isTrue,
      );
      final nested = smart.items.firstWhere((r) => r['id'] == 'nested');
      expect(nested['folder_id'], 'inner');
      // The editor writes the original map: no synthetic SQL columns may leak in.
      await db.update(
        'todos',
        {...nested, 'title': 'Edited'},
        where: 'id = ?',
        whereArgs: ['nested'],
      );
      await repo.setField('nested', 'is_done', 1);
      final done = (await repo.load(filter: 'todoDone')).items
          .where((r) => matchesTodoFilter(r, 'todoDone', now));
      expect(done.single['folder_id'], 'inner');
      expect(done.single['completed_at'], isNotNull);
      expect(
        (await repo.load(
          filter: 'todoAll',
          query: 'Edited',
        )).items.single['id'],
        'nested',
      );
      expect(await db.getVersion(), 11);
    } finally {
      await db.close();
      await dir.delete(recursive: true);
    }
  });
  testWidgets(
    'Completed badges and reduced motion do not keep a ticker running',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TodoStatusIndicator(
            color: Colors.green,
            interval: 800,
            overdue: false,
            completed: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: TodoStatusIndicator(
              color: Colors.black,
              interval: 800,
              overdue: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
