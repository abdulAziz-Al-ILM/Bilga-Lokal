import 'dart:async';

class HabitChanges {
  static final _events = StreamController<void>.broadcast(sync: true);
  static Stream<void> get events => _events.stream;
  static void committed() => _events.add(null);
}
