import 'package:flutter/material.dart';

import '../../features/experiences/experience_model.dart';

/// Actual local-day activity; empty days never receive fabricated values.
class ActivityCalendar extends StatelessWidget {
  final DateTime month;
  final String? selected;
  final Map<String, int> values;
  final ValueChanged<DateTime> onMonth, onDay;
  const ActivityCalendar({
    super.key,
    required this.month,
    required this.values,
    required this.onMonth,
    required this.onDay,
    this.selected,
  });
  @override
  Widget build(BuildContext context) {
    final local = MaterialLocalizations.of(context),
        first = DateTime(month.year, month.month),
        days = DateTime(month.year, month.month + 1, 0).day;
    final offset = (first.weekday % 7 - local.firstDayOfWeekIndex + 7) % 7;
    final names = local.narrowWeekdays;
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: local.previousMonthTooltip,
              onPressed: () => onMonth(DateTime(month.year, month.month - 1)),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                local.formatMonthYear(month),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: local.nextMonthTooltip,
              onPressed: () => onMonth(DateTime(month.year, month.month + 1)),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        Table(
          children: [
            TableRow(
              children: [
                for (var i = 0; i < 7; i++)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      names[(local.firstDayOfWeekIndex + i) % 7],
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
            for (var row = 0; row < (offset + days + 6) ~/ 7; row++)
              TableRow(
                children: [
                  for (var col = 0; col < 7; col++)
                    Builder(
                      builder: (c) {
                        final d = row * 7 + col - offset + 1;
                        if (d < 1 || d > days) {
                          return const SizedBox(height: 52);
                        }
                        final date = DateTime(month.year, month.month, d),
                            key = ExperienceModel.day(date),
                            value = values[key] ?? 0;
                        return Semantics(
                          label: '${local.formatFullDate(date)}: $value',
                          selected: selected == key,
                          button: true,
                          child: InkWell(
                            key: Key('activity-day-$key'),
                            onTap: () => onDay(date),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 52),
                              margin: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: selected == key
                                    ? Theme.of(c).colorScheme.primaryContainer
                                    : value > 0
                                    ? Theme.of(c).colorScheme.secondaryContainer
                                    : null,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(local.formatDecimal(d)),
                                  if (value > 0)
                                    Text(
                                      local.formatDecimal(value),
                                      style: Theme.of(c).textTheme.labelSmall,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
