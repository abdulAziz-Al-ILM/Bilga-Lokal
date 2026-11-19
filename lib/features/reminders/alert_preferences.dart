import 'package:shared_preferences/shared_preferences.dart';

class AlertPreferences {
  static const types = [
    'taskDue',
    'taskSoon',
    'habitEvening',
    'financeRecurring',
    'financeBudget',
    'experienceReview',
    'bookReading',
    'bookCards',
  ];
  final Map<String, bool> values;
  final int eveningMinute;
  const AlertPreferences(this.values, this.eveningMinute);
  bool has(String type) => values[type] == true;
  static Future<AlertPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AlertPreferences({
      for (final type in types)
        type: prefs.getBool('bilga.alert.$type') ?? false,
    }, prefs.getInt('bilga.alert.eveningMinute') ?? 1140);
  }

  static Future<void> save(String type, bool value) async =>
      (await SharedPreferences.getInstance()).setBool(
        'bilga.alert.$type',
        value,
      );

  static Future<void> saveEveningMinute(int value) async =>
      (await SharedPreferences.getInstance()).setInt(
        'bilga.alert.eveningMinute',
        value,
      );
}
