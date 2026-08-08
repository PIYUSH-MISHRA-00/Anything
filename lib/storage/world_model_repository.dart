/// WorldModelRepository — Vision Milestone V10 (Release Candidate
/// Hardening). Persists the World Graph, its version/snapshot history,
/// and Runtime Intelligence's Observation/Learning/Automation history —
/// resolving V9's own documented limitation ("WorldMemory/WorldHistory
/// are scoped to whatever owns the WorldModelCoordinator instance's
/// lifetime — not yet persisted across process restarts").
///
/// Deliberately reuses the EXISTING SQLite architecture rather than
/// inventing a new storage layer: this repository shares the exact same
/// physical database connection as `SqliteExperienceRepository` (via its
/// public `database` getter) and creates its own tables with
/// `CREATE TABLE IF NOT EXISTS` — idempotent, safe to call on every open,
/// and requiring no schema-version bump or `onUpgrade` migration to the
/// existing, heavily-tested `SqliteExperienceRepository` (which today has
/// no `onUpgrade` mechanism at all — confirmed by audit). Same package
/// (`sqflite`), same file conventions (snake_case columns, ISO-8601
/// timestamps, `ConflictAlgorithm.replace`) as
/// `sqlite_experience_repository.dart`.
///
/// Honest about what is and isn't fully round-tripped: `WorldNode`/
/// `WorldEdge`/`ObservationRecord` are simple, flat types and persist
/// with full fidelity. `LearningRecord`/`AutomationRecord` carry deeply
/// nested structures (a `Pattern`'s full evidence list; an
/// `AutomationPlan`'s full step list) that this milestone persists as
/// real, useful SUMMARIES (`PersistedLearningSummary`/
/// `PersistedAutomationSummary`) rather than fabricating a full
/// reconstruction from a flat row — documented explicitly, never
/// silently lossy.
library;

import 'package:sqflite/sqflite.dart';

import '../world_model/entity_identity.dart';
import '../world_model/world_edge.dart';
import '../world_model/world_graph.dart';
import '../world_model/world_node.dart';
import '../world_model/world_types.dart';
import '../runtime_intelligence/observation_record.dart';
import '../runtime_intelligence/ril_types.dart';
import 'sqlite_experience_repository.dart';

/// A persisted trail entry for World Graph growth — deliberately lighter
/// than the in-memory `WorldSnapshot` (which optionally carries a full
/// graph): persisting a full graph copy per version would grow
/// unboundedly. Only the LATEST graph is fully persisted (via
/// `saveGraph`/`loadGraph`); this table is an audit trail of how it grew.
class WorldSnapshotRecord {
  final int version;
  final DateTime createdAt;
  final int nodeCount;
  final int edgeCount;

  const WorldSnapshotRecord({
    required this.version,
    required this.createdAt,
    required this.nodeCount,
    required this.edgeCount,
  });
}

class PersistedLearningSummary {
  final String id;
  final String patternId;
  final PatternKind patternKind;
  final String description;
  final double confidenceScore;
  final String confidenceReason;
  final DateTime learnedAt;
  final int version;

  const PersistedLearningSummary({
    required this.id,
    required this.patternId,
    required this.patternKind,
    required this.description,
    required this.confidenceScore,
    required this.confidenceReason,
    required this.learnedAt,
    required this.version,
  });
}

class PersistedAutomationSummary {
  final String planId;
  final String description;
  final bool allEligible;
  final DateTime plannedAt;
  final int version;

  const PersistedAutomationSummary({
    required this.planId,
    required this.description,
    required this.allEligible,
    required this.plannedAt,
    required this.version,
  });
}

class WorldModelRepository {
  final SqliteExperienceRepository _experienceRepository;
  bool _tablesEnsured = false;

