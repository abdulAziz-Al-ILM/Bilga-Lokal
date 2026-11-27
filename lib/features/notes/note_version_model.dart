class NoteVersion {
  final int? versionId;
  final String noteId;
  final String title;
  final String body;
  final String? richBody;
  final DateTime createdAt;

  const NoteVersion({
    this.versionId,
    required this.noteId,
    required this.title,
    required this.body,
    this.richBody,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'version_id': versionId,
      'note_id': noteId,
      'title': title,
      'body': body,
      'rich_body': richBody,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory NoteVersion.fromMap(Map<String, dynamic> map) {
    return NoteVersion(
      versionId: map['version_id'] as int?,
      noteId: map['note_id'] as String,
      title: map['title'] as String,
      body: map['body'] as String,
      richBody: map['rich_body'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
