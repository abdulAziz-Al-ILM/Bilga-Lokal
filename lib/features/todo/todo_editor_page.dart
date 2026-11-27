import 'dart:async';

import '../guidance/guide_controller.dart';
import '../voice/voice_screen_host.dart';
import 'reminders/todo_notification_permission.dart';
import 'reminders/todo_settings_page.dart';
import 'recurrence_rule.dart';
import 'recurrence_dialog.dart';
import 'todo_checklist_store.dart';
import 'todo_checklist_editor.dart';
import 'todo_editor_store.dart';

import 'package:sqflite/sqflite.dart';

import '../attachments/attachments_page.dart';
import 'todo_presentation.dart';

import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/dialogs.dart';

class TodoEditorPage extends StatefulWidget {
  final Map<String, Object?>? todo;
  final String? folderId;
  final Database? database;
  final String initialTitle, initialDescription;
  final DateTime? initialDue, initialReminder;
  final GuideController? guide;
  final Map<String, GlobalKey> guideTargets;
  const TodoEditorPage({
    super.key,
    this.todo,
    this.folderId,
    this.database,
    this.initialTitle = '',
    this.initialDescription = '',
    this.initialDue,
    this.initialReminder,
    this.guide,
    this.guideTargets = const {},
  });
  @override
  State<TodoEditorPage> createState() => _TodoEditorPageState();
}

class _TodoEditorPageState extends State<TodoEditorPage> {
  late final TextEditingController title, description;
  late final TodoEditorStore store = TodoEditorStore(database: widget.database);
  String? get taskId => widget.todo?['id'] as String?;
  bool requestingNotifications = false;
  late int priority;
  late DateTime? due;
  DateTime? remindAt, originalReminder;
  bool reminder = false, originalEnabled = false, reminderLoaded = false;
  bool busy = false, allowPop = false;
  bool reminderExplicit = false;
  RecurrenceRule? repeat, originalRepeat;
  Map<String, Object?>? series;
  bool seriesLoaded = false, applyFuture = false;
  List<TodoChecklistItem> checklist = [], originalChecklist = [];
  bool checklistLoaded = false;
  bool get checklistDirty =>
      checklist.length != originalChecklist.length ||
      List.generate(checklist.length, (i) => i).any(
        (i) =>
            checklist[i].id != originalChecklist[i].id ||
            checklist[i].title != originalChecklist[i].title ||
            checklist[i].done != originalChecklist[i].done,
      );
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
    title = TextEditingController(
      text: widget.todo?['title'] as String? ?? widget.initialTitle,
    );
    description = TextEditingController(
      text: widget.todo?['description'] as String? ?? widget.initialDescription,
    );
    title.addListener(
      () => widget.guide?.satisfy(
        'titleEntered',
        valid: title.text.trim().isNotEmpty,
      ),
    );
    priority = widget.todo?['priority'] as int? ?? 0;
    due =
        DateTime.tryParse(widget.todo?['due_at'] as String? ?? '')?.toLocal() ??
        widget.initialDue;
    if (widget.todo == null && widget.initialReminder != null) {
      remindAt = widget.initialReminder;
      reminder = true;
      reminderExplicit = true;
    }
    unawaited(loadReminder());
    unawaited(loadSeries());
    unawaited(loadChecklist());
  }

  Future<void> loadChecklist() async {
    try {
      final items = widget.todo == null
          ? <TodoChecklistItem>[]
          : await store.checklistFor(taskId!);
      if (mounted) {
        setState(() {
          checklist = items;
          originalChecklist = [...items];
          checklistLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) showError(context);
    }
  }

  Future<void> loadSeries() async {
    if (widget.todo == null) {
      setState(() => seriesLoaded = true);
      return;
    }
    try {
      final value = await store.seriesFor(taskId!);
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
      final value = await store.reminderFor(taskId!);
      if (!mounted) return;
      setState(() {
        if (value != null) {
          reminder = value.enabled;
          remindAt = value.time;
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
      checklistDirty ||
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
    if (requestingNotifications) return;
    requestingNotifications = true;
    try {
      final permission = await TodoNotificationPermission.request();
      if (!mounted || !reminder) return;
      switch (permission) {
        case TodoNotificationPermission.allowed:
          break;
        case TodoNotificationPermission.blocked:
          showError(context, 'moduleReminderBlocked');
        case TodoNotificationPermission.unavailable:
          showError(context, 'moduleReminderUnavailable');
      }
    } finally {
      requestingNotifications = false;
    }
  }

  Future<void> save() async {
    if (busy || !reminderLoaded || !seriesLoaded || !checklistLoaded) return;
    if (!TodoChecklistStore.validTitles(
      checklist.map((item) => item.title).toList(),
    )) {
      showError(context, 'required');
      return;
    }
    if (repeat != null && due == null) {
      showError(context, 'repeatDueRequired');
      return;
    }
    final draft = TodoEditorDraft(
      taskId: taskId,
      folderId: widget.folderId,
      title: title.text,
      description: description.text,
      priority: priority,
      due: due,
      originalDue: widget.todo?['due_at'] as String?,
      reminder: (enabled: reminder, time: remindAt),
      originalReminder: (enabled: originalEnabled, time: originalReminder),
      checklist: List.unmodifiable(checklist),
      checklistChanged: checklistDirty,
      recurrence: repeat,
      recurrenceChanged: repeatDirty,
      recurrenceReadOnly: repeatReadOnly,
      applyToFuture: applyFuture,
      hasSeries: series != null,
    );
    if (reminder &&
        draft.reminderChanged &&
        (remindAt == null || !remindAt!.isAfter(DateTime.now()))) {
      showError(context, 'reminderFuture');
      return;
    }
    if (draft.title.trim().isEmpty) {
      showError(context, 'required');
      return;
    }
    setState(() => busy = true);
    try {
      await store.save(draft);
      if (!mounted) return;
      widget.guide?.event('saved');
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
  Widget build(BuildContext context) => VoiceReadRegion(
    read: () => [
      title.text,
      description.text,
      if (checklist.isNotEmpty) context.tr('taskChecklist'),
      for (final item in checklist) item.title,
    ].join('\n'),
    child: _editor(context),
  );

  Widget _editor(BuildContext context) => PopScope<bool>(
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
            key: widget.guideTargets['save'],
            tooltip: context.tr('save'),
            onPressed:
                busy || !reminderLoaded || !seriesLoaded || !checklistLoaded
                ? null
                : save,
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: busy,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (!reminderLoaded || !seriesLoaded || !checklistLoaded)
              const LinearProgressIndicator(),
            TextField(
              key: widget.guideTargets['title'],
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
              key: widget.guideTargets['body'],
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
            if (checklistLoaded)
              TodoChecklistEditor(
                items: checklist,
                onChanged: (items) => setState(() => checklist = items),
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
              onPressed:
                  busy || !reminderLoaded || !seriesLoaded || !checklistLoaded
                  ? null
                  : save,
              child: Text(context.tr('save')),
            ),
          ],
        ),
      ),
    ),
  );
}
