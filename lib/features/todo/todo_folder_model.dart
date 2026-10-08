class TodoFolder {
  final String id;
  final String name;
  final String? parentId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TodoFolder({
    required this.id,
    required this.name,
    this.parentId,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'parent_id': parentId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory TodoFolder.fromMap(Map<String, dynamic> map) {
    return TodoFolder(
      id: map['id'] as String,
      name: map['name'] as String,
      parentId: map['parent_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  TodoFolder copyWith({
    String? id,
    String? name,
    Object? parentId = _noChange,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TodoFolder(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: identical(parentId, _noChange)
          ? this.parentId
          : parentId as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

const Object _noChange = Object();
