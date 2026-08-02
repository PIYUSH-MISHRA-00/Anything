/// GraphConsistency — checks a WorldGraph for structural defects: edges
/// referencing a node id that isn't in the graph. Mirrors
/// DependencyGraph/EvolutionGraph's own "missing" checks, applied at the
/// World Graph level. This is the fail-closed gate WorldPlanner requires
/// before a GraphUpdate is considered approved — the same
/// "review-before-commit" philosophy SCARE established, applied to graph
/// structure specifically (SCARE's own DesignReviewEngine.review() is
/// bound to ReviewContext/ArchitectureCandidate and cannot be re-invoked
/// on a WorldGraph directly).
library;

import 'world_edge.dart';
import 'world_graph.dart';

class GraphValidation {
  final bool isValid;
  final List<WorldEdge> danglingEdges;

  const GraphValidation({required this.isValid, this.danglingEdges = const []});
}

class GraphConsistency {
  const GraphConsistency();

  GraphValidation validate(WorldGraph graph) {
    final nodeIds = graph.nodes.map((n) => n.identity).toSet();
    final dangling = graph.edges.where((e) => !nodeIds.contains(e.fromId) || !nodeIds.contains(e.toId)).toList();
    return GraphValidation(isValid: dangling.isEmpty, danglingEdges: dangling);
  }
}
