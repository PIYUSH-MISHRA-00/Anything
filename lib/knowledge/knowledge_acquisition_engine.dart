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
import 'package:anything/diagnostics/log_entry.dart';
import 'package:anything/diagnostics/structured_logger.dart';
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

/// A query planned from one requirement, carrying that requirement's
/// semantics (freshness, objective/topic terms) so cache policy and
/// requirement-satisfaction scoring can act per requirement rather than on
/// a flat string. Generic — the terms are the user's own words.
class PlannedKnowledgeQuery {
  final String query;
  final String freshness;
  final List<String> objectiveTerms;
  final List<String> topicTerms;

  const PlannedKnowledgeQuery({
    required this.query,
    this.freshness = '',
    this.objectiveTerms = const [],
    this.topicTerms = const [],
  });
}

/// The Knowledge Acquisition Engine.
class KnowledgeAcquisitionEngine {
  final SearchProvider? _searchProvider;
  final WebWeaveXAdapter? _webweavexAdapter;
  final KnowledgeCache _cache;
  final int _maxResultsPerQuery;
  final StructuredLogger? _logger;

  KnowledgeAcquisitionEngine({
    SearchProvider? searchProvider,
    WebWeaveXAdapter? webweavexAdapter,
    KnowledgeCache? cache,
    int maxResultsPerQuery = 5,
    StructuredLogger? logger,
  }) : _searchProvider = searchProvider,
       _webweavexAdapter = webweavexAdapter,
       _cache = cache ?? KnowledgeCache(),
       _maxResultsPerQuery = maxResultsPerQuery,
       _logger = logger;

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

