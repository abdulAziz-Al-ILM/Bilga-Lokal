import 'package:bilga/core/settings.dart';
import 'package:bilga/features/agent/agent_access.dart';
import 'package:bilga/features/todo/reminders/todo_bridge.dart';
import 'package:bilga/features/todo/reminders/todo_reminder_store.dart';
import 'package:bilga/features/todo/reminders/todo_sync.dart';
import 'package:bilga/features/todo/todo_database.dart';
import 'package:bilga/features/todo/todo_model.dart';
import 'package:bilga/features/todo/todo_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'review_guard.dart';

void registerNotificationCases(IntegrationTestWidgetsFlutterBinding binding) {
  testWidgets(
    'Real quiet notification delivers, snoozes and completes through its native action',
    (tester) async {
      await requireReviewPackage();
      expect(AppSettings.instance.appLock, isFalse);
      expect(AgentAccess.instance.coreAllowed, isTrue);
      final state = await TodoBridge.state();
      expect(
        state['notifications'],
        isTrue,
        reason: 'Review notifications must be allowed on the tablet',
      );
      final originalSettings = Map<String, dynamic>.from(
        state['settings'] as Map,
      );
      final db = await TodoDatabase.database;
      final id =
          'bilga-review-notification-${DateTime.now().microsecondsSinceEpoch}';
      final sync = TodoSync(canRead: () => true);
      Future<bool> visible() async =>
          await TodoBridge.channel.invokeMethod<bool>('reviewNotification', {
            'tag': id,
            'operation': 'exists',
          }) ??
          false;
      Future<void> waitFor(Future<bool> Function() condition) async {
        final deadline = DateTime.now().add(const Duration(seconds: 90));
        while (!await condition() && DateTime.now().isBefore(deadline)) {
          await tester.pump(const Duration(milliseconds: 500));
        }
        expect(await condition(), isTrue);
      }

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: Text('Synthetic reminder verification')),
          ),
        ),
      );
      try {
        await TodoBridge.channel.invokeMethod<void>('settings', {
          ...originalSettings,
          'enabled': true,
          'sound': false,
          'overlay': false,
          'showTitles': false,
        });
        final now = DateTime.now(),
            due = DateTime.now().add(const Duration(seconds: 8));
        await TodoService(database: db).addTodo(
          Todo(
            id: id,
            title: 'Synthetic tablet reminder',
            isDone: false,
            dueAt: due,
            createdAt: now,
            updatedAt: now,
          ),
        );
        await TodoReminderStore.save(db, id, due);
        await sync.refresh();
        await waitFor(visible);
        await sync.refresh();
        expect(
          (await db.query(
            'todo_reminders',
            where: 'todo_id=?',
            whereArgs: [id],
          )).single['fired'],
          1,
        );

        final snoozed = DateTime.now().add(const Duration(seconds: 8));
        expect(
          await TodoBridge.channel.invokeMethod<bool>('snooze', {
            'id': id,
            'at': snoozed.toIso8601String(),
          }),
          isTrue,
        );
        expect(await visible(), isFalse);
        await sync.refresh();
        final reminder = (await db.query(
          'todo_reminders',
          where: 'todo_id=?',
          whereArgs: [id],
        )).single;
        expect(DateTime.parse(reminder['remind_at'] as String), snoozed);
        expect(reminder['fired'], 0);
        await waitFor(visible);
        expect(
          await TodoBridge.channel.invokeMethod<bool>('reviewNotification', {
            'tag': id,
            'operation': 'complete',
          }),
          isTrue,
        );
        await waitFor(
          () async =>
              (await db.query(
                'todos',
                where: 'id=?',
                whereArgs: [id],
              )).single['is_done'] ==
              1,
        );
        expect(await visible(), isFalse);
        expect(
          await db.query('todo_reminders', where: 'todo_id=?', whereArgs: [id]),
          isEmpty,
        );
        binding.reportData = {
          ...?binding.reportData,
          'notification': {
            'realDelivery': true,
            'snoozeDelivery': true,
            'nativePendingIntentCompletion': true,
            'exactPermission': state['exact'],
            'sound': false,
          },
        };
        expect(tester.takeException(), isNull);
      } finally {
        await db.delete('todos', where: 'id=?', whereArgs: [id]);
        await sync.refresh();
        await TodoBridge.channel.invokeMethod<void>(
          'settings',
          originalSettings,
        );
        await sync.refresh();
        sync.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );
}
