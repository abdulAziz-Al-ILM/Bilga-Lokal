import 'package:bilga/features/todo/recurrence_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Calendar day intervals preserve original wall fields and skip missed dates', () {
    final rule = RecurrenceRule(unit: RecurrenceUnit.day, interval: 3);
    final anchor = DateTime.utc(2026, 1, 1, 9, 15, 20, 30, 40);
    expect(
      rule.next(anchor, after: anchor),
      DateTime.utc(2026, 1, 4, 9, 15, 20, 30, 40),
    );
    expect(
      rule.next(anchor, after: DateTime.utc(2026, 1, 10, 10)),
      DateTime.utc(2026, 1, 13, 9, 15, 20, 30, 40),
    );
    expect(rule.next(anchor, after: DateTime.utc(2025)), anchor);
  });
  test('Weekly custom weekdays stay in the anchored interval week', () {
    final rule = RecurrenceRule(
      unit: RecurrenceUnit.week,
      interval: 2,
      weekdays: {1, 3},
    );
    final anchor = DateTime.utc(
      2026,
      1,
      6,
      9,
    ); // Tuesday; first occurrence is explicit.
    final wed = rule.next(anchor, after: anchor)!;
    expect(wed, DateTime.utc(2026, 1, 7, 9));
    expect(rule.next(anchor, after: wed), DateTime.utc(2026, 1, 19, 9));
    expect(
      rule.next(anchor, after: DateTime.utc(2026, 1, 20)),
      DateTime.utc(2026, 1, 21, 9),
    );
    expect(
      RecurrenceRule(unit: RecurrenceUnit.week).next(anchor, after: anchor),
      DateTime.utc(2026, 1, 13, 9),
    );
  });
  test('Month-end clamping does not drift the original day', () {
    final rule = RecurrenceRule(unit: RecurrenceUnit.month);
    final anchor = DateTime.utc(2024, 1, 31, 8);
    final feb = rule.next(anchor, after: anchor)!;
    expect(feb, DateTime.utc(2024, 2, 29, 8));
    expect(rule.next(anchor, after: feb), DateTime.utc(2024, 3, 31, 8));
    expect(
      rule.next(anchor, after: DateTime.utc(2025, 2, 1)),
      DateTime.utc(2025, 2, 28, 8),
    );
  });
  test(
    'Yearly leap-day clamping recovers February 29 in the next leap year',
    () {
      final rule = RecurrenceRule(unit: RecurrenceUnit.year);
      final anchor = DateTime.utc(2024, 2, 29, 8);
      expect(rule.next(anchor, after: anchor), DateTime.utc(2025, 2, 28, 8));
      expect(
        rule.next(anchor, after: DateTime.utc(2027, 3)),
        DateTime.utc(2028, 2, 29, 8),
      );
    },
  );
  test('End date includes the final calendar day and stops afterward', () {
    final rule = RecurrenceRule(
      unit: RecurrenceUnit.day,
      until: DateTime.utc(2026, 1, 2),
    );
    final anchor = DateTime.utc(2026, 1, 1, 23);
    expect(rule.next(anchor, after: anchor), DateTime.utc(2026, 1, 2, 23));
    expect(rule.next(anchor, after: DateTime.utc(2026, 1, 2, 23)), isNull);
    expect(
      rule.next(DateTime.utc(2026, 1, 3), after: DateTime.utc(2025)),
      isNull,
    );
    expect(
      RecurrenceRule(unit: RecurrenceUnit.year)
          .next(DateTime.utc(9999), after: DateTime.utc(9999)),
      isNull,
    );
  });
  test(
    'Versioned rule serialization is canonical and owns its weekday set',
    () {
      final input = {5, 1};
      final rule = RecurrenceRule(
        unit: RecurrenceUnit.week,
        weekdays: input,
        until: DateTime.utc(2027),
      );
      input.add(3);
      expect(rule.weekdays, {1, 5});
      expect(RecurrenceRule.decode(rule.encode()).encode(), rule.encode());
      expect(() => rule.weekdays.add(2), throwsUnsupportedError);
    },
  );
  test('Malformed, ambiguous and future rules are rejected', () {
    for (final raw in [
      '{}',
      '[]',
      '{"version":2,"unit":"day","interval":1}',
      '{"version":1,"unit":"day","interval":0}',
      '{"version":1,"unit":"day","interval":true}',
      '{"version":1,"unit":"week","interval":1,"weekdays":[1,1]}',
      '{"version":1,"unit":"day","interval":1,"weekdays":[2]}',
      '{"version":1,"unit":"day","interval":1,"until":"2026-02-31"}',
      '{"version":1,"unit":"day","interval":1,"unknown":true}',
    ]) {
      expect(
        () => RecurrenceRule.decode(raw),
        throwsFormatException,
        reason: raw,
      );
    }
  });
  test('Very late completion advances directly without scanning years of occurrences', () {
    final rule = RecurrenceRule(unit: RecurrenceUnit.day);
    expect(
      rule.next(DateTime.utc(1), after: DateTime.utc(9998, 12, 31, 23)),
      DateTime.utc(9999),
    );
  });
}
