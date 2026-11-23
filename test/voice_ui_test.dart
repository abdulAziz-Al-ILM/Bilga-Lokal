import 'package:bilga/features/voice/speech_bridge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'database_safety_test.dart' show initializeTestSqlite;
import 'support/voice_ui_cases.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  databaseFactory = createDatabaseFactoryFfi(ffiInit: initializeTestSqlite);
  test('Recognizer selection is stored separately for each language', () async {
    SharedPreferences.setMockInitialValues({});
    await SpeechBridge().setDeviceRecognizerPreference('uz-UZ', false);
    expect(await SpeechBridge().prefersDeviceRecognizer('uz-UZ'), isFalse);
    expect(await SpeechBridge().prefersDeviceRecognizer('en-US'), isTrue);
    expect(await SpeechBridge().prefersDeviceRecognizer('ru-RU'), isTrue);
  });
  registerVoiceUiCases();
}
