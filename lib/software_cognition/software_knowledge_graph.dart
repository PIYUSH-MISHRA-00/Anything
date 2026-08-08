/// SoftwareKnowledgeGraph — combines the existing KnowledgeGraph
/// (web-acquired documentation/articles, `lib/software_architect/`) with
/// a SemanticSoftwareGraph (acquired repository/package understanding)
/// into one queryable structure for reasoning, without merging their
/// distinct node shapes into a lossy common type.
library;

import '../software_architect/knowledge_graph.dart';
import 'semantic_software_graph.dart';

class SoftwareKnowledgeGraph {
  final KnowledgeGraph knowledge;
  final SemanticSoftwareGraph software;

  const SoftwareKnowledgeGraph({
    this.knowledge = KnowledgeGraph.empty,
    this.software = const SemanticSoftwareGraph(),
  });

  bool get isEmpty => knowledge.isEmpty && software.nodes.isEmpty;
}
