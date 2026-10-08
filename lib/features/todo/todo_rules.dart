DateTime? todoDue(Map<String, Object?> row) =>
    DateTime.tryParse(row['due_at'] as String? ?? '');

bool todoIsOverdue(Map<String, Object?> row, DateTime now) {
  final due = todoDue(row);
  return row['is_done'] != 1 && due != null && !due.isAfter(now);
}

/// Four gentle half-cycle lengths; no deadline and completed tasks are static.
int todoPulseMilliseconds(Map<String, Object?> row, DateTime now) {
  final due = todoDue(row);
  if (row['is_done'] == 1 || due == null) return 0;
  final left = due.difference(now);
  if (left <= Duration.zero) return 800;
  if (left < const Duration(hours: 1)) return 1400;
  if (left < const Duration(days: 1)) return 2200;
  return 3200;
}

bool matchesTodoFilter(Map<String, Object?> row, String filter, DateTime now) {
  final done = row['is_done'] == 1;
  if (filter == 'todoDone') return done;
  if (filter == 'todoOverdue') return todoIsOverdue(row, now);
  if (filter == 'todoHour' || filter == 'todoDay') {
    final due = todoDue(row);
    if (done || due == null || !due.isAfter(now)) return false;
    final limit = filter == 'todoHour'
        ? const Duration(hours: 1)
        : const Duration(days: 1);
    return due.difference(now) < limit;
  }
  return true;
}
