/// SQLite-backed Knowledge Repository — Implementation Specification IS-R48.
///
/// Persists canonical `KnowledgeResource` rows so acquired knowledge survives
/// application restart.
///
/// WHY THIS IS NOT A SECOND PERSISTENCE LAYER. `lib/storage/` already holds
/// ten per-domain repositories (`SqliteExperienceRepository`,
/// `WorldModelRepository`, `EngineeringMemoryRepository`, `IntentRepository`,
/// `ActivityRepository`, ...). A per-domain repository behind the ONE
/// canonical owner of its domain IS the established architecture here; this
/// is the Nth instance of that pattern, deliberately mirroring
/// `SqliteExperienceRepository` (injectable `dbName`, lazy `database` getter,
/// `_createTables`, `close()`) rather than inventing a new shape.
///
/// WHY SQLITE RATHER THAN SharedPreferences. `ActivityRepository` stores one
/// small JSON blob under a single key, which forces a full read/write of
/// everything on every access. Knowledge resources are bounded by
/// `RuntimeSecurityLimits.maxKnowledgeBytes` (200 KB each), and IS-R48
/// explicitly requires bounded startup with no eager loading and incremental
/// restoration. A keyed table supports loading exactly one cache key's rows on
/// demand; a single blob cannot.
///
/// OWNERSHIP. This repository is an implementation detail of `KnowledgeCache`
/// and is not a cache itself: it has no lookup policy, no ranking, no
/// deduplication and no expiry. It stores rows and returns rows.
/// `KnowledgeCache` remains the single canonical cache (certified).
///
/// SERIALIZATION. No custom serializer, no custom JSON, no custom canonical
/// encoder. Rows carry:
///   * `resource_json` — the resource's OWN existing `toJson()`, encoded with
///     `dart:convert`. IS-R48 fixed `toJson()`/`fromJson()` to round-trip
///     `content`, which they previously dropped.
///   * `canonical_representation` — produced by WebWeaveX's own
///     `stableSerialize` via `WebWeaveXAdapter.canonicalRepresentation()`,
///     passed in by the caller. This repository never imports
///     `package:webweavex` (R46 invariant I-21b) and never computes a
///     canonical form itself.
///
/// INTEGRITY ON LOAD. A row whose stored `content` no longer hashes to its
/// stored `content_hash` is DROPPED, not repaired and not returned. Silently
/// serving corrupted knowledge to the reasoner would be worse than a cache
/// miss, and fabricating a replacement is never acceptable.
library;

import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../knowledge/knowledge_resource.dart';

/// One persisted resource together with the canonical representation that was
/// computed for it at acquisition time.
class PersistedKnowledgeResource {
  final KnowledgeResource resource;

  /// The `stableSerialize` output recorded when this resource was stored.
  /// Retained as evidence: a test (or a caller holding the adapter) can
  /// recompute it and prove the canonical form survived the round trip.
  final String canonicalRepresentation;

  const PersistedKnowledgeResource({
    required this.resource,
    required this.canonicalRepresentation,
  });
}

/// Size and recency of one persisted cache key. A reported FACT, never a
/// retention decision — see [KnowledgeRepository.keySummaries].
class KnowledgeKeySummary {
  final String cacheKey;
  final int entryCount;
  final int totalBytes;
  final DateTime newestRetrievedAt;

  const KnowledgeKeySummary({
    required this.cacheKey,
    required this.entryCount,
    required this.totalBytes,
    required this.newestRetrievedAt,
  });
}

class KnowledgeRepository {
  Database? _database;
  final String _dbName;

