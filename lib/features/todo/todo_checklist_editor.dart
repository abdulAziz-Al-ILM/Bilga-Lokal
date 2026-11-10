import 'package:flutter/material.dart';

import '../../core/strings.dart';
import 'reminders/todo_reminder_store.dart';
import 'todo_checklist_store.dart';

class TodoChecklistEditor extends StatelessWidget {
  final List<TodoChecklistItem> items;
  final ValueChanged<List<TodoChecklistItem>> onChanged;
  const TodoChecklistEditor({
    super.key,
    required this.items,
    required this.onChanged,
  });

  void update(int index, TodoChecklistItem item) =>
      onChanged([...items]..[index] = item);
  void action(int index, String action) {
    final copy = [...items];
    if (action == 'delete') {
      copy.removeAt(index);
    } else {
      final target = index + (action == 'up' ? -1 : 1);
      if (target < 0 || target >= copy.length) return;
      final item = copy.removeAt(index);
      copy.insert(target, item);
    }
    onChanged(copy);
  }

  @override
  Widget build(BuildContext context) {
    final local = MaterialLocalizations.of(context);
    final progress =
        '${local.formatDecimal(items.where((item) => item.done).length)} / ${local.formatDecimal(items.length)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Text(
          '${context.tr('taskChecklist')} · $progress',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(
              value: items.where((item) => item.done).length / items.length,
              semanticsLabel: '${context.tr('taskChecklist')} $progress',
            ),
          ),
        for (var i = 0; i < items.length; i++)
          Row(
            key: ValueKey('check-row-${items[i].id}'),
            children: [
              Checkbox(
                value: items[i].done,
                semanticLabel: context.tr('taskChecklistDone'),
                onChanged: (done) => update(i, items[i].copyWith(done: done)),
              ),
              Expanded(
                child: TextFormField(
                  key: ValueKey('check-title-${items[i].id}'),
                  initialValue: items[i].title,
                  maxLength: TodoChecklistStore.maxTitle,
                  autocorrect: false,
                  enableSuggestions: false,
                  enableIMEPersonalizedLearning: false,
                  decoration: InputDecoration(
                    labelText: context.tr('taskChecklistItem'),
                    counterText: '',
                  ),
                  onChanged: (title) =>
                      update(i, items[i].copyWith(title: title)),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: context.tr('taskChecklistActions'),
                onSelected: (value) => action(i, value),
                itemBuilder: (c) => [
                  if (i > 0)
                    PopupMenuItem(
                      value: 'up',
                      child: Text(c.tr('taskChecklistUp')),
                    ),
                  if (i < items.length - 1)
                    PopupMenuItem(
                      value: 'down',
                      child: Text(c.tr('taskChecklistDown')),
                    ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(c.tr('taskChecklistRemove')),
                  ),
                ],
              ),
            ],
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            key: const Key('task-checklist-add'),
            icon: const Icon(Icons.add),
            label: Text(context.tr('taskChecklistAdd')),
            onPressed: items.length >= TodoChecklistStore.maxItems
                ? null
                : () => onChanged([
                    ...items,
                    TodoChecklistItem(
                      'check:${TodoReminderStore.revision()}',
                      '',
                    ),
                  ]),
          ),
        ),
      ],
    );
  }
}
