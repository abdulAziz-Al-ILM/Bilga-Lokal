import 'package:sqflite/sqflite.dart';

import 'recurrence_rule.dart';
import 'reminders/todo_reminder_store.dart';
import 'todo_changes.dart';
import 'todo_checklist_store.dart';
import 'todo_database.dart';
import 'todo_series_store.dart';

typedef TodoEditorReminder = ({bool enabled, DateTime? time});

class TodoEditorDraft {
  const TodoEditorDraft({
    required this.taskId,
    required this.folderId,
    required this.title,
    required this.description,
    required this.priority,
    required this.due,
    required this.originalDue,
    required this.reminder,
    required this.originalReminder,
    required this.checklist,
    required this.checklistChanged,
    required this.recurrence,
    required this.recurrenceChanged,
    required this.recurrenceReadOnly,
    required this.applyToFuture,
    required this.hasSeries,
  });

  final String? taskId, folderId, originalDue;
  final String title, description;
  final int priority;
  final DateTime? due;
  final TodoEditorReminder reminder, originalReminder;
  final List<TodoChecklistItem> checklist;
  final RecurrenceRule? recurrence;
  final bool checklistChanged, recurrenceChanged, recurrenceReadOnly;
  final bool applyToFuture, hasSeries;

  bool get dueChanged => due != DateTime.tryParse(originalDue ?? '')?.toLocal();

  bool get reminderChanged =>
      taskId == null || reminder != originalReminder || dueChanged;
}

/// Persists the task, reminder, checklist and recurrence in one transaction.
class TodoEditorStore {
  const TodoEditorStore({Database? database}) : _provided = database;

  final Database? _provided;
  Future<Database> get _database async =>
      _provided ?? await TodoDatabase.database;

  Future<List<TodoChecklistItem>> checklistFor(String id) async =>
      TodoChecklistStore.load(await _database, id);

  Future<Map<String, Object?>?> seriesFor(String id) async =>
      TodoSeriesStore.forTask(await _database, id);

  Future<TodoEditorReminder?> reminderFor(String id) async {
    final db = await _database;
    final rows = await db.query(
      'todo_reminders',
      where: 'todo_id=?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return (
      enabled: row['enabled'] == 1,
      time: DateTime.tryParse(row['remind_at'] as String)?.toLocal(),
    );
  }

  Future<void> save(TodoEditorDraft draft) async {
    final db = await _database;
    final now = DateTime.now();
    final id = draft.taskId ?? now.microsecondsSinceEpoch.toString();
    final timestamp = now.toIso8601String();
    final data = <String, Object?>{
      'title': draft.title.trim(),
      'description': draft.description,
      'priority': draft.priority,
      'due_at': draft.dueChanged
          ? draft.due?.toIso8601String()
          : draft.originalDue,
      'updated_at': timestamp,
    };
    await db.transaction((txn) async {
      if (draft.taskId == null) {
        await txn.insert('todos', {
          ...data,
          'id': id,
          'is_done': 0,
          'is_deleted': 0,
          'folder_id': draft.folderId,
          'created_at': timestamp,
        });
      } else {
        final updated = await txn.update(
          'todos',
          data,
          where: 'id=? AND is_deleted=0',
          whereArgs: [id],
        );
        if (updated != 1) throw StateError('task_missing');
      }
      if (draft.reminderChanged) {
        final completed =
            draft.reminder.enabled &&
            (await txn.query(
                  'todos',
                  columns: ['is_done'],
                  where: 'id=?',
                  whereArgs: [id],
                )).single['is_done'] ==
                1;
        await TodoReminderStore.save(
          txn,
          id,
          draft.reminder.time,
          enabled: draft.reminder.enabled && !completed,
        );
      }
      if (draft.checklistChanged) {
        await TodoChecklistStore.replace(txn, id, draft.checklist);
      }
      if (!draft.recurrenceReadOnly) {
        final rule = draft.recurrence;
        if (rule == null && draft.recurrenceChanged) {
          await TodoSeriesStore.stop(txn, id);
        } else if (rule != null &&
            (draft.taskId == null ||
                draft.recurrenceChanged ||
                draft.applyToFuture)) {
          await TodoSeriesStore.configure(
            txn,
            id,
            rule,
            updateDefaults: draft.applyToFuture || !draft.hasSeries,
            resetAnchor: draft.applyToFuture && draft.dueChanged,
          );
        }
      }
    });
    TodoChanges.committed();
  }
}
