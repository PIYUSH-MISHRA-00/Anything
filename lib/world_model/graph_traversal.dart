/// GraphTraversal — deterministic, bounded breadth-first traversal over
/// a WorldGraph. Never unbounded: always stops at maxDepth and never
/// revisits a node, so a cyclic graph can never cause an infinite loop.
library;

import 'entity_identity.dart';
import 'graph_index.dart';
import 'world_edge.dart';
import 'world_graph.dart';
import 'world_types.dart';

class TraversalStep {
  final EntityIdentity nodeId;
  final int depth;
  final WorldEdge? viaEdge;

  const TraversalStep({
    required this.nodeId,
    required this.depth,
    this.viaEdge,
  });
}

class GraphTraversal {
  const GraphTraversal();

  /// Forward traversal (follows outgoing edges) — "what does this depend
  /// on / reference / contain."
  List<TraversalStep> forward(
    WorldGraph graph,
    EntityIdentity start, {
    int maxDepth = 5,
    Set<RelationshipKind>? relationKinds,
  }) => _traverse(
    GraphIndex.build(graph),
    start,
    maxDepth,
    relationKinds,
    forward: true,
  );

  /// Reverse traversal (follows incoming edges) — "what depends on /
  /// references / contains this."
  List<TraversalStep> reverse(
    WorldGraph graph,
    EntityIdentity start, {
    int maxDepth = 5,
    Set<RelationshipKind>? relationKinds,
  }) => _traverse(
    GraphIndex.build(graph),
    start,
    maxDepth,
    relationKinds,
    forward: false,
  );

  List<TraversalStep> _traverse(
    GraphIndex index,
    EntityIdentity start,
    int maxDepth,
    Set<RelationshipKind>? relationKinds, {
    required bool forward,
  }) {
    final visited = <EntityIdentity>{start};
    final results = <TraversalStep>[];
    var frontier = [TraversalStep(nodeId: start, depth: 0)];

    while (frontier.isNotEmpty && frontier.first.depth < maxDepth) {
      final next = <TraversalStep>[];
      for (final step in frontier) {
        final edges = forward
            ? index.outgoingFrom(step.nodeId)
            : index.incomingTo(step.nodeId);
        for (final edge in edges) {
          if (relationKinds != null && !relationKinds.contains(edge.kind)) {
            continue;
          }
          final neighbor = forward ? edge.toId : edge.fromId;
          if (!visited.add(neighbor)) continue;
          final entry = TraversalStep(
            nodeId: neighbor,
            depth: step.depth + 1,
            viaEdge: edge,
          );
          results.add(entry);
          next.add(entry);
        }
      }
      frontier = next;
    }
    return results;
  }
}
