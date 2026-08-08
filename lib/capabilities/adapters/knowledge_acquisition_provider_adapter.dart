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
  Future<List<Map<String, dynamic>>> retrieve(String query) async {
    final bundle = await _engine.acquire(
      requirements: [
        KnowledgeRequirement(
          objective: query,
          resourceType: 'reference',
          queryHints: [query],
        ),
      ],
      queryHints: [query],
    );
    return bundle.resources
        .map(
          (r) => {
            'title': r.title,
            'sourceUri': r.sourceUri,
            'content': r.content ?? '',
            'retrievedAt': r.retrievedAt.toIso8601String(),
          },
        )
        .toList();
  }
}
