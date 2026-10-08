import 'package:flutter/material.dart';

import '../../core/editor_form.dart';
import '../../core/strings.dart';
import '../attachments/attachments_page.dart';
import 'habit_store.dart';

class HabitsPage extends StatefulWidget {
  const HabitsPage({super.key});
  @override
  State<HabitsPage> createState() => _HabitsState();
}

class _HabitsState extends State<HabitsPage> with WidgetsBindingObserver {
  final store = HabitStore();
  late Future<List<Habit>> loading;
  bool archive = false, busy = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    reload();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) setState(reload);
  }

  void reload() {
    loading = store.all(includeArchived: archive);
  }

  Future<void> run(Future<void> Function() f) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await f();
    } catch (_) {
      if (mounted) failure(context);
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          reload();
        });
      }
    }
  }

  Future<void> edit([Habit? h]) async {
    final p = h?.plan ?? HabitPlan();
    await editFields(
      context,
      context.tr('xHabits'),
      {
        'title': context.tr('title'),
        'weekdays': context.tr('hDays'),
        'target': context.tr('hTarget'),
        'unit': context.tr('hUnit'),
        'minimum': context.tr('hMinimum'),
        'cue': context.tr('hCue'),
        'reason': context.tr('hReason'),
      },
      initial: {
        'title': h?.title ?? '',
        'weekdays': (p.weekdays.toList()..sort()).join(','),
        'target': '${p.target}',
        'unit': p.unit,
        'minimum': p.minimum,
        'cue': p.cue,
        'reason': p.reason,
      },
      requiredFields: {'title', 'weekdays', 'target'},
      weekdayFields: {'weekdays'},
      numberFields: {'target'},
      onSave: (v) async {
        final days = v['weekdays']!
            .split(RegExp(r'[,،\s]+'))
            .where((s) => s.isNotEmpty)
            .map(int.parse)
            .toSet();
        final plan = HabitPlan(
          weekdays: days,
          target: int.parse(v['target']!),
          unit: v['unit']!,
          minimum: v['minimum']!,
          cue: v['cue']!,
          reason: v['reason']!,
        );
        HabitPlan.decode(plan.encode());
        if (h == null) {
          await store.create(v['title']!, plan: plan);
        } else {
          await store.configure(h.id, v['title']!, plan);
        }
      },
    );
  }

  Future<void> check(Habit h, DateTime date) async {
    final e = h.plan.entries[dayKey(date)];
    await editFields(
      context,
      '${h.title} · ${dayKey(date)}',
      {
        'amount': '${context.tr('hAmount')} (${h.plan.unit})',
        'note': context.tr('notes'),
      },
      initial: {
        'amount': '${h.plan.amount(date, h.days)}',
        'note': e?['note'] ?? '',
      },
      multiline: {'note'},
      requiredFields: {'amount'},
      numberFields: {'amount'},
      onSave: (v) =>
          store.checkIn(h.id, date, int.parse(v['amount']!), note: v['note']),
    );
  }

  Future<void> history(Habit h) async {
    final today = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: DateTime(2000),
      lastDate: today,
    );
    if (date != null && mounted) await check(h, date);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.tr('xHabits')),
      actions: [
        IconButton(
          tooltip: context.tr('archive'),
          icon: Icon(archive ? Icons.unarchive : Icons.archive_outlined),
          onPressed: busy
              ? null
              : () => setState(() {
                  archive = !archive;
                  reload();
                }),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: busy ? null : () => run(edit),
      child: const Icon(Icons.add),
    ),
    body: FutureBuilder<List<Habit>>(
      future: loading,
      builder: (c, s) {
        if (s.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(reload),
              child: Text(c.tr('retry')),
            ),
          );
        }
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final list = s.data!, now = DateTime.now();
        final active = list
            .where((h) => !h.archived && h.plan.scheduled(now))
            .toList();
        final done = active.where((h) => h.plan.done(now, h.days)).length;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: list.length + 1,
              itemBuilder: (c, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${c.tr('hToday')} · $done / ${active.length}',
                          style: Theme.of(c).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: active.isEmpty ? 0 : done / active.length,
                        ),
                        const SizedBox(height: 12),
                        Text(c.tr('hEncourage')),
                        if (list.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(c.tr('hFirst')),
                          ),
                      ],
                    ),
                  );
                }
                final h = list[index - 1], p = h.plan;
                var planned = 0, completed = 0;
                for (var i = 0; i < 28; i++) {
                  final d = DateTime(now.year, now.month, now.day - i);
                  if (dayKey(d).compareTo(dayKey(h.created)) >= 0 &&
                      p.scheduled(d) &&
                      !p.skipped(d)) {
                    planned++;
                    if (p.done(d, h.days)) completed++;
                  }
                }
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                h.title,
                                style: Theme.of(c).textTheme.titleLarge,
                              ),
                            ),
                            PopupMenuButton<String>(
                              enabled: !busy,
                              onSelected: (v) => run(() async {
                                if (v == 'edit') {
                                  await edit(h);
                                } else {
                                  await store.archive(h.id, !h.archived);
                                }
                              }),
                              itemBuilder: (c) => [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text(c.tr('edit')),
                                ),
                                PopupMenuItem(
                                  value: 'archive',
                                  child: Text(
                                    c.tr(h.archived ? 'restore' : 'archive'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Text(
                          '${p.amount(now, h.days)} / ${p.target} ${p.unit} · ${p.streak(h.days, now)} ${c.tr('hStreak')}',
                        ),
                        if (p.cue.isNotEmpty) Text('${c.tr('hCue')}: ${p.cue}'),
                        if (p.minimum.isNotEmpty)
                          Text('${c.tr('hMinimum')}: ${p.minimum}'),
                        if (p.reason.isNotEmpty)
                          Text('${c.tr('hReason')}: ${p.reason}'),
                        const SizedBox(height: 12),
                        Text('${c.tr('h28Days')}: $completed / $planned'),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: planned == 0 ? 0 : completed / planned,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 5,
                          runSpacing: 4,
                          children: List.generate(28, (i) {
                            final d = DateTime(
                              now.year,
                              now.month,
                              now.day - 27 + i,
                            );
                            return ActionChip(
                              label: Text('${d.day}/${d.month}'),
                              avatar: Icon(
                                p.done(d, h.days)
                                    ? Icons.check_circle
                                    : p.skipped(d)
                                    ? Icons.pause_circle_outline
                                    : p.amount(d, h.days) > 0
                                    ? Icons.timelapse
                                    : Icons.circle_outlined,
                                size: 16,
                              ),
                              onPressed: busy || h.archived
                                  ? null
                                  : () => run(() => check(h, d)),
                            );
                          }),
                        ),
                        if (!h.archived)
                          Wrap(
                            spacing: 8,
                            children: [
                              FilledButton.icon(
                                onPressed: busy
                                    ? null
                                    : () => run(
                                        () => store.mark(
                                          h.id,
                                          now,
                                          !p.done(now, h.days),
                                        ),
                                      ),
                                icon: Icon(
                                  p.done(now, h.days)
                                      ? Icons.undo
                                      : Icons.check,
                                ),
                                label: Text(
                                  c.tr(p.done(now, h.days) ? 'undo' : 'hDone'),
                                ),
                              ),
                              OutlinedButton(
                                onPressed: busy
                                    ? null
                                    : () => run(() => check(h, now)),
                                child: Text(c.tr('hCheckIn')),
                              ),
                              TextButton(
                                onPressed: busy
                                    ? null
                                    : () => run(
                                        () => store.checkIn(
                                          h.id,
                                          now,
                                          p.amount(now, h.days),
                                          skipped: !p.skipped(now),
                                        ),
                                      ),
                                child: Text(c.tr('hPause')),
                              ),
                              TextButton(
                                onPressed: busy
                                    ? null
                                    : () => run(() => history(h)),
                                child: Text(c.tr('history')),
                              ),
                            ],
                          ),
                        TextButton.icon(
                          onPressed: () => Navigator.push(
                            c,
                            MaterialPageRoute(
                              builder: (_) => AttachmentsPage(
                                kind: 'habit',
                                owner: h.id,
                                title: h.title,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.attach_file),
                          label: Text(c.tr('xAttach')),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    ),
  );
}
