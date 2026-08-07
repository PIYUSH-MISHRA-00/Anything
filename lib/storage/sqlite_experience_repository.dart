/// SQLite-backed Experience Repository.
///
/// Persists ExperiencePackage metadata and packages.
library;

import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

import '../app/experience_provenance.dart';
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

  /// IS-R52: canonical provenance. ONE field carrying the whole provenance
  /// value object rather than ten loose columns' worth of primitives on this
  /// class — so there is exactly one provenance model, and adding a future
  /// field (marketplace id, cloud id, signature) changes `ExperienceProvenance`
  /// and nothing here.
  ///
  /// Defaults to unknown-origin provenance, which is exactly what a row
  /// written before R52 truthfully has. The repository stores it; it never
  /// computes trust from it (certified I-55).
  final ExperienceProvenance provenance;

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
    this.provenance = const ExperienceProvenance(),
  });

  /// The canonical identity of this Experience (IS-R52 Task 3).
  ExperienceIdentity get identity =>
      ExperienceIdentity(experienceId: id, provenance: provenance);

  ExperienceMetadataRecord copyWith({ExperienceProvenance? provenance}) {
    return ExperienceMetadataRecord(
      id: id,
      name: name,
      description: description,
      category: category,
      createdAt: createdAt,
      updatedAt: updatedAt,
      lastUsedAt: lastUsedAt,
      packageVersion: packageVersion,
      packagePath: packagePath,
      isProtected: isProtected,
      provenance: provenance ?? this.provenance,
    );
  }

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
    'provenance': jsonEncode(provenance.toJson()),
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
      provenance: _provenanceFrom(json['provenance']),
    );
  }
}

/// Decodes a stored provenance blob. A row written before IS-R52 has no such
/// column, and a corrupt one is unreadable — both yield unknown-origin
/// provenance, which is the truthful answer rather than a fabricated origin.
/// Never throws: a metadata read must not fail because provenance is absent.
ExperienceProvenance _provenanceFrom(dynamic raw) {
  if (raw is! String || raw.isEmpty) return const ExperienceProvenance();
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return const ExperienceProvenance();
    return ExperienceProvenance.fromJson(Map<String, dynamic>.from(decoded));
  } catch (_) {
    return const ExperienceProvenance();
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
    return await openDatabase(path, version: 3, onCreate: _createTables, onUpgrade: _upgradeTables);
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
        is_protected INTEGER DEFAULT 0,
        provenance TEXT
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

    await _createIndexes(db);
  }

  /// Vision Milestone V10: a real `onUpgrade` migration path — this
  /// database previously had version:1 with no upgrade mechanism at all
  /// (confirmed by repository audit). `CREATE INDEX IF NOT EXISTS` is
  /// idempotent and additive only: it never touches existing rows, never
  /// changes any public API, and is safe to run against a database that
  /// already has these indexes (fresh installs get them via
  /// `_createTables` directly).
  Future<void> _upgradeTables(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createIndexes(db);
    }
    // IS-R52: provenance column, added additively.
    //
    // ADD COLUMN with no NOT NULL and no default is the whole migration: every
    // existing row keeps its data and reads back as unknown-origin provenance,
    // which is truthful — those Experiences really do predate provenance
    // tracking. No row is rewritten, nothing is backfilled with a guess, and
    // an interrupted upgrade cannot corrupt anything.
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE experiences ADD COLUMN provenance TEXT');
    }
  }

  /// `listAll()` orders by `last_used_at DESC, created_at DESC` — this
  /// index lets SQLite satisfy that ordering directly instead of a full
  /// table scan + sort as the experiences table grows.
  Future<void> _createIndexes(Database db) async {
    await db.execute('CREATE INDEX IF NOT EXISTS idx_experiences_last_used ON experiences(last_used_at DESC, created_at DESC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_experiences_category ON experiences(category)');
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
      'provenance': jsonEncode(record.provenance.toJson()),
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
            provenance: _provenanceFrom(row['provenance']),
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
