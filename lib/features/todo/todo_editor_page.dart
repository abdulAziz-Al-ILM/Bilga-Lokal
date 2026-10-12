import 'reminders/todo_reminder_store.dart';
import 'reminders/todo_bridge.dart';
import 'reminders/todo_settings_page.dart';
import 'todo_changes.dart';

import 'package:sqflite/sqflite.dart';

import '../attachments/attachments_page.dart';
import 'todo_presentation.dart';

import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/dialogs.dart';
import 'todo_database.dart';

class TodoEditorPage extends StatefulWidget {
  final Map<String, Object?>? todo;
  final String? folderId;
  final Database? database;
  const TodoEditorPage({super.key, this.todo, this.folderId, this.database});
  @override
  State<TodoEditorPage> createState() => _TodoEditorPageState();
}

class _TodoEditorPageState extends State<TodoEditorPage> {
  late final TextEditingController title, description;
  late int priority;
  late DateTime? due;
  DateTime? remindAt, originalReminder;
  bool reminder = false, originalEnabled = false, reminderLoaded = false;
  bool busy = false, allowPop = false;
  bool reminderExplicit = false;
  @override
  void initState() {
    super.initState();
    title = TextEditingController(text: widget.todo?['title'] as String? ?? '');
    description = TextEditingController(
      text: widget.todo?['description'] as String? ?? '',
    );
    priority = widget.todo?['priority'] as int? ?? 0;
    due = DateTime.tryParse(widget.todo?['due_at'] as String? ?? '')?.toLocal();
    loadReminder();
  }

  Future<void> loadReminder() async {
    if (widget.todo == null) {
      setState(() => reminderLoaded = true);
      return;
    }
    try {
      final db = widget.database ?? await TodoDatabase.database;
      final rows = await db.query(
        'todo_reminders',
        where: 'todo_id=?',
        whereArgs: [widget.todo!['id']],
      );
      if (!mounted) return;
      setState(() {
        if (rows.isNotEmpty) {
          reminder = rows.first['enabled'] == 1;
          remindAt = DateTime.tryParse(rows.first['remind_at'] as String)
              ?.toLocal();
        }
        originalEnabled = reminder;
        originalReminder = remindAt;
        reminderLoaded = true;
      });
    } catch (_) {
      if (mounted) showError(context);
    }
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    super.dispose();
  }

  bool get dirty =>
      title.text != (widget.todo?['title'] ?? '') ||
      description.text != (widget.todo?['description'] ?? '') ||
      priority != (widget.todo?['priority'] ?? 0) ||
      due !=
          DateTime.tryParse(widget.todo?['due_at'] as String? ?? '')
              ?.toLocal() ||
      reminder != originalEnabled ||
      remindAt != originalReminder;
  Future<void> leave() async {
    if (busy) return;
    if (dirty && !await confirm(context, context.tr('discardChanges'))) return;
    if (!mounted) return;
    setState(() => allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context);
  }

  Future<void> pickDue({bool reminderOnly = false}) async {
    final now = DateTime.now();
    final initial = (reminderOnly ? remindAt : due) ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 100),
      lastDate: DateTime(initial.year + 100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    setState(() {
      final selected = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      if (reminderOnly) {
        remindAt = selected;
      } else {
        due = selected;
        if (widget.todo == null && !reminderExplicit) {
          reminder = true;
          remindAt = selected;
        }
        // An explicitly chosen/snoozed reminder remains independent.
        if (reminder && remindAt == null) remindAt = selected;
      }
    });
    if (reminder) await requestNotifications();
  }

  Future<void> requestNotifications() async {
    try {
      final state = await TodoBridge.state();
      if (state['notifications'] != true) {
        await TodoBridge.channel.invokeMethod<void>(
          'permission',
          'notifications',
        );
      }
    } catch (_) {}
  }

