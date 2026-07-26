/// Knowledge Acquisition Engine for Anything.
///
/// Orchestrates knowledge retrieval, normalization, provenance,
/// trust, licensing, deduplication, ranking, and caching.
library;

import 'package:uuid/uuid.dart';

import 'package:anything/kernel/specification/experience_spec.dart';
import 'knowledge_resource.dart';
import 'knowledge_bundle.dart';
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

/// The Knowledge Acquisition Engine.
class KnowledgeAcquisitionEngine {
  final WebWeaveXAdapter? _webweavexAdapter;
  final KnowledgeCache _cache;

  KnowledgeAcquisitionEngine({
    WebWeaveXAdapter? webweavexAdapter,
    KnowledgeCache? cache,
  }) : _webweavexAdapter = webweavexAdapter,
       _cache = cache ?? KnowledgeCache();

  /// Acquire knowledge for the given requirements.
  Future<KnowledgeBundle> acquire({
    required List<KnowledgeRequirement> requirements,
    required List<String> queryHints,
  }) async {
    if (requirements.isEmpty) {
      return KnowledgeBundle(
        id: const Uuid().v4(),
        status: BundleStatus.ready,
        resources: [],
        generatedAt: DateTime.now(),
      );
    }

    // Check cache first
    final cached = await _checkCache(requirements);
    if (cached != null) return cached;

    // Plan queries
    final queries = _planQueries(requirements, queryHints);

    // Retrieve from provider
    final resources = <KnowledgeResource>[];
    final warnings = <String>[];
    final unresolved = <String>[];

    if (_webweavexAdapter != null) {
      for (final query in queries) {
        try {
          final results = await _webweavexAdapter.retrieve(query);
          resources.addAll(results);
        } catch (e) {
          warnings.add('Retrieval failed for: $query');
        }
      }
    } else {
      warnings.add('No knowledge provider configured');
      for (final req in requirements) {
        unresolved.add(req.objective);
      }
    }

    // Normalize, deduplicate, rank
    final normalized = _normalize(resources);
    final deduplicated = _deduplicate(normalized);
    final ranked = _rank(deduplicated);

    // Cache results
    if (ranked.isNotEmpty) {
      await _cache.store(ranked);
    }

    final status = unresolved.isEmpty
        ? (ranked.isEmpty ? BundleStatus.ready : BundleStatus.ready)
        : (ranked.isEmpty ? BundleStatus.failed : BundleStatus.partial);

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

  Future<KnowledgeBundle?> _checkCache(
    List<KnowledgeRequirement> requirements,
  ) async {
    final cached = await _cache.findRelevant(requirements);
    if (cached.isNotEmpty) {
      return KnowledgeBundle(
        id: const Uuid().v4(),
        status: BundleStatus.offlineCached,
        resources: cached,
        requirementsSatisfied: requirements.map((r) => r.objective).toList(),
        generatedAt: DateTime.now(),
        cacheStatus: 'offline_cached',
      );
    }
    return null;
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

/// Local knowledge cache.
class KnowledgeCache {
  final Map<String, KnowledgeResource> _cache = {};

  Future<void> store(List<KnowledgeResource> resources) async {
    for (final resource in resources) {
      _cache[resource.id] = resource;
    }
  }

  Future<List<KnowledgeResource>> findRelevant(
    List<KnowledgeRequirement> requirements,
  ) async {
    final results = <KnowledgeResource>[];
    for (final resource in _cache.values) {
      for (final req in requirements) {
        if (resource.title.toLowerCase().contains(
              req.objective.toLowerCase(),
            ) ||
            resource.sourceUri.contains(req.objective.toLowerCase())) {
          results.add(resource);
          break;
        }
      }
    }
    return results;
  }

  Future<void> clear() async {
    _cache.clear();
  }

  int get size => _cache.length;
}
