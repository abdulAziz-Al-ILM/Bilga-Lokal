import 'package:bilga/features/todo/recurrence_rule.dart';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

/// Run with TZ=America/New_York using the host's real timezone database.
void main() {
  check(
    DateTime(2026, 1).timeZoneOffset == const Duration(hours: -5),
    'Run this check with TZ=America/New_York',
  );
  final daily = RecurrenceRule(unit: RecurrenceUnit.day);
  final spring = DateTime(2026, 3, 7, 9);
  final springNext = daily.next(spring, after: spring)!;
  check(
    springNext.hour == 9 &&
        springNext.day == 8 &&
        springNext.difference(spring) == const Duration(hours: 23),
    'Spring schedule drifted',
  );
  final autumn = DateTime(2026, 10, 31, 9);
  final autumnNext = daily.next(autumn, after: autumn)!;
  check(
    autumnNext.hour == 9 &&
        autumnNext.day == 1 &&
        autumnNext.difference(autumn) == const Duration(hours: 25),
    'Autumn schedule drifted',
  );
  final missingHour = DateTime(2026, 3, 7, 2, 30);
  final normalized = daily.next(missingHour, after: missingHour)!;
  check(
    normalized.day == 8 && normalized.hour == 3 && normalized.minute == 30,
    'Nonexistent local time did not normalize forward',
  );
  final restoredHour = daily.next(missingHour, after: normalized)!;
  check(
    restoredHour.day == 9 &&
        restoredHour.hour == 2 &&
        restoredHour.minute == 30,
    'Gap normalization changed the series anchor',
  );
  final repeatedHour = DateTime(2026, 10, 31, 1, 30);
  final overlap = daily.next(repeatedHour, after: repeatedHour)!;
  check(
    overlap.day == 1 && daily.next(repeatedHour, after: overlap)!.day == 2,
    'Ambiguous local hour generated a duplicate occurrence',
  );
  // ignore: avoid_print
  print('PASS real New York timezone: 23/25-hour days, DST gap and overlap');
}
