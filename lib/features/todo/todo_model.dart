enum TodoPriority { normal, important, veryImportant, critical }

class Todo {
  final String id;
  final String title;
  final bool isDone;
  final TodoPriority priority;
  final DateTime? dueAt;
  final String? folderId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Todo({
    required this.id,
    required this.title,
    required this.isDone,
    this.priority = TodoPriority.normal,
    this.dueAt,
    this.folderId,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'is_done': isDone ? 1 : 0,
      'priority': priority.index,
      'due_at': dueAt?.toIso8601String(),
      'folder_id': folderId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Todo.fromMap(Map<String, dynamic> map) {
    final rawPriority = map['priority'] as int? ?? 0;

    final safePriorityIndex = rawPriority
        .clamp(0, TodoPriority.values.length - 1)
        .toInt();

    return Todo(
      id: map['id'] as String,
      title: map['title'] as String,
      isDone: (map['is_done'] as int? ?? 0) == 1,
      priority: TodoPriority.values[safePriorityIndex],
      dueAt: map['due_at'] != null
          ? DateTime.parse(map['due_at'] as String)
          : null,
      folderId: map['folder_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Todo copyWith({
    String? id,
    String? title,
    bool? isDone,
    TodoPriority? priority,
    Object? dueAt = _noChange,
    Object? folderId = _noChange,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Todo(
      id: id ?? this.id,
      title: title ?? this.title,
      isDone: isDone ?? this.isDone,
      priority: priority ?? this.priority,
      dueAt: identical(dueAt, _noChange) ? this.dueAt : dueAt as DateTime?,
      folderId: identical(folderId, _noChange)
          ? this.folderId
          : folderId as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

const Object _noChange = Object();
