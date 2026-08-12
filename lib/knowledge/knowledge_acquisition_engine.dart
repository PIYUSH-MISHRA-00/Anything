/// Knowledge Acquisition Engine for Anything.
///
/// Orchestrates knowledge retrieval, normalization, provenance,
/// trust, licensing, deduplication, ranking, and caching.
///
/// Pipeline: query text -> SearchProvider (candidate URLs) ->
/// WebWeaveXAdapter (real extraction per URL) -> validation -> dedup ->
/// ranking -> cache. WebWeaveX is only ever handed a URL; it never sees a
/// free-text query (see search_provider.dart / webweavex_adapter.dart).
///
/// Safe by default: with no SearchProvider/WebWeaveXAdapter configured
/// (the bare `KnowledgeAcquisitionEngine()` constructor), no network is
/// ever touched — every requirement is reported unresolved rather than
/// fabricated. Production wiring (real search + real extraction) happens
/// explicitly at the app's composition root
/// (lib/features/home/home_screen.dart), not as an implicit default here,
/// so every other caller (including the whole existing test suite) keeps
/// today's deterministic, network-free behavior unless it opts in.
library;

import 'package:uuid/uuid.dart';

import 'package:anything/app/retention_policy_engine.dart';
import 'package:anything/kernel/specification/experience_spec.dart';
import 'package:anything/storage/knowledge_repository.dart';
import 'knowledge_resource.dart';
import 'knowledge_bundle.dart';
import 'search_provider.dart';
import 'webweavex_adapter.dart';

/// Deterministic cache key: identical (query, language, provider, options)
/// always maps to the same key, and only that.
class KnowledgeCacheKey {
  final String query;
  final String language;
  final String provider;
  final Map<String, String> options;

  const KnowledgeCacheKey({
    required this.query,
    this.language = 'en',
    this.provider = 'webweavex',
    this.options = const {},
  });

  String toStableString() {
    final normalizedQuery = query.trim().toLowerCase();
    final sortedOptions = options.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final optionsPart = sortedOptions
        .map((e) => '${e.key}=${e.value}')
        .join('&');
    return '$provider::$language::$normalizedQuery::$optionsPart';
  }

  @override
  bool operator ==(Object other) =>
      other is KnowledgeCacheKey && toStableString() == other.toStableString();

  @override
  int get hashCode => toStableString().hashCode;
}

/// The Knowledge Acquisition Engine.
class KnowledgeAcquisitionEngine {
  final SearchProvider? _searchProvider;
  final WebWeaveXAdapter? _webweavexAdapter;
  final KnowledgeCache _cache;
  final int _maxResultsPerQuery;

  KnowledgeAcquisitionEngine({
    SearchProvider? searchProvider,
    WebWeaveXAdapter? webweavexAdapter,
    KnowledgeCache? cache,
    int maxResultsPerQuery = 5,
  }) : _searchProvider = searchProvider,
       _webweavexAdapter = webweavexAdapter,
       _cache = cache ?? KnowledgeCache(),
       _maxResultsPerQuery = maxResultsPerQuery;

  /// Exposes the shared `SearchProvider` (Implementation Milestone R16) —
  /// same pattern as `SoftwareCognitionCoordinator.engine`/`.reasoner`
  /// (R14/R15): lets a new consumer (`AnythingKernel`'s autonomous
  /// discovery step) reuse the EXACT same provider instance this engine
  /// already searches with, never a second search abstraction.
  SearchProvider? get searchProvider => _searchProvider;

