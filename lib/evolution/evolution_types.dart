/// Autonomous Evolution Engine (AEE) — Vision Milestone V7 — core typed
/// vocabulary. Mirrors the established pattern from Design Review (V6):
/// no Maps, no dynamic, no JSON blobs, every finding self-explaining via
/// a real [Confidence] or [RiskLevel], never a bare number.
library;

import '../feature_discovery/feature_types.dart' show ComplexityLevel;
import '../software_architect/confidence.dart';

/// Where a proposal sits on the roadmap — never a raw priority number.
enum EvolutionPhase { current, immediate, next, later, future, experimental }

/// How urgently an opportunity should be considered, independent of phase
/// (phase also factors in cost/risk; priority is the raw importance
/// signal an estimator attaches before phase placement).
enum EvolutionPriority { critical, high, medium, low, speculative }

/// The structural kind of gap an opportunity represents. Every value
/// traces to a real, already-computed signal (FeatureGraph priority, an
/// architecture posture decision, or a non-critical Design Review
/// finding) — never a template or domain guess.
enum EvolutionOpportunityCategory {
  missingCapability,
  missingWorkflow,
  missingNavigation,
  missingSearch,
  missingFiltering,
  missingAccessibility,
  missingOffline,
  missingSynchronization,
  missingPerformance,
  missingMaintainability,
}

/// Points to exactly what produced an [EvolutionOpportunity] or
/// [EvolutionCandidate] — a real FeatureGraph node, architecture decision,
/// or Design Review issue, never a fabricated claim.
class EvolutionEvidence {
  final String affectedGraph;
  final String affectedNodeId;
  final String? sourceFeatureId;
  final String? sourceReviewIssueId;

  const EvolutionEvidence({
    required this.affectedGraph,
    required this.affectedNodeId,
    this.sourceFeatureId,
    this.sourceReviewIssueId,
  });
}

/// Why an opportunity or proposal exists (or was rejected) — the
/// substrate for "Why did you recommend this?".
class EvolutionReason {
  final String summary;
  final EvolutionEvidence evidence;
  final Confidence confidence;

  const EvolutionReason({
    required this.summary,
    required this.evidence,
    required this.confidence,
  });
}

/// Typed cost estimate — every dimension a [ComplexityLevel], never an
/// arbitrary number.
class EvolutionCost {
  final ComplexityLevel engineering;
  final ComplexityLevel migration;
  final ComplexityLevel testing;
  final ComplexityLevel documentation;

  const EvolutionCost({
    this.engineering = ComplexityLevel.low,
    this.migration = ComplexityLevel.none,
    this.testing = ComplexityLevel.low,
    this.documentation = ComplexityLevel.low,
  });
}

/// Typed risk estimate — every dimension named in this milestone's own
/// Risk Estimation section, each a [RiskLevel].
class EvolutionRisk {
  final RiskLevel migrationRisk;
  final RiskLevel modificationRisk;
  final RiskLevel securityRisk;
  final RiskLevel dataRisk;
  final RiskLevel performanceRisk;
  final RiskLevel runtimeRisk;
  final RiskLevel userImpact;
  final RiskLevel testingCost;
  final RiskLevel documentationCost;

  const EvolutionRisk({
    this.migrationRisk = RiskLevel.none,
    this.modificationRisk = RiskLevel.none,
    this.securityRisk = RiskLevel.none,
    this.dataRisk = RiskLevel.none,
    this.performanceRisk = RiskLevel.none,
    this.runtimeRisk = RiskLevel.none,
    this.userImpact = RiskLevel.none,
    this.testingCost = RiskLevel.none,
    this.documentationCost = RiskLevel.none,
  });

  /// The single highest risk level across every dimension — used by
  /// [EvolutionPlanner] to gate which phase a candidate can reach.
  RiskLevel get highest => [
    migrationRisk,
    modificationRisk,
    securityRisk,
    dataRisk,
    performanceRisk,
    runtimeRisk,
    userImpact,
  ].reduce((a, b) => a.index > b.index ? a : b);
}

/// Typed benefit estimate — every dimension a self-explaining
/// [Confidence], mirroring SolutionScore's (V5) proven pattern exactly.
class EvolutionBenefit {
  final Confidence engineeringValue;
  final Confidence userValue;
  final Confidence maintenanceValue;
  final Confidence performanceValue;
  final Confidence securityValue;
  final Confidence accessibilityValue;
  final Confidence offlineValue;
  final Confidence futureValue;

  const EvolutionBenefit({
    required this.engineeringValue,
    required this.userValue,
    required this.maintenanceValue,
    required this.performanceValue,
    required this.securityValue,
    required this.accessibilityValue,
    required this.offlineValue,
    required this.futureValue,
  });

  /// Equal-weighted mean across all 8 dimensions — the same "explain
  /// every score, never fabricate a single number" pattern as
  /// SolutionScore.overall.
  double get overall =>
      (engineeringValue.score +
          userValue.score +
          maintenanceValue.score +
          performanceValue.score +
          securityValue.score +
          accessibilityValue.score +
          offlineValue.score +
          futureValue.score) /
      8.0;
}

enum EvolutionDecisionKind { accepted, rejected, deferred, executed }

/// What ultimately happened to one opportunity or proposal — every
/// automatic or human decision is recorded, never silent.
class EvolutionDecision {
  final String subjectId;
  final EvolutionDecisionKind kind;
  final String rationale;
  final Confidence confidence;

  const EvolutionDecision({
    required this.subjectId,
    required this.kind,
    required this.rationale,
    required this.confidence,
  });
}

enum EvolutionDependencyKind { requires, blocks, relatesTo }

/// A typed edge in the [EvolutionGraph] between two candidates/
/// opportunities.
class EvolutionDependency {
  final String fromId;
  final String toId;
  final EvolutionDependencyKind kind;

  const EvolutionDependency({
    required this.fromId,
    required this.toId,
    required this.kind,
  });
}
