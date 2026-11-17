import '../reminders/module_reminder_changes.dart';

class HabitChanges {
  static Stream<void> get events => ModuleReminderChanges.events;
  static void committed() => ModuleReminderChanges.committed();
}
