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

Color todoColor(Map<String, Object?> row, DateTime now, {bool dark = false}) =>
    switch (todoTimeState(row, now)) {
      TodoTimeState.green => const Color(0xFF32A66A),
      TodoTimeState.yellow => const Color(0xFFE5B82F),
      TodoTimeState.red => const Color(0xFFE45458),
      TodoTimeState.overdue =>
        dark ? const Color(0xFF6B727E) : const Color(0xFF17191C),
      TodoTimeState.completed =>
        dark ? const Color(0xFFC5CBD3) : const Color(0xFF9AA2AD),
      TodoTimeState.neutral =>
        dark ? const Color(0xFF89919C) : const Color(0xFF9AA2AD),
    };
