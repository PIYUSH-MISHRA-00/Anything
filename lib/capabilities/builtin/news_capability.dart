/// News capability — structured articles via DataProviderRegistry.
library;

import '../../knowledge/data_provider_registry.dart';
import '../../knowledge/default_data_providers.dart';
import '../platform/capability_platform.dart';

/// Platform capability: `news` / searchArticles.
///
/// Selects a provider that satisfies `news_articles`, not a hardcoded
/// "news → Google News" Kernel rule.
class NewsCapability extends PlatformCapability {
  NewsCapability({DataProviderRegistry? registry})
    : _registry = registry ?? buildDefaultDataProviderRegistry(),
      super(
        id: 'news',
        name: 'News',
        description: 'Structured news article search',
        supportedOperations: const ['searchArticles', 'retrieve'],
      );

  final DataProviderRegistry _registry;

  @override
  Future<CapabilityInvocationResult> execute(
    String operation,
    Map<String, dynamic> params,
  ) async {
    if (operation != 'searchArticles' && operation != 'retrieve') {
      return CapabilityInvocationResult(
        status: CapabilityResultStatus.unsupported,
        error: 'Unknown news operation: $operation',
      );
    }
    final query =
        (params['query'] ?? params['location'])?.toString().trim() ?? '';
    if (query.isEmpty) {
      return const CapabilityInvocationResult(
        status: CapabilityResultStatus.invalidArguments,
        error: 'Query required',
      );
    }
    final result = await _registry.acquire(
      const DataRequirement(
        domainConcept: DataConcepts.newsArticles,
        fields: ['title', 'source', 'summary', 'url'],
        freshness: 'current',
      ),
      {'query': query},
    );
    if (!result.ok) {
      return CapabilityInvocationResult.failure(
        result.error ?? 'News provider unavailable',
      );
    }
    final data = Map<String, dynamic>.from(result.data!);
    final prov = Map<String, dynamic>.from(
      (data['provenance'] as Map?)?.cast<String, dynamic>() ?? {},
    );
    prov['selectedProvider'] = result.providerId;
    prov['attemptedProviders'] = result.attempted;
    data['provenance'] = prov;
    return CapabilityInvocationResult.success(data: data);
  }
}
