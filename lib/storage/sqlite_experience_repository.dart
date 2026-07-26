/// SQLite-backed Experience Repository.
///
/// Persists ExperiencePackage metadata and packages.
library;

import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

import '../creation/experience_package.dart';

/// Convert SQLite integer/bool to Dart bool.
bool _jsonToBool(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is int) return value != 0;
  return false;
}

/// Experience metadata for lightweight storage.
class ExperienceMetadataRecord {
  final String id;
  final String name;
  final String description;
  final String category;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastUsedAt;
  final String packageVersion;
  final String? packagePath;
  final bool isProtected;

  const ExperienceMetadataRecord({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.createdAt,
    required this.updatedAt,
    this.lastUsedAt,
    this.packageVersion = '1.0.0',
    this.packagePath,
    this.isProtected = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'category': category,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'last_used_at': lastUsedAt?.toIso8601String(),
    'package_version': packageVersion,
    'package_path': packagePath,
    'is_protected': isProtected,
  };

  factory ExperienceMetadataRecord.fromJson(Map<String, dynamic> json) {
    return ExperienceMetadataRecord(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'unknown',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      lastUsedAt: json['last_used_at'] != null
          ? DateTime.parse(json['last_used_at'] as String)
          : null,
      packageVersion: json['package_version'] as String? ?? '1.0.0',
      packagePath: json['package_path'] as String?,
      isProtected: _jsonToBool(json['is_protected']),
    );
  }
}

/// SQLite-backed Experience Repository.
class SqliteExperienceRepository {
  Database? _database;
  final String _dbName;

  SqliteExperienceRepository({String dbName = 'anything_experiences.db'})
    : _dbName = dbName;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);
    return await openDatabase(path, version: 1, onCreate: _createTables);
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE experiences (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        category TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        last_used_at TEXT,
        package_version TEXT,
        package_path TEXT,
        is_protected INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE experience_packages (
        experience_id TEXT PRIMARY KEY,
        package_data TEXT NOT NULL,
        integrity_hash TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE protected_envelopes (
        experience_id TEXT PRIMARY KEY,
        envelope_data TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  /// Save experience metadata.
  Future<void> saveMetadata(ExperienceMetadataRecord record) async {
    final db = await database;
    await db.insert('experiences', {
      'id': record.id,
      'name': record.name,
      'description': record.description,
      'category': record.category,
      'created_at': record.createdAt.toIso8601String(),
      'updated_at': record.updatedAt.toIso8601String(),
      'last_used_at': record.lastUsedAt?.toIso8601String(),
      'package_version': record.packageVersion,
      'package_path': record.packagePath,
      'is_protected': record.isProtected ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Save a complete ExperiencePackage.
  Future<void> savePackage(ExperiencePackage package) async {
    final db = await database;
    final jsonStr = jsonEncode(package.toJson());
    final hash = ExperiencePackage.computeIntegrityHash(package);

    await db.insert('experience_packages', {
      'experience_id': package.manifest.experienceId,
      'package_data': jsonStr,
      'integrity_hash': hash,
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Get experience metadata by ID.
  Future<ExperienceMetadataRecord?> getMetadata(String id) async {
    final db = await database;
    final rows = await db.query(
      'experiences',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (rows.isEmpty) return null;
    return ExperienceMetadataRecord.fromJson(rows.first);
  }

  /// Get a complete ExperiencePackage by ID.
  Future<ExperiencePackage?> getPackage(String experienceId) async {
    final db = await database;
    final rows = await db.query(
      'experience_packages',
      where: 'experience_id = ?',
      whereArgs: [experienceId],
    );

    if (rows.isEmpty) return null;
    final jsonStr = rows.first['package_data'] as String;
    return ExperiencePackage.fromJson(jsonDecode(jsonStr));
  }

  /// List all experience metadata, ordered by last used.
  Future<List<ExperienceMetadataRecord>> listAll({int? limit}) async {
    final db = await database;
    final rows = await db.query(
      'experiences',
      orderBy: 'last_used_at DESC, created_at DESC',
      limit: limit,
    );

    return rows
        .map(
          (row) => ExperienceMetadataRecord(
            id: row['id'] as String,
            name: row['name'] as String,
            description: row['description'] as String? ?? '',
            category: row['category'] as String? ?? 'unknown',
            createdAt: DateTime.parse(row['created_at'] as String),
            updatedAt: DateTime.parse(row['updated_at'] as String),
            lastUsedAt: row['last_used_at'] != null
                ? DateTime.parse(row['last_used_at'] as String)
                : null,
            packageVersion: row['package_version'] as String? ?? '1.0.0',
            isProtected: _jsonToBool(row['is_protected']),
          ),
        )
        .toList();
  }

  /// Update last used timestamp.
  Future<void> touchLastUsed(String experienceId) async {
    final db = await database;
    await db.update(
      'experiences',
      {'last_used_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [experienceId],
    );
  }

  /// Delete experience and its package.
  Future<void> delete(String experienceId) async {
    final db = await database;
    await db.delete('experiences', where: 'id = ?', whereArgs: [experienceId]);
    await db.delete(
      'experience_packages',
      where: 'experience_id = ?',
      whereArgs: [experienceId],
    );
    await db.delete(
      'protected_envelopes',
      where: 'experience_id = ?',
      whereArgs: [experienceId],
    );
  }

  /// Delete only the plaintext package data (used after protection).
  Future<void> deletePackage(String experienceId) async {
    final db = await database;
    await db.delete(
      'experience_packages',
      where: 'experience_id = ?',
      whereArgs: [experienceId],
    );
  }

  /// Update the protection state flag on the experience metadata.
  Future<void> updateProtectionState(
    String experienceId,
    bool isProtected,
  ) async {
    final db = await database;
    await db.update(
      'experiences',
      {'is_protected': isProtected ? 1 : 0},
      where: 'id = ?',
      whereArgs: [experienceId],
    );
  }

  /// Save a protected envelope (Kaalka ciphertext + metadata).
  Future<void> saveProtectedEnvelope(
    String experienceId,
    dynamic envelope,
  ) async {
    final db = await database;
    final jsonStr = envelope is String ? envelope : _safeJsonEncode(envelope);
    await db.insert('protected_envelopes', {
      'experience_id': experienceId,
      'envelope_data': jsonStr,
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Load a protected envelope by experience ID.
  ///
  /// Returns null if no envelope exists.
  Future<dynamic> getProtectedEnvelope(String experienceId) async {
    final db = await database;
    final rows = await db.query(
      'protected_envelopes',
      where: 'experience_id = ?',
      whereArgs: [experienceId],
    );
    if (rows.isEmpty) return null;
    return rows.first['envelope_data'] as String;
  }

  /// Delete a protected envelope (used after successful unprotection).
  Future<void> deleteProtectedEnvelope(String experienceId) async {
    final db = await database;
    await db.delete(
      'protected_envelopes',
      where: 'experience_id = ?',
      whereArgs: [experienceId],
    );
  }

  String _safeJsonEncode(dynamic obj) {
    if (obj is String) return obj;
    try {
      final jsonMap = (obj as dynamic).toJson();
      return jsonEncode(Map<String, dynamic>.from(jsonMap as Map));
    } catch (_) {
      return obj.toString();
    }
  }

  /// Close database.
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
