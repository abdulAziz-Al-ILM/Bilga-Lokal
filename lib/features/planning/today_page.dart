import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../habits/habits_page.dart';
import '../notes/note_editor_page.dart';
import '../todo/todo_editor_page.dart';
import 'planner_repository.dart';

class TodayPage extends StatefulWidget {
  final PlannerRepository? repository;
  const TodayPage({super.key, this.repository});
  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  late Future<DailyPlan> plan;
  late DateTime now;
  bool weekly = false;
  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    now = DateTime.now();
    plan = (widget.repository ?? PlannerRepository()).load(now);
  }

  Future<void> open(Widget page) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
    if (mounted) setState(reload);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.tr('todayPlan')),
      actions: [
        IconButton(
          tooltip: context.tr('retry'),
          onPressed: () => setState(reload),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<DailyPlan>(
      future: plan,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(reload),
              child: Text(context.tr('retry')),
            ),
          );
        }
        final p = snapshot.data;
        if (p == null) return const Center(child: CircularProgressIndicator());
        final sections = <(String, List<Map<String, Object?>>)>[
          ('todoOverdue', p.overdue),
          ('todayPlan', p.today),
          if (weekly) ('weekAhead', p.upcoming),
          ('todoDone', p.completed),
        ];
        return RefreshIndicator(
          onRefresh: () async {
            setState(reload);
            await plan;
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                MaterialLocalizations.of(context).formatFullDate(now),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => open(const NoteEditorPage()),
                    icon: const Icon(Icons.note_add_outlined),
                    label: Text(context.tr('quickNote')),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => open(const TodoEditorPage()),
                    icon: const Icon(Icons.add_task),
                    label: Text(context.tr('quickTask')),
                  ),
                  FilterChip(
                    label: Text(context.tr('weekAhead')),
                    selected: weekly,
                    onSelected: (v) => setState(() => weekly = v),
                  ),
                ],
              ),
              for (final (key, tasks) in sections) ...[
                const SizedBox(height: 20),
                Text(
                  '${context.tr(key)} · ${MaterialLocalizations.of(context).formatDecimal(tasks.length)}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (tasks.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(context.tr('empty')),
                  ),
                for (final t in tasks)
                  Card(
                    child: ListTile(
                      leading: Icon(
                        t['is_done'] == 1
                            ? Icons.check_circle_outline
                            : Icons.radio_button_unchecked,
                      ),
                      title: Text(t['title'] as String),
                      subtitle: t['due_at'] == null
                          ? null
                          : Text(_date(t['due_at'] as String)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => open(TodoEditorPage(todo: t)),
                    ),
                  ),
              ],
              const SizedBox(height: 20),
              Text(
                context.tr('xHabits'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (p.habits.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(context.tr('empty')),
                ),
              for (final h in p.habits)
                Card(
                  child: ListTile(
                    title: Text(h.title),
                    subtitle: Text(
                      '${h.plan.amount(now, h.days)} / ${h.plan.target} ${h.plan.unit}',
                    ),
                    leading: Icon(
                      h.plan.done(now, h.days)
                          ? Icons.check_circle_outline
                          : Icons.local_fire_department_outlined,
                    ),
                    onTap: () => open(const HabitsPage()),
                  ),
                ),
              const SizedBox(height: 24),
              Text(
                context.tr('plannerReminderInfo'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    ),
  );

  String _date(String value) {
    final at = DateTime.parse(value).toLocal();
    return '${MaterialLocalizations.of(context).formatMediumDate(at)} · ${TimeOfDay.fromDateTime(at).format(context)}';
  }
}
