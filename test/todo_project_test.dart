import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'database_safety_test.dart' show initializeTestSqlite;
import 'support/todo_project_cases.dart';

void main() {
  databaseFactory = createDatabaseFactoryFfi(ffiInit: initializeTestSqlite);
  registerTodoProjectTests();
}
