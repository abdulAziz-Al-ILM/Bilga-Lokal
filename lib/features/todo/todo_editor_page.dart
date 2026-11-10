import 'reminders/todo_reminder_store.dart';
import 'reminders/todo_bridge.dart';
import 'reminders/todo_settings_page.dart';
import 'todo_changes.dart';
import 'todo_series_store.dart';
import 'recurrence_rule.dart';
import 'recurrence_dialog.dart';

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
  RecurrenceRule? repeat, originalRepeat;
  Map<String, Object?>? series;
  bool seriesLoaded = false, applyFuture = false;
  bool get historical =>
      series != null && series!['head_task_id'] != widget.todo?['id'];
  bool get repeatReadOnly => historical || widget.todo?['is_done'] == 1;
  DateTime get seriesAnchor =>
      DateTime.tryParse(series?['anchor_at'] as String? ?? '') ??
      due ??
      DateTime.now();
  bool get repeatDirty => repeat == null || originalRepeat == null
      ? repeat != originalRepeat
      : !repeat!.sameSchedule(originalRepeat!, anchor: seriesAnchor);
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
    loadSeries();
  }

  Future<void> loadSeries() async {
    if (widget.todo == null) {
      setState(() => seriesLoaded = true);
      return;
    }
    try {
      final db = widget.database ?? await TodoDatabase.database;
      final value = await TodoSeriesStore.forTask(
        db,
        widget.todo!['id'] as String,
      );
      if (!mounted) return;
      setState(() {
        series = value;
        if (value?['active'] == 1) {
          repeat = RecurrenceRule.decode(value!['rule'] as String)
              .canonical(DateTime.parse(value['anchor_at'] as String));
        }
        originalRepeat = repeat;
        seriesLoaded = true;
      });
    } catch (_) {
      if (mounted) showError(context);
    }
  }

  Future<void> pickRepeat() async {
    if (!seriesLoaded || repeatReadOnly) return;
    if (due == null) await pickDue();
    if (!mounted || due == null) return;
    if (due!.year < 1 || due!.year > 9999) {
      showError(context, 'repeatDueRequired');
      return;
    }
    final choice = await showDialog<RecurrenceChoice>(
      context: context,
      builder: (_) => RecurrenceDialog(anchor: due!, initial: repeat),
    );
    if (choice != null && mounted) {
      setState(() {
        repeat = choice.rule;
        if (repeatDirty) applyFuture = true;
      });
    }
  }

  String repeatSummary(BuildContext context) {
    final value = repeat;
    if (value == null) return context.tr('repeatNone');
    final local = MaterialLocalizations.of(context);
    return '${context.tr(recurrenceUnitKey(value.unit))} · ${context.tr('repeatInterval')}: ${local.formatDecimal(value.interval)}'
        '${value.unit == RecurrenceUnit.week ? '\n${(value.canonical(seriesAnchor).weekdays.toList()..sort()).map((d) => context.tr(recurrenceWeekdayKey(d))).join(', ')}' : ''}'
        '${value.until == null ? '' : '\n${context.tr('repeatUntil')}: ${local.formatMediumDate(value.until!)}'}';
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
      remindAt != originalReminder ||
      repeatDirty ||
      applyFuture;
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
    if (busy || !reminderLoaded || !seriesLoaded) return;
    if (repeat != null && due == null) {
      showError(context, 'repeatDueRequired');
      return;
    }
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
        if (!repeatReadOnly) {
          if (repeat == null && repeatDirty) {
            await TodoSeriesStore.stop(txn, data['id'] as String);
          } else if (repeat != null &&
              (widget.todo == null || repeatDirty || applyFuture)) {
            await TodoSeriesStore.configure(
              txn,
              data['id'] as String,
              repeat!,
              updateDefaults: applyFuture || series == null,
              resetAnchor:
                  applyFuture &&
                  due !=
                      DateTime.tryParse(widget.todo?['due_at'] as String? ?? '')
                          ?.toLocal(),
            );
          }
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
            onPressed: busy || !reminderLoaded || !seriesLoaded ? null : save,
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: busy,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (!reminderLoaded || !seriesLoaded)
              const LinearProgressIndicator(),
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
                      tooltip: context.tr(
                        repeat == null ? 'clear' : 'repeatClearDue',
                      ),
                      onPressed: repeat != null || !seriesLoaded
                          ? null
                          : () => setState(() => due = null),
                      icon: const Icon(Icons.close),
                    ),
            ),
            ListTile(
              key: const Key('task-repeat'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.repeat),
              title: Text(context.tr('repeat')),
              subtitle: Text(repeatSummary(context)),
              onTap: seriesLoaded && !repeatReadOnly ? pickRepeat : null,
            ),
            if (repeatReadOnly)
              Text(
                context.tr(historical ? 'repeatHistorical' : 'repeatReopen'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (series != null && series!['active'] == 0 && !historical)
              Text(
                context.tr('repeatStopped'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (series != null && repeat != null && !repeatReadOnly)
              SwitchListTile(
                key: const Key('task-series-scope'),
                contentPadding: EdgeInsets.zero,
                title: Text(context.tr('repeatFuture')),
                subtitle: Text(
                  context.tr(applyFuture ? 'repeatExplain' : 'repeatOnly'),
                ),
                value: applyFuture,
                onChanged: repeatDirty
                    ? null
                    : (value) => setState(() => applyFuture = value),
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
              onPressed: busy || !reminderLoaded || !seriesLoaded ? null : save,
              child: Text(context.tr('save')),
            ),
          ],
        ),
      ),
    ),
  );
}
