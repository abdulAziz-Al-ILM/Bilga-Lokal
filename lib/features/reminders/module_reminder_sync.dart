import 'alert_preferences.dart';
import 'attention_repository.dart';
import '../todo/todo_changes.dart';

import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../finance/ledger.dart';
import '../finance/finance_planning.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/settings.dart';
import '../../core/strings.dart';
import '../habits/habit_changes.dart';
import '../habits/habit_store.dart';
import '../habits/habit_schedule.dart';
import '../notes/note_database.dart';

class ModuleReminderBridge {
  static const channel = MethodChannel('bilga/modules');
  static Future<Map<String, dynamic>> state() async {
    try {
      return {
        ...?await channel.invokeMapMethod<String, dynamic>('state'),
        'available': true,
      };
    } on MissingPluginException {
      return {'available': false};
    }
  }

  static Future<void> action(String value) => channel.invokeMethod<void>(value);
}

/// Mirrors only opted-in reminder policy and recent completion dates. No titles,
/// database keys, experiment text or financial values cross this channel.
class ModuleReminderSync extends ChangeNotifier {
  static ModuleReminderSync? active;
  final bool Function() canRead;
  final Database? provided;
  ModuleReminderSync({required this.canRead, this.provided});
  StreamSubscription<void>? _changes, _taskChanges;
  Future<void>? _work;
  bool _dirty = false, _closed = false;
  bool failed = false;
  void start() {
    active = this;
    _changes = HabitChanges.events.listen((_) => unawaited(refresh()));
    _taskChanges = TodoChanges.events.listen((_) => unawaited(refresh()));
    AppSettings.instance.addListener(changed);
    changed();
  }

  void changed() => unawaited(refresh());
  Future<void> refresh() {
    if (_closed) return Future.value();
    _dirty = true;
    return _work ??= _run().whenComplete(() {
      _work = null;
      if (_dirty && !_closed) unawaited(refresh());
    });
  }

  static Future<List<Map<String, dynamic>>> habitRows(
    Database db,
    DateTime now,
  ) async {
    final rows = <Map<String, dynamic>>[],
        today = dayKey(now),
        cutoff = dayKey(DateTime(now.year, now.month, now.day - 399));
    var after = '';
    while (true) {
      final source = await db.query(
        'habits',
        where: "is_archived=0 AND id>? AND json_extract(details,'\$.reminderMinute') IS NOT NULL",
        whereArgs: [after],
        orderBy: 'id',
        limit: 32,
      );
      if (source.isEmpty) break;
      for (final value in source) {
        if (rows.length == 5000) throw const FormatException('reminder_limit');
        after = value['id'] as String;
        final h = Habit.fromMap(value), p = h.plan, minute = p.reminderMinute;
        if (minute == null) continue;
        final windows = <Map<String, dynamic>>[
          {'from': '0001-01-01', 'schedule': p.dayPlan(now).encode()},
        ];
        final future =
            p.schedules.keys.where((k) => k.compareTo(today) > 0).toList()
              ..sort();
        for (final day in future) {
          final value = p.schedules[day];
          final schedule = value is List
              ? HabitSchedule.decode({
                  'weekdays': value,
                  'target': p.legacyTarget ?? p.target,
                })
              : HabitSchedule.decode(Map<String, dynamic>.from(value));
          windows.add({'from': day, 'schedule': schedule.encode()});
        }
        final completed =
            {...h.days, ...p.entries.keys}
                .where(
                  (k) =>
                      HabitSchedule.validDate(k) &&
                      k.compareTo(cutoff) >= 0 &&
                      k.compareTo(today) <= 0 &&
                      p.done(DateTime.parse(k), h.days) &&
                      !p.skipped(DateTime.parse(k)),
                )
                .toList()
              ..sort();
        rows.add({
          'id': 'habit:${h.id}',
          'target': h.id,
          'kind': 'habit',
          'minute': minute,
          'created': dayKey(h.created),
          'windows': windows,
          'completed': completed,
          'config': jsonEncode([minute, dayKey(h.created), windows]),
        });
      }
    }
    return rows;
  }

