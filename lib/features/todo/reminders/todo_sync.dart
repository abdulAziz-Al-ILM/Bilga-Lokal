import '../../agent/agent_access.dart';
import '../widget/todo_widget_permissions.dart';

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/settings.dart';
import '../../../core/strings.dart';
import '../todo_database.dart';
import '../todo_changes.dart';
import 'todo_bridge.dart';
import 'todo_reminder_store.dart';

class TodoSync {
  final bool Function() canRead;
  final Future<Database> Function() database;
  TodoSync({required this.canRead, Future<Database> Function()? database})
    : database = database ?? (() => TodoDatabase.database);
  StreamSubscription<void>? _changes;
  Future<void>? _work;
  bool _dirty = false, _disposed = false;
  void start() {
    _changes = TodoChanges.events.listen((_) => unawaited(refresh()));
    AppSettings.instance.addListener(changed);
    changed();
  }

  void changed() => unawaited(refresh());
  Future<void> refresh() {
    if (_disposed) return Future.value();
    _dirty = true;
    return _work ??= _run().whenComplete(() => _work = null);
  }

  Future<void> _run() async {
    while (_dirty && !_disposed) {
      _dirty = false;
      try {
        if (!canRead()) {
          await TodoBridge.channel.invokeMethod<void>('redact');
          continue;
        }
        final db = await database();
        final events =
            (await TodoBridge.channel.invokeListMethod<dynamic>('events') ?? [])
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
        await TodoReminderStore(db).applyEvents(events);
        await TodoBridge.channel.invokeMethod<void>(
          'ack',
          events.map((e) => e['eventId']).toList(),
        );
        final state = await TodoBridge.state();
        final options = Map<String, dynamic>.from(
          state['settings'] as Map? ?? {},
        );
        final exportTitles = options['showTitles'] == true;
        final hasSeries = await db.getVersion() >= 10;
        final tasks = await db.transaction((txn) async {
          final grants = await TodoWidgetPermissions.allowed(txn);
          final occurrences = {
            if (hasSeries)
              for (final row in await txn.query('todo_occurrences'))
                row['todo_id']: row,
          };
          final reminders = {
            for (final r in await txn.query(
              'todo_reminders',
              where: 'enabled=1',
            ))
              r['todo_id']: r,
          };
          return [
            for (final task in await TodoReminderStore.active(txn))
              {
                'id': task['id'],
                if (exportTitles || grants[task['id']] == true)
                  'title': task['title'],
                'widgetAllowed': grants[task['id']] == true,
                'version': task['updated_at'],
                'due': task['due_at'],
                'done': task['is_done'] == 1,
                if (occurrences[task['id']] case final occurrence?) ...{
                  'series': occurrence['series_id'],
                  'sequence': occurrence['sequence'],
                },
                if (reminders[task['id']] case final r?
                    when task['is_done'] != 1)
                  'reminder': {
                    'at': r['remind_at'],
                    'revision': r['revision'],
                    'fired': r['fired'] == 1,
                  },
              },
          ];
        });
        if (!canRead() || _disposed) {
          if (!_disposed) await TodoBridge.channel.invokeMethod<void>('redact');
          continue;
        }
        final settings = AppSettings.instance;
        final dark = settings.brightness == Brightness.dark;
        final scheme = bilgaTheme(
          settings.palette,
          dark ? Brightness.dark : Brightness.light,
        ).colorScheme;
        await TodoBridge.channel.invokeMethod<void>('publish', {
          'tasks': tasks,
          'sqlEpoch': state['sqlEpoch'] ?? 0,
          'actionUntil': AgentAccess.instance.corePurchased
              ? DateTime.now()
                    .add(const Duration(days: 7))
                    .millisecondsSinceEpoch
              : AgentAccess.instance.trialActive
              ? DateTime.now().millisecondsSinceEpoch +
                    AgentAccess.instance.trial!.remainingMillis
              : 0,
          'language': settings.language,
          'redacted': settings.appLock,
          'background': scheme.surface.toARGB32(),
          'foreground': scheme.onSurface.toARGB32(),
          'dark': dark,
          'labels': {
            for (final k in [
              ...todoNativeLabels,
              'todoDone',
              'todoOverdue',
              'none',
              'remaining',
              'dayUnit',
            ])
              k: Strings.get(settings.language, k),
          },
        });
      } on MissingPluginException {
        // Android-only. No alternate storage, network or auth bypass.
      } catch (_) {
        try {
          await TodoBridge.channel.invokeMethod<void>('redact');
        } catch (_) {}
      }
    }
  }

  void dispose() {
    _disposed = true;
    unawaited(_changes?.cancel());
    AppSettings.instance.removeListener(changed);
  }
}

const todoNativeLabels = [
  'todos',
  'task',
  'newTask',
  'empty',
  'close',
  'reminderDone',
  'reminderSnooze',
  'reminderMessage',
  'reminderSettings',
  'snooze5',
  'snooze10',
  'snooze30',
  'snooze60',
  'tomorrow',
  'snoozeCustom',
];
