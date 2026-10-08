import 'dart:convert';

class Note {
  final String id;
  final String title;
  final String body;
  final String? folderId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final bool isFavorite;
  final bool isArchived;
  final List<String> tags;

  const Note({
    required this.id,
    required this.title,
    required this.body,
    this.folderId,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.isFavorite = false,
    this.isArchived = false,
    this.tags = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'folder_id': folderId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
      'is_favorite': isFavorite ? 1 : 0,
      'is_archived': isArchived ? 1 : 0,
      'tags': jsonEncode(tags),
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] as String,
      title: map['title'] as String,
      body: map['body'] as String,
      folderId: map['folder_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
      isFavorite: map['is_favorite'] == 1,
      isArchived: map['is_archived'] == 1,
      tags: List<String>.from(
        jsonDecode(map['tags'] as String? ?? '[]') as List,
      ),
    );
  }

  Note copyWith({
    String? id,
    String? title,
    String? body,
    Object? folderId = _noChange,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    bool? isFavorite,
    bool? isArchived,
    List<String>? tags,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      folderId: identical(folderId, _noChange)
          ? this.folderId
          : folderId as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      isFavorite: isFavorite ?? this.isFavorite,
      isArchived: isArchived ?? this.isArchived,
      tags: tags ?? this.tags,
    );
  }
}

const Object _noChange = Object();
