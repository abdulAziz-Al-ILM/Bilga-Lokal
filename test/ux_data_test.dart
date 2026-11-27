import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'database_safety_test.dart' show initializeTestSqlite;
import 'support/ux_data_cases.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  databaseFactory = createDatabaseFactoryFfi(ffiInit: initializeTestSqlite);
  registerUxDataCases();
}
