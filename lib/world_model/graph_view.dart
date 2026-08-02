/// GraphView — a read-only, typed presentation of a subset of the World
/// Graph, built by GraphTraversal from a focus point — the substrate for
/// "show everything related to Project Alpha." Reuses GraphTraversal/
/// GraphProjection rather than a second traversal implementation.
library;

import 'entity_identity.dart';
import 'graph_projection.dart';
import 'graph_traversal.dart';
import 'world_edge.dart';
import 'world_graph.dart';
import 'world_node.dart';

class GraphView {
  final EntityIdentity focus;
  final List<WorldNode> nodes;
  final List<WorldEdge> edges;

  const GraphView({required this.focus, this.nodes = const [], this.edges = const []});

  /// Everything reachable from [focus] in either direction, up to
  /// [maxDepth] — a real, bounded traversal, never the whole graph
  /// unless [focus] is genuinely connected to everything.
  factory GraphView.centeredOn(WorldGraph graph, EntityIdentity focus, {int maxDepth = 3}) {
    const traversal = GraphTraversal();
    final forwardSteps = traversal.forward(graph, focus, maxDepth: maxDepth);
    final reverseSteps = traversal.reverse(graph, focus, maxDepth: maxDepth);
    final reachableIds = {focus, ...forwardSteps.map((s) => s.nodeId), ...reverseSteps.map((s) => s.nodeId)};

    const projection = GraphProjection();
    final sub = projection.project(graph);
    final nodes = sub.nodes.where((n) => reachableIds.contains(n.identity)).toList();
    final edges = sub.edges.where((e) => reachableIds.contains(e.fromId) && reachableIds.contains(e.toId)).toList();

    return GraphView(focus: focus, nodes: nodes, edges: edges);
  }
}
