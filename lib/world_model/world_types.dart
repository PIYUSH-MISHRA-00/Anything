/// World Model & Semantic Graph (WMSG) — Vision Milestone V9 — shared
/// typed vocabulary. Mirrors the established pattern from DependencyGraph
/// (V4), EvolutionGraph (V7), and every RIL graph (V8): a real node kind
/// enum, a real typed relationship enum, no Maps, no dynamic, no JSON
/// blobs in the public data model.
library;

/// Every kind of thing the World Graph can represent — "everything
/// becomes a node," but always through this fixed, typed vocabulary,
/// never a raw string.
enum WorldNodeKind {
  experience,
  entity,
  capability,
  knowledge,
  workflow,
  schedule,
  recommendation,
  evolution,
  review,
  automation,
  storage,
  project,
  observation,
  learning,
  repository,
  softwarePackage,
  softwareComponent,

  /// A backend API endpoint (Implementation Milestone R8) — database
  /// tables deliberately reuse the existing `entity` kind (a backend
  /// table and its frontend entity are the SAME real-world concept,
  /// viewed from a different engineering angle), so this is the one
  /// genuinely new concept the backend engineering vocabulary needs.
  backendEndpoint,
}

/// Every typed relationship the World Graph supports — never a raw
/// string, never inferred from a keyword.
enum RelationshipKind {
  contains,
  references,
  dependsOn,
  extends_,
  duplicates,
  derivedFrom,
  produces,
  consumes,
  improves,
  replaces,
  relatesTo,
}

/// Why a GraphUpdate/edge exists — points at the real source graph and
/// node that produced it, mirroring EvolutionEvidence (V7) /
/// RecommendationEvidence (V8)'s "never a fabricated claim" pattern.
class GraphEvidence {
  final String sourceGraph;
  final String sourceNodeId;

  const GraphEvidence({required this.sourceGraph, required this.sourceNodeId});
}

/// The World Model's own confidence type (distinct from
/// `software_architect`'s `Confidence`, mirroring PatternConfidence (V8) /
/// EvolutionReason's per-milestone confidence convention) — a graph fact
/// is only ever as confident as the bridge that produced it.
class GraphConfidence {
  final double score;
  final String reason;

  const GraphConfidence({required this.score, required this.reason});

  static const GraphConfidence full = GraphConfidence(
    score: 1.0,
    reason: 'Directly and unambiguously derived from a real source graph.',
  );
}
