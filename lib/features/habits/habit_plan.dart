import 'dart:convert';

import 'habit_rules.dart';

/// Local-calendar dates, never elapsed 24-hour durations (DST safe).
class HabitPlan {
  final Set<int> weekdays;
  final int target;
  final String unit, cue, reason, minimum;
  final Map<String, dynamic> entries, schedules;
  HabitPlan({
    Set<int>? weekdays,
    this.target = 1,
    this.unit = '',
    this.cue = '',
    this.reason = '',
    this.minimum = '',
    Map<String, dynamic>? entries,
    Map<String, dynamic>? schedules,
  }) : weekdays = weekdays ?? {1, 2, 3, 4, 5, 6, 7},
       entries = entries ?? {},
       schedules = schedules ?? {};
  factory HabitPlan.decode(String text) {
    final data = jsonDecode(text);
    if (data is! Map) throw const FormatException('habit_plan');
    final days = data['weekdays'] ?? [1, 2, 3, 4, 5, 6, 7];
    final target = data['target'] ?? 1;
    final entries = data['entries'] ?? <String, dynamic>{};
    final schedules = data['schedules'] ?? <String, dynamic>{};
    if (schedules is! Map ||
        schedules.entries.any(
          (e) =>
              DateTime.tryParse('${e.key}') == null ||
              e.value is! List ||
              (e.value as List).isEmpty ||
              (e.value as List).any((d) => d is! int || d < 1 || d > 7),
        )) {
      throw const FormatException('habit_schedule');
    }
    if (days is! List ||
        days.isEmpty ||
        days.any((d) => d is! int || d < 1 || d > 7) ||
        target is! int ||
        target < 1 ||
        target > 1000000 ||
        entries is! Map ||
        entries.length > 50000) {
      throw const FormatException('habit_plan');
    }
    for (final k in ['unit', 'cue', 'reason', 'minimum']) {
      if (data[k] != null &&
          (data[k] is! String || (data[k] as String).length > 2000)) {
        throw const FormatException('habit_text');
      }
    }
    for (final e in entries.entries) {
      final date = DateTime.tryParse('${e.key}');
      final v = e.value;
      if (date == null ||
          dayKey(date) != e.key ||
          v is! Map ||
          v['amount'] is! int ||
          v['amount'] < 0 ||
          v['amount'] > 1000000 ||
          v['target'] is! int ||
          v['target'] < 1 ||
          v['target'] > 1000000 ||
          v['skipped'] is! bool ||
          v['note'] is! String ||
          (v['note'] as String).length > 2000) {
        throw const FormatException('habit_entry');
      }
    }
    return HabitPlan(
      weekdays: Set<int>.from(days),
      target: target,
      unit: data['unit'] ?? '',
      cue: data['cue'] ?? '',
      reason: data['reason'] ?? '',
      minimum: data['minimum'] ?? '',
      entries: Map<String, dynamic>.from(entries),
      schedules: Map<String, dynamic>.from(schedules),
    );
  }
  String encode() => jsonEncode({
    'weekdays': weekdays.toList()..sort(),
    'target': target,
    'unit': unit,
    'cue': cue,
    'reason': reason,
    'minimum': minimum,
    'entries': entries,
    'schedules': schedules,
  });
  bool scheduled(DateTime day) {
    final keys =
        schedules.keys.where((k) => k.compareTo(dayKey(day)) <= 0).toList()
          ..sort();
    return keys.isEmpty
        ? weekdays.contains(day.weekday)
        : (schedules[keys.last] as List).contains(day.weekday);
  }

  int amount(DateTime day, Set<String> legacy) =>
      (entries[dayKey(day)]?['amount'] as int?) ??
      (legacy.contains(dayKey(day)) ? target : 0);
  bool done(DateTime day, Set<String> legacy) {
    final e = entries[dayKey(day)];
    return e == null
        ? legacy.contains(dayKey(day))
        : !e['skipped'] && e['amount'] >= e['target'];
  }

  bool skipped(DateTime day) => entries[dayKey(day)]?['skipped'] == true;
  int streak(Set<String> legacy, DateTime now) {
    var day = DateTime(now.year, now.month, now.day), count = 0;
    // Today remains open; unplanned days never break a streak.
    if (!done(day, legacy)) day = DateTime(day.year, day.month, day.day - 1);
    for (var i = 0; i < 36500; i++) {
      if (scheduled(day)) {
        if (skipped(day)) {
          /* A deliberate pause neither earns nor removes progress. */
        } else if (done(day, legacy)) {
          count++;
        } else {
          break;
        }
      }
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return count;
  }
}