  KnowledgeRepository({String dbName = 'anything_knowledge.db'})
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
    // `position` preserves the ranked order the acquisition engine produced,
    // so a restored list is byte-identical to the one that was stored rather
    // than merely set-equal.
    await db.execute('''
      CREATE TABLE knowledge_resources (
        cache_key TEXT NOT NULL,
        position INTEGER NOT NULL,
        resource_id TEXT NOT NULL,
        content_hash TEXT,
        canonical_representation TEXT NOT NULL,
        resource_json TEXT NOT NULL,
        retrieved_at TEXT NOT NULL,
        stored_at TEXT NOT NULL,
        PRIMARY KEY (cache_key, position)
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_knowledge_cache_key ON knowledge_resources (cache_key)',
    );
  }

  /// Replace every row for [cacheKey] with [entries], in order.
  ///
  /// Delete-then-insert mirrors `KnowledgeCache.put()`'s existing
  /// replace-on-put semantics exactly — IS-R48 introduces no new invalidation
  /// policy, because the codebase has none to extend (there is no TTL,
  /// eviction or staleness rule anywhere in the knowledge subsystem).
  Future<void> putResources(
    String cacheKey,
    List<PersistedKnowledgeResource> entries,
  ) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.delete(
        'knowledge_resources',
        where: 'cache_key = ?',
        whereArgs: [cacheKey],
      );
      for (var i = 0; i < entries.length; i++) {
        final entry = entries[i];
        await txn.insert('knowledge_resources', {
          'cache_key': cacheKey,
          'position': i,
          'resource_id': entry.resource.id,
          'content_hash': entry.resource.contentHash,
          'canonical_representation': entry.canonicalRepresentation,
          'resource_json': jsonEncode(entry.resource.toJson()),
          'retrieved_at': entry.resource.retrievedAt.toIso8601String(),
          'stored_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  /// Rows for exactly [cacheKey], in stored order — the incremental unit of
  /// restoration. Returns `null` when nothing is persisted for this key, so
  /// callers can distinguish "not cached" from "cached, and genuinely empty".
  Future<List<PersistedKnowledgeResource>?> resourcesFor(String cacheKey) async {
    final db = await database;
    final rows = await db.query(
      'knowledge_resources',
      where: 'cache_key = ?',
      whereArgs: [cacheKey],
      orderBy: 'position ASC',
    );
    if (rows.isEmpty) return null;

    final entries = <PersistedKnowledgeResource>[];
    for (final row in rows) {
      final decoded = _decode(row);
      if (decoded != null) entries.add(decoded);
    }
    // Every row was corrupt: report a miss rather than an empty hit, so the
    // caller re-acquires instead of trusting an empty result.
    if (entries.isEmpty) return null;
    return entries;
  }

  /// Decodes one row, or returns `null` if it is unusable. Never throws and
  /// never repairs: an unreadable or tampered row is dropped.
  PersistedKnowledgeResource? _decode(Map<String, Object?> row) {
    try {
      final json = jsonDecode(row['resource_json'] as String);
      if (json is! Map<String, dynamic>) return null;
      final resource = KnowledgeResource.fromJson(json);

      // Integrity: stored content must still hash to the stored hash.
      final storedHash = row['content_hash'] as String?;
      final content = resource.content;
      if (storedHash != null && content != null) {
        if (KnowledgeResource.computeHash(content) != storedHash) return null;
      }

      return PersistedKnowledgeResource(
        resource: resource,
        canonicalRepresentation: row['canonical_representation'] as String,
      );
    } catch (_) {
      return null;
    }
  }

  /// Per-key size and recency, WITHOUT loading any resource content.
  ///
  /// IS-R50: this is the input `KnowledgeCache` hands to
  /// `RetentionPolicyEngine`. It is deliberately a plain aggregate query and
  /// NOT a retention decision — this repository still owns no policy, has no
  /// bounds of its own, and reclaims nothing on its own initiative. It reports
  /// facts; something else decides. (Certified by invariants I-44/I-45.)
  ///
  /// Uses SQL aggregation so evaluating retention never materialises stored
  /// content, keeping the cost proportional to key count rather than corpus
  /// size.
  Future<List<KnowledgeKeySummary>> keySummaries() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT cache_key, '
      'COUNT(*) AS entries, '
      'SUM(LENGTH(resource_json)) AS bytes, '
      'MAX(retrieved_at) AS newest '
      'FROM knowledge_resources GROUP BY cache_key ORDER BY cache_key ASC',
    );
    return [
      for (final row in rows)
        KnowledgeKeySummary(
          cacheKey: row['cache_key'] as String,
          entryCount: (row['entries'] as int?) ?? 0,
          totalBytes: (row['bytes'] as int?) ?? 0,
          newestRetrievedAt:
              DateTime.tryParse(row['newest'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
        ),
    ];
  }

  /// Every persisted cache key. Used for diagnostics and by certification —
  /// deliberately NOT used to eagerly load anything.
  Future<List<String>> cacheKeys() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT DISTINCT cache_key FROM knowledge_resources ORDER BY cache_key ASC',
    );
    return [for (final row in rows) row['cache_key'] as String];
  }

  /// Number of persisted rows — diagnostics only.
  Future<int> resourceCount() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM knowledge_resources',
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<void> removeKey(String cacheKey) async {
    final db = await database;
    await db.delete(
      'knowledge_resources',
      where: 'cache_key = ?',
      whereArgs: [cacheKey],
    );
  }

  Future<void> clear() async {
    final db = await database;
    await db.delete('knowledge_resources');
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