  /// Acquire knowledge for the given requirements.
  Future<KnowledgeBundle> acquire({
    required List<KnowledgeRequirement> requirements,
    required List<String> queryHints,
    String language = 'en',
  }) async {
    if (requirements.isEmpty) {
      return KnowledgeBundle(
        id: const Uuid().v4(),
        status: BundleStatus.ready,
        resources: [],
        generatedAt: DateTime.now(),
      );
    }

    final queries = _planQueries(requirements, queryHints);
    final resources = <KnowledgeResource>[];
    final warnings = <String>[];
    var anyFromCache = false;
    var anyFreshlyFetched = false;
    var anyQueryResolved = false;

    for (final query in queries) {
      // Cache is always consulted first, independent of whether a live
      // provider is configured — this is what makes "offline: reuse
      // cached knowledge" and "network unavailable: still usable if
      // already cached" actually true rather than aspirational.
      final key = KnowledgeCacheKey(
        query: _canonicalQuery(query),
        language: language,
      );
      var found = await _cache.get(key);
      found ??= _cache.findRelevant(query);
      if (found != null && found.isNotEmpty) {
        resources.addAll(found);
        anyFromCache = true;
        anyQueryResolved = true;
        continue;
      }

      if (_searchProvider == null || _webweavexAdapter == null) {
        warnings.add('No knowledge provider configured for: $query');
        continue;
      }

      try {
        final results = await _searchProvider.search(
          query,
          maxResults: _maxResultsPerQuery,
        );
        final urls = results.map((r) => r.url).toList();
        final extracted = await _webweavexAdapter.extractAll(urls);
        final validated = _validate(extracted);
        if (validated.isNotEmpty) {
          await _cache.put(key, validated);
          resources.addAll(validated);
          anyFreshlyFetched = true;
          anyQueryResolved = true;
        } else {
          warnings.add('No usable results for: $query');
        }
      } catch (e) {
        warnings.add('Retrieval failed for: $query');
      }
    }

    final unresolved = anyQueryResolved
        ? <String>[]
        : requirements.map((r) => r.objective).toList();

    final normalized = _normalize(resources);
    final deduplicated = _deduplicate(normalized);
    final ranked = _rank(deduplicated);

    final hasResults = ranked.isNotEmpty;
    final allRequirementsUnresolved =
        unresolved.length == requirements.length && requirements.isNotEmpty;

    final status = allRequirementsUnresolved
        ? BundleStatus.failed
        : !hasResults
        ? BundleStatus.failed
        : (anyFreshlyFetched
              ? BundleStatus.ready
              : (anyFromCache
                    ? BundleStatus.offlineCached
                    : BundleStatus.ready));

    return KnowledgeBundle(
      id: const Uuid().v4(),
      status: status,
      resources: ranked,
      requirementsSatisfied: requirements
          .where((r) => !unresolved.contains(r.objective))
          .map((r) => r.objective)
          .toList(),
      unresolvedRequirements: unresolved,
      warnings: warnings,
      generatedAt: DateTime.now(),
      cacheStatus: anyFromCache && !anyFreshlyFetched ? 'offline_cached' : null,
    );
  }

  /// Canonicalize a query before it becomes a cache key (Implementation
  /// Specification IS-R47 Task 4).
  ///
  /// `KnowledgeCacheKey.toStableString()` already trims/lowercases/sorts, but
  /// it does NOT Unicode-normalize — so two canonically-equivalent queries
  /// (NFC vs NFD, or containing CRLF) mapped to different cache entries and
  /// re-fetched the same knowledge. Routing the query through the SAME
  /// canonical normalizer the extracted content already goes through closes
  /// that, with no second normalizer and no second cache.
  ///
  /// Delegated through [WebWeaveXAdapter.normalizeText] rather than importing
  /// `package:webweavex` here, so the adapter stays the single WebWeaveX
  /// boundary (R46 invariant I-21b). With no adapter configured — the bare,
  /// network-free `KnowledgeAcquisitionEngine()` default — behavior is
  /// unchanged, which is what keeps every existing caller and test intact.
  String _canonicalQuery(String query) =>
      _webweavexAdapter?.normalizeText(query) ?? query;

  List<String> _planQueries(
    List<KnowledgeRequirement> requirements,
    List<String> queryHints,
  ) {
    final queries = <String>[];
    for (final req in requirements) {
      // Enhance the objective with freshness hints so the search engine
      // returns current/real-time results instead of encyclopedia articles.
      // This is generic — no domain-specific routing, just query enrichment.
      var objective = req.objective;
      if (req.freshness == 'current' && objective.isNotEmpty) {
        objective = '$objective current latest real-time';
      }
      queries.add(objective);
      for (final hint in req.queryHints) {
        if (hint != req.objective) {
          queries.add(hint);
        }
      }
    }
    queries.addAll(queryHints.where((h) => !queries.contains(h)));
    return queries;
  }

