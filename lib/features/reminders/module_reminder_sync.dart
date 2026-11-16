import 'dart:async';
import 'dart:convert';

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
  StreamSubscription<void>? _changes;
  Future<void>? _work;
  bool _dirty = false, _closed = false;
  bool failed = false;
  void start() {
    active = this;
    _changes = HabitChanges.events.listen((_) => unawaited(refresh()));
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
        limit: 1,
      );
      if (source.isEmpty) break;
      if (rows.length == 5000) throw const FormatException('reminder_limit');
      after = source.single['id'] as String;
      final h = Habit.fromMap(source.single),
          p = h.plan,
          minute = p.reminderMinute;
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
    return rows;
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
        final rows = await habitRows(db, DateTime.now());
        if (!canRead() || _closed) continue;
        final language = AppSettings.instance.language;
        await ModuleReminderBridge.channel.invokeMethod<void>('publish', {
          'rows': rows,
          'labels': {
            'habit': Strings.get(language, 'xHabits'),
            'finance': Strings.get(language, 'xFinance'),
            'message': Strings.get(language, 'moduleReminderMessage'),
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
    AppSettings.instance.removeListener(changed);
    if (identical(active, this)) active = null;
    super.dispose();
  }
}
