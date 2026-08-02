/// GraphProjection — produces a real sub-graph filtered by node kind
/// and/or relationship kind. SemanticGraph.projectFrom and GraphView both
/// reuse this rather than reimplementing filtering.
library;

import 'world_edge.dart';
import 'world_graph.dart';
import 'world_node.dart';
import 'world_types.dart';

class GraphProjection {
  const GraphProjection();

  WorldGraph project(WorldGraph graph, {Set<WorldNodeKind>? nodeKinds, Set<RelationshipKind>? relationKinds}) {
    final nodes = nodeKinds == null ? graph.nodes : graph.nodes.where((n) => nodeKinds.contains(n.kind)).toList();
    final nodeIds = nodes.map((n) => n.identity).toSet();

    final edges = graph.edges.where((e) {
      if (!nodeIds.contains(e.fromId) || !nodeIds.contains(e.toId)) return false;
      if (relationKinds != null && !relationKinds.contains(e.kind)) return false;
      return true;
    }).toList();

    return WorldGraph(nodes: nodes, edges: edges);
  }

  List<WorldNode> nodesOfKind(WorldGraph graph, WorldNodeKind kind) => graph.nodesOfKind(kind);

  List<WorldEdge> edgesOfKind(WorldGraph graph, RelationshipKind kind) => graph.edges.where((e) => e.kind == kind).toList();
}
