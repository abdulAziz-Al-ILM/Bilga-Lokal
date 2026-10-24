import '../../core/private_database.dart';
import 'note_tag_store.dart';
import 'note_widget_permission_store.dart';
import 'widget/notes_widget_loading.dart';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class NoteDatabase {
  static Future<Database>? _opening;

  static Future<Database> get database {
    return _opening ??= _openDatabase().catchError((Object error) {
      _opening = null;
      throw error;
    });
  }

  static Future<Database> _openDatabase() async {
    final databasePath = await getDatabasesPath();

    final path = join(databasePath, 'bilga.db');

    return openAt(path, secure: true);
  }

  /// Opens an isolated database in tests; production keeps its existing filename.
  static Future<Database> openAt(String path, {bool secure = false}) {
    return PrivateDatabase.open(
      path,
      secure: secure,
      verifyOnOpen: true,
      diagnostic: NotesWidgetLoading.trace,
      version: 13,

      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        await db.rawQuery('PRAGMA journal_mode = DELETE');
        await db.execute('PRAGMA synchronous = FULL');
      },
      onCreate: (db, version) async {
        await createRecords(db);
        await createHabits(db);
        await db.execute(
          "ALTER TABLE habits ADD COLUMN details TEXT NOT NULL DEFAULT '{}'",
        );
        await db.execute('''
          CREATE TABLE notes (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            body TEXT NOT NULL,
            folder_id TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            is_deleted INTEGER NOT NULL DEFAULT 0,
            trash_batch TEXT,
            is_favorite INTEGER NOT NULL DEFAULT 0,
            is_archived INTEGER NOT NULL DEFAULT 0,
            tags TEXT NOT NULL DEFAULT '[]'
          )
          ''');

        await db.execute('''
          CREATE TABLE note_versions (
            version_id INTEGER PRIMARY KEY AUTOINCREMENT,
            note_id TEXT NOT NULL,
            title TEXT NOT NULL,
            body TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
          ''');

        await db.execute('''
          CREATE TABLE folders (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            parent_id TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            is_deleted INTEGER NOT NULL DEFAULT 0,
            trash_batch TEXT
          )
          ''');
        await NoteTagStore.createSchema(db);
        await NoteWidgetPermissionStore.createSchema(db);
      },

      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 10) {
          await createRecords(db);
        }
        if (oldVersion < 9) {
          await createHabits(db);
        }
        if (oldVersion < 11) {
          await db.execute(
            "ALTER TABLE habits ADD COLUMN details TEXT NOT NULL DEFAULT '{}'",
          );
        }
        if (oldVersion < 2) {
          await db.execute('''
            ALTER TABLE notes
            ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0
            ''');
        }

        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE note_versions (
              version_id INTEGER PRIMARY KEY AUTOINCREMENT,
              note_id TEXT NOT NULL,
              title TEXT NOT NULL,
              body TEXT NOT NULL,
              created_at TEXT NOT NULL
            )
            ''');
        }

        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE folders (
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
            ALTER TABLE notes
            ADD COLUMN folder_id TEXT
            ''');
        }

        if (oldVersion < 6) {
          await db.execute('''
            ALTER TABLE folders
            ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0
            ''');
        }
        if (oldVersion < 7) {
          await db.execute('ALTER TABLE notes ADD COLUMN trash_batch TEXT');
          await db.execute('ALTER TABLE folders ADD COLUMN trash_batch TEXT');
        }

        if (oldVersion < 8) {
          await db.execute(
            'ALTER TABLE notes ADD COLUMN is_favorite INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute(
            'ALTER TABLE notes ADD COLUMN is_archived INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute(
            "ALTER TABLE notes ADD COLUMN tags TEXT NOT NULL DEFAULT '[]'",
          );
        }
        if (oldVersion < 12) {
          await NoteTagStore.createSchema(db);
          await NoteTagStore.migrateLegacy(db);
        }
        if (oldVersion < 13) {
          await NoteWidgetPermissionStore.createSchema(db);
        }
      },
    );
  }

  static Future<void> createHabits(DatabaseExecutor db) => db.execute('''
    CREATE TABLE habits (
      id TEXT PRIMARY KEY, title TEXT NOT NULL, days TEXT NOT NULL DEFAULT '[]',
      is_archived INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL, updated_at TEXT NOT NULL
    )
  ''');
  static Future<void> createRecords(DatabaseExecutor db) => db.execute('''
    CREATE TABLE private_records(id TEXT PRIMARY KEY, kind TEXT NOT NULL, payload TEXT NOT NULL, revision INTEGER NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL)
  ''');
}
