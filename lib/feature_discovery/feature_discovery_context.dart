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

  const FeatureDiscoveryContext({required this.app, required this.requirements, this.knowledge});
}
