/// Feature Discovery Context — everything one FeatureDiscoveryEngine run
/// needs. Runs before Architecture in the Kernel pipeline, so it sees the
/// RequirementGraph (and optionally the KnowledgeGraph), never an
/// ArchitectureCandidate.
library;

import '../software_architect/knowledge_graph.dart';
import '../software_architect/requirement_graph.dart';
import '../synthesis/application_reasoner.dart';

class FeatureDiscoveryContext {
  final SemanticApp app;
  final RequirementGraph requirements;
  final KnowledgeGraph? knowledge;

  /// Capability ids already observed as real World Graph `capability`
  /// nodes (Implementation Milestone R3) — a primitive `Set<String>`, not
  /// a `WorldGraph`/`WorldModelCoordinator` reference, so this module
  /// gains no new dependency on `lib/world_model/` (the Kernel, the one
  /// place that already depends on both, computes this and passes it in).
  /// Empty by default — byte-for-byte pre-R3 behavior when omitted.
  final Set<String> priorCapabilityIds;

  const FeatureDiscoveryContext({
    required this.app,
    required this.requirements,
    this.knowledge,
    this.priorCapabilityIds = const {},
  });
}
