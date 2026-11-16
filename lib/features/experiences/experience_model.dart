import 'dart:convert';

/// Versioned additions; legacy payloads remain valid without being rewritten.
class ExperienceModel {
  static const categories = [
    'work',
    'life',
    'feelings',
    'gratitude',
    'spiritual',
    'lesson',
  ];
  static const fields = [
    'body',
    'feelings',
    'lesson',
    'next',
    'hypothesis',
    'method',
    'observations',
    'evidence',
    'result',
    'conclusions',
  ];
  static const states = ['active', 'completed', 'paused'];
  static String day(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  static bool date(String text) {
    final value = DateTime.tryParse(text);
    return value != null && day(value) == text;
  }

  static void validate(Map<String, dynamic> data) {
    if (data['title'] is! String ||
        (data['title'] as String).trim().isEmpty ||
        (data['title'] as String).length > 200 ||
        utf8.encode(jsonEncode(data)).length > 4 * 1024 * 1024) {
      throw const FormatException('experience');
    }
    if (data['experienceVersion'] != null && data['experienceVersion'] != 1) {
      throw const FormatException('experience_version');
    }
    final category = data['category'] ?? 'life';
    if (category is! String || category.isEmpty || category.length > 2048) {
      throw const FormatException('category');
    }
    for (final key in fields) {
      if (data[key] != null &&
          (data[key] is! String || (data[key] as String).length > 100000)) {
        throw const FormatException('experience_text');
      }
    }
    if (data['date'] != null &&
        (data['date'] is! String || !date(data['date']))) {
      throw const FormatException('experience_date');
    }
    if (data['favorite'] != null && data['favorite'] is! bool) {
      throw const FormatException('experience_favorite');
    }
    if (data['status'] != null && !states.contains(data['status'])) {
      throw const FormatException('experience_status');
    }
    if (data['mode'] != null &&
        !['reflection', 'experiment'].contains(data['mode'])) {
      throw const FormatException('experience_mode');
    }
    final tags = data['tags'] ?? [];
    if (tags is! List ||
        tags.length > 30 ||
        tags.any((t) => t is! String || t.trim().isEmpty || t.length > 80) ||
        tags.toSet().length != tags.length) {
      throw const FormatException('experience_tags');
    }
  }
}
