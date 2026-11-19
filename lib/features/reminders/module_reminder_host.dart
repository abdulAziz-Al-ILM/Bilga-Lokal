import '../books/reading/reading_hub.dart';
import '../books/reading/reading_store.dart';
import '../finance/finance_planning_page.dart';
import '../books/book_library_page.dart';
import '../experiences/experiences_page.dart';
import '../todo/todo_database.dart';
import '../todo/todo_editor_page.dart';
import 'notification_center.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_lock.dart';
import '../agent/agent_access.dart';
import '../habits/habit_store.dart';
import '../habits/habit_statistics_page.dart';
import '../private_space/record_store.dart';
import '../finance/finance_page.dart';
import 'module_reminder_sync.dart';

/// Notification navigation stays behind the existing AppLock/CoreAccessGate.
class ModuleReminderHost extends StatefulWidget {
  final Widget child;
  const ModuleReminderHost({super.key, required this.child});
  @override
  State<ModuleReminderHost> createState() => _ModuleReminderHostState();
}

class _ModuleReminderHostState extends State<ModuleReminderHost>
    with WidgetsBindingObserver {
  late final sync = ModuleReminderSync(canRead: () => allowed);
  final pending = <Map<String, dynamic>>[];
  bool locked = true, opening = false;
  bool get allowed {
    final access = AgentAccess.instance;
    return mounted &&
        !locked &&
        (!access.initialized ||
            (access.coreAllowed &&
                !(access.trialActive &&
                    !access.corePurchased &&
                    access.trial?.introduced == false)));
  }

  @override
  void initState() {
    super.initState();
    sync.start();
    WidgetsBinding.instance.addObserver(this);
    AgentAccess.instance.addListener(changed);
    ModuleReminderBridge.channel.setMethodCallHandler((call) async {
      if (call.method == 'ready') {
        await sync.refresh();
        await consume();
      }
      if (call.method == 'launch') await consume();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => consume());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    locked = AppLockScope.isLocked(context);
    changed();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      changed();
      unawaited(consume());
    }
  }

  void changed() {
    unawaited(sync.refresh());
    WidgetsBinding.instance.addPostFrameCallback((_) => drain());
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> consume() async {
    try {
      final value = await ModuleReminderBridge.channel
          .invokeMapMethod<String, dynamic>('consumeLaunch');
      if (value != null && pending.length < 20) pending.add(value);
      await drain();
    } on MissingPluginException {
      /* Android only. */
    } catch (_) {
      /* Source stays protected; user can open its module normally. */
    }
  }

  Future<void> drain() async {
    if (!allowed || opening || pending.isEmpty) return;
    opening = true;
    final value = pending.removeAt(0);
    try {
      final id = value['target'];
      if (id is! String) return;
      if (value['kind'] == 'habit') {
        final store = HabitStore();
        await store.get(id);
        if (!mounted || !allowed) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => HabitStatisticsPage(
              store: store,
              habitId: id,
              access: AgentAccess.instance,
            ),
          ),
        );
      } else if (value['kind'] == 'task') {
        final db = await TodoDatabase.database;
        final task = await db.query(
          'todos',
          where: 'id=? AND is_deleted=0 AND is_done=0',
          whereArgs: [id],
        );
        if (!mounted || !allowed || task.isEmpty) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TodoEditorPage(todo: task.single, database: db),
          ),
        );
      } else if (value['kind'] == 'book' && value['event'] == 'bookCards') {
        final store = ReadingStore();
        final cards = await store.due(id);
        if (!mounted || !allowed) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FlashcardPage(
              store: store,
              cards: cards,
              allowed: () => allowed,
            ),
          ),
        );
      } else if (value['kind'] == 'book' ||
          value['kind'] == 'experience' ||
          value['kind'] == 'center') {
        if (!mounted || !allowed) return;
        final page = switch (value['kind']) {
          'book' => const BookLibraryPage(),
          'experience' => const ExperiencesPage(),
          _ => const NotificationCenter(),
        };
        await Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => page));
      } else if (value['kind'] == 'finance') {
        final record = await RecordStore().get(id);
        if (!mounted || record.kind != 'finance' || !allowed) return;
        final section = switch (value['event']) {
          'financeDebt' => 'debts',
          'financeRecurring' => 'recurring',
          'budgetNear' || 'budgetExceeded' => 'budgets',
          _ => null,
        };
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => section == null
                ? FinancePage(initialLedgerId: id)
                : FinancePlanningPage(
                    ledger: record,
                    store: RecordStore(),
                    access: AgentAccess.instance,
                    initialSection: section,
                  ),
          ),
        );
      }
    } catch (_) {
      /* A deleted source is never recreated. */
    } finally {
      opening = false;
      if (mounted) unawaited(drain());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AgentAccess.instance.removeListener(changed);
    ModuleReminderBridge.channel.setMethodCallHandler(null);
    sync.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => widget.child;
}
