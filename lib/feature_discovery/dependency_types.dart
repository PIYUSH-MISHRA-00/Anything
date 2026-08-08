/// Dependency Graph — the lower-level chain from a discovered feature down
/// to the concrete capability/permission/storage/navigation primitives it
/// needs (Feature -> Capability -> Permission -> Storage -> Navigation),
/// distinct from FeatureGraph's feature-to-feature relationships.
library;

import 'feature_types.dart' show FeatureRelationKind;

/// What kind of concrete thing a DependencyNode represents.
enum DependencyNodeKind {
  feature,
  capability,
  permission,
  storage,
  navigation,
  state,
  validation,
}

/// One node in the dependency graph — a feature, or one of the concrete
/// primitives a feature bottoms out in.
class DependencyNode {
  final String id;
  final DependencyNodeKind kind;
  final String label;

  const DependencyNode({
    required this.id,
    required this.kind,
    required this.label,
  });
}

/// A typed edge between two dependency nodes.
class DependencyEdge {
  final String fromId;
  final String toId;
  final FeatureRelationKind relation;

  const DependencyEdge({
    required this.fromId,
    required this.toId,
    required this.relation,
  });
}

/// The complete, typed dependency graph.
class DependencyGraph {
  final List<DependencyNode> nodes;
  final List<DependencyEdge> edges;

  const DependencyGraph({this.nodes = const [], this.edges = const []});

  DependencyNode? nodeById(String id) =>
      nodes.where((n) => n.id == id).firstOrNull;

  List<DependencyEdge> edgesFrom(String id) =>
      edges.where((e) => e.fromId == id).toList();

  DependencyGraph merge(DependencyGraph other) {
    final nodeIds = nodes.map((n) => n.id).toSet();
    return DependencyGraph(
      nodes: [...nodes, ...other.nodes.where((n) => !nodeIds.contains(n.id))],
      edges: [...edges, ...other.edges],
    );
  }
}

/// A single typed dependency requirement one FeatureCandidate has on a
/// concrete primitive — the atomic unit a DependencyResolver produces,
/// before it's assembled into the DependencyGraph.
class FeatureDependency {
  final String featureId;
  final DependencyNodeKind dependsOnKind;
  final String dependsOnId;
  final String dependsOnLabel;
  final FeatureRelationKind relation;
  final String rationale;

  const FeatureDependency({
    required this.featureId,
    required this.dependsOnKind,
    required this.dependsOnId,
    required this.dependsOnLabel,
    this.relation = FeatureRelationKind.requires,
    required this.rationale,
  });
}
