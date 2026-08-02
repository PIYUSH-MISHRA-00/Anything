/// GraphMerge — merges a GraphUpdate (or a second WorldGraph) into an
/// existing one, deduplicating by EntityIdentity — the same identity
/// appearing twice with the SAME kind/label is a real, expected
/// deduplication (e.g. two Experiences both referencing the "http"
/// capability); the same identity with a DIFFERENT kind/label is a real
/// GraphConflict, surfaced rather than silently overwritten.
library;

import 'entity_identity.dart';
import 'graph_conflict.dart';
import 'world_edge.dart';
import 'world_graph.dart';
import 'world_node.dart';

class GraphMergeResult {
  final WorldGraph graph;
  final List<GraphConflict> conflicts;

  const GraphMergeResult({required this.graph, this.conflicts = const []});

  bool get isClean => conflicts.isEmpty;
}

class GraphMerge {
  const GraphMerge();

  GraphMergeResult merge(WorldGraph base, WorldGraph incoming) {
    final byIdentity = <EntityIdentity, WorldNode>{for (final n in base.nodes) n.identity: n};
    final conflicts = <GraphConflict>[];

    for (final node in incoming.nodes) {
      final existing = byIdentity[node.identity];
      if (existing == null) {
        byIdentity[node.identity] = node;
      } else if (existing.kind != node.kind || existing.label != node.label) {
        conflicts.add(
          GraphConflict(
            identity: node.identity,
            description: 'Identity "${node.identity}" already exists as ${existing.kind.name}/"${existing.label}", '
                'but incoming data claims ${node.kind.name}/"${node.label}".',
          ),
        );
      }
      // Identical kind/label: a real, expected deduplication — keep the
      // existing node, add nothing new.
    }

    final mergedEdgeKeys = <String>{};
    final mergedEdges = <WorldEdge>[];
    for (final edge in [...base.edges, ...incoming.edges]) {
      final key = '${edge.fromId}|${edge.toId}|${edge.kind.name}';
      if (mergedEdgeKeys.add(key)) mergedEdges.add(edge);
    }

    return GraphMergeResult(graph: WorldGraph(nodes: byIdentity.values.toList(), edges: mergedEdges), conflicts: conflicts);
  }
}
