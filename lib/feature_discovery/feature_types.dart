/// Feature Discovery Engine (FDI) — core typed vocabulary.
///
/// A FeatureGraph node/edge model, strongly typed throughout: no Maps, no
/// dynamic, no JSON blobs. Every feature is discovered structurally from
/// the shape of a RequirementGraph/SemanticApp — nothing here inspects a
/// domain name.
library;

import '../software_architect/confidence.dart';

/// How important a discovered feature is to the requested application.
enum FeaturePriority { mandatory, recommended, optional, future, experimental }

/// A cross-cutting kind of feature — structural, never domain-specific.
enum FeatureCategory {
  data,
  persistence,
  relational,
  search,
  indexing,
  navigation,
  validation,
  state,
  capability,
  permission,
  security,
  offline,
  reporting,
}

/// A typed, bounded complexity/cost level — never an arbitrary number.
enum ComplexityLevel { none, low, medium, high }

/// Every cost dimension a feature can carry, all typed.
class FeatureComplexity {
  final ComplexityLevel implementation;
  final ComplexityLevel engineering;
  final ComplexityLevel runtime;
  final ComplexityLevel memoryCost;
  final ComplexityLevel storageCost;
  final ComplexityLevel batteryCost;
  final ComplexityLevel networkCost;
  final ComplexityLevel maintenanceCost;
  final ComplexityLevel modificationCost;

  const FeatureComplexity({
    this.implementation = ComplexityLevel.low,
    this.engineering = ComplexityLevel.low,
    this.runtime = ComplexityLevel.low,
    this.memoryCost = ComplexityLevel.low,
    this.storageCost = ComplexityLevel.low,
    this.batteryCost = ComplexityLevel.none,
    this.networkCost = ComplexityLevel.none,
    this.maintenanceCost = ComplexityLevel.low,
    this.modificationCost = ComplexityLevel.low,
  });
}

/// The base decision record every feature-discovery module produces —
/// mirrors ArchitectureDecision/EngineeringDecision's shape exactly.
class FeatureDecision {
  final String id;
  final FeatureCategory category;
  final String subjectId;
  final String decision;
  final String rationale;
  final Confidence confidence;

  const FeatureDecision({
    required this.id,
    required this.category,
    required this.subjectId,
    required this.decision,
    required this.rationale,
    required this.confidence,
  });
}

/// Records why a feature exists (or doesn't) — the substrate for a future
/// "Why did you create this?" explanation surface.
class FeatureExplanation {
  final String featureId;
  final String whyDiscovered;
  final String? whyRequired;
  final String? whyOptional;
  final String? whyOmitted;
  final String? whyDependent;

  const FeatureExplanation({
    required this.featureId,
    required this.whyDiscovered,
    this.whyRequired,
    this.whyOptional,
    this.whyOmitted,
    this.whyDependent,
  });
}

/// A raw feature signal, before priority/complexity/review are attached —
/// what a discovery rule emits.
class FeatureCandidate {
  final String id;
  final String name;
  final FeatureCategory category;

  /// The RequirementGraph/SemanticApp node ids that structurally triggered
  /// this candidate — never a domain name, always a stable identifier.
  final List<String> sourceNodeIds;
  final String rationale;

  const FeatureCandidate({
    required this.id,
    required this.name,
    required this.category,
    this.sourceNodeIds = const [],
    required this.rationale,
  });
}

/// A finalized, graph-resident feature: the candidate plus everything
/// analysis attached to it.
class FeatureNode {
  final FeatureCandidate candidate;
  final FeaturePriority priority;
  final FeatureComplexity complexity;
  final FeatureDecision decision;
  final FeatureExplanation explanation;

  const FeatureNode({
    required this.candidate,
    required this.priority,
    required this.complexity,
    required this.decision,
    required this.explanation,
  });

  String get id => candidate.id;
  String get name => candidate.name;
  FeatureCategory get category => candidate.category;

  FeatureNode copyWith({
    FeaturePriority? priority,
    FeatureComplexity? complexity,
    FeatureDecision? decision,
    FeatureExplanation? explanation,
  }) {
    return FeatureNode(
      candidate: candidate,
      priority: priority ?? this.priority,
      complexity: complexity ?? this.complexity,
      decision: decision ?? this.decision,
      explanation: explanation ?? this.explanation,
    );
  }
}

/// How one feature relates to another within the FeatureGraph, and how a
/// feature relates to a lower-level dependency in the DependencyGraph.
enum FeatureRelationKind {
  requires,
  dependsOn,
  optionalWith,
  recommends,
  conflictsWith,
  replaces,
  extends_,
}

/// A typed edge between two FeatureNodes.
class FeatureEdge {
  final String fromFeatureId;
  final String toFeatureId;
  final FeatureRelationKind kind;

  const FeatureEdge({
    required this.fromFeatureId,
    required this.toFeatureId,
    required this.kind,
  });
}

/// The complete, typed feature graph for one application intent.
class FeatureGraph {
  final List<FeatureNode> nodes;
  final List<FeatureEdge> edges;
  final int iteration;
  final Confidence overallConfidence;

  const FeatureGraph({
    this.nodes = const [],
    this.edges = const [],
    this.iteration = 0,
    this.overallConfidence = const Confidence(
      score: 0.0,
      reason: 'not yet analyzed',
    ),
  });

  FeatureNode? nodeById(String id) =>
      nodes.where((n) => n.id == id).firstOrNull;

  List<FeatureEdge> edgesFrom(String featureId) =>
      edges.where((e) => e.fromFeatureId == featureId).toList();

  List<FeatureEdge> edgesTo(String featureId) =>
      edges.where((e) => e.toFeatureId == featureId).toList();

  List<FeatureNode> nodesOfCategory(FeatureCategory category) =>
      nodes.where((n) => n.category == category).toList();

  List<FeatureDecision> get allDecisions =>
      nodes.map((n) => n.decision).toList();

  FeatureGraph copyWith({
    List<FeatureNode>? nodes,
    List<FeatureEdge>? edges,
    int? iteration,
    Confidence? overallConfidence,
  }) {
    return FeatureGraph(
      nodes: nodes ?? this.nodes,
      edges: edges ?? this.edges,
      iteration: iteration ?? this.iteration,
      overallConfidence: overallConfidence ?? this.overallConfidence,
    );
  }
}
