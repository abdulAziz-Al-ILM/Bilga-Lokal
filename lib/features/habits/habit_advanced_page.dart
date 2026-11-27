import '../reminders/module_reminder_status.dart';

import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/editor_form.dart';
import '../../core/strings.dart';
import '../guidance/guide_controller.dart';
import '../guidance/guide_host.dart';
import 'habit_plan.dart';
import 'habit_rules.dart';
import 'habit_schedule.dart';

class HabitAdvancedPage extends StatefulWidget {
  final HabitPlan initial;
  final Future<void> Function(HabitPlan) onSave;
  const HabitAdvancedPage({
    super.key,
    required this.initial,
    required this.onSave,
  });
  @override
  State<HabitAdvancedPage> createState() => _HabitAdvancedState();
}

class _HabitAdvancedState extends State<HabitAdvancedPage> {
  final form = GlobalKey<FormState>();
  late final base = widget.initial.currentSchedule;
  late String type = base.type;
  late Set<int> days = {...base.weekdays};
  late String start = base.start ?? dayKey(DateTime.now());
  late String? end = base.end, goalDate = widget.initial.goalDate;
  late int? reminder = widget.initial.reminderMinute;
  late final pauses = [...base.pauses];
  late final fields = {
    'target': TextEditingController(text: '${widget.initial.target}'),
    'interval': TextEditingController(text: '${base.interval}'),
    'quota': TextEditingController(text: '${base.quota}'),
    'category': TextEditingController(text: widget.initial.category),
    'tags': TextEditingController(text: widget.initial.tags.join(', ')),
    'goal': TextEditingController(
      text: widget.initial.goalTarget?.toString() ?? '',
    ),
  };
  final anchors = {
    for (final k in ['type', 'target', 'goal', 'save']) k: GlobalKey(),
  };
  late final guide = GuideController(
    id: 'habit.schedule',
    steps: const [
      GuideStep('type', 'type', 'haGuideType'),
      GuideStep('target', 'target', 'haGuideQuantity'),
      GuideStep('goal', 'goal', 'haGuideGoal'),
      GuideStep('save', 'save', 'haGuideSave', event: 'saved'),
    ],
  );
  bool busy = false, leaving = false;
  String? error;
  late final String original;
  String get fingerprint => jsonEncode({
    'type': type,
    'days': days.toList()..sort(),
    'start': start,
    'end': end,
    'pauses': [
      for (final p in pauses) [p.from, p.until],
    ],
    'goalDate': goalDate,
    'reminderMinute': reminder,
    'fields': {for (final e in fields.entries) e.key: e.value.text},
  });
  @override
  void initState() {
    super.initState();
    original = fingerprint;
    for (final c in fields.values) {
      c.addListener(changed);
    }
  }

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    guide.dispose();
    super.dispose();
  }

  int? number(String text) {
    var s = text.trim();
    for (final first in [0x660, 0x6f0, 0x966, 0x9e6, 0xe50]) {
      for (var i = 0; i < 10; i++) {
        s = s.replaceAll(String.fromCharCode(first + i), '$i');
      }
    }
    return RegExp(r'^\d+$').hasMatch(s) ? int.tryParse(s) : null;
  }

  Future<String?> pick(String? value) async {
    final now = DateTime.now(),
        d = await showDatePicker(
          context: context,
          initialDate: DateTime.tryParse(value ?? '') ?? now,
          firstDate: DateTime(1900),
          lastDate: DateTime(2200),
        );
    return d == null ? null : dayKey(d);
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final goal = fields['goal']!.text.trim().isEmpty
          ? null
          : number(fields['goal']!.text);
      if (goalDate != null && goal == null) {
        throw const FormatException('goal_required');
      }
      final schedule = HabitSchedule.decode({
        'v': 1,
        'type': type,
        'weekdays': days.toList(),
        'target': number(fields['target']!.text),
        'interval': type == 'interval'
            ? number(fields['interval']!.text)
            : base.interval,
        'quota': ['weekly', 'monthly'].contains(type)
            ? number(fields['quota']!.text)
            : base.quota,
        'start': start,
        'end': end,
        'pauses': [
          for (final p in pauses) {'from': p.from, 'until': p.until},
        ],
      });
      final data = Map<String, dynamic>.from(
        jsonDecode(widget.initial.withSchedule(schedule).encode()),
      );
      data.addAll({
        'category': fields['category']!.text.trim(),
        'tags': fields['tags']!.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList(),
        'goalTarget': goal,
        'goalDate': goalDate,
        'reminderMinute': reminder,
      });
      await widget.onSave(HabitPlan.decode(jsonEncode(data)));
      guide.event('saved');
      if (mounted) {
        setState(() => leaving = true);
        await WidgetsBinding.instance.endOfFrame;
        if (mounted) Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) setState(() => error = context.tr('haInvalid'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget count(
    String key,
    String label, {
    int max = 1000000,
    bool optional = false,
  }) => Padding(
    key: anchors[key],
    padding: const EdgeInsets.only(top: 14),
    child: TextFormField(
      key: Key('habit-advanced-$key'),
      controller: fields[key],
      enabled: !busy,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
      validator: (s) {
        if (optional && (s ?? '').trim().isEmpty) return null;
        final n = number(s ?? '');
        return n == null || n < 1 || n > max ? context.tr('haInvalid') : null;
      },
    ),
  );
  @override
  Widget build(BuildContext c) => GuideHost(
    controller: guide,
    targets: anchors,
    child: PopScope(
      canPop: !busy && (leaving || fingerprint == original),
      onPopInvokedWithResult: (did, _) async {
        if (!did &&
            !busy &&
            await consent(c, c.tr('discardChanges')) &&
            mounted) {
          setState(() => leaving = true);
          await WidgetsBinding.instance.endOfFrame;
          if (mounted) Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(c.tr('haAdvanced')),
          actions: [
            IconButton(
              tooltip: c.tr('gHelp'),
              onPressed: busy ? null : () => guide.start(),
              icon: const Icon(Icons.help_outline),
            ),
            Container(
              key: anchors['save'],
              child: TextButton(
                key: const Key('habit-advanced-save'),
                onPressed: busy ? null : save,
                child: Text(c.tr('save')),
              ),
            ),
          ],
        ),
        body: Form(
          key: form,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(c.tr('haPurpose')),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      error!,
                      style: TextStyle(color: Theme.of(c).colorScheme.error),
                    ),
                  ),
                if (busy) const LinearProgressIndicator(),
                Wrap(
                  key: anchors['type'],
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final value in [
                      'weekdays',
                      'interval',
                      'weekly',
                      'monthly',
                    ])
                      ChoiceChip(
                        key: Key('habit-schedule-$value'),
                        label: Text(c.tr('haType_$value')),
                        selected: type == value,
                        onSelected: busy
                            ? null
                            : (_) => setState(() => type = value),
                      ),
                  ],
                ),
                if (type == 'weekdays')
                  Wrap(
                    spacing: 6,
                    children: [
                      for (var d = 1; d <= 7; d++)
                        FilterChip(
                          label: Text(
                            MaterialLocalizations.of(c).narrowWeekdays[d % 7],
                          ),
                          selected: days.contains(d),
                          onSelected: busy
                              ? null
                              : (yes) => setState(() {
                                  if (yes) {
                                    days.add(d);
                                  } else if (days.length > 1) {
                                    days.remove(d);
                                  }
                                }),
                        ),
                    ],
                  ),
                if (type == 'interval')
                  count('interval', c.tr('haInterval'), max: 365),
                if (['weekly', 'monthly'].contains(type)) ...[
                  count(
                    'quota',
                    c.tr('haQuota'),
                    max: type == 'weekly' ? 7 : 31,
                  ),
                  Text(c.tr('haQuotaHint')),
                ],
                count('target', c.tr('haDailyTarget')),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () async {
                          final d = await pick(start);
                          if (d != null && mounted) setState(() => start = d);
                        },
                  icon: const Icon(Icons.event),
                  label: Text('${c.tr('haStart')}: $start'),
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: busy
                            ? null
                            : () async {
                                final d = await pick(end);
                                if (d != null && mounted) {
                                  setState(() => end = d);
                                }
                              },
                        child: Text(
                          '${c.tr('haEnd')}: ${end ?? c.tr('haNone')}',
                        ),
                      ),
                    ),
                    if (end != null)
                      IconButton(
                        tooltip: c.tr('haClear'),
                        onPressed: busy
                            ? null
                            : () => setState(() => end = null),
                        icon: const Icon(Icons.clear),
                      ),
                  ],
                ),
                Text(
                  c.tr('haPauses'),
                  style: Theme.of(c).textTheme.titleMedium,
                ),
                for (var i = 0; i < pauses.length; i++)
                  ListTile(
                    title: Text('${pauses[i].from} – ${pauses[i].until}'),
                    trailing: IconButton(
                      tooltip: c.tr('delete'),
                      onPressed: busy
                          ? null
                          : () => setState(() => pauses.removeAt(i)),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                TextButton.icon(
                  onPressed: busy || pauses.length >= 100
                      ? null
                      : () async {
                          final r = await showDateRangePicker(
                            context: c,
                            firstDate: DateTime(1900),
                            lastDate: DateTime(2200),
                          );
                          if (r != null && mounted) {
                            setState(
                              () => pauses.add((
                                from: dayKey(r.start),
                                until: dayKey(r.end),
                              )),
                            );
                          }
                        },
                  icon: const Icon(Icons.pause_circle_outline),
                  label: Text(c.tr('haAddPause')),
                ),
                TextFormField(
                  key: const Key('habit-category'),
                  controller: fields['category'],
                  enabled: !busy,
                  maxLength: 100,
                  decoration: InputDecoration(
                    labelText: c.tr('haCategory'),
                    helperText: c.tr('haCategoryHint'),
                  ),
                ),
                TextFormField(
                  key: const Key('habit-tags'),
                  controller: fields['tags'],
                  enabled: !busy,
                  maxLength: 2400,
                  decoration: InputDecoration(
                    labelText: c.tr('eTags'),
                    helperText: c.tr('eTagsHint'),
                  ),
                ),
                count('goal', c.tr('haGoal'), optional: true),
                Text(c.tr('haGoalHint')),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: busy
                            ? null
                            : () async {
                                final d = await pick(goalDate);
                                if (d != null && mounted) {
                                  setState(() => goalDate = d);
                                }
                              },
                        child: Text(
                          '${c.tr('haGoalDate')}: ${goalDate ?? c.tr('haNone')}',
                        ),
                      ),
                    ),
                    if (goalDate != null)
                      IconButton(
                        tooltip: c.tr('haClear'),
                        onPressed: busy
                            ? null
                            : () => setState(() => goalDate = null),
                        icon: const Icon(Icons.clear),
                      ),
                  ],
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile(
                          key: const Key('habit-reminder-toggle'),
                          title: Text(c.tr('haReminder')),
                          subtitle: Text(c.tr('moduleReminderQuiet')),
                          value: reminder != null,
                          onChanged: busy
                              ? null
                              : (enabled) async {
                                  if (!enabled) {
                                    setState(() => reminder = null);
                                    return;
                                  }
                                  final picked = await showTimePicker(
                                    context: c,
                                    initialTime: TimeOfDay.now(),
                                  );
                                  if (picked != null && mounted) {
                                    setState(
                                      () => reminder =
                                          picked.hour * 60 + picked.minute,
                                    );
                                  }
                                },
                        ),
                        if (reminder != null) ...[
                          OutlinedButton(
                            key: const Key('habit-reminder-time'),
                            onPressed: busy
                                ? null
                                : () async {
                                    final picked = await showTimePicker(
                                      context: c,
                                      initialTime: TimeOfDay(
                                        hour: reminder! ~/ 60,
                                        minute: reminder! % 60,
                                      ),
                                    );
                                    if (picked != null && mounted) {
                                      setState(
                                        () => reminder =
                                            picked.hour * 60 + picked.minute,
                                      );
                                    }
                                  },
                            child: Text(
                              TimeOfDay(
                                hour: reminder! ~/ 60,
                                minute: reminder! % 60,
                              ).format(c),
                            ),
                          ),
                          const ModuleReminderStatus(),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
