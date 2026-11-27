import 'dart:async';

/// Refresh derived native policy only after a source write actually commits.
class ModuleReminderChanges {
  static final _events = StreamController<void>.broadcast(sync: true);
  static Stream<void> get events => _events.stream;
  static void committed() => _events.add(null);
}
