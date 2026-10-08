import 'package:flutter/material.dart';

import 'todo_rules.dart';
export 'todo_rules.dart';

/// Presentation only. Persisted priority values and database schema stay intact.
const todoPriorityColors = <Color>[
  Color(0xFF32A66A), // low
  Color(0xFF398CE5), // medium
  Color(0xFFE5B82F), // high
  Color(0xFFE45458), // critical
];

Color todoColor(Map<String, Object?> row, DateTime now) {
  if (row['is_done'] == 1) return todoPriorityColors.first;
  if (todoIsOverdue(row, now)) return const Color(0xFF17191C);
  return todoPriorityColors[(row['priority'] as int? ?? 0).clamp(0, 3)];
}
