import 'package:bilga/features/books/reading/reading_clock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Clock splits monotonic active time at local midnight and excludes inactive gaps', () {
    final c = ReadingClock(DateTime(2026, 11, 14, 23, 59, 50));
    c.sample(DateTime(2026, 11, 15, 0, 0, 10), const Duration(seconds: 20));
    expect(c.days['2026-11-14']!.seconds, 10);
    expect(c.days['2026-11-15']!.seconds, 10);
    c.sample(DateTime(2026, 11, 15, 8), Duration.zero);
    expect(c.days['2026-11-15']!.seconds, 10);
    c.sample(DateTime(2026, 11, 15, 8, 0, 5), const Duration(seconds: 5));
    expect(c.days['2026-11-15']!.seconds, 15);
  });
  test('Clock preserves fractional seconds and caps credit at real positive wall span', () {
    final t = DateTime(2026, 11, 15, 12);
    final c = ReadingClock(t);
    for (var i = 1; i <= 4; i++) {
      c.sample(
        t.add(Duration(milliseconds: 250 * i)),
        const Duration(milliseconds: 250),
      );
    }
    expect(c.days.values.single.seconds, 1);
    c.sample(t, const Duration(hours: 1));
    expect(c.days.values.single.seconds, 1);
    c.sample(t.add(const Duration(seconds: 1)), const Duration(hours: 1));
    expect(c.days.values.single.seconds, 2);
  });
}