  WorldModelRepository({SqliteExperienceRepository? experienceRepository})
    : _experienceRepository =
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
      CREATE TABLE IF NOT EXISTS world_graph_nodes (
        identity TEXT PRIMARY KEY,
        kind TEXT NOT NULL,
        label TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS world_graph_edges (
        from_id TEXT NOT NULL,
        to_id TEXT NOT NULL,
        kind TEXT NOT NULL,
        evidence_graph TEXT NOT NULL,
        evidence_node TEXT NOT NULL,
        confidence_score REAL NOT NULL,
        confidence_reason TEXT NOT NULL,
        PRIMARY KEY (from_id, to_id, kind)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_world_edges_from ON world_graph_edges(from_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_world_edges_to ON world_graph_edges(to_id)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS world_snapshots (
        version INTEGER PRIMARY KEY,
        created_at TEXT NOT NULL,
        node_count INTEGER NOT NULL,
        edge_count INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS observation_records (
        id TEXT PRIMARY KEY,
        category TEXT NOT NULL,
        experience_id TEXT,
        screen_id TEXT,
        entity_id TEXT,
        capability_id TEXT,
        succeeded INTEGER NOT NULL,
        count INTEGER,
        timestamp TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_observation_experience ON observation_records(experience_id)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS learning_records (
        id TEXT PRIMARY KEY,
        pattern_id TEXT NOT NULL,
        pattern_kind TEXT NOT NULL,
        description TEXT NOT NULL,
        confidence_score REAL NOT NULL,
        confidence_reason TEXT NOT NULL,
        learned_at TEXT NOT NULL,
        version INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS automation_records (
        plan_id TEXT PRIMARY KEY,
        description TEXT NOT NULL,
        all_eligible INTEGER NOT NULL,
        planned_at TEXT NOT NULL,
        version INTEGER NOT NULL
      )
    ''');
  }

  // ---------------------------------------------------------------------
  // World Graph — always represents the LATEST approved state.
  // ---------------------------------------------------------------------

  /// Replaces the persisted graph with [graph] in one transaction, using
  /// a real batch (Vision Milestone V10 performance hardening: a stress
  /// test with 1000 nodes / 10000 edges measured ~5.7s with one
  /// `insert()` call per row inside the transaction; batching the same
  /// writes cut this dramatically — see docs/performance for the
  /// measured before/after). The graph on disk always matches the last
  /// successfully-applied WorldModelEngine update, never a stale partial
  /// state.
  Future<void> saveGraph(WorldGraph graph) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('world_graph_nodes');
      await txn.delete('world_graph_edges');

      final batch = txn.batch();
      for (final node in graph.nodes) {
        batch.insert('world_graph_nodes', {
          'identity': node.identity.value,
          'kind': node.kind.name,
          'label': node.label,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final edge in graph.edges) {
        batch.insert('world_graph_edges', {
          'from_id': edge.fromId.value,
          'to_id': edge.toId.value,
          'kind': edge.kind.name,
          'evidence_graph': edge.evidence.sourceGraph,
          'evidence_node': edge.evidence.sourceNodeId,
          'confidence_score': edge.confidence.score,
          'confidence_reason': edge.confidence.reason,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<WorldGraph> loadGraph() async {
    final db = await _db;
    final nodeRows = await db.query('world_graph_nodes');
    final edgeRows = await db.query('world_graph_edges');

    // EntityIdentity has no public constructor from a raw string — every
    // persisted identity was originally produced by EntityIdentity.stable
    // or .structural, so its `.value` already IS the canonical string,
    // self-namespaced by its OWN node kind (e.g. "entity:Task,text:title",
    // "capability:clock"). Reconstruction must derive the kind from the
    // identity value's own prefix — NOT from an edge row's `kind` column,
    // which names the RELATIONSHIP kind (e.g. "consumes"), a completely
    // different vocabulary (WorldNodeKind vs RelationshipKind).
    EntityIdentity identityFromValue(String value) {
      final separator = value.indexOf(':');
      final kindName = value.substring(0, separator);
      final rest = value.substring(separator + 1);
      return EntityIdentity.stable(WorldNodeKind.values.byName(kindName), rest);
    }

    final nodes = nodeRows
        .map(
          (row) => WorldNode(
            identity: identityFromValue(row['identity'] as String),
            kind: WorldNodeKind.values.byName(row['kind'] as String),
            label: row['label'] as String,
          ),
        )
        .toList();

    final edges = edgeRows
        .map(
          (row) => WorldEdge(
            fromId: identityFromValue(row['from_id'] as String),
            toId: identityFromValue(row['to_id'] as String),
            kind: RelationshipKind.values.byName(row['kind'] as String),
            evidence: GraphEvidence(
              sourceGraph: row['evidence_graph'] as String,
              sourceNodeId: row['evidence_node'] as String,
            ),
            confidence: GraphConfidence(
              score: row['confidence_score'] as double,
              reason: row['confidence_reason'] as String,
            ),
          ),
        )
        .toList();

    return WorldGraph(nodes: nodes, edges: edges);
  }

  // ---------------------------------------------------------------------
  // World Snapshot / Version history
  // ---------------------------------------------------------------------

  Future<void> recordSnapshot(WorldSnapshotRecord record) async {
    final db = await _db;
    await db.insert('world_snapshots', {
      'version': record.version,
      'created_at': record.createdAt.toIso8601String(),
      'node_count': record.nodeCount,
      'edge_count': record.edgeCount,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<WorldSnapshotRecord>> loadSnapshotHistory() async {
    final db = await _db;
    final rows = await db.query('world_snapshots', orderBy: 'version ASC');
    return rows
        .map(
          (row) => WorldSnapshotRecord(
            version: row['version'] as int,
            createdAt: DateTime.parse(row['created_at'] as String),
            nodeCount: row['node_count'] as int,
            edgeCount: row['edge_count'] as int,
          ),
        )
        .toList();
  }

  // ---------------------------------------------------------------------
  // Observation history — full fidelity (already a flat, structural type).
  // ---------------------------------------------------------------------

  Future<void> recordObservation(ObservationRecord record) async {
    final db = await _db;
    await db.insert('observation_records', {
      'id': record.id,
      'category': record.category.name,
      'experience_id': record.experienceId,
      'screen_id': record.screenId,
      'entity_id': record.entityId,
      'capability_id': record.capabilityId,
      'succeeded': record.succeeded ? 1 : 0,
      'count': record.count,
      'timestamp': record.timestamp.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> recordObservations(List<ObservationRecord> records) async {
    final db = await _db;
    final batch = db.batch();
    for (final record in records) {
      batch.insert('observation_records', {
        'id': record.id,
        'category': record.category.name,
        'experience_id': record.experienceId,
        'screen_id': record.screenId,
        'entity_id': record.entityId,
        'capability_id': record.capabilityId,
        'succeeded': record.succeeded ? 1 : 0,
        'count': record.count,
        'timestamp': record.timestamp.toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<ObservationRecord>> loadObservations({
    String? experienceId,
  }) async {
    final db = await _db;
    final rows = experienceId == null
        ? await db.query('observation_records')
        : await db.query(
            'observation_records',
            where: 'experience_id = ?',
            whereArgs: [experienceId],
          );

    return rows
        .map(
          (row) => ObservationRecord(
            id: row['id'] as String,
            category: ObservationCategory.values.byName(
              row['category'] as String,
            ),
            experienceId: row['experience_id'] as String?,
            screenId: row['screen_id'] as String?,
            entityId: row['entity_id'] as String?,
            capabilityId: row['capability_id'] as String?,
            succeeded: (row['succeeded'] as int) == 1,
            count: row['count'] as int?,
            timestamp: DateTime.parse(row['timestamp'] as String),
          ),
        )
        .toList();
  }

  // ---------------------------------------------------------------------
  // Learning history — a real, useful summary (never the full nested
  // PatternEvidence list, documented honestly).
  // ---------------------------------------------------------------------

  Future<void> recordLearningSummary(PersistedLearningSummary summary) async {
    final db = await _db;
    await db.insert('learning_records', {
      'id': summary.id,
      'pattern_id': summary.patternId,
      'pattern_kind': summary.patternKind.name,
      'description': summary.description,
      'confidence_score': summary.confidenceScore,
      'confidence_reason': summary.confidenceReason,
      'learned_at': summary.learnedAt.toIso8601String(),
      'version': summary.version,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<PersistedLearningSummary>> loadLearningSummaries() async {
    final db = await _db;
    final rows = await db.query('learning_records', orderBy: 'learned_at ASC');
    return rows
        .map(
          (row) => PersistedLearningSummary(
            id: row['id'] as String,
            patternId: row['pattern_id'] as String,
            patternKind: PatternKind.values.byName(
              row['pattern_kind'] as String,
            ),
            description: row['description'] as String,
            confidenceScore: row['confidence_score'] as double,
            confidenceReason: row['confidence_reason'] as String,
            learnedAt: DateTime.parse(row['learned_at'] as String),
            version: row['version'] as int,
          ),
        )
        .toList();
  }

  // ---------------------------------------------------------------------
  // Automation history — a real, useful summary (never the full nested
  // step list, documented honestly).
  // ---------------------------------------------------------------------

  Future<void> recordAutomationSummary(
    PersistedAutomationSummary summary,
  ) async {
    final db = await _db;
    await db.insert('automation_records', {
      'plan_id': summary.planId,
      'description': summary.description,
      'all_eligible': summary.allEligible ? 1 : 0,
      'planned_at': summary.plannedAt.toIso8601String(),
      'version': summary.version,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<PersistedAutomationSummary>> loadAutomationSummaries() async {
    final db = await _db;
    final rows = await db.query(
      'automation_records',
      orderBy: 'planned_at ASC',
    );
    return rows
        .map(
          (row) => PersistedAutomationSummary(
            planId: row['plan_id'] as String,
            description: row['description'] as String,
            allEligible: (row['all_eligible'] as int) == 1,
            plannedAt: DateTime.parse(row['planned_at'] as String),
            version: row['version'] as int,
          ),
        )
        .toList();
  }
}
