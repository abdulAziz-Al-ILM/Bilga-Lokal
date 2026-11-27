import 'package:flutter/material.dart';

import '../../core/strings.dart';
import 'recurrence_rule.dart';

class RecurrenceChoice {
  final RecurrenceRule? rule;
  const RecurrenceChoice(this.rule);
}

String recurrenceUnitKey(RecurrenceUnit unit) => switch (unit) {
  RecurrenceUnit.day => 'repeatDay',
  RecurrenceUnit.week => 'repeatWeek',
  RecurrenceUnit.month => 'repeatMonth',
  RecurrenceUnit.year => 'repeatYear',
};
String recurrenceWeekdayKey(int day) => const [
  'repeatMonday',
  'repeatTuesday',
  'repeatWednesday',
  'repeatThursday',
  'repeatFriday',
  'repeatSaturday',
  'repeatSunday',
][day - 1];

class RecurrenceDialog extends StatefulWidget {
  final DateTime anchor;
  final RecurrenceRule? initial;
  const RecurrenceDialog({super.key, required this.anchor, this.initial});
  @override
  State<RecurrenceDialog> createState() => _RecurrenceDialogState();
}

class _RecurrenceDialogState extends State<RecurrenceDialog> {
  late RecurrenceUnit? unit = widget.initial?.unit;
  late final TextEditingController interval = TextEditingController();
  late final Set<int> days =
      widget.initial == null || widget.initial!.weekdays.isEmpty
      ? {widget.anchor.weekday}
      : {...widget.initial!.weekdays};
  late DateTime? until = widget.initial?.until;
  bool initialized = false;
  String? error;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initialized) {
      interval.text = MaterialLocalizations.of(context)
          .formatDecimal(widget.initial?.interval ?? 1);
      initialized = true;
    }
  }

  @override
  void dispose() {
    interval.dispose();
    super.dispose();
  }

  int? parseInterval() {
    var text = interval.text.trim();
    final local = MaterialLocalizations.of(context);
    for (var i = 0; i < 10; i++) {
      text = text.replaceAll(local.formatDecimal(i), '$i');
    }
    return RegExp(r'^[0-9]{1,3}$').hasMatch(text) ? int.tryParse(text) : null;
  }

  void save() {
    if (unit == null) {
      Navigator.pop(context, const RecurrenceChoice(null));
      return;
    }
    final count = parseInterval();
    if (count == null || count < 1 || count > 365) {
      setState(() => error = 'repeatInvalidInterval');
      return;
    }
    if (unit == RecurrenceUnit.week && days.isEmpty) {
      setState(() => error = 'repeatChooseDay');
      return;
    }
    if (until != null &&
        DateTime(until!.year, until!.month, until!.day).isBefore(
          DateTime(widget.anchor.year, widget.anchor.month, widget.anchor.day),
        )) {
      setState(() => error = 'repeatInvalidEnd');
      return;
    }
    Navigator.pop(
      context,
      RecurrenceChoice(
        RecurrenceRule(
          unit: unit!,
          interval: count,
          weekdays: unit == RecurrenceUnit.week ? days : {},
          until: until,
        ),
      ),
    );
  }

  Future<void> pickEnd() async {
    final first = DateTime(
      widget.anchor.year,
      widget.anchor.month,
      widget.anchor.day,
    );
    final last = DateTime(
      (first.year + 100).clamp(until?.year ?? first.year, 9999),
      12,
      31,
    );
    var initial = until == null
        ? first
        : DateTime(until!.year, until!.month, until!.day);
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    final value = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (value != null && mounted) setState(() => until = value);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.tr('repeat')),
    content: SingleChildScrollView(
      child: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<RecurrenceUnit?>(
              initialValue: unit,
              isExpanded: true,
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text(context.tr('repeatNone')),
                ),
                for (final value in RecurrenceUnit.values)
                  DropdownMenuItem(
                    value: value,
                    child: Text(context.tr(recurrenceUnitKey(value))),
                  ),
              ],
              onChanged: (value) => setState(() => unit = value),
            ),
            if (unit != null) ...[
              const SizedBox(height: 16),
              TextField(
                key: const Key('repeat-interval'),
                controller: interval,
                keyboardType: TextInputType.number,
                autocorrect: false,
                enableSuggestions: false,
                enableIMEPersonalizedLearning: false,
                decoration: InputDecoration(
                  labelText: context.tr('repeatInterval'),
                ),
              ),
              if (unit == RecurrenceUnit.week) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(context.tr('repeatOn')),
                ),
                Wrap(
                  spacing: 6,
                  children: [
                    for (var day = 1; day <= 7; day++)
                      FilterChip(
                        label: Text(context.tr(recurrenceWeekdayKey(day))),
                        selected: days.contains(day),
                        onSelected: (value) => setState(
                          () => value ? days.add(day) : days.remove(day),
                        ),
                      ),
                  ],
                ),
              ],
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.tr('repeatUntil')),
                subtitle: Text(
                  until == null
                      ? context.tr('repeatNoEnd')
                      : MaterialLocalizations.of(context)
                            .formatMediumDate(until!),
                ),
                onTap: pickEnd,
                trailing: until == null
                    ? null
                    : IconButton(
                        tooltip: context.tr('clear'),
                        onPressed: () => setState(() => until = null),
                        icon: const Icon(Icons.close),
                      ),
              ),
              Text(
                context.tr('repeatExplain'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  context.tr(error!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.tr('cancel')),
      ),
      FilledButton(onPressed: save, child: Text(context.tr('save'))),
    ],
  );
}
