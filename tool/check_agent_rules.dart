// ignore_for_file: avoid_print
import 'package:bilga/features/agent/agent_command.dart';
import 'package:bilga/features/habits/habit_rules.dart';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
  print('PASS $message');
}

void main() {
  check(
    parseAgentCommand('create note: Shopping | Milk').argument ==
        'Shopping | Milk',
    'Note arguments retained',
  );
  check(
    parseAgentCommand('создай задачу: Позвонить').action == AgentAction.task,
    'Russian command',
  );
  check(
    parseAgentCommand('kitob o‘qish deb odat yarat').action ==
        AgentAction.habit,
    'Uzbek suffix command',
  );
  check(
    parseAgentCommand('Qo‘ng‘iroq qil: +998901234567').action ==
        AgentAction.call,
    'Uzbek apostrophes',
  );
  check(
    parseAgentCommand('  READ TASKS  ').action == AgentAction.tasks,
    'English case/whitespace',
  );
  check(
    parseAgentCommand('delete all notes').action == AgentAction.unknown,
    'Unknown command cannot delete',
  );
  check(
    parseAgentCommand('noteworthy').action == AgentAction.unknown,
    'Whole command boundary',
  );
  check(
    parseAgentCommand('create note: delete all tasks').argument ==
        'delete all tasks',
    'Content is not executable',
  );
  check(
    safePhone('+998 (90) 123-45-67') == '+998901234567',
    'Phone formatting',
  );
  check(
    safePhone('*123#') == null &&
        safePhone('123?body=secret') == null &&
        safePhone('Mom') == null,
    'Reject service codes and malformed numbers',
  );
  check(
    habitStreak({'2026-08-31', '2026-09-01'}, DateTime(2026, 9, 2)) == 2,
    'Streak across month and yesterday',
  );
  check(
    habitStreak({'2026-08-31', '2026-09-01'}, DateTime(2026, 9, 3)) == 0,
    'Missed day breaks streak',
  );
  check(
    habitStreak({
          '2024-02-28',
          '2024-02-29',
          '2024-03-01',
        }, DateTime(2024, 3, 1)) ==
        3,
    'Leap-day streak',
  );
  check(
    dayKey(DateTime(2026, 1, 2, 23, 59)) == '2026-01-02',
    'Daily identity independent of time',
  );
}
