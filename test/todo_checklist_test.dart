import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'database_safety_test.dart' show initializeTestSqlite;
import 'support/todo_checklist_cases.dart';

void main() {
  databaseFactory = createDatabaseFactoryFfi(ffiInit: initializeTestSqlite);
  registerTodoChecklistTests();
}
