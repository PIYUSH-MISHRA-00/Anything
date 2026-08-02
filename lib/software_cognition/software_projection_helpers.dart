/// Small, shared helper for filtering a SemanticSoftwareGraph's edges (and
/// their endpoint nodes) down to a specific set of relationship kinds —
/// used by the DependencyGraph/ImportGraph/CodeRelationshipGraph
/// projections in `architecture_analyzer.dart`.
library;

import 'semantic_software_graph.dart';
import 'software_types.dart';

SemanticSoftwareGraph projectByRelationship(SemanticSoftwareGraph graph, Set<SoftwareRelationshipKind> kinds) {
  final keptEdges = graph.edges.where((e) => kinds.contains(e.kind)).toList();
  final keptIds = {for (final e in keptEdges) ...[e.fromId, e.toId]};
  final keptNodes = graph.nodes.where((n) => keptIds.contains(n.identity)).toList();
  return SemanticSoftwareGraph(nodes: keptNodes, edges: keptEdges);
}
