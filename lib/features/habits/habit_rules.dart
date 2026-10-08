String dayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

int habitStreak(Set<String> days, DateTime now) {
  var day = DateTime(now.year, now.month, now.day);
  if (!days.contains(dayKey(day))) {
    day = DateTime(day.year, day.month, day.day - 1);
  }
  var result = 0;
  while (days.contains(dayKey(day))) {
    result++;
    day = DateTime(day.year, day.month, day.day - 1);
  }
  return result;
}
