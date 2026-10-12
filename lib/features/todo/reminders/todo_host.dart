import 'package:sqflite/sqflite.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_lock.dart';
import '../../../core/dialogs.dart';
import '../../../core/strings.dart';
import '../../agent/agent_access.dart';
import '../../collections/collection_page.dart';
import '../../collections/collection_repository.dart';
import '../todo_database.dart';
import '../todo_editor_page.dart';
import '../todo_changes.dart';
import '../widget/todo_widget_config_page.dart';
import 'todo_actions.dart';
import 'todo_bridge.dart';
import 'todo_sync.dart';
import 'todo_reminder_store.dart';

/// All navigation and completion stay behind existing AppLock/CoreAccessGate.
class TodoHost extends StatefulWidget {
  final Widget child;
  final Future<Database> Function()? database;
  const TodoHost({super.key, required this.child, this.database});
  @override
  State<TodoHost> createState() => _TodoHostState();
}

class _TodoHostState extends State<TodoHost> with WidgetsBindingObserver {
  late final TodoSync sync;
  final pending = <Map<String, dynamic>>[];
  bool locked = true, opening = false;
  bool get allowed {
    final a = AgentAccess.instance;
    return mounted &&
        !locked &&
        (!a.initialized ||
            (a.coreAllowed &&
                !(a.trialActive &&
                    !a.corePurchased &&
                    a.trial?.introduced == false)));
  }

  @override
  void initState() {
    super.initState();
    sync = TodoSync(canRead: () => allowed, database: widget.database)..start();
    WidgetsBinding.instance.addObserver(this);
    AgentAccess.instance.addListener(changed);
    TodoBridge.channel.setMethodCallHandler((call) async {
      if (call.method == 'launch') await consume();
      if (call.method == 'changed') {
        TodoChanges.committed();
        await sync.refresh();
      }
      if (call.method == 'due') {
        pending.add({'action': 'reminder', 'id': call.arguments});
        await sync.refresh();
        await drain();
      }
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
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      changed();
      unawaited(consume());
    }
  }

  void changed() {
    if (!mounted) return;
    unawaited(sync.refresh());
    WidgetsBinding.instance.addPostFrameCallback((_) => drain());
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> consume() async {
    try {
      final launch = await TodoBridge.channel.invokeMapMethod<String, dynamic>(
        'consumeLaunch',
      );
      if (launch != null) pending.add(launch);
      await drain();
    } on MissingPluginException {
      /* Android only. */
    }
  }

  Future<void> drain() async {
    if (!allowed || opening || pending.isEmpty) return;
    opening = true;
    final launch = pending.removeAt(0);
    try {
      final action = launch['action'];
      Widget? page;
      if (action == 'configure') {
        page = TodoWidgetConfigPage(
          widgetId: launch['widgetId'] as int,
          sync: sync,
          database: await (widget.database?.call() ?? TodoDatabase.database),
        );
      } else if (action == 'create') {
        page = TodoEditorPage(
          database: await (widget.database?.call() ?? TodoDatabase.database),
        );
      } else if (action == 'list') {
        page = const CollectionPage(kind: CollectionKind.todos);
      } else {
        final tasks = await TodoReminderStore.active(
          await (widget.database?.call() ?? TodoDatabase.database),
        );
        if (!mounted) return;
        if (!allowed) {
          pending.insert(0, launch);
          return;
        }
        final task = tasks.where((t) => t['id'] == launch['id']).firstOrNull;
        if (task == null) {
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(context.tr('empty'))));
          }
          return;
        }
        if (action == 'done') {
          if (task['is_done'] != 1 &&
              await confirm(
                context,
                task['title'] as String,
                title: context.tr('reminderDone'),
              )) {
            if (!allowed) return;
            await CollectionRepository(
              CollectionKind.todos,
              provided:
                  await (widget.database?.call() ?? TodoDatabase.database),
            ).setField(task['id'] as String, 'is_done', 1);
            await sync.refresh();
          }
        } else if (action == 'snooze' || action == 'reminder') {
          if (task['is_done'] != 1 && mounted) {
            await showTodoReminder(
              context,
              task,
              snoozeOnly: action == 'snooze',
            );
          }
        } else {
          page = TodoEditorPage(
            todo: task,
            database: await (widget.database?.call() ?? TodoDatabase.database),
          );
        }
      }
      if (page != null && mounted && allowed) {
        unawaited(
          Navigator.of(context)
              .push<void>(MaterialPageRoute(builder: (_) => page!))
              .then((_) => sync.refresh()),
        );
      }
    } catch (_) {
      if (mounted) showError(context);
    } finally {
      opening = false;
      if (mounted) unawaited(drain());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AgentAccess.instance.removeListener(changed);
    TodoBridge.channel.setMethodCallHandler(null);
    sync.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
