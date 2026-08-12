/// Real KnowledgeProvider backing KnowledgeCapability, wrapping the
/// already-real, WebWeaveX-only `KnowledgeAcquisitionEngine` (R1: wiring
/// an already-canonical system, never a second acquisition path).
library;

import '../../kernel/specification/experience_spec.dart'
    show KnowledgeRequirement;
import '../../knowledge/knowledge_acquisition_engine.dart';
import '../builtin/knowledge_capability.dart';

class KnowledgeAcquisitionProviderAdapter implements KnowledgeProvider {
  final KnowledgeAcquisitionEngine _engine;

  const KnowledgeAcquisitionProviderAdapter(this._engine);

  @override
  Future<List<Map<String, dynamic>>> retrieve(
    String query, {
    String freshness = '',
    String topic = '',
  }) async {
    final bundle = await _engine.acquire(
      requirements: [
        KnowledgeRequirement(
          objective: query,
          resourceType: freshness == 'current' ? 'webDocument' : 'reference',
          freshness: freshness,
          // Requirement preservation: the Experience's own semantic subject
          // (from its creation intent) travels with every runtime query.
          topicTerms: KnowledgeAcquisitionEngine.significantTerms(topic),
        ),
      ],
      queryHints: const [],
    );
    return bundle.resources
        .map(
          (r) => {
            'title': r.title,
            'sourceUri': r.sourceUri,
            'sourceDomain': r.sourceDomain,
            'content': r.content ?? '',
            'retrievedAt': r.retrievedAt.toIso8601String(),
            'imageUrl': r.imageUrl ?? '',
            'provider': r.provenance.provider,
            if (bundle.cacheStatus != null) 'cacheStatus': bundle.cacheStatus,
          },
        )
        .toList();
  }
}
