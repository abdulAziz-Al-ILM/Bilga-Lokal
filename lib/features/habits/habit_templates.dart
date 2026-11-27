import 'habit_plan.dart';

/// Bundled suggestions, never database fixtures. Every use starts a new draft.
class HabitTemplate {
  final String id, category, unit;
  final int target;
  final Set<int> weekdays;
  const HabitTemplate(
    this.id,
    this.category, {
    this.target = 1,
    this.unit = '',
    this.weekdays = const {1, 2, 3, 4, 5, 6, 7},
  });
  HabitPlan plan(String Function(String) tr) => HabitPlan(
    weekdays: Set<int>.from(weekdays),
    target: target,
    unit: unit.isEmpty ? '' : tr(unit),
    reason: tr('htWhy_$id'),
  );
}

const habitTemplates = <HabitTemplate>[
  HabitTemplate('water', 'health', target: 6, unit: 'htGlasses'),
  HabitTemplate('walk', 'health', target: 10, unit: 'htMinutes'),
  HabitTemplate('exercise', 'health', weekdays: {1, 3, 5}),
  HabitTemplate('sleep', 'health'),
  HabitTemplate('stretch', 'health', target: 5, unit: 'htMinutes'),
  HabitTemplate('read', 'learning', target: 15, unit: 'htMinutes'),
  HabitTemplate('math', 'learning', target: 20, unit: 'htMinutes'),
  HabitTemplate('language', 'learning', target: 10, unit: 'htMinutes'),
  HabitTemplate('lessons', 'learning'),
  HabitTemplate(
    'study',
    'learning',
    target: 25,
    unit: 'htMinutes',
    weekdays: {1, 2, 3, 4, 5},
  ),
  HabitTemplate('plan', 'productivity'),
  HabitTemplate('important', 'productivity'),
  HabitTemplate('distractions', 'productivity'),
  HabitTemplate('desk', 'home'),
  HabitTemplate('tidy', 'home', target: 5, unit: 'htMinutes'),
  HabitTemplate('journal', 'development'),
  HabitTemplate('reflect', 'reflection', target: 3, unit: 'htMinutes'),
  HabitTemplate('skill', 'development', target: 15, unit: 'htMinutes'),
  HabitTemplate('expenses', 'finance'),
  HabitTemplate('budget', 'finance', weekdays: {7}),
  HabitTemplate('quiet', 'reflection', target: 5, unit: 'htMinutes'),
  HabitTemplate('rest', 'wellbeing'),
];
