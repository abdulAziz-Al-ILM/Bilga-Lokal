import 'dart:async';

/// Emitted only after committed Notes changes; contains no user data.
class NotesChanges {
  static final _events = StreamController<void>.broadcast(sync: true);
  static Stream<void> get events => _events.stream;
  static void committed() => _events.add(null);
  static Future<T> after<T>(Future<T> write) => write.then((value) {
    committed();
    return value;
  });
}
