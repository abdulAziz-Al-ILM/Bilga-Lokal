import 'dart:convert';
import 'dart:math' as math;

enum RecurrenceUnit { day, week, month, year }

/// Calendar recurrence anchored to the original due date, never to a clamped
/// February date. Local anchors follow the device's wall clock; UTC anchors
/// remain UTC. Nonexistent/ambiguous local times use the runtime's timezone
/// resolution. No elapsed 24-hour arithmetic is used for local schedules.
class RecurrenceRule {
  final RecurrenceUnit unit;
  final int interval;
  final Set<int> weekdays;
  final DateTime? until;

  factory RecurrenceRule({
    required RecurrenceUnit unit,
    int interval = 1,
    Set<int> weekdays = const {},
    DateTime? until,
  }) {
    if (interval < 1 ||
        interval > 365 ||
        weekdays.any((d) => d < 1 || d > 7) ||
        (unit != RecurrenceUnit.week && weekdays.isNotEmpty) ||
        (until != null && (until.year < 1 || until.year > 9999))) {
      throw const FormatException('recurrence_invalid');
    }
    return RecurrenceRule._(
      unit,
      interval,
      Set.unmodifiable(weekdays),
      until == null ? null : DateTime.utc(until.year, until.month, until.day),
    );
  }

  const RecurrenceRule._(this.unit, this.interval, this.weekdays, this.until);

  factory RecurrenceRule.decode(String encoded) {
    if (encoded.length > 2048) {
      throw const FormatException('recurrence_invalid');
    }
    final data = jsonDecode(encoded);
    if (data is! Map ||
        data['version'] is! int ||
        data['version'] != 1 ||
        data.keys.any(
          (k) =>
              !{'version', 'unit', 'interval', 'weekdays', 'until'}.contains(k),
        )) {
      throw const FormatException('recurrence_invalid');
    }
    final unit = RecurrenceUnit.values
        .where((u) => u.name == data['unit'])
        .firstOrNull;
    final interval = data['interval'];
    final days = data['weekdays'] ?? <dynamic>[];
    if (unit == null ||
        interval is! int ||
        days is! List ||
        days.any((d) => d is! int || d < 1 || d > 7) ||
        days.toSet().length != days.length) {
      throw const FormatException('recurrence_invalid');
    }
    DateTime? until;
    if (data['until'] != null) {
      final raw = data['until'];
      if (raw is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) {
        throw const FormatException('recurrence_invalid');
      }
      until = DateTime.tryParse('${raw}T00:00:00Z');
      if (until == null || dateKey(until) != raw) {
        throw const FormatException('recurrence_invalid');
      }
    }
    return RecurrenceRule(
      unit: unit,
      interval: interval,
      weekdays: Set<int>.from(days),
      until: until,
    );
  }

  String encode() => jsonEncode({
    'version': 1,
    'unit': unit.name,
    'interval': interval,
    if (weekdays.isNotEmpty) 'weekdays': weekdays.toList()..sort(),
    if (until != null) 'until': dateKey(until!),
  });

  RecurrenceRule canonical(DateTime anchor) =>
      unit == RecurrenceUnit.week && weekdays.isEmpty
      ? RecurrenceRule(
          unit: unit,
          interval: interval,
          weekdays: {anchor.weekday},
          until: until,
        )
      : this;
  bool sameSchedule(RecurrenceRule other, {required DateTime anchor}) =>
      canonical(anchor).encode() == other.canonical(anchor).encode();

  static String dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static int _serial(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;

  DateTime? _wall(DateTime anchor, int year, int month, int day) {
    if (year < 1 || year > 9999) return null;
    final last = DateTime.utc(year, month + 1, 0).day;
    final construct = anchor.isUtc ? DateTime.utc : DateTime.new;
    final candidate = construct(
      year,
      month,
      math.min(day, last),
      anchor.hour,
      anchor.minute,
      anchor.second,
      anchor.millisecond,
      anchor.microsecond,
    );
    if (until != null && _serial(candidate) > _serial(until!)) return null;
    return candidate;
  }

  DateTime? _day(DateTime anchor, int serial) {
    final date = DateTime.fromMillisecondsSinceEpoch(
      serial * Duration.millisecondsPerDay,
      isUtc: true,
    );
    return _wall(anchor, date.year, date.month, date.day);
  }

  /// First nominal occurrence strictly after [after]. Passing the completion
  /// time skips missed dates without generating a backlog of duplicate tasks.
  /// Passing the previous due time instead advances exactly one occurrence.
  DateTime? next(DateTime anchor, {required DateTime after}) {
    if (anchor.year < 1 || anchor.year > 9999) {
      throw const FormatException('recurrence_invalid');
    }
    final cutoff = anchor.isUtc ? after.toUtc() : after.toLocal();
    if (cutoff.isBefore(anchor)) {
      return until != null && _serial(anchor) > _serial(until!) ? null : anchor;
    }
    if (cutoff.year > 9999) return null;
    final anchorDay = _serial(anchor), currentDay = _serial(cutoff);
    switch (unit) {
      case RecurrenceUnit.day:
        var period = math.max(0, (currentDay - anchorDay) ~/ interval);
        for (var i = 0; i < 2; i++, period++) {
          final candidate = _day(anchor, anchorDay + period * interval);
          if (candidate == null) return null;
          if (candidate.isAfter(cutoff)) return candidate;
        }
      case RecurrenceUnit.week:
        final week = anchorDay - anchor.weekday + 1;
        final days = (weekdays.isEmpty ? [anchor.weekday] : weekdays.toList())
          ..sort();
        var period = math.max(0, (currentDay - week) ~/ (7 * interval));
        for (var i = 0; i < 2; i++, period++) {
          for (final day in days) {
            final candidate = _day(
              anchor,
              week + period * interval * 7 + day - 1,
            );
            if (candidate == null) return null;
            if (!candidate.isBefore(anchor) && candidate.isAfter(cutoff)) {
              return candidate;
            }
          }
        }
      case RecurrenceUnit.month:
        final first = anchor.year * 12 + anchor.month - 1;
        final current = cutoff.year * 12 + cutoff.month - 1;
        var period = math.max(0, (current - first) ~/ interval);
        for (var i = 0; i < 2; i++, period++) {
          final month = first + period * interval;
          final candidate = _wall(
            anchor,
            month ~/ 12,
            month % 12 + 1,
            anchor.day,
          );
          if (candidate == null) return null;
          if (candidate.isAfter(cutoff)) return candidate;
        }
      case RecurrenceUnit.year:
        var period = math.max(0, (cutoff.year - anchor.year) ~/ interval);
        for (var i = 0; i < 2; i++, period++) {
          final candidate = _wall(
            anchor,
            anchor.year + period * interval,
            anchor.month,
            anchor.day,
          );
          if (candidate == null) return null;
          if (candidate.isAfter(cutoff)) return candidate;
        }
    }
    return null;
  }
}
