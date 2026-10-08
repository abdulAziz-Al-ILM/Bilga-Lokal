#!/usr/bin/env python3
"""Execute the actual Dart SQL on SQLite; this is not a Flutter runtime test."""
import pathlib
import re
import sqlite3

ROOT = pathlib.Path(__file__).resolve().parents[1]


def statements(text):
    pattern = r"""db\.execute\(\s*(?:'''(.*?)'''|'([^'\n]*)'|"([^"\n]*)")"""
    return [a or b or c for a, b, c in re.findall(pattern, text, re.S)]


def upgrades(source):
    section = source.split('onUpgrade:', 1)[1]
    blocks = []
    for match in re.finditer(r'if \(oldVersion < (\d+)\) \{', section):
        start = match.end()
        depth, end = 1, start
        while depth:
            if section[end] == '{': depth += 1
            if section[end] == '}': depth -= 1
            end += 1
        blocks.append((int(match.group(1)), statements(section[start:end - 1])))
    return sorted(blocks, key=lambda item: item[0])


def schema(db):
    tables = [r[0] for r in db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")]
    return {table: {r[1]: (r[2], r[3], r[4], r[5]) for r in db.execute(f'PRAGMA table_info({table})')} for table in tables}


def run(feature, name, maximum, initial):
    source = (ROOT / f'lib/features/{feature}/{name}_database.dart').read_text()
    for helper_name in ['createHabits', 'createRecords']:
        marker = 'await ' + helper_name + '(db);'
        if marker in source:
            helper = source.split('static Future<void> ' + helper_name, 1)[1].split('static Future<void>', 1)[0]
            sqls = statements(helper)
            assert len(sqls) == 1
            source = source.replace(marker, "await db.execute(" + chr(39)*3 + sqls[0] + chr(39)*3 + ");")
    fresh = sqlite3.connect(':memory:')
    for sql in statements(source.split('onCreate:', 1)[1].split('onUpgrade:', 1)[0]):
        fresh.execute(sql)
    expected = schema(fresh)
    steps = upgrades(source)
    for version in range(1, maximum + 1):
        db = sqlite3.connect(':memory:')
        db.execute(initial)
        for target, sqls in steps:
            if target <= version:
                for sql in sqls: db.execute(sql)
        table = 'notes' if name == 'note' else 'todos'
        row = {'id': 'preserve', 'title': 'O‘zbekcha 😀', 'created_at': '2026-09-06T12:00:00', 'updated_at': '2026-09-06T12:00:00'}
        if table == 'notes': row['body'] = '  whitespace\nsecond line\n'
        else: row['is_done'] = 1
        if version >= (2 if table == 'notes' else 5): row['is_deleted'] = 1
        db.execute(f"INSERT INTO {table} ({','.join(row)}) VALUES ({','.join('?' for _ in row)})", list(row.values()))
        db.commit()
        with db:
            for target, sqls in steps:
                if target > version:
                    for sql in sqls: db.execute(sql)
        assert schema(db) == expected, (name, version, schema(db), expected)
        for key, value in row.items():
            assert db.execute(f'SELECT {key} FROM {table}').fetchone()[0] == value
        assert db.execute('PRAGMA integrity_check').fetchone()[0] == 'ok'
        print(f'PASS {name}: v{version} -> current; schema and existing data preserved')
        db.close()
    fresh.close()


run('notes', 'note', 10, 'CREATE TABLE notes (id TEXT PRIMARY KEY, title TEXT NOT NULL, body TEXT NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL)')
run('todo', 'todo', 5, 'CREATE TABLE todos (id TEXT PRIMARY KEY, title TEXT NOT NULL, is_done INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL, updated_at TEXT NOT NULL)')
