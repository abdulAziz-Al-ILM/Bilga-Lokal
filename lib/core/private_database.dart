import 'dart:io';

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' as cipher;

class PrivateDatabase {
  static const channel = MethodChannel('bilga/vault');
  static Future<String>? _key;
  static Future<String> key() => _key ??= channel
      .invokeMethod<String>('key')
      .then((v) {
        if (v == null || !RegExp(r'^[0-9a-f]{64}$').hasMatch(v)) {
          throw StateError('key');
        }
        return v;
      })
      .catchError((Object e) {
        _key = null;
        throw e;
      });
  static String quote(String s) => "'${s.replaceAll("'", "''")}'";
  static Future<bool> plain(File f) async {
    if (!await f.exists() || await f.length() < 16) return false;
    final h = await f.open();
    try {
      return String.fromCharCodes(await h.read(16)) == 'SQLite format 3\x00';
    } finally {
      await h.close();
    }
  }

  static Future<void> verify(
    File f,
    String password, {
    Map<String, int> expectedCounts = const {},
  }) async {
    final db = await cipher.openDatabase(
      f.path,
      password: password,
      singleInstance: false,
    );
    try {
      await verifyConnection(db);
      for (final entry in expectedCounts.entries) {
        final table = '"${entry.key.replaceAll('"', '""')}"';
        if ((await db.rawQuery('SELECT count(*) FROM $table'))
                .single
                .values
                .single !=
            entry.value) {
          throw StateError('count');
        }
      }
    } finally {
      await db.close();
    }
  }

  static Future<void> verifyConnection(Database db) async {
    if ((await db.rawQuery('PRAGMA integrity_check')).single.values.single !=
        'ok') {
      throw StateError('integrity');
    }
  }

  static Future<Database> open(
    String path, {
    required bool secure,
    required int version,
    required OnDatabaseCreateFn onCreate,
    required OnDatabaseVersionChangeFn onUpgrade,
    OnDatabaseConfigureFn? onConfigure,
    bool verifyOnOpen = false,
    void Function(String)? diagnostic,
  }) async {
    if (!secure) {
      // Android's system SQLite varies by vendor and can omit JSON1, which
      // current search indexes require. The bundled SQLCipher engine also
      // opens standard plaintext SQLite when no password is provided. Keep
      // one SQL feature set for migration fixtures and encrypted databases.
      if (Platform.isAndroid) {
        return cipher.openDatabase(
          path,
          version: version,
          onCreate: onCreate,
          onUpgrade: onUpgrade,
          onConfigure: onConfigure,
        );
      }
      return openDatabase(
        path,
        version: version,
        onCreate: onCreate,
        onUpgrade: onUpgrade,
        onConfigure: onConfigure,
      );
    }
    diagnostic?.call('database.key.begin');
    final password = await key();
    diagnostic?.call('database.key.ready');
    final source = File(path),
        old = File('$path.plain-migration'),
        stage = File('$path.cipher-stage');
    if (!await source.exists() && await old.exists()) await old.rename(path);
    if (await plain(source)) {
      if (await stage.exists()) await stage.delete();
      final counts = <String, int>{};
      final db = await cipher.openDatabase(path, singleInstance: false);
      try {
        final v = await db.getVersion();
        await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
        await db.rawQuery('PRAGMA journal_mode=DELETE');
        await db.execute(
          'ATTACH DATABASE ${quote(stage.path)} AS secured KEY ${quote(password)}',
        );
        try {
          await db.rawQuery("SELECT sqlcipher_export('secured')");
          await db.execute('PRAGMA secured.user_version=$v');
          for (final row in await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
          )) {
            final t = '"${(row['name'] as String).replaceAll('"', '""')}"';
            counts[row['name'] as String] =
                (await db.rawQuery('SELECT count(*) FROM main.$t'))
                        .single
                        .values
                        .single
                    as int;
          }
        } finally {
          await db.execute('DETACH DATABASE secured');
        }
      } finally {
        await db.close();
      }
      // Export can leave attached virtual-table schemas stale on the source
      // connection. Verify integrity and every table count after reopening the
      // staged encrypted file, before touching the original plaintext file.
      await verify(stage, password, expectedCounts: counts);
      if (await old.exists()) throw StateError('recovery_conflict');
      await source.rename(old.path);
      await stage.rename(path);
      await verify(source, password);
      await old.delete();
    } else if (!verifyOnOpen && await source.exists()) {
      await verify(source, password);
      if (await old.exists()) await old.delete();
      if (await stage.exists()) await stage.delete();
    }
    diagnostic?.call('database.cipher.begin');
    final opened = await cipher.openDatabase(
      path,
      password: password,
      version: version,
      onCreate: onCreate,
      onUpgrade: onUpgrade,
      onConfigure: (db) async {
        if (verifyOnOpen) {
          // Notes uses this same connection for verification and normal reads.
          // A separate verify/close/reopen can stall in the Android plugin's
          // close callback. Verify before configuration or schema migration.
          diagnostic?.call('database.integrity.begin');
          await verifyConnection(db);
          diagnostic?.call('database.integrity.ready');
        }
        // This PRAGMA returns a row. Android SQLCipher's execSQL rejects
        // statements that return results, preventing every secure DB from opening.
        await db.rawQuery('PRAGMA secure_delete=ON');
        await db.execute('PRAGMA temp_store=MEMORY');
        if (onConfigure != null) await onConfigure(db);
        diagnostic?.call('database.configure.ready');
      },
    );
    diagnostic?.call('database.cipher.ready');
    return opened;
  }
}
