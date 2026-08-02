/// SemanticGraph — the real, structural "Experience -> contains -> Entity
/// -> references -> Knowledge -> uses -> Capability -> produces ->
/// Workflow" view of the World Graph. A genuine PROJECTION of WorldGraph
/// (via GraphProjection), never a second competing graph implementation
/// — SemanticNode/SemanticEdge are the same underlying shape as
/// WorldNode/WorldEdge, restricted to the kinds this milestone's own
/// Semantic Graph section names.
library;

import 'world_edge.dart';
import 'world_graph.dart';
import 'world_node.dart';
import 'world_types.dart';

typedef SemanticNode = WorldNode;
typedef SemanticEdge = WorldEdge;

const _semanticKinds = {
  WorldNodeKind.experience,
  WorldNodeKind.entity,
  WorldNodeKind.knowledge,
  WorldNodeKind.capability,
  WorldNodeKind.workflow,
  WorldNodeKind.observation,
  WorldNodeKind.learning,
  WorldNodeKind.recommendation,
  WorldNodeKind.automation,
};

class SemanticGraph {
  final List<SemanticNode> nodes;
  final List<SemanticEdge> edges;

  const SemanticGraph({this.nodes = const [], this.edges = const []});

  /// Projects the semantic-relevant subset of a real WorldGraph — never
  /// a separately-maintained graph that could drift from it.
  factory SemanticGraph.projectFrom(WorldGraph graph) {
    final semanticNodes = graph.nodes.where((n) => _semanticKinds.contains(n.kind)).toList();
    final semanticIds = semanticNodes.map((n) => n.identity).toSet();
    final semanticEdges = graph.edges.where((e) => semanticIds.contains(e.fromId) && semanticIds.contains(e.toId)).toList();
    return SemanticGraph(nodes: semanticNodes, edges: semanticEdges);
  }
}
