/// Solution Graph — the top-level typed model Multi-Solution Reasoning
/// produces: one SolutionCandidate per generated architecture variant, and
/// a SolutionGraph of typed relations (dominates/equivalentTo/
/// alternativeTo/conflictsWith) between them once compared.
library;

import '../feature_discovery/dependency_types.dart';
import '../feature_discovery/feature_types.dart' show FeatureComplexity;
import '../software_architect/architecture_candidate.dart';
import '../software_architect/architecture_types.dart' show CapabilityDecision;
import '../software_architect/confidence.dart';
import 'solution_explanation.dart';
import 'solution_score.dart';
import 'solution_tradeoff.dart';
import 'solution_variation_types.dart';

enum SolutionRelationKind { dominates, dominatedBy, equivalentTo, alternativeTo, conflictsWith }

class SolutionNode {
  final String candidateId;
  final String label;
  final double overallScore;

  const SolutionNode({required this.candidateId, required this.label, required this.overallScore});
}

class SolutionEdge {
  final String fromCandidateId;
  final String toCandidateId;
  final SolutionRelationKind kind;
  final String rationale;

  const SolutionEdge({
    required this.fromCandidateId,
    required this.toCandidateId,
    required this.kind,
    required this.rationale,
  });
}

class SolutionGraph {
  final List<SolutionNode> nodes;
  final List<SolutionEdge> edges;

  const SolutionGraph({this.nodes = const [], this.edges = const []});

  SolutionNode? nodeById(String id) => nodes.where((n) => n.candidateId == id).firstOrNull;

  List<SolutionEdge> edgesFrom(String id) => edges.where((e) => e.fromCandidateId == id).toList();

  List<SolutionEdge> edgesTo(String id) => edges.where((e) => e.toCandidateId == id).toList();
}

/// One fully-engineered candidate solution: Architecture -> Engineering ->
/// Capabilities -> Dependencies -> Complexity -> Tradeoffs -> Confidence ->
/// Cost -> Explanation, exactly the pipeline the milestone specifies.
/// `complexity` doubles as the solution's cost profile (reusing V4's
/// FeatureComplexity/ComplexityLevel rather than inventing a parallel
/// "SolutionCost" type for the same bounded-level concept).
class SolutionCandidate {
  final String id;
  final String label;
  final ArchitectureCandidate architecture;
  final ArchitectureVariation architectureVariation;
  final EngineeringVariation engineeringVariation;
  final NavigationVariation navigationVariation;
  final CapabilityVariation capabilityVariation;
  final OfflineVariation offlineVariation;
  final SynchronizationVariation synchronizationVariation;
  final StorageVariation storageVariation;
  final StateVariation stateVariation;

  /// The shared Dependency Graph (Vision Milestone V4) — features and
  /// their dependencies don't vary by architecture choice, only how they
  /// are engineered does; carried here for Solution Graph completeness.
  final DependencyGraph dependencies;

  final FeatureComplexity complexity;
  final List<SolutionTradeoff> tradeoffs;
  final SolutionScore? score;
  final Confidence confidence;
  final SolutionExplanation explanation;

  const SolutionCandidate({
    required this.id,
    required this.label,
    required this.architecture,
    required this.architectureVariation,
    required this.engineeringVariation,
    required this.navigationVariation,
    required this.capabilityVariation,
    required this.offlineVariation,
    required this.synchronizationVariation,
    required this.storageVariation,
    required this.stateVariation,
    required this.dependencies,
    required this.complexity,
    this.tradeoffs = const [],
    this.score,
    required this.confidence,
    required this.explanation,
  });

  List<CapabilityDecision> get capabilities => architecture.capabilities;

  SolutionCandidate copyWith({List<SolutionTradeoff>? tradeoffs, SolutionScore? score, SolutionExplanation? explanation}) {
    return SolutionCandidate(
      id: id,
      label: label,
      architecture: architecture,
      architectureVariation: architectureVariation,
      engineeringVariation: engineeringVariation,
      navigationVariation: navigationVariation,
      capabilityVariation: capabilityVariation,
      offlineVariation: offlineVariation,
      synchronizationVariation: synchronizationVariation,
      storageVariation: storageVariation,
      stateVariation: stateVariation,
      dependencies: dependencies,
      complexity: complexity,
      tradeoffs: tradeoffs ?? this.tradeoffs,
      confidence: confidence,
      explanation: explanation ?? this.explanation,
      score: score ?? this.score,
    );
  }
}

/// A single total-ordering rank for a FeatureComplexity profile — the sum
/// of its per-dimension ComplexityLevel indices. Used only to compare two
/// candidates' overall complexity for dominance/selection purposes; never
/// exposed as a user-facing "score."
int solutionComplexityRank(FeatureComplexity complexity) {
  return complexity.implementation.index +
      complexity.engineering.index +
      complexity.runtime.index +
      complexity.memoryCost.index +
      complexity.storageCost.index +
      complexity.batteryCost.index +
      complexity.networkCost.index +
      complexity.maintenanceCost.index +
      complexity.modificationCost.index;
}
