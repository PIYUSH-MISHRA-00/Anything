/// SemanticSoftwareGraph — the typed graph every Software Cognition
/// analyzer contributes to, mirroring WorldGraph's proven API
/// (`lib/world_model/world_graph.dart`) exactly: plain node/edge lists
/// plus typed lookups, never a Map-based adjacency structure.
library;

import 'software_identity.dart';
import 'software_node.dart';
import 'software_types.dart'
    show SoftwareNodeKind, SoftwareEvidence, SoftwareConfidence;

class SemanticSoftwareGraph {
  final List<SoftwareNode> nodes;
  final List<SoftwareEdge> edges;

  const SemanticSoftwareGraph({this.nodes = const [], this.edges = const []});

  List<SoftwareNode> nodesOfKind(SoftwareNodeKind kind) =>
      nodes.where((n) => n.kind == kind).toList();

  List<SoftwareEdge> edgesFrom(SoftwareIdentity id) =>
      edges.where((e) => e.fromId == id).toList();

  List<SoftwareEdge> edgesTo(SoftwareIdentity id) =>
      edges.where((e) => e.toId == id).toList();

  SoftwareNode? nodeById(SoftwareIdentity id) {
    for (final n in nodes) {
      if (n.identity == id) return n;
    }
    return null;
  }

  SemanticSoftwareGraph concat(SemanticSoftwareGraph other) =>
      SemanticSoftwareGraph(
        nodes: [...nodes, ...other.nodes],
        edges: [...edges, ...other.edges],
      );
}

/// A real, surfaced conflict — two nodes with the same identity but a
/// different kind or label — never silently overwritten. Mirrors
/// GraphConflict's "no duplicate identities" philosophy exactly.
class SoftwareGraphConflict {
  final SoftwareNode existing;
  final SoftwareNode incoming;

  const SoftwareGraphConflict({required this.existing, required this.incoming});
}

class SoftwareMergeResult {
  final SemanticSoftwareGraph graph;
  final List<SoftwareGraphConflict> conflicts;

  const SoftwareMergeResult({required this.graph, this.conflicts = const []});

  bool get isClean => conflicts.isEmpty;
}

/// Merges two SemanticSoftwareGraphs, deduplicating identical
/// identity+kind+label nodes and identical edges — never doubling,
/// never silently dropping a real conflict.
class SoftwareMerge {
  const SoftwareMerge();

  SoftwareMergeResult merge(SemanticSoftwareGraph a, SemanticSoftwareGraph b) {
    final byId = <SoftwareIdentity, SoftwareNode>{};
    final conflicts = <SoftwareGraphConflict>[];

    for (final node in [...a.nodes, ...b.nodes]) {
      final existing = byId[node.identity];
      if (existing == null) {
        byId[node.identity] = node;
      } else if (existing.kind != node.kind || existing.label != node.label) {
        conflicts.add(
          SoftwareGraphConflict(existing: existing, incoming: node),
        );
      }
    }

    final edgeKeys = <String>{};
    final mergedEdges = <SoftwareEdge>[];
    for (final edge in [...a.edges, ...b.edges]) {
      final key = '${edge.fromId.value}|${edge.toId.value}|${edge.kind.name}';
      if (edgeKeys.add(key)) mergedEdges.add(edge);
    }

    return SoftwareMergeResult(
      graph: SemanticSoftwareGraph(
        nodes: byId.values.toList(),
        edges: mergedEdges,
      ),
      conflicts: conflicts,
    );
  }
}

/// A filtered sub-graph containing only the requested node kinds (and the
/// edges whose endpoints both survive the filter) — mirrors
/// GraphProjection's read-only, non-mutating filtering exactly.
class SoftwareProjection {
  const SoftwareProjection();

  SemanticSoftwareGraph projectKinds(
    SemanticSoftwareGraph graph,
    Set<SoftwareNodeKind> kinds,
  ) {
    final keptNodes = graph.nodes.where((n) => kinds.contains(n.kind)).toList();
    final keptIds = keptNodes.map((n) => n.identity).toSet();
    final keptEdges = graph.edges
        .where((e) => keptIds.contains(e.fromId) && keptIds.contains(e.toId))
        .toList();
    return SemanticSoftwareGraph(nodes: keptNodes, edges: keptEdges);
  }
}

/// A record of one transformative step: acquired software understanding
/// (never raw source) was distilled into a named, typed concept the
/// reasoning/generation pipeline may use. Never carries source code —
/// only a description of what was learned and where it traces to. This
/// is the concrete, inspectable proof that Software Cognition stays
/// transformative rather than reproducing copied implementations (Vision
/// Milestone V11's Copyright requirement).
class SoftwareTransformation {
  final String description;
  final SoftwareEvidence tracedTo;
  final SoftwareConfidence confidence;

  const SoftwareTransformation({
    required this.description,
    required this.tracedTo,
    required this.confidence,
  });
}
