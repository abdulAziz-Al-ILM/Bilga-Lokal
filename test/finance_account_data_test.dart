import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'database_safety_test.dart' show initializeTestSqlite;
import 'support/finance_account_data_cases.dart';

void main() {
  databaseFactory = createDatabaseFactoryFfi(ffiInit: initializeTestSqlite);
  registerFinanceAccountDataTests();
}
