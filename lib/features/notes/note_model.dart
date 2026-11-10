import 'dart:convert';

class Note {
  final String id;
  final String title;
  final String body;
  final String? richBody;
  final String? folderId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final bool isFavorite;
  final bool isArchived;
  final List<String> tags;
  // Null means a legacy caller supplied names; hydrated notes carry stable IDs.
  final List<String>? tagIds;

  const Note({
    required this.id,
    required this.title,
    required this.body,
    this.richBody,
    this.folderId,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.isFavorite = false,
    this.isArchived = false,
    this.tags = const [],
    this.tagIds,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'rich_body': richBody,
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
      richBody: map['rich_body'] as String?,
      folderId: map['folder_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
      isFavorite: map['is_favorite'] == 1,
      isArchived: map['is_archived'] == 1,
      tags: List<String>.from(
        jsonDecode(map['tags'] as String? ?? '[]') as List,
      ),
      tagIds: map['tag_ids'] == null
          ? null
          : List<String>.from(jsonDecode(map['tag_ids'] as String) as List),
    );
  }

  Note copyWith({
    String? id,
    String? title,
    String? body,
    Object? richBody = _noChange,
    Object? folderId = _noChange,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    bool? isFavorite,
    bool? isArchived,
    List<String>? tags,
    Object? tagIds = _noChange,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      richBody: identical(richBody, _noChange)
          ? (body != null && body != this.body ? null : this.richBody)
          : richBody as String?,
      folderId: identical(folderId, _noChange)
          ? this.folderId
          : folderId as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      isFavorite: isFavorite ?? this.isFavorite,
      isArchived: isArchived ?? this.isArchived,
      tags: tags ?? this.tags,
      tagIds: identical(tagIds, _noChange)
          ? (tags == null ? this.tagIds : null)
          : tagIds as List<String>?,
    );
  }
}

const Object _noChange = Object();
