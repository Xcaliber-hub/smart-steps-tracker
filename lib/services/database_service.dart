// SPDX-License-Identifier: GPL-3.0-or-later
// Smart Steps Tracker — a free and open-source step counter.

import 'package:sqflite/sqflite.dart';

import '../models/achievement.dart';
import '../models/day_record.dart';
import '../models/reminder.dart';
import '../utils/constants.dart';

/// SQLite persistence for daily records, achievements and reminders.
///
/// Schema (v1):
/// - `days(date TEXT PRIMARY KEY, steps INTEGER, distance_m REAL,
///   calories REAL, active_min INTEGER, floors INTEGER)`
/// - `achievements(id TEXT PRIMARY KEY, unlocked_at TEXT)`
/// - `reminders(id TEXT PRIMARY KEY, title TEXT, minutes_of_day INTEGER,
///   enabled INTEGER, type TEXT)`
class DatabaseService {
  Database? _db;
  Future<Database>? _openFuture;

  /// Returns an open database, reopening transparently if the cached
  /// handle was closed.
  ///
  /// The handle can be invalidated without this object knowing: the
  /// WorkManager background isolate opens the same file, and closing it
  /// there can drop the native handle out from under the main isolate
  /// (hence the `database_closed` errors). Checking [Database.isOpen]
  /// here makes every access self-healing instead of stuck on a dead
  /// handle forever. Concurrent opens are serialized so two callers never
  /// race to open the same file twice.
  Future<Database> get database async {
    final db = _db;
    if (db != null && db.isOpen) return db;
    if (_openFuture != null) return _openFuture!;
    final future = _open();
    _openFuture = future;
    try {
      _db = await future;
      return _db!;
    } finally {
      _openFuture = null;
    }
  }

  Future<Database> _open() async {
    final path = '${await getDatabasesPath()}/${AppConstants.dbName}';
    return openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE days(
            date TEXT PRIMARY KEY,
            steps INTEGER NOT NULL DEFAULT 0,
            distance_m REAL NOT NULL DEFAULT 0,
            calories REAL NOT NULL DEFAULT 0,
            active_min INTEGER NOT NULL DEFAULT 0,
            floors INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE achievements(
            id TEXT PRIMARY KEY,
            unlocked_at TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE reminders(
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            minutes_of_day INTEGER NOT NULL,
            enabled INTEGER NOT NULL DEFAULT 1,
            type TEXT NOT NULL DEFAULT 'custom'
          )
        ''');
      },
    );
  }

  // --- Days -------------------------------------------------------------

  /// Insert or replace a day's record.
  Future<void> upsertDay(DayRecord record) async {
    final db = await database;
    await db.insert(
      'days',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<DayRecord?> getDay(String dateKey) async {
    final db = await database;
    final rows = await db.query(
      'days',
      where: 'date = ?',
      whereArgs: [dateKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DayRecord.fromMap(rows.first);
  }

  /// Records for [from]..[to] inclusive, ascending by date.
  Future<List<DayRecord>> getDaysInRange(DateTime from, DateTime to) async {
    final db = await database;
    final rows = await db.query(
      'days',
      where: 'date >= ? AND date <= ?',
      whereArgs: [DayRecord.dateKeyFor(from), DayRecord.dateKeyFor(to)],
      orderBy: 'date ASC',
    );
    return rows.map(DayRecord.fromMap).toList();
  }

  Future<List<DayRecord>> getAllDays() async {
    final db = await database;
    final rows = await db.query('days', orderBy: 'date ASC');
    return rows.map(DayRecord.fromMap).toList();
  }

  Future<int> lifetimeSteps() async {
    final db = await database;
    final rows = await db.rawQuery('SELECT SUM(steps) AS total FROM days');
    return ((rows.first['total'] as num?) ?? 0).toInt();
  }

  // --- Achievements -----------------------------------------------------

  Future<void> markAchievementUnlocked(String id, DateTime at) async {
    final db = await database;
    await db.insert(
      'achievements',
      {'id': id, 'unlocked_at': at.toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Map of achievement id -> unlock timestamp for unlocked badges.
  Future<Map<String, DateTime>> unlockedAchievements() async {
    final db = await database;
    final rows = await db.query('achievements');
    final result = <String, DateTime>{};
    for (final row in rows) {
      final raw = row['unlocked_at'] as String?;
      if (raw != null) {
        result[row['id']! as String] = DateTime.parse(raw);
      }
    }
    return result;
  }

  /// Full catalog with unlock state applied.
  Future<List<Achievement>> achievementsWithState() async {
    final unlocked = await unlockedAchievements();
    return AchievementCatalog.all
        .map((a) => a.copyWith(unlockedAt: unlocked[a.id]))
        .toList();
  }

  // --- Reminders ----------------------------------------------------------

  Future<void> upsertReminder(ReminderItem reminder) async {
    final db = await database;
    await db.insert(
      'reminders',
      reminder.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ReminderItem>> getReminders() async {
    final db = await database;
    final rows = await db.query('reminders', orderBy: 'minutes_of_day ASC');
    return rows.map(ReminderItem.fromMap).toList();
  }

  Future<void> deleteReminder(String id) async {
    final db = await database;
    await db.delete('reminders', where: 'id = ?', whereArgs: [id]);
  }

  /// Deletes all user data. Used for "reset" flows; import replaces via upsert.
  Future<void> clearAll() async {
    final db = await database;
    await db.delete('days');
    await db.delete('achievements');
    await db.delete('reminders');
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
    _openFuture = null;
  }
}
