/// EngineeringMemoryRepository — Implementation Milestone R5. Persists
/// `RequirementGraph`/`ArchitectureCandidate` (full fidelity) and an
/// `EngineeringMemorySummary` (deliberate, honest summary — see
/// `engineering_memory_summary.dart`) per Experience — closing R4's own
/// documented finding that these are transient, Kernel-internal
/// artifacts, never persisted, so `planEvolution()` could never compare
/// against real historical state.
///
/// Reuses the EXISTING SQLite architecture exactly like
/// `WorldModelRepository` (Vision Milestone V10) already does: shares the
/// same physical database connection as `SqliteExperienceRepository` (via
/// its public `database` getter), creates its own table with
/// `CREATE TABLE IF NOT EXISTS` — idempotent, requires no schema-version
/// bump or `onUpgrade` migration to either existing repository. Same
/// serialization convention as `ExperiencePackage` itself: hand-written
/// `toJson()`, `jsonEncode` to a TEXT column, a `sha256` integrity hash
/// computed the exact same way `ExperiencePackage.computeIntegrityHash`
/// already does (`package:crypto`, already a dependency) — never a new
/// hashing scheme.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import '../application_engineering/engineering_memory_summary.dart';
import '../software_architect/architecture_candidate.dart';
import '../software_architect/architecture_candidate_serialization.dart';
import '../software_architect/requirement_graph.dart';
import '../software_architect/requirement_graph_serialization.dart';
import 'sqlite_experience_repository.dart';

/// The persisted engineering memory for one Experience — a real, typed
/// value, never a bare row. Backward-compatible callers (any Experience
/// created before this milestone) simply get `null` from `load()`.
class EngineeringMemoryRecord {
  final String experienceId;
  final RequirementGraph? requirementGraph;
  final ArchitectureCandidate? architectureCandidate;
  final EngineeringMemorySummary? engineeringSummary;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EngineeringMemoryRecord({
    required this.experienceId,
    this.requirementGraph,
    this.architectureCandidate,
    this.engineeringSummary,
    required this.createdAt,
    required this.updatedAt,
  });
}

class EngineeringMemoryRepository {
  static const int _schemaVersion = 1;

  final SqliteExperienceRepository _experienceRepository;
  bool _tablesEnsured = false;

  EngineeringMemoryRepository({SqliteExperienceRepository? experienceRepository})
    : _experienceRepository = experienceRepository ?? SqliteExperienceRepository();

  Future<Database> get _db async {
    final db = await _experienceRepository.database;
    if (!_tablesEnsured) {
      await _ensureTables(db);
      _tablesEnsured = true;
    }
    return db;
  }

  Future<void> _ensureTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS engineering_memory (
        experience_id TEXT PRIMARY KEY,
        schema_version INTEGER NOT NULL,
        requirement_graph_json TEXT,
        architecture_candidate_json TEXT,
        engineering_summary_json TEXT,
        integrity_hash TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  String _computeHash(String? a, String? b, String? c) =>
      sha256.convert(utf8.encode('${a ?? ''}|${b ?? ''}|${c ?? ''}')).toString();

  /// Saves engineering memory for [experienceId]. Real, deterministic:
  /// the same inputs always serialize to the same JSON and the same
  /// integrity hash. Never called inside the same SQLite transaction as
  /// `SqliteExperienceRepository.savePackage()` — see
  /// `docs/architecture/ENGINEERING_MEMORY.md` "Atomicity" for why a
  /// failure here must never roll back (or block) a successful package
  /// save, mirroring R1-R4's identical "bookkeeping must never break the
  /// primary operation" contract for World Model ingestion.
  Future<void> save({
    required String experienceId,
    RequirementGraph? requirementGraph,
    ArchitectureCandidate? architectureCandidate,
    EngineeringMemorySummary? engineeringSummary,
  }) async {
    final db = await _db;
    final reqJson = requirementGraph == null ? null : jsonEncode(requirementGraph.toJson());
    final archJson = architectureCandidate == null ? null : jsonEncode(architectureCandidate.toJson());
    final engJson = engineeringSummary == null ? null : jsonEncode(engineeringSummary.toJson());
    final now = DateTime.now().toIso8601String();

    await db.insert('engineering_memory', {
      'experience_id': experienceId,
      'schema_version': _schemaVersion,
      'requirement_graph_json': reqJson,
      'architecture_candidate_json': archJson,
      'engineering_summary_json': engJson,
      'integrity_hash': _computeHash(reqJson, archJson, engJson),
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Returns `null` when no engineering memory was ever persisted for
  /// [experienceId] (every Experience created before this milestone, or
  /// one for which persistence silently failed at creation time) —
  /// callers must treat this as a normal, expected case, never an error
  /// (Rule 10: backward compatibility, graceful degradation).
  ///
  /// A tampered/corrupted row (integrity hash mismatch) is detected and
  /// treated exactly like a missing one — returns `null` rather than
  /// surfacing malformed data, matching the "honest, never silent, never
  /// crash" contract established by every prior R-series milestone.
  Future<EngineeringMemoryRecord?> load(String experienceId) async {
    final db = await _db;
    final rows = await db.query('engineering_memory', where: 'experience_id = ?', whereArgs: [experienceId]);
    if (rows.isEmpty) return null;
    final row = rows.first;

    final reqJson = row['requirement_graph_json'] as String?;
    final archJson = row['architecture_candidate_json'] as String?;
    final engJson = row['engineering_summary_json'] as String?;

    final expectedHash = row['integrity_hash'] as String;
    if (_computeHash(reqJson, archJson, engJson) != expectedHash) {
      return null;
    }

    try {
      return EngineeringMemoryRecord(
        experienceId: experienceId,
        requirementGraph: reqJson == null
            ? null
            : RequirementGraphJson.fromJson(jsonDecode(reqJson) as Map<String, dynamic>),
        architectureCandidate: archJson == null
            ? null
            : ArchitectureCandidateJson.fromJson(jsonDecode(archJson) as Map<String, dynamic>),
        engineeringSummary: engJson == null
            ? null
            : EngineeringMemorySummary.fromJson(jsonDecode(engJson) as Map<String, dynamic>),
        createdAt: DateTime.parse(row['created_at'] as String),
        updatedAt: DateTime.parse(row['updated_at'] as String),
      );
    } catch (_) {
      // Malformed JSON despite a matching hash (e.g. a future schema
      // version this build doesn't understand) — degrade gracefully,
      // never throw into a caller that didn't expect engineering memory
      // to be mandatory.
      return null;
    }
  }

  Future<void> delete(String experienceId) async {
    final db = await _db;
    await db.delete('engineering_memory', where: 'experience_id = ?', whereArgs: [experienceId]);
  }
}
