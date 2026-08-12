/// Knowledge capability — trusted knowledge retrieval for Experiences.
library;

import '../platform/capability_platform.dart';

/// Knowledge provider abstraction.
abstract class KnowledgeProvider {
  Future<List<Map<String, dynamic>>> retrieve(
    String query, {
    String freshness,
  });
}

/// Fake knowledge provider for testing.
class FakeKnowledgeProvider implements KnowledgeProvider {
  final List<Map<String, dynamic>> _results;

  FakeKnowledgeProvider({List<Map<String, dynamic>> results = const []})
    : _results = List.from(results);

  @override
  Future<List<Map<String, dynamic>>> retrieve(
    String query, {
    String freshness = '',
  }) async {
    return _results;
  }
}

/// Knowledge capability for Experiences.
class KnowledgeCapability extends PlatformCapability {
  final KnowledgeProvider _provider;

  KnowledgeCapability({required KnowledgeProvider provider})
    : _provider = provider,
      super(
        id: 'knowledge',
        name: 'Knowledge',
        description: 'Knowledge retrieval',
        supportedOperations: ['retrieve'],
      );

  @override
  Future<CapabilityInvocationResult> execute(
    String operation,
    Map<String, dynamic> params,
  ) async {
    if (operation != 'retrieve') {
      return CapabilityInvocationResult(
        status: CapabilityResultStatus.unsupported,
        error: 'Unknown knowledge operation: $operation',
      );
    }

    final query = params['query'] as String?;
    if (query == null || query.isEmpty) {
      return const CapabilityInvocationResult(
        status: CapabilityResultStatus.invalidArguments,
        error: 'Query required',
      );
    }

    // Extract freshness from params — passed through from the behavior graph
    // config by BehaviorInterpreter._executeServiceCall(). When 'current',
    // the adapter enhances the query to fetch real-time data instead of
    // encyclopedia articles.
    final freshness = params['freshness'] as String? ?? '';

    try {
      final results = await _provider.retrieve(query, freshness: freshness);
      return CapabilityInvocationResult.success(data: {'results': results});
    } catch (e) {
      return CapabilityInvocationResult.failure(e.toString());
    }
  }
}
