// ignore_for_file: avoid_print
import 'package:bilga/features/todo/todo_rules.dart';

void require(bool value, String message) {
  if (!value) throw StateError(message);
}

void main() {
  final now = DateTime.utc(2026, 9, 18, 12);
  Map<String, Object?> task(int? seconds, {bool done = false}) => {
    'due_at': seconds == null
        ? null
        : now.add(Duration(seconds: seconds)).toIso8601String(),
    'is_done': done ? 1 : 0,
  };
  const expected = {
    -100: 800,
    0: 800,
    1: 1400,
    3599: 1400,
    3600: 2200,
    86399: 2200,
    86400: 3200,
    90000: 3200,
  };
  for (final entry in expected.entries) {
    require(
      todoPulseMilliseconds(task(entry.key), now) == entry.value,
      'pulse at ${entry.key}',
    );
  }
  require(
    todoPulseMilliseconds(task(null), now) == 0,
    'no deadline must be static',
  );
  require(
    todoPulseMilliseconds(task(-1, done: true), now) == 0,
    'completed must be static',
  );
  for (final seconds in [1, 3599]) {
    require(
      matchesTodoFilter(task(seconds), 'todoHour', now),
      'hour includes $seconds',
    );
  }
  for (final seconds in [0, -1, 3600, 86400]) {
    require(
      !matchesTodoFilter(task(seconds), 'todoHour', now),
      'hour excludes $seconds',
    );
  }
  require(
    matchesTodoFilter(task(86399), 'todoDay', now),
    'day includes future',
  );
  require(
    !matchesTodoFilter(task(86400), 'todoDay', now),
    'day upper boundary',
  );
  require(
    !matchesTodoFilter(task(1, done: true), 'todoDay', now),
    'completed excluded',
  );
  require(
    !matchesTodoFilter(task(null), 'todoDay', now),
    'missing deadline excluded',
  );
  require(matchesTodoFilter(task(-1), 'todoOverdue', now), 'overdue');
  require(
    !matchesTodoFilter(task(-1, done: true), 'todoOverdue', now),
    'completed not overdue',
  );
  require(
    matchesTodoFilter(task(null, done: true), 'todoDone', now),
    'done without deadline',
  );
  require(
    matchesTodoFilter({'due_at': '2026-09-18T17:30:00+05:00'}, 'todoHour', now),
    'timezone',
  );
  require(
    !todoIsOverdue({'due_at': 'invalid'}, now),
    'invalid date must not crash',
  );
  print(
    'PASS deadline boundaries, time zones, completed/overdue filtering and four pulse rates',
  );
}
