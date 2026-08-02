/// WorldGraph — the complete, typed graph of everything: Experiences,
/// entities, capabilities, knowledge, workflows, schedules,
/// recommendations, evolution, review, automation, storage, projects.
/// Mirrors DependencyGraph (V4) / EvolutionGraph (V7)'s node+edge shape
/// and lookup-helper conventions exactly.
library;

import 'entity_identity.dart';
import 'world_edge.dart';
import 'world_node.dart';
import 'world_types.dart';

class WorldGraph {
  final List<WorldNode> nodes;
  final List<WorldEdge> edges;

  const WorldGraph({this.nodes = const [], this.edges = const []});

  WorldNode? nodeById(EntityIdentity id) => nodes.where((n) => n.identity == id).firstOrNull;

  List<WorldEdge> edgesFrom(EntityIdentity id) => edges.where((e) => e.fromId == id).toList();

  List<WorldEdge> edgesTo(EntityIdentity id) => edges.where((e) => e.toId == id).toList();

  List<WorldNode> nodesOfKind(WorldNodeKind kind) => nodes.where((n) => n.kind == kind).toList();

  /// Combines this graph with another, without deduplicating — callers
  /// wanting deduplication should use GraphMerge, which reuses this
  /// concatenation and then resolves conflicts explicitly.
  WorldGraph concat(WorldGraph other) => WorldGraph(nodes: [...nodes, ...other.nodes], edges: [...edges, ...other.edges]);
}
