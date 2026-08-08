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
import '../backend_engineering/backend_engineering_plan.dart';
import '../backend_engineering/backend_engineering_serialization.dart';
import '../implementation_model/canonical_implementation_model.dart';
import '../implementation_model/canonical_implementation_serialization.dart';
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

  /// Real, persisted backend engineering decisions (Implementation
  /// Milestone R8) — `null` for every pre-R8 record, exactly like the
  /// other fields above are `null` for pre-R5 records.
  final BackendEngineeringPlan? backendEngineeringPlan;

  /// Real, persisted, language-independent implementation model
  /// (Implementation Milestone R9) — `null` for every pre-R9 record,
  /// exactly like [backendEngineeringPlan] is `null` for pre-R8 records.
  final CanonicalImplementationModel? canonicalImplementationModel;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EngineeringMemoryRecord({
    required this.experienceId,
    this.requirementGraph,
    this.architectureCandidate,
    this.engineeringSummary,
    this.backendEngineeringPlan,
    this.canonicalImplementationModel,
    required this.createdAt,
    required this.updatedAt,
  });
}

class EngineeringMemoryRepository {
  // Implementation Milestone R8: bumped 1 -> 2 for the new
  // backend_engineering_json column. Implementation Milestone R9: bumped
  // 2 -> 3 for canonical_implementation_json. Purely informational
  // (stored per row, never enforced by sqflite itself) — the real
  // migration is the additive `ALTER TABLE` in `_ensureTables` below,
  // mirroring SqliteExperienceRepository's own real onUpgrade discipline
  // (V10) at the column level rather than the whole-database level,
  // since this table (unlike the main experiences table) has no separate
  // onUpgrade hook of its own.
  static const int _schemaVersion = 3;

  final SqliteExperienceRepository _experienceRepository;
  bool _tablesEnsured = false;

  EngineeringMemoryRepository({
    SqliteExperienceRepository? experienceRepository,
  }) : _experienceRepository =
           experienceRepository ?? SqliteExperienceRepository();

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
        backend_engineering_json TEXT,
        canonical_implementation_json TEXT,
        integrity_hash TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    // Implementation Milestone R8/R9: additive columns for a table that
    // may already exist from an R5/R8-era database (CREATE TABLE IF NOT
    // EXISTS above is then a no-op and never adds new columns). sqflite
    // has no "ADD COLUMN IF NOT EXISTS" — catching the real "duplicate
    // column" failure is the established, safe idempotency pattern for
    // this exact situation; never destructive, never touches existing
    // rows.
    for (final column in [
      'backend_engineering_json',
      'canonical_implementation_json',
    ]) {
      try {
        await db.execute(
          'ALTER TABLE engineering_memory ADD COLUMN $column TEXT',
        );
      } catch (_) {
        // Column already exists (fresh-install CREATE TABLE already added
        // it above, or a prior R8/R9 run already migrated it) — expected,
        // not an error.
      }
    }
  }

  /// Deliberately UNCHANGED (still 3 fields) since Vision Milestone R5 —
  /// Implementation Milestone R8's `backendEngineeringJson` and R9's
  /// `canonicalImplementationJson` are intentionally NOT included here.
  /// Extending this formula to 4+ fields
  /// would change every R5-era row's expected hash retroactively (an old
  /// row's `integrity_hash` was computed without a `backend_engineering`
  /// placeholder at all), which would make `load()` treat every
  /// pre-existing, genuinely-valid R5 record as "tampered" and silently
  /// discard it — a real backward-compatibility regression, not a
  /// hypothetical one. Backend engineering data is still integrity-
  /// checked implicitly (malformed JSON is caught and degrades
  /// gracefully in `load()`'s existing try/catch), just not by this
  /// specific hash — a real, small, documented scope limit, not silently
  /// glossed over.
  String _computeHash(String? a, String? b, String? c) => sha256
      .convert(utf8.encode('${a ?? ''}|${b ?? ''}|${c ?? ''}'))
      .toString();

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
    BackendEngineeringPlan? backendEngineeringPlan,
    CanonicalImplementationModel? canonicalImplementationModel,
  }) async {
    final db = await _db;
    final reqJson = requirementGraph == null
        ? null
        : jsonEncode(requirementGraph.toJson());
    final archJson = architectureCandidate == null
        ? null
        : jsonEncode(architectureCandidate.toJson());
    final engJson = engineeringSummary == null
        ? null
        : jsonEncode(engineeringSummary.toJson());
    final backendJson = backendEngineeringPlan == null
        ? null
        : jsonEncode(backendEngineeringPlan.toJson());
    final cimJson = canonicalImplementationModel == null
        ? null
        : jsonEncode(canonicalImplementationModel.toJson());
    final now = DateTime.now().toIso8601String();

    await db.insert('engineering_memory', {
      'experience_id': experienceId,
      'schema_version': _schemaVersion,
      'requirement_graph_json': reqJson,
      'architecture_candidate_json': archJson,
      'engineering_summary_json': engJson,
      'backend_engineering_json': backendJson,
      'canonical_implementation_json': cimJson,
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
    final rows = await db.query(
      'engineering_memory',
      where: 'experience_id = ?',
      whereArgs: [experienceId],
    );
    if (rows.isEmpty) return null;
    final row = rows.first;

    final reqJson = row['requirement_graph_json'] as String?;
    final archJson = row['architecture_candidate_json'] as String?;
    final engJson = row['engineering_summary_json'] as String?;

    final expectedHash = row['integrity_hash'] as String;
    if (_computeHash(reqJson, archJson, engJson) != expectedHash) {
      return null;
    }

    // Implementation Milestone R8: read defensively via row.keys.contains
    // rather than row['backend_engineering_json'] directly — an R5-era
    // row loaded before this process's own _ensureTables migration ran
    // could theoretically be queried mid-migration in a multi-isolate
    // scenario; sqflite's single-isolate default and this repository's
    // _tablesEnsured gate make this a defensive belt, not a fix for an
    // observed bug.
    final backendJson = row.containsKey('backend_engineering_json')
        ? row['backend_engineering_json'] as String?
        : null;
    // Implementation Milestone R9: same defensive row.containsKey read as
    // backendJson above — an R5/R8-era row loaded before this process's
    // own _ensureTables migration ran could theoretically be queried
    // mid-migration.
    final cimJson = row.containsKey('canonical_implementation_json')
        ? row['canonical_implementation_json'] as String?
        : null;

    try {
      return EngineeringMemoryRecord(
        experienceId: experienceId,
        requirementGraph: reqJson == null
            ? null
            : RequirementGraphJson.fromJson(
                jsonDecode(reqJson) as Map<String, dynamic>,
              ),
        architectureCandidate: archJson == null
            ? null
            : ArchitectureCandidateJson.fromJson(
                jsonDecode(archJson) as Map<String, dynamic>,
              ),
        engineeringSummary: engJson == null
            ? null
            : EngineeringMemorySummary.fromJson(
                jsonDecode(engJson) as Map<String, dynamic>,
              ),
        backendEngineeringPlan: backendJson == null
            ? null
            : backendEngineeringPlanFromJson(
                jsonDecode(backendJson) as Map<String, dynamic>,
              ),
        canonicalImplementationModel: cimJson == null
            ? null
            : canonicalImplementationModelFromJson(
                jsonDecode(cimJson) as Map<String, dynamic>,
              ),
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
    await db.delete(
      'engineering_memory',
      where: 'experience_id = ?',
      whereArgs: [experienceId],
    );
  }
}
