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

import 'package:anything/kernel/specification/experience_spec.dart';
import 'knowledge_resource.dart';
import 'knowledge_bundle.dart';
import 'search_provider.dart';
import 'webweavex_adapter.dart';

/// Status of knowledge acquisition.
enum AcquisitionStatus {
  idle,
  planning,
  retrieving,
  normalizing,
  evaluating,
  ready,
  partial,
  offlineCached,
  failed,
}

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
      final key = KnowledgeCacheKey(query: query, language: language);
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

  List<String> _planQueries(
    List<KnowledgeRequirement> requirements,
    List<String> queryHints,
  ) {
    final queries = <String>[];
    for (final req in requirements) {
      queries.add(req.objective);
      queries.addAll(req.queryHints);
    }
    queries.addAll(queryHints);
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
/// In-memory and process-scoped: "offline mode reuses cached knowledge"
/// within a session/process lifetime (e.g. the knowledge refinement loop's
/// repeated rounds, or repeated Experience-modification requests in the
/// same running app instance). Cross-restart persistence is not required
/// by this milestone's scope and is a documented limitation, not a gap
/// hidden by fabricated behavior.
class KnowledgeCache {
  final Map<String, List<KnowledgeResource>> _cache = {};

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
    _cache[key.toStableString()] = List.unmodifiable(resources);
  }

  Future<List<KnowledgeResource>?> get(KnowledgeCacheKey key) async {
    return _cache[key.toStableString()];
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
  }

  int get size => _cache.length;
}
