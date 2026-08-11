/// WebWeaveXDataProvider — universal external acquisition adapter.
///
/// Wraps KnowledgeAcquisitionEngine (WebWeaveX) as a DataProvider so ANY
/// semantic requirement can be satisfied through the canonical acquisition
/// boundary. No domain-specific APIs, no hardcoded providers.
///
/// Architecture:
///   DataRequirement -> WebWeaveXDataProvider -> KnowledgeAcquisitionEngine
///                      -> SearchProvider -> WebWeaveXAdapter -> external source
///
/// This replaces domain-specific providers (WeatherDataService, NewsDataService)
/// with a single generic acquisition path. The semantic purpose is determined
/// by the requirement, not by a domain switch.
library;

import '../kernel/specification/experience_spec.dart';
import 'data_provider_registry.dart';
import 'knowledge_acquisition_engine.dart';

/// Universal external data provider backed by WebWeaveX.
///
/// Any semantic requirement can be acquired through this provider by
/// constructing an appropriate search query. The source is discovered
/// dynamically, not hardcoded.
class WebWeaveXDataProvider {
  final KnowledgeAcquisitionEngine _engine;

  WebWeaveXDataProvider({KnowledgeAcquisitionEngine? engine})
      : _engine = engine ?? KnowledgeAcquisitionEngine();

  /// Acquire data for any semantic requirement through WebWeaveX.
  ///
  /// The requirement's [DataRequirement.domainConcept] and [DataRequirement.fields]
  /// are used to construct a search query. WebWeaveX discovers and acquires
  /// from whatever source satisfies the requirement.
  Future<Map<String, dynamic>> acquire(
    DataRequirement requirement,
    Map<String, dynamic> params,
  ) async {
    final query = _buildQuery(requirement, params);
    try {
      final bundle = await _engine.acquire(
        requirements: [
          KnowledgeRequirement(
            objective: query,
            resourceType: 'webDocument',
            queryHints: [query],
          ),
        ],
        queryHints: [query],
      );
      final results = <Map<String, dynamic>>[];
      for (final resource in bundle.resources) {
        results.add({
          'title': resource.title,
          'content': resource.content,
          'sourceType': 'webweavex',
          'provider': 'webweavex',
          'sourceUri': resource.provenance.sourceUrl,
          'retrievedAt': resource.provenance.retrievedAt.toIso8601String(),
        });
      }
      return {
        'results': results,
        'provenance': {
          'sourceType': 'webweavex',
          'query': query,
          'resultCount': results.length,
          'retrievedAt': DateTime.now().toUtc().toIso8601String(),
        },
      };
    } catch (e) {
      return {
        'results': <Map<String, dynamic>>[],
        'provenance': {
          'sourceType': 'webweavex',
          'error': e.toString(),
          'query': query,
        },
      };
    }
  }

  /// Build a search query from the semantic requirement and parameters.
  ///
  /// This is the intelligence layer: the system determines what to search
  /// for based on what is needed. No domain-specific routing.
  /// The query is constructed from the semantic requirement's objective,
  /// fields, and freshness — not from domain keywords.
  String _buildQuery(DataRequirement requirement, Map<String, dynamic> params) {
    // Extract semantic components from the requirement
    final location = params['location'] ?? params['query'] ?? '';
    final concept = requirement.domainConcept;
    final fields = requirement.fields;
    final freshness = requirement.freshness;

    // Build query from semantic structure, NOT domain routing
    final parts = <String>[];

    // Add location/context if present
    if (location.isNotEmpty) {
      parts.add(location);
    }

    // Add the semantic concept (this is the WHAT, not the domain)
    if (concept.isNotEmpty) {
      parts.add(concept.replaceAll('_', ' '));
    }

    // Add requested fields (these are the specific data points needed)
    if (fields.isNotEmpty) {
      parts.addAll(fields);
    }

    // Add freshness hint if current data is needed
    if (freshness == 'current') {
      parts.add('current latest real-time');
    }

    // Join into a natural search query
    final query = parts.join(' ').trim();
    if (query.isEmpty) {
      // Fallback: use whatever the user provided
      return params['query']?.toString() ?? 'information';
    }
    return query;
  }
}
