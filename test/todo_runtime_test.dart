import 'package:bilga/features/todo/widget/todo_widget_permissions.dart';

import 'dart:io';

import 'package:bilga/core/app_lock.dart';
import 'package:bilga/core/settings.dart';
import 'package:bilga/core/strings.dart';
import 'package:bilga/features/todo/todo_database.dart';
import 'package:bilga/features/todo/todo_editor_page.dart';
import 'package:bilga/features/todo/recurrence_rule.dart';
import 'package:bilga/features/todo/todo_series_store.dart';
import 'package:bilga/features/todo/todo_checklist_store.dart';
import 'package:bilga/features/collections/collection_repository.dart';
import 'package:bilga/features/todo/reminders/todo_bridge.dart';
import 'package:bilga/features/todo/reminders/todo_host.dart';
import 'package:bilga/features/todo/reminders/todo_reminder_store.dart';
import 'package:bilga/features/todo/reminders/todo_sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'database_safety_test.dart' show initializeTestSqlite;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late Database db;
  final calls = <MethodCall>[];
  Map<String, dynamic> options = {}, widgets = {};
  Map<String, dynamic>? launch;
  List<Map<String, dynamic>> events = [];
  setUp(() async {
    databaseFactory = createDatabaseFactoryFfi(ffiInit: initializeTestSqlite);
    directory = await Directory.systemTemp.createTemp('bilga-todo-runtime-');
    db = await TodoDatabase.openAt('${directory.path}/todo.db');
    await Strings.load(code: 'en');
    AppSettings.instance.language = 'en';
    AppSettings.instance.appLock = false;
    calls.clear();
    options = {};
    widgets = {};
    events = [];
    launch = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(TodoBridge.channel, (call) async {
          calls.add(call);
          switch (call.method) {
            case 'state':
              return {'settings': options, 'widgets': widgets};
            case 'events':
              return events;
            case 'consumeLaunch':
              final l = launch;
              launch = null;
              return l;
          }
          return null;
        });
    await db.insert('todos', {
      'id': 'a',
      'title': 'Synthetic task',
      'description': 'original',
      'due_at': '2030-03-15T10:00:00',
      'created_at': '2026-01-01',
      'updated_at': '2026-01-01',
    });
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(TodoBridge.channel, null);
    await db.close();
    await directory.delete(recursive: true);
  });
  test('Default native mirror contains no task titles; consent and AppLock redaction remain separate', () async {
    var allowed = true;
    final sync = TodoSync(canRead: () => allowed, database: () async => db);
    await sync.refresh();
    Map last() =>
        calls.lastWhere((c) => c.method == 'publish').arguments as Map;
    expect((last()['tasks'] as List).single.containsKey('title'), false);
    options = {'showTitles': true};
    await sync.refresh();
    expect((last()['tasks'] as List).single['title'], 'Synthetic task');
    options = {};
    widgets = {
      '7': {'showTitles': true},
    };
    await sync.refresh();
    expect((last()['tasks'] as List).single.containsKey('title'), false);
    await TodoWidgetPermissions.set(db, (await db.query('todos')).single, true);
    await sync.refresh();
    expect((last()['tasks'] as List).single['title'], 'Synthetic task');
    expect((last()['tasks'] as List).single['widgetAllowed'], true);
    AppSettings.instance.appLock = true;
    await sync.refresh();
    expect(last()['redacted'], true);
    allowed = false;
    calls.clear();
    await sync.refresh();
    expect(calls.map((c) => c.method), ['redact']);
    sync.dispose();
  });
  test('Durable delivery/snooze events reach SQL before ack and native publication', () async {
    await TodoReminderStore.save(db, 'a', DateTime(2030, 3, 15, 10));
    final revision = (await db.query('todo_reminders')).single['revision'];
    events = [
      {
        'eventId': 'e',
        'id': 'a',
        'revision': revision,
        'at': '2030-03-15T10:30:00',
        'kind': 'snooze',
      },
    ];
    final sync = TodoSync(canRead: () => true, database: () async => db);
    await sync.refresh();
    expect((await db.query('todos')).single['due_at'], '2030-03-15T10:00:00');
    expect(
      (await db.query('todo_reminders')).single['remind_at'],
      '2030-03-15T10:30:00.000',
    );
    expect(calls.map((c) => c.method).toList(), [
      'events',
      'ack',
      'state',
      'publish',
    ]);
    expect(calls[1].arguments, ['e']);
    sync.dispose();
  });
  Future<void> settleIo(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }
  }

  Future<List<Map<String, Object?>>> readTodos(WidgetTester tester) async {
    List<Map<String, Object?>>? result;
    Object? error;
    // Keep pumping fake-time callbacks while real FFI I/O completes. Awaiting
    // a second query inside runAsync can otherwise block behind a transaction
    // whose continuation still needs the next widget-test pump.
    db
        .query('todos')
        .then<void>(
          (value) {
            result = value;
          },
          onError: (Object failure) {
            error = failure;
          },
        );
    for (var i = 0; i < 500 && result == null && error == null; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
    }
    if (error != null) throw error!;
    expect(
      result,
      isNotNull,
      reason: 'Task query must finish while widget callbacks are pumped',
    );
    return result!;
  }

  Future<void> openTask(WidgetTester tester, Map<String, Object?> row) async {
    await tester.pumpWidget(
      MaterialApp(
        key: UniqueKey(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => TodoEditorPage(todo: row, database: db),
                ),
              ),
              child: const Text('Open task'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open task'));
    await settleIo(tester);
  }

  testWidgets(
    'Editor adds, reorders and checks subtasks; saving persists progress',
    (tester) async {
      final row = (await readTodos(tester)).single;
      await openTask(tester, row);
      final add = find.byKey(const Key('task-checklist-add'));
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pump();
      await tester.enterText(
        find.byType(TextFormField).first,
        'Prepare material',
      );
      await tester.pump();
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).last, 'Review result');
      await tester.pump();
      await tester.ensureVisible(find.byType(Checkbox).first);
      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();
      await tester.tap(find.byTooltip('Subtask actions').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move down'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Save'));
      await settleIo(tester);
      await tester.runAsync(() async {
        final items = await TodoChecklistStore.load(db, 'a');
        expect(items.map((item) => item.title), [
          'Review result',
          'Prepare material',
        ]);
        expect(items.map((item) => item.done), [false, true]);
        final rows = await CollectionRepository(
          CollectionKind.todos,
          provided: db,
        ).load();
        expect(rows.checklistProgress['a']!.total, 2);
        expect(rows.checklistProgress['a']!.done, 1);
      });
      await openTask(tester, row);
      expect(find.text('Review result'), findsOneWidget);
      expect(tester.widget<Checkbox>(find.byType(Checkbox).last).value, true);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Editor saves custom repeat days and collection completion creates one successor',
    (tester) async {
      final row = (await readTodos(tester)).single;
      await openTask(tester, row);
      await tester.ensureVisible(find.byKey(const Key('task-repeat')));
      await tester.tap(find.byKey(const Key('task-repeat')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Does not repeat').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Weeks').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('repeat-interval')), '2');
      for (final day in ['Friday', 'Monday', 'Wednesday']) {
        final chip = find.widgetWithText(FilterChip, day);
        await tester.ensureVisible(chip);
        await tester.tap(chip);
        await tester.pump();
      }
      final save = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Save'),
      );
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Save'));
      await settleIo(tester);
      expect(find.text('Open task'), findsOneWidget);
      await tester.runAsync(() async {
        final state = (await TodoSeriesStore.forTask(db, 'a'))!;
        final rule = RecurrenceRule.decode(state['rule'] as String);
        expect(rule.interval, 2);
        expect(rule.weekdays, {1, 3});
        final repo = CollectionRepository(CollectionKind.todos, provided: db);
        await repo.setField('a', 'is_done', 1);
        expect(await db.query('todos'), hasLength(2));
        final next = (await db.query('todos', where: 'is_done=0')).single;
        expect(
          DateTime.parse(next['due_at'] as String),
          DateTime(2030, 3, 25, 10),
        );
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Editor occurrence edits stay local; explicit future scope updates the series template',
    (tester) async {
      await tester.runAsync(
        () => db.transaction(
          (txn) => TodoSeriesStore.configure(
            txn,
            'a',
            RecurrenceRule(unit: RecurrenceUnit.day),
          ),
        ),
      );
      var row = (await readTodos(tester)).single;
      await openTask(tester, row);
      Finder titleField() => find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Title',
      );
      await tester.enterText(titleField(), 'One occurrence');
      await tester.tap(find.byTooltip('Save'));
      await settleIo(tester);
      String? next;
      await tester.runAsync(() async {
        next = await TodoSeriesStore(db)
            .setCompleted('a', true, at: DateTime(2030, 3, 15, 11));
        row = (await db.query(
          'todos',
          where: 'id=?',
          whereArgs: [next],
        )).single;
        expect(row['title'], 'Synthetic task');
      });
      await openTask(tester, row);
      await tester.enterText(titleField(), 'Future title');
      final scope = find.byKey(const Key('task-series-scope'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(scope);
      await tester.pumpAndSettle();
      await tester.tap(scope);
      await tester.pump();
      await tester.tap(find.byTooltip('Save'));
      await settleIo(tester);
      await tester.runAsync(() async {
        final future = await TodoSeriesStore(db)
            .setCompleted(next!, true, at: DateTime(2030, 3, 16, 11));
        expect(
          (await db.query(
            'todos',
            where: 'id=?',
            whereArgs: [future],
          )).single['title'],
          'Future title',
        );
        expect(
          (await db.query(
            'todos',
            where: 'id=?',
            whereArgs: ['a'],
          )).single['title'],
          'One occurrence',
        );
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Editor explicitly opts into reminders and saves original deadline separately',
    (tester) async {
      final row = (await readTodos(tester)).single;
      await tester.pumpWidget(
        MaterialApp(
          home: TodoEditorPage(todo: row, database: db),
        ),
      );
      await settleIo(tester);
      final toggle = find.byType(SwitchListTile);
      expect(tester.widget<SwitchListTile>(toggle).value, false);
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await settleIo(tester);
      expect(tester.widget<SwitchListTile>(toggle).value, true);
      await tester.tap(find.byTooltip('Save'));
      await settleIo(tester);
      expect((await readTodos(tester)).single['due_at'], row['due_at']);
      expect(
        (await tester.runAsync(() => db.query('todo_reminders')))!
            .single['enabled'],
        1,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'A stale editor never undoes completion, moves a task back or resurrects trash',
    (tester) async {
      final row = (await readTodos(tester)).single;
      await tester.pumpWidget(
        MaterialApp(
          home: TodoEditorPage(todo: row, database: db),
        ),
      );
      await settleIo(tester);
      await tester.runAsync(
        () => db.update(
          'todos',
          {'is_done': 1, 'folder_id': 'moved'},
          where: 'id=?',
          whereArgs: ['a'],
        ),
      );
      await tester.enterText(find.byType(TextField).first, 'Edited safely');
      await tester.tap(find.byTooltip('Save'));
      await settleIo(tester);
      final current = (await readTodos(tester)).single;
      expect(current['is_done'], 1);
      expect(current['folder_id'], 'moved');
      expect(current['title'], 'Edited safely');
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Changing a deadline keeps the independently selected reminder time',
    (tester) async {
      await tester.runAsync(
        () => TodoReminderStore.save(db, 'a', DateTime(2030, 4, 15, 10)),
      );
      final row = (await readTodos(tester)).single;
      await tester.pumpWidget(
        MaterialApp(
          home: TodoEditorPage(todo: row, database: db),
        ),
      );
      await settleIo(tester);
      await tester.ensureVisible(find.text(Strings.get('en', 'due')));
      await tester.tap(find.text(Strings.get('en', 'due')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Switch to text input mode'));
      await tester.pumpAndSettle();
      final minute = find
          .descendant(
            of: find.byType(TimePickerDialog),
            matching: find.byType(TextField),
          )
          .last;
      await tester.enterText(minute, '30');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Save'));
      await settleIo(tester);
      final after = (await readTodos(tester)).single;
      final reminder = (await tester.runAsync(
        () => db.query('todo_reminders'),
      ))!.single;
      expect(after['due_at'], '2030-03-15T10:30:00.000');
      expect(reminder['remind_at'], '2030-04-15T10:00:00.000');
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'New deadline enables reminder once; explicit OFF survives later deadline selection',
    (tester) async {
      await tester.pumpWidget(MaterialApp(home: TodoEditorPage(database: db)));
      await settleIo(tester);
      await tester.enterText(
        find.byType(TextField).first,
        'New scheduled synthetic',
      );
      Future<void> pickDeadline() async {
        await tester.ensureVisible(find.text(Strings.get('en', 'due')));
        await tester.tap(find.text(Strings.get('en', 'due')));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Switch to input'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.descendant(
            of: find.byType(DatePickerDialog),
            matching: find.byType(TextField),
          ),
          '04/15/2030',
        );
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
      }

      await pickDeadline();
      final toggle = find.byType(SwitchListTile);
      expect(tester.widget<SwitchListTile>(toggle).value, true);
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await settleIo(tester);
      await pickDeadline();
      expect(tester.widget<SwitchListTile>(toggle).value, false);
      await tester.tap(find.byTooltip('Save'));
      await settleIo(tester);
      final created = (await tester.runAsync(
        () => db.query(
          'todos',
          where: 'title=?',
          whereArgs: ['New scheduled synthetic'],
        ),
      ))!.single;
      expect(created['due_at'], isNotNull);
      expect(
        await tester.runAsync(
          () => db.query(
            'todo_reminders',
            where: 'todo_id=?',
            whereArgs: [created['id']],
          ),
        ),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Cached-engine channel rebind retries SQL sync and consumes queued creation',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AppLockScope(
            locked: false,
            child: TodoHost(
              database: () async => db,
              child: const Scaffold(body: Text('Home')),
            ),
          ),
        ),
      );
      await settleIo(tester);
      calls.clear();
      tester.binding.channelBuffers.push(
        TodoBridge.channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('changed'),
        ),
        (_) {},
      );
      await settleIo(tester);
      expect(calls.any((call) => call.method == 'publish'), isTrue);
      launch = {'action': 'create', 'widgetId': 7};
      tester.binding.channelBuffers.push(
        TodoBridge.channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('launch'),
        ),
        (_) {},
      );
      await settleIo(tester);
      expect(find.byType(TodoEditorPage), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Widget completion waits behind AppLock and then requires explicit confirmation',
    (tester) async {
      launch = {'action': 'done', 'id': 'a', 'widgetId': 7};
      Widget app(bool locked) => MaterialApp(
        home: AppLockScope(
          locked: locked,
          child: TodoHost(
            database: () async => db,
            child: const Scaffold(body: Text('Home')),
          ),
        ),
      );
      await tester.pumpWidget(app(true));
      await settleIo(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect((await readTodos(tester)).single['is_done'], 0);
      await tester.pumpWidget(app(false));
      await settleIo(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect((await readTodos(tester)).single['is_done'], 0);
      await tester.tap(find.text(Strings.get('en', 'continue')));
      await settleIo(tester);
      expect((await readTodos(tester)).single['is_done'], 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