  /// Reject empty, malformed, or oversized resources before they enter the
  /// bundle. WebWeaveXAdapter already bounds individual content size
  /// (RuntimeSecurityLimits.maxKnowledgeBytes); this is the second,
  /// independent check at the acquisition-engine boundary.
  List<KnowledgeResource> _validate(List<KnowledgeResource> resources) {
    return resources.where((r) {
      if (r.title.isEmpty && (r.content == null || r.content!.isEmpty)) {
        return false;
      }
      if (r.sourceUri.isEmpty) return false;
      final uri = Uri.tryParse(r.sourceUri);
      if (uri == null || !uri.scheme.startsWith('http')) return false;
      return true;
    }).toList();
  }

  List<KnowledgeResource> _normalize(List<KnowledgeResource> resources) {
    return resources
        .where((r) => r.contentHash != null || r.content != null)
        .toList();
  }

  List<KnowledgeResource> _deduplicate(List<KnowledgeResource> resources) {
    final seen = <String>{};
    return resources.where((r) {
      final key = r.contentHash ?? r.sourceUri;
      return seen.add(key);
    }).toList();
  }

  List<KnowledgeResource> _rank(List<KnowledgeResource> resources) {
    final sorted = List<KnowledgeResource>.from(resources);
    sorted.sort(
      (a, b) => b.ranking.overallScore.compareTo(a.ranking.overallScore),
    );
    return sorted;
  }
}

/// Local knowledge cache, keyed by (query, language, provider, options).
///
/// THE single canonical knowledge cache. There is no second cache, no
/// `PersistentKnowledgeCache`, and no cache hierarchy — certified by
/// `test/r46_architectural_integrity_certification_test.dart`.
///
/// PERSISTENCE (Implementation Specification IS-R48) is an implementation
/// detail of this class, not a layer above or beside it. Supply a
/// [KnowledgeRepository] and a [WebWeaveXAdapter] and the same [put]/[get]/
/// [clear] API additionally reads and writes durable rows; supply neither —
/// the default — and behaviour is byte-identical to the pre-R48, purely
/// in-memory cache, which is what keeps every existing caller and test
/// untouched.
///
/// RESTORATION IS LAZY AND INCREMENTAL, BY DESIGN. There is no startup scan
/// and no eager load. A [get] that misses in memory hydrates exactly ONE
/// cache key's rows from storage and promotes them into memory; nothing else
/// is read. IS-R48's own performance rule requires bounded startup with "no
/// eager loading of unnecessary resources" and "incremental cache
/// restoration" — loading on first use is the maximally incremental form of
/// that, and it needs no startup hook at all.
///
/// INVALIDATION reuses the policy that already existed rather than inventing
/// one: [put] replaces a key outright and [clear] empties everything. The
/// knowledge subsystem has no TTL, eviction or staleness rule anywhere (a
/// repository-wide search at R48 found none), so there is no expiration
/// policy engine to extend — and R48 deliberately does not introduce a
/// second one. The persisted rows follow the in-memory semantics exactly:
/// `putResources()` deletes then re-inserts, so a key never accumulates
/// stale rows.
class KnowledgeCache {
  final Map<String, List<KnowledgeResource>> _cache = {};

  /// Durable backing store. `null` (the default) means purely in-memory.
  final KnowledgeRepository? _repository;

  /// Supplies the canonical representation persisted alongside each resource.
  /// Held as the adapter rather than a raw function so this class never
  /// imports `package:webweavex` (R46 invariant I-21b, I-21d).
  final WebWeaveXAdapter? _canonicalizer;

  /// THE canonical retention owner (IS-R50), closing gap G-18.
  ///
  /// R48 deliberately shipped persistence with NO retention policy, because
  /// none existed to reuse and inventing one was out of scope. R50 created the
  /// canonical owner, so knowledge finally has bounds — and this cache asks
  /// for them rather than deciding them. `KnowledgeRepository` remains storage
  /// only: it is told which ids to drop, it never decides.
  final RetentionPolicyEngine retention;

  KnowledgeCache({
    KnowledgeRepository? repository,
    WebWeaveXAdapter? canonicalizer,
    this.retention = const RetentionPolicyEngine(),
  }) : _repository = repository,
       _canonicalizer = canonicalizer;

