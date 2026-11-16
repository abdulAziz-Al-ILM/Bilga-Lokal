import 'package:flutter/material.dart';

import '../../core/editor_form.dart';
import '../../core/strings.dart';
import '../../core/widgets/activity_calendar.dart';
import '../agent/agent_access.dart';
import '../guidance/guide_controller.dart';
import '../guidance/guide_host.dart';
import 'habit_store.dart';

class HabitStatisticsPage extends StatefulWidget {
  final HabitStore store;
  final String habitId;
  final AgentAccess access;
  const HabitStatisticsPage({
    super.key,
    required this.store,
    required this.habitId,
    required this.access,
  });
  @override
  State<HabitStatisticsPage> createState() => _HabitStatisticsState();
}

class _HabitStatisticsState extends State<HabitStatisticsPage>
    with WidgetsBindingObserver {
  Habit? habit;
  bool loading = true, busy = false, failed = false;
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month),
      selected = DateTime.now();
  final anchors = {
    for (final k in ['calendar', 'amount', 'save', 'result']) k: GlobalKey(),
  };
  late final guide = GuideController(
    id: 'habit.history',
    steps: const [
      GuideStep('date', 'calendar', 'haGuideCalendar', event: 'dateSelected'),
      GuideStep(
        'amount',
        'amount',
        'haGuideAmount',
        event: 'amountEntered',
        backBoundary: true,
      ),
      GuideStep('save', 'save', 'haGuideCheckSave', event: 'saved'),
      GuideStep('result', 'result', 'haGuideResult', backBoundary: true),
    ],
  );
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    guide.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !busy) load();
  }

  Future<void> load() async {
    try {
      final h = await widget.store.get(widget.habitId);
      if (mounted) {
        setState(() {
          habit = h;
          loading = false;
          failed = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          failed = true;
        });
      }
    }
  }

  List<DateTime> days(DateTime from, DateTime until) => [
    for (
      var d = from;
      d.isBefore(until) && dayKey(d).compareTo(dayKey(DateTime.now())) <= 0;
      d = DateTime(d.year, d.month, d.day + 1)
    )
      d,
  ];
  int count(DateTime from, DateTime until) =>
      days(from, until).where((d) => habit!.plan.done(d, habit!.days)).length;
  Future<void> edit(DateTime date) async {
    if (busy ||
        habit == null ||
        habit!.archived ||
        dayKey(date).compareTo(dayKey(DateTime.now())) > 0) {
      return;
    }
    if (!widget.access.has(AgentAccess.core)) {
      failure(context);
      return;
    }
    final current = habit!, entry = current.plan.entries[dayKey(date)];
    setState(() => busy = true);
    guide.satisfy('amountEntered', valid: true);
    try {
      await editFields(
        context,
        '${current.title} · ${dayKey(date)}',
        {'amount': context.tr('hAmount'), 'note': context.tr('notes')},
        initial: {
          'amount': '${current.plan.amount(date, current.days)}',
          'note': entry?['note'] ?? '',
        },
        multiline: {'note'},
        requiredFields: {'amount'},
        numberFields: {'amount'},
        fieldKeys: guide.active ? {'amount': anchors['amount']!} : const {},
        saveKey: guide.active ? anchors['save'] : null,
        pageWrapper: guide.active
            ? (child) =>
                  GuideHost(controller: guide, targets: anchors, child: child)
            : null,
        onChanged: (key, v) {
          if (key == 'amount') {
            guide.satisfy(
              'amountEntered',
              valid:
                  int.tryParse(v) != null &&
                  int.parse(v) >= 0 &&
                  int.parse(v) <= 1000000,
            );
          }
        },
        onSave: (v) async {
          if (!widget.access.has(AgentAccess.core)) {
            throw StateError('access_expired');
          }
          await widget.store.checkIn(
            current.id,
            date,
            int.parse(v['amount']!),
            note: v['note'],
          );
          guide.event('saved');
        },
      );
      if (guide.active && guide.step.id != 'result') guide.exit();
      await load();
    } catch (_) {
      if (mounted) failure(context);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) {
    final h = habit;
    if (h == null) {
      return Scaffold(
        appBar: AppBar(title: Text(c.tr('haStatistics'))),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: TextButton(onPressed: load, child: Text(c.tr('retry'))),
              ),
      );
    }
    final p = h.plan,
        now = DateTime.now(),
        week = DateTime(
          selected.year,
          selected.month,
          selected.day - selected.weekday + 1,
        );
    final values = <String, int>{};
    {
      for (final d in days(month, DateTime(month.year, month.month + 1))) {
        if (p.done(d, h.days)) values[dayKey(d)] = 1;
      }
    }
    return GuideHost(
      controller: guide,
      targets: anchors,
      child: Scaffold(
        appBar: AppBar(
          title: Text(h.title),
          actions: [
            if (!h.archived)
              IconButton(
                tooltip: c.tr('gHelp'),
                onPressed: busy ? null : () => guide.start(),
                icon: const Icon(Icons.help_outline),
              ),
          ],
        ),
        body: failed
            ? Center(
                child: TextButton(onPressed: load, child: Text(c.tr('retry'))),
              )
            : RefreshIndicator(
                onRefresh: load,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      c.tr('haStatistics'),
                      style: Theme.of(c).textTheme.headlineSmall,
                    ),
                    Text(c.tr('haCalendarHint')),
                    Container(
                      key: anchors['calendar'],
                      child: ActivityCalendar(
                        month: month,
                        values: values,
                        selected: dayKey(selected),
                        onMonth: (v) => setState(() => month = v),
                        onDay: (d) async {
                          setState(() => selected = d);
                          if (guide.active &&
                              guide.step.id == 'date' &&
                              dayKey(d).compareTo(dayKey(now)) <= 0) {
                            guide.event('dateSelected');
                            await edit(d);
                          }
                        },
                      ),
                    ),
                    Card(
                      key: anchors['result'],
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              MaterialLocalizations.of(c)
                                  .formatFullDate(selected),
                              style: Theme.of(c).textTheme.titleMedium,
                            ),
                            Text(
                              dayKey(selected).compareTo(dayKey(now)) > 0
                                  ? c.tr('haFuture')
                                  : p.done(selected, h.days)
                                  ? c.tr('haDone')
                                  : p.skipped(selected)
                                  ? c.tr('hSkip')
                                  : p.entries.containsKey(dayKey(selected)) ||
                                        h.days.contains(dayKey(selected))
                                  ? c.tr('haPartial')
                                  : c.tr('haUnrecorded'),
                            ),
                            if (p.entries.containsKey(dayKey(selected)) ||
                                h.days.contains(dayKey(selected)))
                              Text(
                                '${p.amount(selected, h.days)} / ${p.targetAt(selected)}',
                              ),
                            if ('${p.entries[dayKey(selected)]?['note'] ?? ''}'
                                .isNotEmpty)
                              SelectableText(
                                p.entries[dayKey(selected)]['note'],
                              ),
                            if (!h.archived)
                              OutlinedButton.icon(
                                key: const Key('habit-edit-selected-day'),
                                onPressed:
                                    busy ||
                                        dayKey(selected)
                                                .compareTo(dayKey(now)) >
                                            0
                                    ? null
                                    : () => edit(selected),
                                icon: const Icon(Icons.edit_calendar),
                                label: Text(c.tr('haEditDay')),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Chip(
                          label: Text(
                            '${c.tr('haDaily')}: ${p.done(selected, h.days) ? 1 : 0}',
                          ),
                        ),
                        Chip(
                          label: Text(
                            '${c.tr('haWeekly')}: ${count(week, DateTime(week.year, week.month, week.day + 7))}',
                          ),
                        ),
                        Chip(
                          label: Text(
                            '${c.tr('haMonthly')}: ${count(DateTime(selected.year, selected.month), DateTime(selected.year, selected.month + 1))}',
                          ),
                        ),
                      ],
                    ),
                    Text(
                      c.tr('haActivityChart'),
                      style: Theme.of(c).textTheme.titleLarge,
                    ),
                    for (final day in [
                      for (var i = 0; i < 7; i++)
                        DateTime(week.year, week.month, week.day + i),
                    ])
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              MaterialLocalizations.of(c).formatShortDate(day),
                            ),
                            if (dayKey(day).compareTo(dayKey(now)) > 0)
                              Text(c.tr('haFuture'))
                            else if (!p.entries.containsKey(dayKey(day)) &&
                                !h.days.contains(dayKey(day)))
                              Text(c.tr('haUnrecorded'))
                            else ...[
                              Text(
                                '${p.amount(day, h.days)} / ${p.targetAt(day)}',
                              ),
                              LinearProgressIndicator(
                                value: p.skipped(day)
                                    ? 0
                                    : (p.amount(day, h.days) / p.targetAt(day))
                                          .clamp(0, 1),
                              ),
                            ],
                          ],
                        ),
                      ),
                    if (p.goalTarget != null) ...[
                      Text(
                        '${c.tr('haGoalProgress')}: ${p.completedDays(h.days, now)} / ${p.goalTarget}',
                      ),
                      LinearProgressIndicator(
                        value: (p.completedDays(h.days, now) / p.goalTarget!)
                            .clamp(0, 1),
                      ),
                      Text(c.tr('haGoalHint')),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
      ),
    );
  }
}
