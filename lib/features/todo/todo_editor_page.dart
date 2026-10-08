import '../attachments/attachments_page.dart';
import 'todo_presentation.dart';

import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/dialogs.dart';
import 'todo_database.dart';

class TodoEditorPage extends StatefulWidget {
  final Map<String, Object?>? todo;
  final String? folderId;
  const TodoEditorPage({super.key, this.todo, this.folderId});
  @override
  State<TodoEditorPage> createState() => _TodoEditorPageState();
}

class _TodoEditorPageState extends State<TodoEditorPage> {
  late final TextEditingController title, description;
  late int priority;
  late DateTime? due;
  bool busy = false, allowPop = false;
  @override
  void initState() {
    super.initState();
    title = TextEditingController(text: widget.todo?['title'] as String? ?? '');
    description = TextEditingController(
      text: widget.todo?['description'] as String? ?? '',
    );
    priority = widget.todo?['priority'] as int? ?? 0;
    due = DateTime.tryParse(widget.todo?['due_at'] as String? ?? '');
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
      due?.toIso8601String() != widget.todo?['due_at'];
  Future<void> leave() async {
    if (busy) return;
    if (dirty && !await confirm(context, context.tr('discardChanges'))) return;
    if (!mounted) return;
    setState(() => allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context);
  }

  Future<void> pickDue() async {
    final now = DateTime.now();
    final initial = due ?? now;
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
    setState(
      () => due = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
  }

  Future<void> save() async {
    if (busy) return;
    if (title.text.trim().isEmpty) {
      showError(context, 'required');
      return;
    }
    setState(() => busy = true);
    try {
      final db = await TodoDatabase.database;
      final now = DateTime.now().toIso8601String();
      final data = <String, Object?>{
        ...?(widget.todo),
        'title': title.text.trim(),
        'description': description.text,
        'priority': priority,
        'due_at': due?.toIso8601String(),
        'updated_at': now,
      };
      if (widget.todo == null) {
        data.addAll({
          'id': DateTime.now().microsecondsSinceEpoch.toString(),
          'is_done': 0,
          'is_deleted': 0,
          'folder_id': widget.folderId,
          'created_at': now,
        });
        await db.insert('todos', data);
      } else {
        await db.update(
          'todos',
          data,
          where: 'id = ?',
          whereArgs: [widget.todo!['id']],
        );
      }
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
              onTap: pickDue,
              trailing: due == null
                  ? null
                  : IconButton(
                      tooltip: context.tr('clear'),
                      onPressed: () => setState(() => due = null),
                      icon: const Icon(Icons.close),
                    ),
            ),
            Text(
              context.tr('noNotifications'),
              style: Theme.of(context).textTheme.bodySmall,
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
