// ignore_for_file: avoid_relative_lib_imports, avoid_print
import '../lib/features/habits/habit_plan.dart';
import '../lib/features/habits/habit_rules.dart';
import '../lib/features/finance/ledger.dart';

void require(bool value, String name) {
  if (!value) throw StateError(name);
  print('PASS $name');
}

void rejects(void Function() call, String name) {
  try {
    call();
  } on FormatException {
    print('PASS $name');
    return;
  }
  throw StateError(name);
}

void main() {
  final p = HabitPlan(
    weekdays: {1, 3, 5},
    target: 20,
    unit: 'minutes',
    cue: 'After tea',
    minimum: 'One page',
    reason: 'Learn',
  );
  final round = HabitPlan.decode(p.encode());
  require(
    round.weekdays.length == 3 &&
        round.target == 20 &&
        round.cue == 'After tea',
    'habit plan round trip',
  );
  require(
    round.scheduled(DateTime(2026, 10, 5)) &&
        !round.scheduled(DateTime(2026, 10, 6)),
    'weekday schedule',
  );
  require(
    round.done(DateTime(2026, 10, 5), {'2026-10-05'}),
    'legacy daily completions preserved',
  );
  round.entries['2026-10-05'] = {
    'amount': 5,
    'target': 20,
    'skipped': false,
    'note': 'Small start',
  };
  require(
    !round.done(DateTime(2026, 10, 5), {}) &&
        round.amount(DateTime(2026, 10, 5), {}) == 5,
    'partial progress stays partial',
  );
  round.entries['2026-10-05']['amount'] = 20;
  require(round.done(DateTime(2026, 10, 5), {}), 'target completion');
  round.entries['2026-10-05']['skipped'] = true;
  require(!round.done(DateTime(2026, 10, 5), {}), 'pause is not completion');
  final streak = HabitPlan(weekdays: {1, 3, 5});
  require(
    streak.streak({'2026-10-02'}, DateTime(2026, 10, 5)) == 1,
    'unplanned weekend does not erase streak',
  );
  require(
    streak.streak({'2026-10-02'}, DateTime(2026, 10, 7)) == 0,
    'missed planned day ends streak',
  );
  final history = HabitPlan(
    weekdays: {2},
    schedules: {
      '2026-10-01': [1, 3, 5],
      '2026-10-06': [2],
    },
  );
  require(
    history.scheduled(DateTime(2026, 10, 5)) &&
        history.scheduled(DateTime(2026, 10, 6)),
    'schedule edits retain previous days',
  );
  require(
    HabitPlan.decode(history.encode()).schedules.length == 2,
    'schedule history round trip',
  );
  for (final text in [
    '{"target":0}',
    '{"weekdays":[]}',
    '{"weekdays":[8]}',
    '{"entries":{"2026-02-30":{}}}',
    '{"target":1.5}',
  ]) {
    rejects(() => HabitPlan.decode(text), 'invalid plan rejected: $text');
  }
  require(dayKey(DateTime(2028, 2, 29)) == '2028-02-29', 'leap date retained');
  final ledger = <String, dynamic>{
    'currency': 'USD',
    'entries': [],
    'budgets': {'2026-10': 12345, '2026-11': 0},
  };
  Ledger.validate(ledger);
  require(
    (ledger['budgets'] as Map).length == 2,
    'month-specific budgets accept zero',
  );
  rejects(
    () => Ledger.validate({
      ...ledger,
      'budgets': {'2026-13': 1},
    }),
    'invalid budget month rejected',
  );
  rejects(
    () => Ledger.validate({
      ...ledger,
      'budgets': {'2026-10': -1},
    }),
    'negative budget rejected',
  );
}
