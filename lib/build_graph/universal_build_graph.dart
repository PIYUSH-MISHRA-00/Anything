/// UniversalBuildGraph — Implementation Milestone R11. The real,
/// deterministic derivation of a build-scoped dependency graph from a
/// `CanonicalImplementationModel` (R9). Retains [sourceModel] directly —
/// the least-disruptive extension over forcing `SummaryManifestGenerator`
/// (R10) to be rebuilt against a graph-shaped API it wasn't designed for;
/// a future, real generator can consume either the graph (for ordering/
/// dependency questions) or the retained model (for full field-level
/// detail), never a lossy one-way conversion.
library;

import '../implementation_model/canonical_implementation_model.dart';
import 'build_graph.dart';

class UniversalBuildGraph {
  final List<BuildGraphNode> nodes;
  final List<BuildGraphEdge> edges;
  final CanonicalImplementationModel sourceModel;

  const UniversalBuildGraph({
    required this.nodes,
    required this.edges,
    required this.sourceModel,
  });

  bool get isEmpty => nodes.isEmpty;

  List<BuildGraphEdge> outgoingFrom(String nodeId) =>
      edges.where((e) => e.fromId == nodeId).toList();
}

class BuildGraphBuilder {
  const BuildGraphBuilder();

  /// Real, deterministic: the same [model] always produces a structurally
  /// identical graph (Rule 7) — every node/edge traces to already-computed
  /// `CanonicalImplementationModel` data, nothing fabricated.
  UniversalBuildGraph build(CanonicalImplementationModel model) {
    final nodes = <BuildGraphNode>[
      for (final e in model.entities)
        BuildGraphNode(id: e.id, kind: BuildNodeKind.entity, label: e.name),
      for (final r in model.repositories)
        BuildGraphNode(id: r.id, kind: BuildNodeKind.repository, label: r.id),
      for (final c in model.controllers)
        BuildGraphNode(id: c.id, kind: BuildNodeKind.controller, label: c.id),
      for (final c in model.capabilityAdapters)
        BuildGraphNode(
          id: c.capabilityId,
          kind: BuildNodeKind.capability,
          label: c.capabilityId,
        ),
    ];
    final nodeIds = nodes.map((n) => n.id).toSet();

    final edges = <BuildGraphEdge>[
      // Real: entity-to-entity/entity-to-capability dependencies, already
      // computed by CanonicalImplementationPlanner (R9).
      for (final d in model.dependencies)
        if (nodeIds.contains(d.fromId) && nodeIds.contains(d.toId))
          BuildGraphEdge(
            fromId: d.fromId,
            toId: d.toId,
            kind: BuildRelationshipKind.dependsOn,
          ),
      // Real: a repository is generated FROM its entity — the repository
      // depends on the entity existing first.
      for (final r in model.repositories)
        if (nodeIds.contains(r.entityId))
          BuildGraphEdge(
            fromId: r.id,
            toId: r.entityId,
            kind: BuildRelationshipKind.dependsOn,
          ),
      // Real: a controller depends on its entity existing first.
      for (final c in model.controllers)
        if (nodeIds.contains(c.entityId))
          BuildGraphEdge(
            fromId: c.id,
            toId: c.entityId,
            kind: BuildRelationshipKind.dependsOn,
          ),
    ];

    return UniversalBuildGraph(nodes: nodes, edges: edges, sourceModel: model);
  }
}
