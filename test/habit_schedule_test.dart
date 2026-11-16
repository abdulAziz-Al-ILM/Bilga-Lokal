import 'package:flutter_test/flutter_test.dart';
import 'package:bilga/features/habits/habit_schedule.dart';
import 'package:bilga/features/habits/habit_rules.dart';

void main() {
  test(
    'Interval scheduling uses calendar dates across DST and leap boundaries',
    () {
      final s = HabitSchedule.decode({
        'type': 'interval',
        'interval': 2,
        'start': '2024-02-28',
        'end': '2024-03-10',
      });
      expect(s.planned(DateTime(2024, 2, 28)), isTrue);
      expect(s.planned(DateTime(2024, 2, 29)), isFalse);
      expect(s.planned(DateTime(2024, 3, 1)), isTrue);
      expect(s.planned(DateTime(2024, 3, 11)), isFalse);
      expect(HabitSchedule.decode(s.encode()).encode(), s.encode());
    },
  );
  test(
    'Weekly quota counts only real completed eligible days and excludes pauses',
    () {
      final s = HabitSchedule.decode({
        'type': 'weekly',
        'quota': 3,
        'start': '2026-11-16',
        'pauses': [
          {'from': '2026-11-18', 'until': '2026-11-20'},
        ],
      });
      final created = DateTime(2026, 11, 16),
          days = {'2026-11-16', '2026-11-17', '2026-11-18', '2026-11-21'};
      expect(s.required(created, created: created), 3);
      expect(
        s.completed(
          created,
          created: created,
          through: DateTime(2026, 11, 20),
          done: (d) => days.contains(dayKey(d)),
        ),
        2,
      );
      expect(
        s.completed(
          created,
          created: created,
          through: DateTime(2026, 11, 22),
          done: (d) => days.contains(dayKey(d)),
        ),
        3,
      );
    },
  );
  test('Monthly quota accounts for partial first period, leap February and finite goals', () {
    final s = HabitSchedule.decode({
      'type': 'monthly',
      'quota': 31,
      'start': '2024-02-27',
      'end': '2024-03-02',
    });
    expect(
      s.required(DateTime(2024, 2, 29), created: DateTime(2024, 2, 27)),
      3,
    );
    expect(s.required(DateTime(2024, 3, 1), created: DateTime(2024, 2, 27)), 2);
    expect(s.required(DateTime(2024, 4, 1), created: DateTime(2024, 2, 27)), 0);
  });
  test('Schedules reject invalid dates, inverted pauses and unsupported future versions', () {
    for (final d in [
      {'v': 2},
      {'type': 'interval'},
      {'start': '2026-02-30'},
      {'type': 'weekly', 'quota': 8},
      {
        'weekdays': [1, 1],
      },
      {'start': '2026-11-20', 'end': '2026-11-19'},
      {
        'pauses': [
          {'from': '2026-11-20', 'until': '2026-11-19'},
        ],
      },
    ]) {
      expect(() => HabitSchedule.decode(d), throwsFormatException);
    }
  });
}
