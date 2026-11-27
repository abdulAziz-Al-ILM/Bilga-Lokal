import 'dart:convert';

import 'habit_rules.dart';
import 'habit_schedule.dart';

/// Backwards-compatible plans with dated, independently interpreted schedules.
class HabitPlan {
  final Set<int> weekdays;
  final int target;
  final String unit, cue, reason, minimum, category;
  final Map<String, dynamic> entries, schedules;
  final HabitSchedule? schedule;
  final Set<String> tags;
  final bool favorite;
  final int? goalTarget, reminderMinute, legacyTarget;
  final String? goalDate;
  HabitPlan({
    Set<int>? weekdays,
    this.target = 1,
    this.unit = '',
    this.cue = '',
    this.reason = '',
    this.minimum = '',
    this.category = '',
    Map<String, dynamic>? entries,
    Map<String, dynamic>? schedules,
    this.schedule,
    Set<String>? tags,
    this.favorite = false,
    this.goalTarget,
    this.legacyTarget,
    this.goalDate,
    this.reminderMinute,
  }) : weekdays = weekdays ?? {1, 2, 3, 4, 5, 6, 7},
       entries = entries ?? {},
       schedules = schedules ?? {},
       tags = tags ?? {};
  factory HabitPlan.decode(String text) {
    final data = jsonDecode(text);
    if (data is! Map) throw const FormatException('habit_plan');
    if (data['v'] != null && data['v'] != 2) {
      throw const FormatException('habit_version');
    }
    final days = data['weekdays'] ?? [1, 2, 3, 4, 5, 6, 7],
        target = data['target'] ?? 1,
        entries = data['entries'] ?? <String, dynamic>{},
        schedules = data['schedules'] ?? <String, dynamic>{};
    if (days is! List ||
        days.isEmpty ||
        days.any((d) => d is! int || d < 1 || d > 7) ||
        target is! int ||
        target < 1 ||
        target > 1000000 ||
        entries is! Map ||
        entries.length > 50000 ||
        schedules is! Map ||
        schedules.length > 36500) {
      throw const FormatException('habit_plan');
    }
    for (final e in schedules.entries) {
      if (!HabitSchedule.validDate(e.key)) {
        throw const FormatException('habit_schedule');
      }
      final v = e.value;
      if (v is List) {
        if (v.isEmpty || v.any((d) => d is! int || d < 1 || d > 7)) {
          throw const FormatException('habit_schedule');
        }
      } else if (v is Map) {
        HabitSchedule.decode(Map<String, dynamic>.from(v));
      } else {
        throw const FormatException('habit_schedule');
      }
    }
    for (final k in ['unit', 'cue', 'reason', 'minimum', 'category']) {
      if (data[k] != null &&
          (data[k] is! String ||
              (data[k] as String).length > (k == 'category' ? 2048 : 2000))) {
        throw const FormatException('habit_text');
      }
    }
    for (final e in entries.entries) {
      final v = e.value;
      if (!HabitSchedule.validDate(e.key) ||
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
    final legacyTarget = data['legacyTarget'];
    if (legacyTarget != null &&
        (legacyTarget is! int || legacyTarget < 1 || legacyTarget > 1000000)) {
      throw const FormatException('habit_legacy_target');
    }
    final tags = data['tags'] ?? [],
        favorite = data['favorite'] ?? false,
        goal = data['goalTarget'],
        goalDate = data['goalDate'],
        reminder = data['reminderMinute'];
    if (tags is! List ||
        tags.length > 30 ||
        tags.any((t) => t is! String || t.trim().isEmpty || t.length > 80) ||
        tags.toSet().length != tags.length ||
        favorite is! bool ||
        goal != null && (goal is! int || goal < 1 || goal > 1000000) ||
        goalDate != null && !HabitSchedule.validDate(goalDate) ||
        reminder != null &&
            (reminder is! int || reminder < 0 || reminder >= 1440)) {
      throw const FormatException('habit_details');
    }
    final raw = data['schedule'];
    if (raw != null && raw is! Map) {
      throw const FormatException('habit_schedule');
    }
    final schedule = raw == null
        ? null
        : HabitSchedule.decode(Map<String, dynamic>.from(raw));
    if (schedule != null &&
        (schedule.target != target ||
            schedule.weekdays.length != days.toSet().length ||
            !schedule.weekdays.containsAll(days.cast<int>()))) {
      throw const FormatException('habit_schedule_mismatch');
    }
    return HabitPlan(
      weekdays: Set<int>.from(days),
      target: target,
      unit: data['unit'] ?? '',
      cue: data['cue'] ?? '',
      reason: data['reason'] ?? '',
      minimum: data['minimum'] ?? '',
      category: data['category'] ?? '',
      entries: Map<String, dynamic>.from(entries),
      schedules: Map<String, dynamic>.from(schedules),
      schedule: schedule,
      tags: Set<String>.from(tags),
      favorite: favorite,
      goalTarget: goal,
      legacyTarget: legacyTarget,
      goalDate: goalDate,
      reminderMinute: reminder,
    );
  }
  bool get advanced =>
      legacyTarget != null ||
      schedule != null ||
      schedules.values.any((v) => v is Map) ||
      category.isNotEmpty ||
      tags.isNotEmpty ||
      favorite ||
      goalTarget != null ||
      goalDate != null ||
      reminderMinute != null;
  String encode() => jsonEncode({
    'weekdays': weekdays.toList()..sort(),
    'target': target,
    'unit': unit,
    'cue': cue,
    'reason': reason,
    'minimum': minimum,
    'entries': entries,
    'schedules': schedules,
    if (advanced) ...{
      'v': 2,
      if (legacyTarget != null) 'legacyTarget': legacyTarget,
      'category': category,
      'tags': tags.toList()..sort(),
      'favorite': favorite,
      'goalTarget': goalTarget,
      'goalDate': goalDate,
      'reminderMinute': reminderMinute,
      if (schedule != null) 'schedule': schedule!.encode(),
    },
  });
  HabitSchedule get currentSchedule =>
      schedule ??
      HabitSchedule.decode({'weekdays': weekdays.toList(), 'target': target});
  HabitSchedule dayPlan(DateTime day) {
    final keys =
        schedules.keys.where((k) => k.compareTo(dayKey(day)) <= 0).toList()
          ..sort();
    if (keys.isEmpty) return currentSchedule;
    final value = schedules[keys.last];
    return value is List
        ? HabitSchedule.decode({
            'weekdays': value,
            'target': legacyTarget ?? target,
          })
        : HabitSchedule.decode(Map<String, dynamic>.from(value));
  }

  bool scheduled(DateTime day) => dayPlan(day).planned(day);

  /// A completed quota stops offering more required days in the same period.
  /// Keep an already-recorded day visible so it can still be corrected.
  bool due(DateTime day, Set<String> legacy, {required DateTime created}) {
    if (dayKey(day).compareTo(dayKey(created)) < 0 || !scheduled(day)) {
      return false;
    }
    final p = dayPlan(day);
    if (p.type != 'weekly' && p.type != 'monthly') return true;
    final start = p.start == null ? created : DateTime.parse(p.start!);
    return done(day, legacy) ||
        p.completed(
              day,
              created: start,
              through: day,
              done: (d) => !skipped(d) && done(d, legacy),
            ) <
            p.required(day, created: start);
  }

  int targetAt(DateTime day) =>
      entries[dayKey(day)]?['target'] as int? ?? dayPlan(day).target;
  int amount(DateTime day, Set<String> legacy) =>
      entries[dayKey(day)]?['amount'] as int? ??
      (legacy.contains(dayKey(day)) ? targetAt(day) : 0);
  bool done(DateTime day, Set<String> legacy) {
    final e = entries[dayKey(day)];
    return e == null
        ? legacy.contains(dayKey(day))
        : !e['skipped'] && e['amount'] >= e['target'];
  }

  bool skipped(DateTime day) =>
      entries[dayKey(day)]?['skipped'] == true || dayPlan(day).paused(day);
  int completedDays(Set<String> legacy, DateTime through) =>
      {...legacy, ...entries.keys}
          .where(
            (k) =>
                k.compareTo(dayKey(through)) <= 0 &&
                done(DateTime.parse(k), legacy),
          )
          .length;
  HabitPlan copyWith({
    Set<int>? weekdays,
    int? target,
    String? unit,
    String? cue,
    String? reason,
    String? minimum,
  }) {
    final days = weekdays ?? this.weekdays, n = target ?? this.target;
    final data = Map<String, dynamic>.from(jsonDecode(encode()));
    data.addAll({
      'weekdays': days.toList(),
      'target': n,
      'unit': unit ?? this.unit,
      'cue': cue ?? this.cue,
      'reason': reason ?? this.reason,
      'minimum': minimum ?? this.minimum,
    });
    if (schedule != null) {
      data['schedule'] = {
        ...schedule!.encode(),
        'weekdays': days.toList(),
        'target': n,
      };
    }
    return HabitPlan.decode(jsonEncode(data));
  }

  HabitPlan withSchedule(HabitSchedule value) => HabitPlan.decode(
    jsonEncode({
      ...jsonDecode(encode()) as Map<String, dynamic>,
      'v': 2,
      'weekdays': value.weekdays.toList(),
      'target': value.target,
      'schedule': value.encode(),
    }),
  );
  int streak(Set<String> legacy, DateTime now, {DateTime? created}) {
    if (legacy.isEmpty &&
        !entries.values.any(
          (v) => v['skipped'] != true && v['amount'] >= v['target'],
        )) {
      return 0;
    }
    var day = DateTime(now.year, now.month, now.day);
    final current = dayPlan(day);
    var count = 0;
    if (current.type == 'weekly' || current.type == 'monthly') {
      final earliest = created ?? DateTime(1900);
      for (var i = 0; i < 5200; i++) {
        final p = dayPlan(day);
        if (p.type != current.type) break;
        final range = p.period(day);
        if (range.until.isBefore(earliest) ||
            range.until.isAtSameMomentAs(earliest)) {
          break;
        }
        final required = p.required(day, created: earliest),
            doneCount = p.completed(
              day,
              created: earliest,
              through: now,
              done: (d) => !skipped(d) && done(d, legacy),
            );
        if (required > 0) {
          if (doneCount >= required) {
            count++;
          } else {
            final open =
                dayKey(range.until).compareTo(dayKey(now)) > 0 &&
                (p.end == null || p.end!.compareTo(dayKey(now)) >= 0);
            if (i != 0 || !open) break;
          }
        }
        day = DateTime(range.from.year, range.from.month, range.from.day - 1);
      }
      return count;
    }
    if (!done(day, legacy)) day = DateTime(day.year, day.month, day.day - 1);
    for (var i = 0; i < 36500; i++) {
      if (created != null && dayKey(day).compareTo(dayKey(created)) < 0) break;
      final p = dayPlan(day);
      if (p.type == 'weekly' || p.type == 'monthly') break;
      if (scheduled(day) && !skipped(day)) {
        if (done(day, legacy)) {
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
