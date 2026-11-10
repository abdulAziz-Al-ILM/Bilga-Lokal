import '../search/search_index.dart';
import '../../core/private_database.dart';
import 'reminders/todo_reminder_store.dart';
import 'widget/todo_widget_permissions.dart';
import 'todo_series_store.dart';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class TodoDatabase {
  static Future<Database>? _opening;

  static Future<Database> get database {
    return _opening ??= _openDatabase().catchError((Object error) {
      _opening = null;
      throw error;
    });
  }

  static Future<Database> _openDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'bilga_todo.db');

    return openAt(path, secure: true);
  }

  /// Opens an isolated database in tests; production keeps its existing filename.
  static Future<Database> openAt(String path, {bool secure = false}) {
    return PrivateDatabase.open(
      path,
      secure: secure,
      version: 10,
      onConfigure: (db) async {
        await db.rawQuery('PRAGMA journal_mode = DELETE');
        await db.execute('PRAGMA synchronous = FULL');
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE todos (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            is_done INTEGER NOT NULL DEFAULT 0,
            priority INTEGER NOT NULL DEFAULT 0,
            due_at TEXT,
            folder_id TEXT,
            is_deleted INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            trash_batch TEXT,
            description TEXT NOT NULL DEFAULT '',
            completed_at TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE todo_folders (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            parent_id TEXT,
            is_deleted INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            trash_batch TEXT
          )
        ''');
        await TodoReminderStore.createSchema(db);
        await TodoWidgetPermissions.createSchema(db);
        await SearchIndex.create(db, notes: false);
        await TodoSeriesStore.createSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            ALTER TABLE todos
            ADD COLUMN due_at TEXT
          ''');
        }

        if (oldVersion < 3) {
          await db.execute('''
            ALTER TABLE todos
            ADD COLUMN priority INTEGER NOT NULL DEFAULT 0
          ''');
        }

        if (oldVersion < 4) {
          await db.execute('''
            ALTER TABLE todos
            ADD COLUMN folder_id TEXT
          ''');

          await db.execute('''
            CREATE TABLE todo_folders (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              parent_id TEXT,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
        }

        if (oldVersion < 5) {
          await db.execute('''
            ALTER TABLE todos
            ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0
          ''');

          await db.execute('''
            ALTER TABLE todo_folders
            ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0
          ''');
        }
        if (oldVersion < 6) {
          await db.execute('ALTER TABLE todos ADD COLUMN trash_batch TEXT');
          await db.execute(
            "ALTER TABLE todos ADD COLUMN description TEXT NOT NULL DEFAULT ''",
          );
          await db.execute('ALTER TABLE todos ADD COLUMN completed_at TEXT');
          await db.execute(
            'ALTER TABLE todo_folders ADD COLUMN trash_batch TEXT',
          );
        }
        if (oldVersion < 7) await TodoReminderStore.createSchema(db);
        if (oldVersion < 8) await TodoWidgetPermissions.createSchema(db);
        if (oldVersion < 9) {
          await SearchIndex.create(db, notes: false);
        }
        if (oldVersion < 10) await TodoSeriesStore.createSchema(db);
      },
    );
  }
}