  /// Persistence needs BOTH a store to write to and a canonicalizer to
  /// produce the canonical representation that must survive the round trip.
  /// With only one of the two, this cache stays purely in-memory rather than
  /// persisting something it cannot canonicalize.
  bool get isPersistent => _repository != null && _canonicalizer != null;

  /// Resources stored via the legacy [store] API (no query key attached —
  /// e.g. pre-seeded by a caller that already knows what it wants cached
  /// without going through a search). Matched by [findRelevant] on a
  /// query-substring basis, mirroring how a caller decides a pre-seeded
  /// resource is "about" a given query.
  final List<KnowledgeResource> _legacyPool = [];

  Future<void> put(
    KnowledgeCacheKey key,
    List<KnowledgeResource> resources,
  ) async {
    final stableKey = key.toStableString();
    _cache[stableKey] = List.unmodifiable(resources);
    if (!isPersistent) return;
    await _repository!.putResources(stableKey, [
      for (final resource in resources)
        PersistedKnowledgeResource(
          resource: resource,
          canonicalRepresentation: _canonicalizer!.canonicalRepresentation(
            resource,
          ),
        ),
    ]);
    await applyRetention();
  }

  /// Applies the ONE canonical retention policy to persisted knowledge
  /// (IS-R50, closing gap G-18).
  ///
  /// The engine decides which cache keys to reclaim; this method applies that
  /// decision by asking the repository to remove them. The repository owns no
  /// policy and the engine owns no storage — which is exactly the separation
  /// invariants I-44/I-45 certify.
  ///
  /// Returns the reclaimed cache keys. A no-op when persistence is off.
  Future<List<String>> applyRetention({DateTime? now}) async {
    final repository = _repository;
    if (repository == null) return const [];

    final summaries = await repository.keySummaries();
    if (summaries.isEmpty) return const [];

    final evaluation = retention.evaluate(
      domain: LifecycleDomain.knowledge,
      candidates: [
        for (final s in summaries)
          LifecycleCandidate(
            id: s.cacheKey,
            timestamp: s.newestRetrievedAt,
            sizeBytes: s.totalBytes,
          ),
      ],
      now: now,
    );

    for (final key in evaluation.reclaimedIds) {
      await repository.removeKey(key);
      _cache.remove(key);
    }
    return evaluation.reclaimedIds;
  }

  /// Memory first; on a miss, hydrate exactly this ONE key from storage and
  /// promote it into memory so the next hit costs nothing. Nothing else is
  /// read — this is the incremental restoration path.
  Future<List<KnowledgeResource>?> get(KnowledgeCacheKey key) async {
    final stableKey = key.toStableString();
    final inMemory = _cache[stableKey];
    if (inMemory != null) return inMemory;
    if (!isPersistent) return null;

    final persisted = await _repository!.resourcesFor(stableKey);
    if (persisted == null) return null;

    final restored = List<KnowledgeResource>.unmodifiable(
      persisted.map((e) => e.resource),
    );
    _cache[stableKey] = restored;
    return restored;
  }

  /// Legacy bulk store: adds resources to a query-less pool, still
  /// reachable via [findRelevant]. Kept for callers that pre-seed known
  /// resources rather than caching a specific query's search results.
  Future<void> store(List<KnowledgeResource> resources) async {
    for (final resource in resources) {
      _cache['resource::${resource.id}'] = [resource];
      _legacyPool.add(resource);
    }
  }

  /// Fuzzy fallback for the legacy pool: a resource "matches" a query if
  /// its title or source URI contains the query text.
  List<KnowledgeResource>? findRelevant(String query) {
    final needle = query.toLowerCase();
    final matches = _legacyPool
        .where(
          (r) =>
              r.title.toLowerCase().contains(needle) ||
              r.sourceUri.toLowerCase().contains(needle),
        )
        .toList();
    return matches.isEmpty ? null : matches;
  }

  Future<void> clear() async {
    _cache.clear();
    _legacyPool.clear();
    if (_repository != null) await _repository.clear();
  }

  /// In-memory key count. Deliberately NOT a durable count: it reports what
  /// is resident right now, which is what every pre-R48 caller already meant
  /// by it. Durable counts come from `KnowledgeRepository.resourceCount()`.
  int get size => _cache.length;
}
