import '../reminders/module_reminder_status.dart';
import 'habit_statistics_page.dart';

import 'dart:convert';

import 'habit_advanced_page.dart';

import 'package:flutter/material.dart';

import '../../core/editor_form.dart';
import '../../core/strings.dart';
import '../agent/agent_access.dart';
import '../agent/purchase_panel.dart';
import '../attachments/attachments_page.dart';
import '../guidance/guide_controller.dart';
import '../guidance/guide_host.dart';
import '../private_space/record_store.dart';
import 'habit_store.dart';
import 'habit_templates.dart';
import 'habit_template_page.dart';

class HabitsPage extends StatefulWidget {
  final HabitStore? store;
  final AgentAccess? access;
  const HabitsPage({super.key, this.store, this.access});
  @override
  State<HabitsPage> createState() => _HabitsState();
}

class _HabitsState extends State<HabitsPage> with WidgetsBindingObserver {
  late final store = widget.store ?? HabitStore();
  AgentAccess get access => widget.access ?? AgentAccess.instance;
  final targets = <String, GlobalKey>{
    for (final id in [
      'title',
      'weekdays',
      'target',
      'unit',
      'save',
      'progress',
    ])
      id: GlobalKey(debugLabel: 'habit-guide-$id'),
  };
  late final guide = GuideController(
    id: 'habit.create',
    steps: const [
      GuideStep('title', 'title', 'hgTitle', event: 'titleEntered'),
      GuideStep('schedule', 'weekdays', 'hgSchedule'),
      GuideStep('target', 'target', 'hgTarget'),
      GuideStep('unit', 'unit', 'hgUnit'),
      GuideStep('save', 'save', 'hgSave', event: 'saved'),
      GuideStep('progress', 'progress', 'hgProgress', backBoundary: true),
    ],
  );
  late Future<List<Habit>> loading;
  bool archive = false, busy = false, favoritesOnly = false;
  String query = '', category = '';
  final search = TextEditingController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    reload();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    search.dispose();
    guide.dispose();
    super.dispose();
  }

  Future<bool> allowed() async {
    if (access.has(AgentAccess.core)) return true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => PurchasePanel(product: AgentAccess.core, access: access),
    );
    return access.has(AgentAccess.core);
  }

  void requireAccess() {
    if (!access.has(AgentAccess.core)) throw StateError('access_expired');
  }

  Future<void> templates() async {
    final selected = await Navigator.push<HabitTemplate>(
      context,
      MaterialPageRoute(builder: (_) => const HabitTemplatePage()),
    );
    if (selected != null && mounted) await edit(null, selected);
  }

  Future<void> help() async {
    final pending = await guide.hasPending();
    if (!mounted) return;
    final start = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(c.tr('gHelp')),
        content: SingleChildScrollView(
          child: Text(
            '${c.tr('hgAbout')}\n\n${c.tr('hgHow')}\n\n${c.tr('hgSafe')}'
            '${pending ? '\n\n${c.tr('hgRestart')}' : ''}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(c.tr('gExit')),
          ),
          FilledButton(
            key: const Key('habit-guide-start'),
            onPressed: () => Navigator.pop(c, true),
            child: Text(c.tr(pending ? 'gResume' : 'gShowMe')),
          ),
        ],
      ),
    );
    if (start == true && mounted) await run(() => edit(null, null, true));
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

  Future<void> edit([
    Habit? h,
    HabitTemplate? template,
    bool guided = false,
  ]) async {
    if (!await allowed() || !mounted) return;
    final p = h?.plan ?? template?.plan(context.tr) ?? HabitPlan();
    if (guided) await guide.resume();
    if (!mounted) return;
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
        'title':
            h?.title ??
            (template == null ? '' : context.tr('ht_${template.id}')),
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
      fieldKeys: guided
          ? {
              for (final id in ['title', 'weekdays', 'target', 'unit'])
                id: targets[id]!,
            }
          : const {},
      saveKey: guided ? targets['save'] : null,
      onChanged: guided
          ? (field, value) {
              if (field == 'title') {
                guide.satisfy('titleEntered', valid: value.trim().isNotEmpty);
              }
            }
          : null,
      pageWrapper: guided
          ? (child) =>
                GuideHost(controller: guide, targets: targets, child: child)
          : null,
      onSave: (v) async {
        requireAccess();
        final days = v['weekdays']!
            .split(RegExp(r'[,،\s]+'))
            .where((s) => s.isNotEmpty)
            .map(int.parse)
            .toSet();
        final plan = p.copyWith(
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
        if (guided) guide.event('saved');
      },
    );
    // Leaving an unsaved editor ends the tour; the existing draft guard applies.
    if (guided && guide.active && guide.step.id != 'progress') guide.exit();
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
      onSave: (v) async {
        requireAccess();
        await store.checkIn(
          h.id,
          date,
          int.parse(v['amount']!),
          note: v['note'],
        );
      },
    );
  }

  Future<void> advanced(Habit h) async {
    if (!await allowed() || !mounted) return;
    final current = await store.get(h.id);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HabitAdvancedPage(
          initial: current.plan,
          onSave: (plan) async {
            requireAccess();
            await store.configure(current.id, current.title, plan);
          },
        ),
      ),
    );
  }

  ({int done, int required}) period(Habit h, DateTime day) {
    final p = h.plan,
        schedule = p.dayPlan(day),
        created = schedule.start == null
            ? h.created
            : DateTime.parse(schedule.start!);
    return (
      done: schedule.completed(
        day,
        created: created,
        through: day,
        done: (d) => !p.skipped(d) && p.done(d, h.days),
      ),
      required: schedule.required(day, created: created),
    );
  }

  bool due(Habit h, DateTime day) =>
      h.plan.due(day, h.days, created: h.created);

  Widget organization(List<Habit> all) {
    final categories = {
      for (final h in all)
        if (h.plan.category.isNotEmpty) h.plan.category,
      if (category.isNotEmpty) category,
    }.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const Key('habit-search'),
          controller: search,
          decoration: InputDecoration(
            labelText: context.tr('search'),
            prefixIcon: const Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => query = v.trim().toLowerCase()),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            FilterChip(
              label: Text(context.tr('favorites')),
              selected: favoritesOnly,
              onSelected: (v) => setState(() => favoritesOnly = v),
            ),
            if (query.isNotEmpty || category.isNotEmpty || favoritesOnly)
              TextButton(
                onPressed: () => setState(() {
                  search.clear();
                  query = category = '';
                  favoritesOnly = false;
                }),
                child: Text(context.tr('eReset')),
              ),
          ],
        ),
        if (categories.isNotEmpty)
          DropdownButtonFormField<String>(
            key: ValueKey('habit-category-$category'),
            initialValue: category,
            isExpanded: true,
            decoration: InputDecoration(labelText: context.tr('haCategory')),
            items: [
              DropdownMenuItem(value: '', child: Text(context.tr('all'))),
              for (final c in categories)
                DropdownMenuItem(
                  value: c,
                  child: Text(c, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() => category = v!),
          ),
        const SizedBox(height: 12),
      ],
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
  Widget build(BuildContext context) => GuideHost(
    controller: guide,
    targets: targets,
    child: Scaffold(
      appBar: AppBar(
        title: Text(context.tr('xHabits')),
        actions: [
          IconButton(
            key: const Key('habit-help'),
            tooltip: context.tr('gHelp'),
            onPressed: busy ? null : help,
            icon: const Icon(Icons.help_outline),
          ),
          IconButton(
            tooltip: context.tr('htLibrary'),
            onPressed: busy ? null : () => run(templates),
            icon: const Icon(Icons.grid_view_outlined),
          ),
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
        key: const Key('habit-add'),
        tooltip: context.tr('hCreate'),
        onPressed: busy ? null : () => run(() => edit()),
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
          if (!s.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = s.data!, now = DateTime.now();
          final list = all
              .where(
                (h) =>
                    (archive ? h.archived : !h.archived) &&
                    (!favoritesOnly || h.plan.favorite) &&
                    (category.isEmpty || h.plan.category == category) &&
                    (query.isEmpty ||
                        [
                          h.title,
                          h.plan.category,
                          h.plan.reason,
                          h.plan.cue,
                          ...h.plan.tags,
                        ].any((v) => v.toLowerCase().contains(query))),
              )
              .toList();
          final active = all.where((h) => !h.archived && due(h, now)).toList();
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
                        key: targets['progress'],
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
                          const SizedBox(height: 12),
                          Text(c.tr('hgAbout')),
                          organization(all),
                          if (all.any(
                            (h) => h.plan.reminderMinute != null && !h.archived,
                          ))
                            const ModuleReminderStatus(),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.icon(
                                key: const Key('habit-templates'),
                                onPressed: busy ? null : () => run(templates),
                                icon: const Icon(Icons.grid_view_outlined),
                                label: Text(c.tr('htLibrary')),
                              ),
                              OutlinedButton.icon(
                                key: const Key('habit-get-started'),
                                onPressed: busy ? null : help,
                                icon: const Icon(Icons.touch_app_outlined),
                                label: Text(c.tr('gGetStarted')),
                              ),
                            ],
                          ),
                          if (list.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                c.tr(all.isEmpty ? 'hFirst' : 'haNoMatches'),
                              ),
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
                                key: Key('habit-menu-${h.id}'),
                                enabled: !busy,
                                onSelected: (v) => run(() async {
                                  requireAccess();
                                  if (v == 'statistics') {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => HabitStatisticsPage(
                                          store: store,
                                          habitId: h.id,
                                          access: access,
                                        ),
                                      ),
                                    );
                                  } else if (v == 'advanced') {
                                    await advanced(h);
                                  } else if (v == 'favorite') {
                                    final current = await store.get(h.id);
                                    final data = Map<String, dynamic>.from(
                                      jsonDecode(current.plan.encode()),
                                    );
                                    data.addAll({
                                      'v': 2,
                                      'favorite': !current.plan.favorite,
                                    });
                                    await store.configure(
                                      h.id,
                                      current.title,
                                      HabitPlan.decode(jsonEncode(data)),
                                    );
                                  } else if (v == 'edit') {
                                    await edit(h);
                                  } else {
                                    await store.archive(h.id, !h.archived);
                                  }
                                }),
                                itemBuilder: (c) => [
                                  PopupMenuItem(
                                    value: 'statistics',
                                    child: Text(c.tr('haStatistics')),
                                  ),
                                  PopupMenuItem(
                                    value: 'advanced',
                                    child: Text(c.tr('haAdvanced')),
                                  ),
                                  PopupMenuItem(
                                    value: 'favorite',
                                    child: Text(c.tr('favorites')),
                                  ),
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
                            '${p.amount(now, h.days)} / ${p.targetAt(now)} ${p.unit} · ${p.streak(h.days, now, created: p.dayPlan(now).start == null ? h.created : DateTime.parse(p.dayPlan(now).start!))} ${c.tr(['weekly', 'monthly'].contains(p.dayPlan(now).type) ? 'haStreak_${p.dayPlan(now).type}' : 'hStreak')}',
                          ),
                          if (p.category.isNotEmpty) Text(p.category),
                          if (p.tags.isNotEmpty)
                            Wrap(
                              spacing: 4,
                              children: [
                                for (final tag in p.tags)
                                  Chip(label: Text(tag)),
                              ],
                            ),
                          if (p.goalTarget != null) ...[
                            Text(
                              '${c.tr('haGoalProgress')}: ${p.completedDays(h.days, now)} / ${p.goalTarget}',
                            ),
                            LinearProgressIndicator(
                              value:
                                  (p.completedDays(h.days, now) / p.goalTarget!)
                                      .clamp(0, 1),
                            ),
                            if (p.goalDate != null)
                              Text('${c.tr('haGoalDate')}: ${p.goalDate}'),
                            if (p.goalDate != null &&
                                p.goalDate!.compareTo(dayKey(now)) < 0 &&
                                p.completedDays(h.days, now) < p.goalTarget!)
                              Text(c.tr('haGoalOverdue')),
                          ],
                          if ([
                            'weekly',
                            'monthly',
                          ].contains(p.dayPlan(now).type))
                            Text(
                              '${c.tr('haPeriod')}: ${period(h, now).done} / ${period(h, now).required}',
                            ),
                          if (p.cue.isNotEmpty)
                            Text('${c.tr('hCue')}: ${p.cue}'),
                          if (p.minimum.isNotEmpty)
                            Text('${c.tr('hMinimum')}: ${p.minimum}'),
                          if (p.reason.isNotEmpty)
                            Text('${c.tr('hReason')}: ${p.reason}'),
                          const SizedBox(height: 12),
                          Text(
                            ['weekly', 'monthly'].contains(p.dayPlan(now).type)
                                ? '${c.tr('h28Days')}: $completed'
                                : '${c.tr('h28Days')}: $completed / $planned',
                          ),
                          const SizedBox(height: 8),
                          if (![
                            'weekly',
                            'monthly',
                          ].contains(p.dayPlan(now).type))
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
                                      : () => run(() async {
                                          requireAccess();
                                          await store.mark(
                                            h.id,
                                            now,
                                            !p.done(now, h.days),
                                          );
                                        }),
                                  icon: Icon(
                                    p.done(now, h.days)
                                        ? Icons.undo
                                        : Icons.check,
                                  ),
                                  label: Text(
                                    c.tr(
                                      p.done(now, h.days) ? 'undo' : 'hDone',
                                    ),
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
                                      : () => run(() async {
                                          requireAccess();
                                          await store.checkIn(
                                            h.id,
                                            now,
                                            p.amount(now, h.days),
                                            skipped: !p.skipped(now),
                                          );
                                        }),
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
                                  store: RecordStore(database: store.provided),
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
    ),
  );
}
