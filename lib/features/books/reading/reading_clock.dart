import 'dart:math' as math;

class ReadingDay {
  final String day;
  final DateTime start;
  DateTime end;
  int microseconds = 0;
  ReadingDay(this.day, this.start, this.end);
  int get seconds => microseconds ~/ Duration.microsecondsPerSecond;
  Map<String, dynamic> get data => {
    'v': 1,
    'day': day,
    'start': start.toUtc().toIso8601String(),
    'end': end.toUtc().toIso8601String(),
    'seconds': seconds,
  };
}

/// The UI supplies monotonic active elapsed time, never wall time as credit.
/// Local midnight splits real reading time into civil-day buckets, including DST.
class ReadingClock {
  DateTime previous;
  final days = <String, ReadingDay>{};
  ReadingClock(this.previous);
  void sample(DateTime now, Duration active) {
    final span = now.difference(previous).inMicroseconds;
    final micros = math.min(
      math.max(0, active.inMicroseconds),
      math.max(0, span),
    );
    if (span > 0 && micros > 0) {
      var cursor = previous, assigned = 0;
      while (cursor.isBefore(now)) {
        final midnight = DateTime(cursor.year, cursor.month, cursor.day + 1);
        final end = midnight.isBefore(now) ? midnight : now;
        final elapsed = end.difference(cursor).inMicroseconds;
        final amount = end == now
            ? micros - assigned
            : (micros * elapsed ~/ span);
        final key = cursor.toIso8601String().substring(0, 10);
        final row = days.putIfAbsent(key, () => ReadingDay(key, cursor, end));
        row.microseconds += amount;
        row.end = end;
        assigned += amount;
        cursor = end;
      }
    }
    previous = now;
  }
}
