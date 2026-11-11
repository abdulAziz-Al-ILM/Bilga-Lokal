import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/dialogs.dart';
import '../../core/strings.dart';
import '../todo/reminders/todo_reminder_store.dart';
import '../todo/todo_checklist_editor.dart';
import '../todo/todo_checklist_store.dart';
import 'task_template_store.dart';
import 'template_catalog.dart';

class TaskTemplateChoice {
  final EntryTemplate? preset;
  final String? customId;
  const TaskTemplateChoice.preset(this.preset) : customId = null;
  const TaskTemplateChoice.custom(this.customId) : preset = null;
}

class TaskTemplatesPage extends StatefulWidget {
  final Database database;
  const TaskTemplatesPage({super.key, required this.database});
  @override
  State<TaskTemplatesPage> createState() => _TaskTemplatesPageState();
}

class _TaskTemplatesPageState extends State<TaskTemplatesPage> {
  List<TaskTemplate>? templates;
  bool failed = false, busy = false;
  TaskTemplateStore get store => TaskTemplateStore(widget.database);
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final value = await store.all();
      if (mounted) {
        setState(() {
          templates = value;
          failed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  Future<void> edit([TaskTemplate? initial]) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => TaskTemplateEditor(store: store, initial: initial),
      ),
    );
    if (mounted) await load();
  }

  Future<void> remove(TaskTemplate template) async {
    if (!await confirm(
          context,
          context.tr('taskTemplateDeleteInfo'),
          title: template.name,
        ) ||
        !mounted) {
      return;
    }
    setState(() => busy = true);
    try {
      await store.delete(template);
      await load();
    } catch (_) {
      if (mounted) showError(context);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> choose({EntryTemplate? preset, TaskTemplate? custom}) async {
    final language = Localizations.localeOf(context).languageCode;
    final name = custom?.name ?? preset!.title(language);
    final preview = custom == null
        ? preset!.lines(language).map((line) => '☐ $line').join('\n\n')
        : '${custom.title}\n\n${custom.description}\n\n${custom.checklist.map((line) => '☐ $line').join('\n')}';
    final use = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(name),
        content: SingleChildScrollView(child: Text(preview)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(c.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(c.tr('tpl_use')),
          ),
        ],
      ),
    );
    if (use == true && mounted) {
      Navigator.pop(
        context,
        custom == null
            ? TaskTemplateChoice.preset(preset!)
            : TaskTemplateChoice.custom(custom.id),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.tr('tpl_templates')),
      actions: [
        IconButton(
          key: const Key('task-template-create'),
          tooltip: context.tr('taskTemplateNew'),
          onPressed: busy ? null : () => edit(),
          icon: const Icon(Icons.add),
        ),
      ],
    ),
    body: failed
        ? Center(
            child: TextButton(
              onPressed: load,
              child: Text(context.tr('retry')),
            ),
          )
        : templates == null
        ? const Center(child: CircularProgressIndicator())
        : AbsorbPointer(
            absorbing: busy,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (busy) const LinearProgressIndicator(),
                Text(
                  context.tr('taskTemplateCustom'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (templates!.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(context.tr('taskTemplateEmpty')),
                  ),
                for (final template in templates!)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.fact_check_outlined),
                      title: Text(template.name),
                      subtitle: Text(
                        template.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => choose(custom: template),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) =>
                            value == 'edit' ? edit(template) : remove(template),
                        itemBuilder: (c) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Text(c.tr('taskTemplateModify')),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(c.tr('taskTemplateDelete')),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                Text(
                  context.tr('taskTemplateBuiltIn'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                for (final template in entryTemplates.where(
                  (template) => template.todo,
                ))
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.checklist),
                      title: Text(
                        template.title(
                          Localizations.localeOf(context).languageCode,
                        ),
                      ),
                      subtitle: Text(
                        template
                            .lines(Localizations.localeOf(context).languageCode)
                            .join(' · '),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => choose(preset: template),
                    ),
                  ),
              ],
            ),
          ),
  );
}

class TaskTemplateEditor extends StatefulWidget {
  final TaskTemplateStore store;
  final TaskTemplate? initial;
  const TaskTemplateEditor({super.key, required this.store, this.initial});
  @override
  State<TaskTemplateEditor> createState() => _TaskTemplateEditorState();
}

class _TaskTemplateEditorState extends State<TaskTemplateEditor> {
  late final TextEditingController name, title, description;
  late int priority;
  late List<TodoChecklistItem> items;
  bool busy = false, allowPop = false;
  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    name = TextEditingController(text: initial?.name ?? '');
    title = TextEditingController(text: initial?.title ?? '');
    description = TextEditingController(text: initial?.description ?? '');
    priority = initial?.priority ?? 0;
    items = [
      for (final line in initial?.checklist ?? <String>[])
        TodoChecklistItem('draft:${TodoReminderStore.revision()}', line),
    ];
  }

  bool get dirty =>
      name.text != (widget.initial?.name ?? '') ||
      title.text != (widget.initial?.title ?? '') ||
      description.text != (widget.initial?.description ?? '') ||
      priority != (widget.initial?.priority ?? 0) ||
      items.length != (widget.initial?.checklist.length ?? 0) ||
      List.generate(
        items.length,
        (i) => i,
      ).any((i) => items[i].title != widget.initial!.checklist[i]);
  Future<void> leave() async {
    if (busy) return;
    if (dirty && !await confirm(context, context.tr('discardChanges'))) return;
    if (mounted) {
      setState(() => allowPop = true);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> save() async {
    if (busy) return;
    if (name.text.trim().isEmpty ||
        title.text.trim().isEmpty ||
        !TodoChecklistStore.validTitles(
          items.map((item) => item.title).toList(),
        )) {
      showError(context, 'required');
      return;
    }
    setState(() => busy = true);
    try {
      await widget.store.save(
        TaskTemplate(
          id: widget.initial?.id ?? '',
          name: name.text,
          title: title.text.trim(),
          description: description.text,
          priority: priority,
          checklist: items.map((item) => item.title.trim()).toList(),
          revision: widget.initial?.revision ?? 0,
        ),
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
  void dispose() {
    name.dispose();
    title.dispose();
    description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope<void>(
    canPop: allowPop,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) leave();
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(context.tr('taskTemplateEdit')),
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
          children: [
            if (busy) const LinearProgressIndicator(),
            for (final field in [
              (name, 'taskTemplateName', 'task-template-name'),
              (title, 'title', 'task-template-title'),
              (description, 'description', 'task-template-description'),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: TextField(
                  key: Key(field.$3),
                  controller: field.$1,
                  maxLength: field.$2 == 'taskTemplateName' ? 200 : null,
                  minLines: field.$2 == 'description' ? 3 : 1,
                  maxLines: field.$2 == 'description' ? 8 : 1,
                  autocorrect: false,
                  enableSuggestions: false,
                  enableIMEPersonalizedLearning: false,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(labelText: context.tr(field.$2)),
                ),
              ),
            DropdownButtonFormField<int>(
              initialValue: priority,
              decoration: InputDecoration(labelText: context.tr('priority')),
              items: [
                for (var i = 0; i < 4; i++)
                  DropdownMenuItem(
                    value: i,
                    child: Text(
                      context.tr(
                        ['normal', 'important', 'veryImportant', 'critical'][i],
                      ),
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => priority = value ?? 0),
            ),
            TodoChecklistEditor(
              items: items,
              allowCompletion: false,
              onChanged: (value) => setState(() => items = value),
            ),
            const SizedBox(height: 16),
            Text(context.tr('taskTemplateIndependent')),
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