  static Future<List<Map<String, dynamic>>> financeRows(Database db) async {
    final rows = <Map<String, dynamic>>[];
    var after = '';
    while (true) {
      final source = await db.query(
        'private_records',
        columns: ['id', 'payload'],
        where: "kind='finance' AND id>? AND EXISTS(SELECT 1 FROM json_each(payload,'\$.planning.debts') WHERE json_extract(value,'\$.minute') IS NOT NULL)",
        whereArgs: [after],
        orderBy: 'id',
        limit: 32,
      );
      if (source.isEmpty) break;
      for (final value in source) {
        after = value['id'] as String;
        final data =
            jsonDecode(value['payload'] as String) as Map<String, dynamic>;
        Ledger.validate(data);
        final entries = {for (final e in data['entries']) e['id']: e};
        for (final item
            in (FinancePlanning.plan(data)['debts'] as Map).entries) {
          final debt = entries[item.key], policy = item.value as Map;
          if (policy['minute'] == null ||
              debt['void'] == true ||
              Ledger.outstanding(
                    data,
                    debt,
                    throughDate: policy['date'] as String,
                  ) <=
                  0) {
            continue;
          }
          if (rows.length == 5000) {
            throw const FormatException('reminder_limit');
          }
          final id = sha256
              .convert(utf8.encode(jsonEncode([after, item.key])))
              .toString();
          rows.add({
            'id': 'finance:$id',
            'target': after,
            'kind': 'finance',
            'date': policy['date'],
            'minute': policy['minute'],
            'config': jsonEncode([policy['date'], policy['minute']]),
          });
        }
      }
    }
    return rows;
  }

  static Future<List<Map<String, dynamic>>> attentionRows(
    Database db,
    DateTime now,
    AlertPreferences preferences,
  ) async {
    final rows = await AttentionRepository(notes: db)
        .load(now, preferences, scheduledOnly: true);
    return [
      for (final row in rows)
        {
          'id':
              'alert:${sha256.convert(utf8.encode(jsonEncode([row.kind, row.event, row.id, row.key])))}',
          'target': row.id,
          'kind': row.kind,
          'event': row.event,
          'date': dayKey(row.at),
          'minute': row.at.hour * 60 + row.at.minute,
          'cadence': row.key == 'daily'
              ? 1
              : row.key == 'weekly'
              ? 7
              : 0,
          'at': row.kind == 'task' ? row.at.millisecondsSinceEpoch : 0,
          'immediate': row.immediate,
          'priority': row.priority,
          'config': jsonEncode([
            row.event,
            row.key,
            row.key == 'daily' || row.key == 'weekly'
                ? preferences.eveningMinute
                : row.at.hour * 60 + row.at.minute,
          ]),
        },
    ];
  }

  Future<void> _run() async {
    while (_dirty && !_closed) {
      _dirty = false;
      if (!canRead()) continue;
      try {
        final state = await ModuleReminderBridge.state();
        if (state['available'] != true) {
          failed = false;
          continue;
        }
        final db = provided ?? await NoteDatabase.database;
        final preferences = await AlertPreferences.load();
        final rows = [
          ...await habitRows(db, DateTime.now()),
          ...await financeRows(db),
          ...await attentionRows(db, DateTime.now(), preferences),
        ];
        if (rows.length > 5000) throw const FormatException('reminder_limit');
        if (!canRead() || _closed) continue;
        final language = AppSettings.instance.language;
        await ModuleReminderBridge.channel.invokeMethod<void>('publish', {
          'rows': rows,
          'labels': {
            'habit': Strings.get(language, 'xHabits'),
            'finance': Strings.get(language, 'xFinance'),
            'message': Strings.get(language, 'moduleReminderMessage'),
            for (final event in [
              ...AlertPreferences.types,
              'budgetNear',
              'budgetExceeded',
              'financeDebt',
            ])
              event: Strings.get(language, 'ncEvent$event'),
          },
        });
        failed = false;
      } on MissingPluginException {
        failed = false;
      } catch (_) {
        failed = true;
      }
      if (!_closed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _closed = true;
    _changes?.cancel();
    _taskChanges?.cancel();
    AppSettings.instance.removeListener(changed);
    if (identical(active, this)) active = null;
    super.dispose();
  }
}
