import 'package:bilga/features/todo/recurrence_rule.dart';
import 'package:bilga/features/todo/reminders/todo_bridge.dart';
import 'package:bilga/features/todo/reminders/todo_reminder_store.dart';
import 'package:bilga/features/todo/reminders/todo_sync.dart';
import 'package:bilga/features/todo/todo_database.dart';
import 'package:bilga/features/todo/todo_model.dart';
import 'package:bilga/features/todo/todo_service.dart';
import 'package:bilga/features/todo/todo_series_store.dart';
import 'package:bilga/features/todo/widget/todo_widget_permissions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';

import 'review_guard.dart';

void registerRecurrenceCases(IntegrationTestWidgetsFlutterBinding binding) {
  testWidgets(
    'Native completion advances the series and delivers its next reminder without Dart publication',
    (tester) async {
      await requireReviewPackage();
      final db = await TodoDatabase.database;
      expect(await db.getVersion(), 10);
      final state = await TodoBridge.state();
      final original = Map<String, dynamic>.from(state['settings'] as Map);
      final id =
          'bilga-review-notification-series-${DateTime.now().microsecondsSinceEpoch}';
      String? seriesId;
      final sync = TodoSync(canRead: () => true);
      Future<T?> probe<T>(String tag, String operation) =>
          TodoBridge.channel.invokeMethod<T>('reviewNotification', {
            'tag': tag,
            'operation': operation,
            'sourceFixture': id,
          });
      Future<void> waitFor(Future<bool> Function() condition) async {
        final end = DateTime.now().add(const Duration(seconds: 90));
        while (!await condition() && DateTime.now().isBefore(end)) {
          await tester.pump(const Duration(milliseconds: 500));
        }
        expect(await condition(), isTrue);
      }

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text('Synthetic recurring reminder verification'),
            ),
          ),
        ),
      );
      try {
        await TodoBridge.channel.invokeMethod<void>('settings', {
          ...original,
          'enabled': true,
          'sound': false,
          'showTitles': false,
          'overlay': false,
        });
        final clock = DateTime.now();
        final due = DateTime(
          clock.year,
          clock.month,
          clock.day + 1,
          clock.hour,
          clock.minute,
          clock.second,
          clock.millisecond,
          clock.microsecond,
        );
        final futureReminder = clock.add(const Duration(seconds: 45));
        final pattern = DateTime(
          futureReminder.year,
          futureReminder.month,
          futureReminder.day - 1,
          futureReminder.hour,
          futureReminder.minute,
          futureReminder.second,
          futureReminder.millisecond,
          futureReminder.microsecond,
        );
        await TodoService(database: db).addTodo(
          Todo(
            id: id,
            title: 'Synthetic recurring reminder',
            isDone: false,
            dueAt: due,
            createdAt: clock,
            updatedAt: clock,
          ),
        );
        await TodoReminderStore.save(db, id, pattern);
        await db.transaction(
          (txn) => TodoSeriesStore.configure(
            txn,
            id,
            RecurrenceRule(unit: RecurrenceUnit.day),
          ),
        );
        seriesId = (await TodoSeriesStore.forTask(db, id))!['id'] as String;
        await TodoWidgetPermissions.set(
          db,
          (await db.query('todos', where: 'id=?', whereArgs: [id])).single,
          true,
        );
        // Override only this occurrence. The series reminder pattern stays intact.
        await TodoReminderStore.save(
          db,
          id,
          clock.add(const Duration(seconds: 8)),
        );
        await sync.refresh();
        await waitFor(() async => await probe<bool>(id, 'exists') == true);
        expect(await probe<bool>(id, 'complete'), isTrue);
        await waitFor(
          () async =>
              (await db.query(
                'todos',
                where: 'id=?',
                whereArgs: [id],
              )).single['is_done'] ==
              1,
        );
        final series = (await TodoSeriesStore.forTask(db, id))!;
        final next = series['head_task_id'] as String;
        expect(next, isNot(id));
        expect(series['current_sequence'], 1);
        expect(
          (await db.query(
            'todo_occurrences',
            where: 'series_id=?',
            whereArgs: [seriesId],
          )),
          hasLength(2),
        );
        expect(
          (await TodoWidgetPermissions.allowed(db)).containsKey(next),
          isFalse,
        );
        final privacy = await probe<Map>(next, 'metadata');
        expect(privacy, {'hasTitle': false, 'widgetAllowed': false});
        // Do not call sync.refresh here: only Android can schedule/post this one.
        await waitFor(() async => await probe<bool>(next, 'exists') == true);
        binding.reportData = {
          ...?binding.reportData,
          'recurrence': {
            'nativeAdvance': true,
            'nextReminderDeliveredWithoutDartRefresh': true,
            'futureWidgetConsentInherited': false,
          },
        };
        expect(tester.takeException(), isNull);
      } finally {
        if (seriesId != null) {
          final occurrences = await db.query(
            'todo_occurrences',
            where: 'series_id=?',
            whereArgs: [seriesId],
          );
          for (final row in occurrences) {
            await db.delete(
              'todos',
              where: 'id=?',
              whereArgs: [row['todo_id']],
            );
          }
          await db.delete('todo_series', where: 'id=?', whereArgs: [seriesId]);
        }
        await db.delete('todos', where: 'id=?', whereArgs: [id]);
        await sync.refresh();
        await TodoBridge.channel.invokeMethod<void>('settings', original);
        await sync.refresh();
        sync.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );
}