    for (final planned in queries) {
      final query = planned.query;
      final key = KnowledgeCacheKey(
        query: _canonicalQuery(query),
        language: language,
      );

      // Freshness-aware cache policy: a 'current' requirement must
      // re-acquire (the cache has no TTL, so a cache-first read would pin
      // the first-ever result forever). The cache is still written and is
      // used as an explicit offline fallback below. Everything else keeps
      // the cache-first behavior that makes offline reuse real.
      List<KnowledgeResource>? found;
      if (planned.freshness != 'current') {
        found = await _cache.get(key);
        found ??= _cache.findRelevant(query);
      }
      if (found != null && found.isNotEmpty) {
        final judged = _judge(planned, found);
        if (judged.isNotEmpty) {
          resources.addAll(judged);
          anyFromCache = true;
          anyQueryResolved = true;
          _logger?.info(
            LogCategory.knowledge,
            'acquire "$query" → ${judged.length} resource(s) from cache',
          );
          continue;
        }
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
        final judged = _judge(planned, validated);
        if (judged.isNotEmpty) {
          await _cache.put(key, judged);
          resources.addAll(judged);
          anyFreshlyFetched = true;
          anyQueryResolved = true;
          _logger?.info(
            LogCategory.knowledge,
            'WebWeaveX acquire "$query" → ${judged.length}/${urls.length} '
            'satisfying resource(s), top=${judged.first.sourceDomain}',
          );
        } else {
          warnings.add(
            validated.isEmpty
                ? 'No usable results for: $query'
                : 'No results satisfied the requirement for: $query',
          );
          _logger?.warning(
            LogCategory.knowledge,
            'WebWeaveX acquire "$query" → 0 satisfying of '
            '${validated.length} extracted',
          );
        }
      } catch (e) {
        warnings.add('Retrieval failed for: $query');
        _logger?.warning(
          LogCategory.knowledge,
          'WebWeaveX acquire failed for "$query"',
        );
        // Offline/network failure: fall back to cached knowledge even for
        // 'current' requirements — explicitly marked as cached rather than
        // silently presented as fresh.
        final cached = await _cache.get(key);
        if (cached != null && cached.isNotEmpty) {
          resources.addAll(cached);
          anyFromCache = true;
          anyQueryResolved = true;
        }
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

  List<PlannedKnowledgeQuery> _planQueries(
    List<KnowledgeRequirement> requirements,
    List<String> queryHints,
  ) {
    final queries = <PlannedKnowledgeQuery>[];
    final seen = <String>{};

    void add(PlannedKnowledgeQuery planned) {
      if (planned.query.trim().isEmpty) return;
      if (!seen.add(planned.query.trim().toLowerCase())) return;
      queries.add(planned);
    }

    for (final req in requirements) {
      // Requirement preservation: compose the search text from the user's
      // literal objective PLUS the requirement's own topic terms PLUS a
      // freshness cue. Generic — every part comes from the requirement, no
      // domain switch. This is what turns "Lucknow" typed into a weather
      // Experience into the query "Lucknow weather current".
      final objectiveTerms = significantTerms(req.objective);
      final parts = <String>[req.objective.trim()];
      final present = req.objective.toLowerCase();
      for (final term in req.topicTerms) {
        if (!present.contains(term.toLowerCase())) parts.add(term);
      }
      if (req.freshness == 'current') parts.add('current');
      add(
        PlannedKnowledgeQuery(
          query: parts.where((p) => p.isNotEmpty).join(' '),
          freshness: req.freshness,
          objectiveTerms: objectiveTerms,
          topicTerms: req.topicTerms,
        ),
      );
      for (final hint in req.queryHints) {
        if (hint != req.objective) {
          add(
            PlannedKnowledgeQuery(
              query: hint,
              freshness: req.freshness,
              objectiveTerms: significantTerms(hint),
              topicTerms: req.topicTerms,
            ),
          );
        }
      }
    }
    for (final hint in queryHints) {
      add(
        PlannedKnowledgeQuery(
          query: hint,
          objectiveTerms: significantTerms(hint),
        ),
      );
    }
    return queries;
  }

  /// Content words of a phrase: lowercase, punctuation-split, with a small
  /// closed-class English stopword set removed. Generic language handling,
  /// never a domain table.
  static List<String> significantTerms(String text) {
    const stopwords = {
      'the', 'a', 'an', 'and', 'or', 'of', 'in', 'on', 'at', 'to', 'for',
      'with', 'about', 'is', 'are', 'was', 'were', 'be', 'me', 'my', 'that',
      'this', 'it', 'its', 'what', 'who', 'how', 'when', 'where', 'which',
      'please', 'right', 'now', // "right now" is freshness, not topic
    };
    return text
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((w) => w.length >= 2 && !stopwords.contains(w))
        .toList();
  }

  /// Temporal-proximity markers used to score how "current" a page reads.
  /// Generic vocabulary of recency, not domain words.
  static final RegExp _temporalMarkers = RegExp(
    r'\b(today|tonight|now|live|latest|breaking|updated?|current(ly)?|'
    r'hourly|minutes? ago|hours? ago|as of|this (morning|afternoon|evening|'
    r'week))\b',
    caseSensitive: false,
  );

  /// Generic requirement satisfaction (the IS-P25 core).
  ///
  /// Judges each candidate resource against the planned query's semantics:
  ///
  /// - relevance: coverage of objective terms (weight 2) and topic terms
  ///   (weight 1) across title + content. A resource mentioning none of the
  ///   requirement's terms cannot satisfy it and is dropped.
  /// - freshness: for `freshness == 'current'`, density of temporal-recency
  ///   markers plus presence of the current year. An encyclopedia article
  ///   is not rejected by name — it simply scores low on recency and loses
  ///   to genuinely current sources. No URL or source-name blacklists.
  ///
  /// Returns satisfying resources re-ranked by their judged score,
  /// replacing the previous constant-score ranking (which preserved raw
  /// search-engine order).
  List<KnowledgeResource> _judge(
    PlannedKnowledgeQuery planned,
    List<KnowledgeResource> candidates,
  ) {
    if (candidates.isEmpty) return candidates;
    final judged = <KnowledgeResource>[];
    for (final resource in candidates) {
      final haystackTitle = resource.title.toLowerCase();
      final haystackBody = (resource.content ?? '').toLowerCase();

      double coverage(List<String> terms) {
        if (terms.isEmpty) return 0;
        var hits = 0.0;
        for (final term in terms) {
          if (haystackTitle.contains(term)) {
            hits += 1;
          } else if (haystackBody.contains(term)) {
            hits += 0.7;
          }
        }
        return hits / terms.length;
      }

      final objectiveCoverage = coverage(planned.objectiveTerms);
      final topicCoverage = coverage(planned.topicTerms);
      final hasAnyTerms =
          planned.objectiveTerms.isNotEmpty || planned.topicTerms.isNotEmpty;
      final relevance = hasAnyTerms
          ? ((objectiveCoverage * 2) + topicCoverage) /
                ((planned.objectiveTerms.isEmpty ? 0 : 2) +
                        (planned.topicTerms.isEmpty ? 0 : 1))
                    .clamp(1, 3)
          : 0.5;

      // Satisfaction floor — CURRENT-data requirements only: evidence that
      // mentions none of the requirement's terms cannot satisfy a request
      // for current data about those terms. Reference requirements keep
      // permissive retain-and-rank behavior (creation-time knowledge must
      // not be starved by literal term matching).
      if (planned.freshness == 'current' &&
          hasAnyTerms &&
          objectiveCoverage == 0 &&
          topicCoverage == 0) {
        continue;
      }

      double freshnessScore = 0.5;
      if (planned.freshness == 'current') {
        final markers = _temporalMarkers
            .allMatches(
              haystackBody.length > 4000
                  ? haystackBody.substring(0, 4000)
                  : haystackBody,
            )
            .length;
        final hasYear = haystackBody.contains(DateTime.now().year.toString());
        freshnessScore =
            ((markers / 4).clamp(0.0, 0.8)) + (hasYear ? 0.2 : 0.0);
      }

      judged.add(
        resource.withRanking(
          RankingMetadata(
            relevanceScore: relevance.clamp(0.0, 1.0),
            authorityScore: 0.5,
            freshnessScore: freshnessScore,
          ),
        ),
      );
    }
    judged.sort(
      (a, b) => b.ranking.overallScore.compareTo(a.ranking.overallScore),
    );
    return judged;
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
