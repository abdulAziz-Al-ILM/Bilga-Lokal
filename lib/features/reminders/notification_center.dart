import '../books/reading/reading_hub.dart';
import '../books/reading/reading_store.dart';
import '../agent/agent_access.dart';
import '../finance/finance_planning_page.dart';
import '../private_space/record_store.dart';

import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/editor_form.dart';
import '../books/book_library_page.dart';
import '../experiences/experiences_page.dart';
import '../habits/habits_page.dart';
import '../todo/todo_database.dart';
import '../todo/todo_editor_page.dart';
import '../todo/reminders/todo_settings_page.dart';
import 'alert_preferences.dart';
import 'attention_repository.dart';
import 'module_reminder_status.dart';
import 'module_reminder_sync.dart';

class NotificationCenter extends StatefulWidget {
  const NotificationCenter({super.key});
  @override
  State<NotificationCenter> createState() => _CenterState();
}

class _CenterState extends State<NotificationCenter> {
  int section = 0;
  bool saving = false;
  late Future<(AlertPreferences, DateTime, List<AttentionRow>)> snapshot =
      load();
  Future<(AlertPreferences, DateTime, List<AttentionRow>)> load() async {
    final preferences = await AlertPreferences.load(), now = DateTime.now();
    return (
      preferences,
      now,
      await AttentionRepository().load(now, preferences),
    );
  }

  void reload() => setState(() => snapshot = load());
  Future<void> settings(Future<void> Function() action) async {
    if (saving) return;
    setState(() => saving = true);
    try {
      await action();
      await ModuleReminderSync.active?.refresh();
    } catch (_) {
      if (mounted) failure(context);
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
          snapshot = load();
        });
      }
    }
  }

  Future<void> open(AttentionRow row) async {
    try {
      Widget? page;
      switch (row.kind) {
        case 'task':
          final db = await TodoDatabase.database;
          final result = await db.query(
            'todos',
            where: 'id=? AND is_deleted=0',
            whereArgs: [row.id],
          );
          if (result.isNotEmpty) {
            page = TodoEditorPage(todo: result.single, database: db);
          }
        case 'finance':
          final store = RecordStore();
          final ledger = await store.get(row.id);
          final section = switch (row.event) {
            'financeDebt' => 'debts',
            'financeRecurring' => 'recurring',
            _ => 'budgets',
          };
          page = FinancePlanningPage(
            ledger: ledger,
            store: store,
            access: AgentAccess.instance,
            initialSection: section,
          );
        case 'book':
          if (row.event == 'bookCards') {
            final store = ReadingStore();
            final cards = await store.due(row.id);
            page = FlashcardPage(
              store: store,
              cards: cards,
              allowed: () => AgentAccess.instance.has(AgentAccess.core),
            );
          } else {
            page = const BookLibraryPage();
          }
        case 'experience':
          page = const ExperiencesPage();
        case 'habit':
        case 'center':
          page = const HabitsPage();
      }
      if (!mounted || page == null) return;
      final target = page;
      await Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (_) => target),
      );
      if (mounted) reload();
    } catch (_) {
      if (mounted) failure(context);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.tr('ncTitle')),
      actions: [
        IconButton(
          tooltip: context.tr('retry'),
          onPressed: saving ? null : reload,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder(
      future: snapshot,
      builder: (c, s) {
        if (s.hasError) {
          return Center(
            child: TextButton(onPressed: reload, child: Text(c.tr('retry'))),
          );
        }
        final data = s.data;
        if (data == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final (preferences, now, all) = data;
        final today = DateTime(now.year, now.month, now.day);
        final rows = all
            .where(
              (r) => switch (section) {
                0 => !r.completed && r.at.isAfter(now),
                1 =>
                  !r.completed &&
                      !r.at.isAfter(now) &&
                      !r.at.isBefore(today) &&
                      r.event != 'taskDue',
                2 =>
                  !r.completed &&
                      (r.at.isBefore(today) ||
                          r.event == 'taskDue' && r.at.isBefore(now)),
                _ => r.completed,
              },
            )
            .toList();
        const sections = [
          'ncUpcoming',
          'ncToday',
          'todoOverdue',
          'ncDelivered',
        ];
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      children: [
                        for (var i = 0; i < sections.length; i++)
                          ChoiceChip(
                            label: Text(c.tr(sections[i])),
                            selected: section == i,
                            onSelected: (_) => setState(() => section = i),
                          ),
                      ],
                    ),
                    ExpansionTile(
                      title: Text(c.tr('reminderSettings')),
                      leading: const Icon(Icons.tune),
                      children: [
                        ListTile(
                          title: Text(c.tr('ncTaskOptions')),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push<void>(
                            c,
                            MaterialPageRoute(
                              builder: (_) => const TodoSettingsPage(),
                            ),
                          ),
                        ),
                        for (final type in AlertPreferences.types)
                          SwitchListTile(
                            title: Text(c.tr('ncEvent$type')),
                            value: preferences.has(type),
                            onChanged: saving
                                ? null
                                : (value) => settings(
                                    () => AlertPreferences.save(type, value),
                                  ),
                          ),
                        ListTile(
                          title: Text(c.tr('ncSummaryTime')),
                          subtitle: Text(
                            TimeOfDay(
                              hour: preferences.eveningMinute ~/ 60,
                              minute: preferences.eveningMinute % 60,
                            ).format(c),
                          ),
                          onTap: saving
                              ? null
                              : () async {
                                  final result = await showTimePicker(
                                    context: c,
                                    initialTime: TimeOfDay(
                                      hour: preferences.eveningMinute ~/ 60,
                                      minute: preferences.eveningMinute % 60,
                                    ),
                                  );
                                  if (mounted && result != null) {
                                    await settings(
                                      () => AlertPreferences.saveEveningMinute(
                                        result.hour * 60 + result.minute,
                                      ),
                                    );
                                  }
                                },
                        ),
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: ModuleReminderStatus(),
                        ),
                      ],
                    ),
                    if (rows.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(c.tr('empty')),
                      ),
                  ],
                ),
              ),
            ),
            SliverList.builder(
              itemCount: rows.length,
              itemBuilder: (c, i) {
                final row = rows[i];
                final local = MaterialLocalizations.of(c);
                return ListTile(
                  leading: Icon(
                    row.completed
                        ? Icons.check_circle_outline
                        : Icons.notifications_outlined,
                  ),
                  title: Text(
                    row.title.isEmpty ? c.tr('ncEvent${row.event}') : row.title,
                  ),
                  subtitle: Text(
                    '${c.tr('ncEvent${row.event}')} · ${local.formatMediumDate(row.at)} · ${TimeOfDay.fromDateTime(row.at).format(c)}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => open(row),
                );
              },
            ),
          ],
        );
      },
    ),
  );
}
