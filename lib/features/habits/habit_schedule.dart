import 'dart:math' as math;

import 'habit_rules.dart';

/// Local-calendar scheduling. Period quotas count completed days, not imaginary
/// check-ins. This pure model is wired through HabitPlan in the next step.
class HabitSchedule {
  final String type;
  final Set<int> weekdays;
  final int interval, quota, target;
  final String? start, end;
  final List<({String from, String until})> pauses;
  const HabitSchedule._(
    this.type,
    this.weekdays,
    this.interval,
    this.quota,
    this.target,
    this.start,
    this.end,
    this.pauses,
  );
  static bool validDate(Object? value) {
    if (value is! String) return false;
    final d = DateTime.tryParse(value);
    return d != null && dayKey(d) == value;
  }

  factory HabitSchedule.decode(Map<String, dynamic> data) {
    final type = data['type'] ?? 'weekdays',
        days = data['weekdays'] ?? [1, 2, 3, 4, 5, 6, 7],
        interval = data['interval'] ?? 1,
        quota = data['quota'] ?? 1,
        target = data['target'] ?? 1,
        start = data['start'],
        end = data['end'],
        pauses = data['pauses'] ?? [];
    if (data['v'] != null && data['v'] != 1 ||
        !['weekdays', 'interval', 'weekly', 'monthly'].contains(type) ||
        days is! List ||
        days.isEmpty ||
        days.any((v) => v is! int || v < 1 || v > 7) ||
        days.toSet().length != days.length ||
        interval is! int ||
        interval < 1 ||
        interval > 365 ||
        quota is! int ||
        quota < 1 ||
        quota > (type == 'weekly' ? 7 : 31) ||
        target is! int ||
        target < 1 ||
        target > 1000000 ||
        start != null && !validDate(start) ||
        end != null && !validDate(end) ||
        start != null &&
            end != null &&
            (start as String).compareTo(end as String) > 0 ||
        type == 'interval' && start == null ||
        pauses is! List ||
        pauses.length > 100) {
      throw const FormatException('habit_schedule');
    }
    final ranges = <({String from, String until})>[];
    for (final p in pauses) {
      if (p is! Map ||
          !validDate(p['from']) ||
          !validDate(p['until']) ||
          (p['from'] as String).compareTo(p['until']) > 0) {
        throw const FormatException('habit_pause');
      }
      ranges.add((from: p['from'] as String, until: p['until'] as String));
    }
    return HabitSchedule._(
      type,
      Set.unmodifiable(days.cast<int>()),
      interval,
      quota,
      target,
      start,
      end,
      List.unmodifiable(ranges),
    );
  }
  Map<String, dynamic> encode() => {
    'v': 1,
    'type': type,
    'weekdays': weekdays.toList()..sort(),
    'interval': interval,
    'quota': quota,
    'target': target,
    'start': start,
    'end': end,
    'pauses': [
      for (final p in pauses) {'from': p.from, 'until': p.until},
    ],
  };
  bool paused(DateTime day) {
    final key = dayKey(day);
    return pauses.any(
      (p) => key.compareTo(p.from) >= 0 && key.compareTo(p.until) <= 0,
    );
  }

  bool active(DateTime day) {
    final key = dayKey(day);
    return (start == null || key.compareTo(start!) >= 0) &&
        (end == null || key.compareTo(end!) <= 0) &&
        !paused(day);
  }

  bool planned(DateTime day) {
    if (!active(day)) return false;
    if (type == 'weekdays') return weekdays.contains(day.weekday);
    if (type == 'interval') {
      final s = DateTime.parse(start!);
      final n = DateTime.utc(
        day.year,
        day.month,
        day.day,
      ).difference(DateTime.utc(s.year, s.month, s.day)).inDays;
      return n >= 0 && n % interval == 0;
    }
    return true;
  }

  ({DateTime from, DateTime until}) period(DateTime day) {
    if (type == 'monthly') {
      return (
        from: DateTime(day.year, day.month),
        until: DateTime(day.year, day.month + 1),
      );
    }
    if (type == 'weekly') {
      return (
        from: DateTime(day.year, day.month, day.day - day.weekday + 1),
        until: DateTime(day.year, day.month, day.day - day.weekday + 8),
      );
    }
    return (
      from: DateTime(day.year, day.month, day.day),
      until: DateTime(day.year, day.month, day.day + 1),
    );
  }

  /// A pause or a partial first/final period cannot demand more days than exist.
  int required(DateTime day, {required DateTime created}) {
    final p = period(day);
    var available = 0;
    for (
      var d = p.from;
      d.isBefore(p.until);
      d = DateTime(d.year, d.month, d.day + 1)
    ) {
      if (dayKey(d).compareTo(dayKey(created)) >= 0 && planned(d)) available++;
    }
    return math.min(
      type == 'weekly' || type == 'monthly' ? quota : 1,
      available,
    );
  }

  int completed(
    DateTime day, {
    required DateTime created,
    required DateTime through,
    required bool Function(DateTime) done,
  }) {
    final p = period(day);
    var count = 0;
    for (
      var d = p.from;
      d.isBefore(p.until) && dayKey(d).compareTo(dayKey(through)) <= 0;
      d = DateTime(d.year, d.month, d.day + 1)
    ) {
      if (dayKey(d).compareTo(dayKey(created)) >= 0 && planned(d) && done(d)) {
        count++;
      }
    }
    return count;
  }
}