  Future<void> save() async {
    if (busy || !reminderLoaded) return;
    if (reminder &&
        (widget.todo == null ||
            reminder != originalEnabled ||
            remindAt != originalReminder ||
            due !=
                DateTime.tryParse(widget.todo?['due_at'] as String? ?? '')
                    ?.toLocal()) &&
        (remindAt == null || !remindAt!.isAfter(DateTime.now()))) {
      showError(context, 'reminderFuture');
      return;
    }
    if (title.text.trim().isEmpty) {
      showError(context, 'required');
      return;
    }
    setState(() => busy = true);
    try {
      final db = widget.database ?? await TodoDatabase.database;
      final now = DateTime.now().toIso8601String();
      final data = <String, Object?>{
        if (widget.todo != null) 'id': widget.todo!['id'],
        'title': title.text.trim(),
        'description': description.text,
        'priority': priority,
        'due_at':
            due ==
                DateTime.tryParse(widget.todo?['due_at'] as String? ?? '')
                    ?.toLocal()
            ? (widget.todo?['due_at'])
            : due?.toIso8601String(),
        'updated_at': now,
      };
      await db.transaction((txn) async {
        if (widget.todo == null) {
          data.addAll({
            'id': DateTime.now().microsecondsSinceEpoch.toString(),
            'is_done': 0,
            'is_deleted': 0,
            'folder_id': widget.folderId,
            'created_at': now,
          });
          await txn.insert('todos', data);
        } else {
          final current = await txn.query(
            'todos',
            where: 'id=? AND is_deleted=0',
            whereArgs: [widget.todo!['id']],
          );
          if (current.isEmpty) throw StateError('task_missing');
          await txn.update(
            'todos',
            data,
            where: 'id = ?',
            whereArgs: [widget.todo!['id']],
          );
        }
        if (widget.todo == null ||
            reminder != originalEnabled ||
            remindAt != originalReminder ||
            due !=
                DateTime.tryParse(widget.todo?['due_at'] as String? ?? '')
                    ?.toLocal()) {
          await TodoReminderStore.save(
            txn,
            data['id'] as String,
            remindAt,
            enabled:
                reminder &&
                (await txn.query(
                      'todos',
                      where: 'id=?',
                      whereArgs: [data['id']],
                    )).single['is_done'] !=
                    1,
          );
        }
      });
      TodoChanges.committed();
      if (!mounted) return;
      setState(() => allowPop = true);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => busy = false);
        showError(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<bool>(
    canPop: allowPop,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) leave();
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(context.tr('task')),
        leading: IconButton(
          onPressed: busy ? null : leave,
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.attach_file),
            tooltip: context.tr('xAttach'),
            onPressed: busy || widget.todo == null
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AttachmentsPage(
                        kind: 'todo',
                        owner: widget.todo!['id'] as String,
                        title: title.text,
                      ),
                    ),
                  ),
          ),
          IconButton(
            tooltip: context.tr('save'),
            onPressed: busy ? null : save,
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: busy,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextField(
              autocorrect: false,
              enableSuggestions: false,
              enableIMEPersonalizedLearning: false,
              controller: title,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: context.tr('title')),
            ),
            const SizedBox(height: 16),
            TextField(
              autocorrect: false,
              enableSuggestions: false,
              enableIMEPersonalizedLearning: false,
              controller: description,
              minLines: 3,
              maxLines: 8,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: context.tr('description')),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: priority,
              decoration: InputDecoration(labelText: context.tr('priority')),
              items: List.generate(
                4,
                (i) => DropdownMenuItem(
                  value: i,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.circle,
                        size: 14,
                        color: todoPriorityColors[i],
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          context.tr(
                            [
                              'normal',
                              'important',
                              'veryImportant',
                              'critical',
                            ][i],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              onChanged: (v) => setState(() => priority = v ?? 0),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: Text(context.tr('due')),
              subtitle: Text(
                due == null
                    ? context.tr('none')
                    : '${MaterialLocalizations.of(context).formatMediumDate(due!)} ${TimeOfDay.fromDateTime(due!).format(context)}',
              ),
              onTap: () => pickDue(),
              trailing: due == null
                  ? null
                  : IconButton(
                      tooltip: context.tr('clear'),
                      onPressed: () => setState(() => due = null),
                      icon: const Icon(Icons.close),
                    ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.tr('reminder')),
              value: reminder,
              onChanged: !reminderLoaded
                  ? null
                  : (v) async {
                      setState(() {
                        reminderExplicit = true;
                        reminder = v;
                        if (v) {
                          remindAt ??=
                              due ??
                              DateTime.now().add(const Duration(minutes: 10));
                        }
                      });
                      if (v) await requestNotifications();
                    },
            ),
            if (reminder)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.notifications_active_outlined),
                title: Text(context.tr('reminder')),
                subtitle: Text(
                  remindAt == null
                      ? context.tr('none')
                      : '${MaterialLocalizations.of(context).formatMediumDate(remindAt!)} ${TimeOfDay.fromDateTime(remindAt!).format(context)}',
                ),
                onTap: () => pickDue(reminderOnly: true),
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.tune),
              title: Text(context.tr('reminderSettings')),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TodoSettingsPage()),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: busy ? null : save,
              child: Text(context.tr('save')),
            ),
          ],
        ),
      ),
    ),
  );
}
