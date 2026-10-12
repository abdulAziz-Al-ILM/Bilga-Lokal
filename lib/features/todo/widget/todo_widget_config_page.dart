import 'package:sqflite/sqflite.dart';

import '../todo_database.dart';
import '../reminders/todo_reminder_store.dart';
import 'todo_widget_permissions.dart';

import 'package:flutter/material.dart';

import '../../../core/strings.dart';
import '../../../core/dialogs.dart';
import '../reminders/todo_bridge.dart';
import '../reminders/todo_sync.dart';

class TodoWidgetConfigPage extends StatefulWidget {
  final int widgetId;
  final TodoSync sync;
  final Database? database;
  const TodoWidgetConfigPage({
    super.key,
    required this.widgetId,
    required this.sync,
    this.database,
  });
  @override
  State<TodoWidgetConfigPage> createState() => _TodoWidgetConfigPageState();
}

class _TodoWidgetConfigPageState extends State<TodoWidgetConfigPage> {
  String source = 'upcoming';
  List<Map<String, Object?>> tasks = [];
  Map<String, bool> grants = {};
  Future<Database> get db async =>
      widget.database ?? await TodoDatabase.database;
  bool titles = false, busy = false, ready = false, allowPop = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool configuration = true}) async {
    try {
      final state = await TodoBridge.state();
      tasks = await TodoReminderStore.active(await db);
      grants = await TodoWidgetPermissions.allowed(await db);
      final configs = state['widgets'] as Map? ?? {};
      final config = configs[widget.widgetId.toString()] as Map? ?? {};
      if (mounted) {
        setState(() {
          if (configuration) {
            source = config['source'] as String? ?? 'upcoming';
            titles = config['showTitles'] == true;
          }
          ready = true;
        });
      }
    } catch (_) {
      if (context.mounted) showError(context);
    }
  }

  Future<void> finish(bool save) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      if (save) {
        await TodoBridge.channel.invokeMethod<void>('saveWidget', {
          'id': widget.widgetId,
          'source': source,
          'showTitles': titles,
        });
        await widget.sync.refresh();
      }
      await TodoBridge.channel.invokeMethod<void>(
        save ? 'finishWidget' : 'cancelWidget',
      );
      if (mounted) {
        setState(() => allowPop = true);
        await WidgetsBinding.instance.endOfFrame;
        if (mounted) Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        setState(() => busy = false);
        showError(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<void>(
    canPop: allowPop,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) finish(false);
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(context.tr('widgetTodo')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: busy ? null : () => finish(false),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          DropdownButtonFormField<String>(
            initialValue: source,
            key: ValueKey('$ready-$source'),
            decoration: InputDecoration(labelText: context.tr('widgetSource')),
            items: [
              for (final pair in [
                ('today', 'hToday'),
                ('upcoming', 'widgetUpcoming'),
                ('overdue', 'todoOverdue'),
              ])
                DropdownMenuItem(
                  value: pair.$1,
                  child: Text(context.tr(pair.$2)),
                ),
            ],
            onChanged: busy
                ? null
                : (v) => setState(() => source = v ?? 'upcoming'),
          ),
          SwitchListTile(
            title: Text(context.tr('reminderTitles')),
            value: titles,
            onChanged: busy
                ? null
                : (v) async {
                    if (v &&
                        !await confirm(
                          context,
                          context.tr('reminderPrivacy'),
                        )) {
                      return;
                    }
                    if (mounted) setState(() => titles = v);
                  },
          ),
          Text(context.tr('reminderPrivacy')),
          const SizedBox(height: 12),
          Text(
            context.tr('widgetAllow'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (final task in tasks)
            SwitchListTile(
              title: Text(
                task['title'] as String,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              value: grants[task['id']] == true,
              onChanged: busy
                  ? null
                  : (v) async {
                      if (v &&
                          !await confirm(
                            context,
                            context.tr('reminderPrivacy'),
                          )) {
                        return;
                      }
                      if (!mounted) return;
                      setState(() => busy = true);
                      try {
                        await TodoWidgetPermissions.set(await db, task, v);
                        await load(configuration: false);
                        if (mounted && v) setState(() => titles = true);
                      } catch (_) {
                        if (context.mounted) showError(context);
                      } finally {
                        if (mounted) setState(() => busy = false);
                      }
                    },
            ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: busy || !ready ? null : () => finish(true),
            child: Text(context.tr('save')),
          ),
        ],
      ),
    ),
  );
}
