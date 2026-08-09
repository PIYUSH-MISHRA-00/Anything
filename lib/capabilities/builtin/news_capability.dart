/// News capability — structured articles (not WebWeaveX knowledge).
library;

import '../../domain_services/news_data_service.dart';
import '../platform/capability_platform.dart';

/// Platform capability: `news` / searchArticles.
class NewsCapability extends PlatformCapability {
  NewsCapability({NewsDataService? service})
    : _service = service ?? NewsDataService(),
      super(
        id: 'news',
        name: 'News',
        description: 'Structured news article retrieval',
        supportedOperations: const ['searchArticles', 'retrieve'],
      );

  final NewsDataService _service;

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
    try {
      final articles = await _service.searchArticles(query);
      return CapabilityInvocationResult.success(
        data: {
          'results': articles.map((a) => a.toResultMap()).toList(),
          'provenance': {
            'sourceType': 'structuredNews',
            'provider': 'google-news-rss',
            'retrievedAt': DateTime.now().toUtc().toIso8601String(),
          },
        },
      );
    } catch (e) {
      return CapabilityInvocationResult.failure(e.toString());
    }
  }
}
