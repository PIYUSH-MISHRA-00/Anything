/// GraphUpdate — a typed diff to apply to a WorldGraph. Every Bridge
/// produces one of these rather than mutating a graph directly, so every
/// change to the World Graph is explicit, inspectable, and reviewable
/// before it is applied.
library;

import 'world_edge.dart';
import 'world_graph.dart';
import 'world_node.dart';

class GraphUpdate {
  final List<WorldNode> addedNodes;
  final List<WorldEdge> addedEdges;

  const GraphUpdate({this.addedNodes = const [], this.addedEdges = const []});

  WorldGraph applyTo(WorldGraph graph) => WorldGraph(nodes: [...graph.nodes, ...addedNodes], edges: [...graph.edges, ...addedEdges]);

  bool get isEmpty => addedNodes.isEmpty && addedEdges.isEmpty;
}
