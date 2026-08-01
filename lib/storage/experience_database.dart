/// Real local database for Experience data persistence.
///
/// Maps ExperienceDataRuntime to SQLite.
/// Each Experience gets isolated data namespace.
library;

import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../security/runtime_security_limits.dart';

/// Real SQLite-backed database for Experience data.
class ExperienceDatabase {
  Database? _database;
  final String _experienceId;
  final String? _customPath;

  /// Creates an ExperienceDatabase.
  /// If [customPath] is provided, uses that path instead of the default.
  ExperienceDatabase(this._experienceId, {String? customPath})
    : _customPath = customPath;

  /// Get or initialize the database.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path =
        _customPath ??
        p.join(await getDatabasesPath(), 'experience_$_experienceId.db');
    return await openDatabase(path, version: 1, onCreate: _createTables);
  }

  Future<void> _createTables(Database db, int version) async {
    // Create a generic records table for each entity
    await db.execute('''
      CREATE TABLE records (
        id TEXT PRIMARY KEY,
        entity TEXT NOT NULL,
        data TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE INDEX idx_records_entity ON records(entity)
    ''');
  }

  /// Insert a record.
  Future<void> insert(String entity, Map<String, dynamic> record) async {
    final db = await database;
    final id =
        record['id'] as String? ??
        'rec-${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.insert('records', {
      'id': id,
      'entity': entity,
      'data': jsonEncode(record),
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Query records for an entity, bounded by a trusted maximum row count
  /// regardless of how many rows actually exist — a generated Experience
  /// cannot force an unbounded fetch into memory by growing its own table
  /// (see RuntimeSecurityLimits.maxFetchRowsPerQuery). [limit], if given,
  /// may only ever narrow that bound, never raise it.
  Future<List<Map<String, dynamic>>> query(String entity, {int? limit}) async {
    final db = await database;
    final effectiveLimit = limit == null
        ? RuntimeSecurityLimits.maxFetchRowsPerQuery
        : (limit < RuntimeSecurityLimits.maxFetchRowsPerQuery
              ? limit
              : RuntimeSecurityLimits.maxFetchRowsPerQuery);
    final rows = await db.query(
      'records',
      where: 'entity = ?',
      whereArgs: [entity],
      orderBy: 'created_at ASC',
      limit: effectiveLimit,
    );

    return rows.map((row) {
      final data = jsonDecode(row['data'] as String) as Map<String, dynamic>;
      return data;
    }).toList();
  }

  /// Read a record by ID.
  Future<Map<String, dynamic>?> readById(String entity, String id) async {
    final db = await database;
    final rows = await db.query(
      'records',
      where: 'entity = ? AND id = ?',
      whereArgs: [entity, id],
    );

    if (rows.isEmpty) return null;
    return jsonDecode(rows.first['data'] as String) as Map<String, dynamic>;
  }

  /// Update a record by ID.
  Future<void> update(
    String entity,
    String id,
    Map<String, dynamic> updates,
  ) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Read existing record
    final existing = await readById(entity, id);
    if (existing == null) return;

    final merged = {...existing, ...updates};

    await db.update(
      'records',
      {'data': jsonEncode(merged), 'updated_at': now},
      where: 'entity = ? AND id = ?',
      whereArgs: [entity, id],
    );
  }

  /// Delete a record by ID.
  Future<void> delete(String entity, String id) async {
    final db = await database;
    await db.delete(
      'records',
      where: 'entity = ? AND id = ?',
      whereArgs: [entity, id],
    );
  }

  /// Count records for an entity.
  Future<int> count(String entity) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM records WHERE entity = ?',
      [entity],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Close the database.
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
