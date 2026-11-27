import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preserve only the named Review tutorial preferences; never inspect/export
/// unrelated preferences or change production package storage.
void preserveGuidePreferences(bool secure, List<String> ids) {
  if (!secure) return;
  late Map<String, Object?> before;
  setUp(() async {
    final prefs = await SharedPreferences.getInstance();
    before = {
      for (final id in ids) 'bilga.guide.$id': prefs.get('bilga.guide.$id'),
    };
  });
  tearDown(() async {
    final prefs = await SharedPreferences.getInstance();
    for (final e in before.entries) {
      final value = e.value;
      if (value == null) {
        await prefs.remove(e.key);
      } else if (value is String) {
        await prefs.setString(e.key, value);
      } else if (value is bool) {
        await prefs.setBool(e.key, value);
      } else if (value is int) {
        await prefs.setInt(e.key, value);
      } else if (value is double) {
        await prefs.setDouble(e.key, value);
      } else if (value is List<String>) {
        await prefs.setStringList(e.key, value);
      }
    }
  });
}
