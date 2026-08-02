/// Self-Critique & Autonomous Design Review Engine (SCARE) — core typed
/// vocabulary. Every review finding is fully self-explaining by
/// construction: reason, evidence, and a recommended fix travel with it,
/// never a bare pass/fail.
library;

import '../software_architect/confidence.dart';

/// Every concern the review engine inspects — one per named *Reviewer.
enum ReviewCategory {
  architecture,
  dependency,
  engineering,
  specification,
  state,
  navigation,
  binding,
  behavior,
  capability,
  security,
  integrity,
  accessibility,
  performance,
  maintainability,
  offline,
  runtime,
  migration,
  modification,
  consistency,
}

enum ReviewSeverity { info, warning, critical }

/// Exactly which real graph/node/capability/dependency a finding traces
/// to — never a vague "something is wrong somewhere."
class ReviewEvidence {
  final String affectedGraph;
  final String affectedNodeId;
  final String? affectedCapabilityId;
  final String? affectedDependencyId;

  const ReviewEvidence({
    required this.affectedGraph,
    required this.affectedNodeId,
    this.affectedCapabilityId,
    this.affectedDependencyId,
  });
}

class ReviewRecommendation {
  final String description;

  /// Whether ReviewRefinement can safely apply this fix without human/
  /// system judgment (conservative by design — see review_refinement.dart).
  final bool autoApplicable;

  const ReviewRecommendation({required this.description, this.autoApplicable = false});
}

/// One finding. Every field the milestone's "Review Explanations" section
/// requires is present directly on the type — not reconstructed later.
class ReviewIssue {
  final String id;
  final ReviewCategory category;
  final ReviewSeverity severity;
  final String reason;
  final ReviewEvidence evidence;
  final ReviewRecommendation recommendation;
  final Confidence confidence;

  const ReviewIssue({
    required this.id,
    required this.category,
    required this.severity,
    required this.reason,
    required this.evidence,
    required this.recommendation,
    required this.confidence,
  });

  bool get autoFixable => recommendation.autoApplicable;
}

/// Human-facing formatting of one ReviewIssue — mirrors
/// FeatureExplanation (V4) / SolutionExplanation (V5)'s established shape.
class ReviewExplanation {
  final String issueId;
  final String summary;
  final String reason;
  final String evidenceSummary;
  final String recommendedFix;

  const ReviewExplanation({
    required this.issueId,
    required this.summary,
    required this.reason,
    required this.evidenceSummary,
    required this.recommendedFix,
  });

  factory ReviewExplanation.forIssue(ReviewIssue issue) {
    return ReviewExplanation(
      issueId: issue.id,
      summary: '${issue.category.name}: ${issue.reason}',
      reason: issue.reason,
      evidenceSummary:
          '${issue.evidence.affectedGraph} / ${issue.evidence.affectedNodeId}'
          '${issue.evidence.affectedCapabilityId != null ? ' (capability: ${issue.evidence.affectedCapabilityId})' : ''}'
          '${issue.evidence.affectedDependencyId != null ? ' (dependency: ${issue.evidence.affectedDependencyId})' : ''}',
      recommendedFix: issue.recommendation.description,
    );
  }
}

/// What ultimately happened to one ReviewIssue during a review session —
/// the atomic unit ReviewMemory persists for later reuse.
enum ReviewDecisionKind { accepted, rejected, fixed }

class ReviewDecision {
  final String issueId;
  final ReviewDecisionKind kind;
  final String rationale;
  final Confidence confidence;

  const ReviewDecision({
    required this.issueId,
    required this.kind,
    required this.rationale,
    required this.confidence,
  });
}
