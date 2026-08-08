/// GraphIndex — O(1) lookup structures built once from a WorldGraph,
/// avoiding repeated O(n) scans across GraphTraversal/GraphSearch calls.
library;

import 'entity_identity.dart';
import 'world_edge.dart';
import 'world_graph.dart';
import 'world_node.dart';

class GraphIndex {
  final Map<EntityIdentity, WorldNode> _nodesById;
  final Map<EntityIdentity, List<WorldEdge>> _outgoing;
  final Map<EntityIdentity, List<WorldEdge>> _incoming;

  GraphIndex._(this._nodesById, this._outgoing, this._incoming);

  factory GraphIndex.build(WorldGraph graph) {
    final nodesById = {for (final n in graph.nodes) n.identity: n};
    final outgoing = <EntityIdentity, List<WorldEdge>>{};
    final incoming = <EntityIdentity, List<WorldEdge>>{};
    for (final edge in graph.edges) {
      outgoing.putIfAbsent(edge.fromId, () => []).add(edge);
      incoming.putIfAbsent(edge.toId, () => []).add(edge);
    }
    return GraphIndex._(nodesById, outgoing, incoming);
  }

  WorldNode? nodeById(EntityIdentity id) => _nodesById[id];

  List<WorldEdge> outgoingFrom(EntityIdentity id) =>
      List.unmodifiable(_outgoing[id] ?? const []);

  List<WorldEdge> incomingTo(EntityIdentity id) =>
      List.unmodifiable(_incoming[id] ?? const []);
}
