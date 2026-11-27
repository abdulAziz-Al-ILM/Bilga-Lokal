import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/dialogs.dart';
import '../../core/strings.dart';
import 'todo_project_store.dart';

class TodoProjectEditor extends StatefulWidget {
  final Database database;
  final TodoProject? project;
  final Map<String, Object?>? folder;
  final String? parentId;
  const TodoProjectEditor({
    super.key,
    required this.database,
    this.project,
    this.folder,
    this.parentId,
  });
  @override
  State<TodoProjectEditor> createState() => _TodoProjectEditorState();
}

class _TodoProjectEditorState extends State<TodoProjectEditor> {
  late final TextEditingController name, description;
  late String status;
  late String? due;
  bool busy = false, allowPop = false;
  String get originalName =>
      widget.project?.name ?? widget.folder?['name'] as String? ?? '';
  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: originalName);
    description = TextEditingController(
      text: widget.project?.description ?? '',
    );
    status = widget.project?.status ?? 'active';
    due = widget.project?.dueDate;
  }

  bool get dirty =>
      name.text != originalName ||
      description.text != (widget.project?.description ?? '') ||
      status != (widget.project?.status ?? 'active') ||
      due != widget.project?.dueDate;
  Future<void> leave() async {
    if (busy) return;
    if (dirty && !await confirm(context, context.tr('discardChanges'))) return;
    if (mounted) {
      setState(() => allowPop = true);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> pickDue() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(due ?? '') ?? DateTime.now(),
      firstDate: DateTime(1),
      lastDate: DateTime(9999, 12, 31),
    );
    if (selected != null && mounted) {
      setState(() => due = selected.toIso8601String().substring(0, 10));
    }
  }

  Future<void> save() async {
    if (busy) return;
    if (name.text.trim().isEmpty) {
      showError(context, 'required');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => busy = true);
    try {
      final id = await TodoProjectStore(widget.database).save(
        folderId: widget.project?.folderId ?? widget.folder?['id'] as String?,
        parentId: widget.parentId,
        name: name.text,
        description: description.text,
        status: status,
        dueDate: due,
        expectedRevision: widget.project?.revision,
        expectedFolderStamp:
            widget.project?.folderStamp ??
            widget.folder?['updated_at'] as String?,
      );
      if (mounted) {
        setState(() => allowPop = true);
        await WidgetsBinding.instance.endOfFrame;
        if (mounted) Navigator.pop(context, id);
      }
    } catch (_) {
      if (mounted) {
        setState(() => busy = false);
        showError(context);
      }
    }
  }

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope<String>(
    canPop: allowPop,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) leave();
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(context.tr('taskProjectDetails')),
        leading: IconButton(
          onPressed: busy ? null : leave,
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
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
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            if (busy) const LinearProgressIndicator(),
            TextField(
              key: const Key('task-project-name'),
              controller: name,
              maxLength: 200,
              autocorrect: false,
              enableSuggestions: false,
              enableIMEPersonalizedLearning: false,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: context.tr('title')),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('task-project-description'),
              controller: description,
              minLines: 3,
              maxLines: 8,
              autocorrect: false,
              enableSuggestions: false,
              enableIMEPersonalizedLearning: false,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: context.tr('description')),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: const Key('task-project-status'),
              initialValue: status,
              decoration: InputDecoration(
                labelText: context.tr('taskProjectStatus'),
              ),
              items: [
                for (final value in TodoProject.statuses)
                  DropdownMenuItem(
                    value: value,
                    child: Text(context.tr(taskProjectStatusKey(value))),
                  ),
              ],
              onChanged: (value) => setState(() => status = value ?? 'active'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.tr('taskProjectDue')),
              subtitle: Text(
                due == null
                    ? context.tr('none')
                    : MaterialLocalizations.of(context)
                          .formatFullDate(DateTime.parse(due!)),
              ),
              leading: const Icon(Icons.event_outlined),
              onTap: pickDue,
              trailing: due == null
                  ? null
                  : IconButton(
                      tooltip: context.tr('clear'),
                      onPressed: () => setState(() => due = null),
                      icon: const Icon(Icons.close),
                    ),
            ),
            Text(context.tr('taskProjectStatusInfo')),
            const SizedBox(height: 16),
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

String taskProjectStatusKey(String status) => switch (status) {
  'paused' => 'taskProjectPaused',
  'closed' => 'taskProjectClosed',
  _ => 'taskProjectActive',
};

class TodoProjectSummary extends StatelessWidget {
  final TodoProject project;
  final ({int total, int done, int overdue}) progress;
  final VoidCallback? onEdit;
  const TodoProjectSummary({
    super.key,
    required this.project,
    required this.progress,
    this.onEdit,
  });
  @override
  Widget build(BuildContext context) {
    final local = MaterialLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr('taskProject'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(context.tr(taskProjectStatusKey(project.status))),
            if (project.description.isNotEmpty)
              Text(
                project.description,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
              ),
            if (project.dueDate != null)
              Text(
                '${context.tr('taskProjectDue')}: ${local.formatFullDate(DateTime.parse(project.dueDate!))}',
              ),
            Text(
              '${context.tr('taskProjectProgress')}: ${local.formatDecimal(progress.done)} / ${local.formatDecimal(progress.total)}',
            ),
            if (progress.total > 0)
              LinearProgressIndicator(
                value: progress.done / progress.total,
                semanticsLabel: context.tr('taskProjectProgress'),
              ),
            if (progress.overdue > 0)
              Text(
                '${context.tr('todoOverdue')}: ${local.formatDecimal(progress.overdue)}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (onEdit != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  key: const Key('task-project-edit'),
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(context.tr('taskProjectDetails')),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
