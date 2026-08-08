/// EngineeringMemorySummary — Implementation Milestone R5's honest,
/// deliberately-scoped persistence of `EngineeringPlan`.
///
/// REALITY: `EngineeringCandidate` (the plan's `finalCandidate`) pulls in
/// 8 sub-engineering-result types (behavior/data/navigation/interaction/
/// persistence/offline/synchronization/lifecycle/performance/
/// accessibility/security), each with its own nested EventGraph/
/// StateMachineDefinition/BindingGraph shapes. Full lossless round-trip
/// serialization of that entire tree is achievable in principle but was
/// judged, for this milestone, not the right tradeoff against
/// `RequirementGraph`/`ArchitectureCandidate` (both persisted with full
/// fidelity — see their own `*_serialization.dart` files) and the rest of
/// R5's scope (repository, creation/modification wiring, tests, docs).
///
/// This mirrors the EXACT precedent `WorldModelRepository` already
/// established for `LearningRecord`/`AutomationRecord` (Vision Milestone
/// V10): persist a real, useful, honestly-labeled SUMMARY rather than
/// either skipping engineering memory for this type entirely or rushing
/// an under-verified full serialization of ~1700 lines of nested types.
///
/// Consequence, stated plainly (see R5's Known Limitations): because
/// `EngineeringDiffer.diff()` requires two full `EngineeringCandidate`
/// instances (it reads `validations`, `bindingGraph.edges`, and each
/// singular result's real decision string), a persisted SUMMARY cannot
/// be fed back into it. `EngineeringDiff` remains unpopulated by
/// `planEvolution()` with real historical state this milestone — an
/// honest limitation, not a silent gap.
library;

import 'engineering_plan.dart';
import 'engineering_types.dart';

class EngineeringDecisionSummary {
  final String id;
  final EngineeringDecisionCategory category;
  final String subjectId;
  final String decision;
  final String rationale;
  final double confidenceScore;

  const EngineeringDecisionSummary({
    required this.id,
    required this.category,
    required this.subjectId,
    required this.decision,
    required this.rationale,
    required this.confidenceScore,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category.name,
    'subjectId': subjectId,
    'decision': decision,
    'rationale': rationale,
    'confidenceScore': confidenceScore,
  };

  factory EngineeringDecisionSummary.fromJson(Map<String, dynamic> json) =>
      EngineeringDecisionSummary(
        id: json['id'] as String,
        category: EngineeringDecisionCategory.values.byName(
          json['category'] as String,
        ),
        subjectId: json['subjectId'] as String,
        decision: json['decision'] as String,
        rationale: json['rationale'] as String,
        confidenceScore: (json['confidenceScore'] as num).toDouble(),
      );
}

class EngineeringMemorySummary {
  final String candidateId;
  final int iteration;
  final EngineeringRefinementOutcome outcome;
  final int reviewIssueCount;
  final int criticalReviewIssueCount;
  final double overallConfidenceScore;
  final List<EngineeringDecisionSummary> decisions;

  const EngineeringMemorySummary({
    required this.candidateId,
    required this.iteration,
    required this.outcome,
    required this.reviewIssueCount,
    required this.criticalReviewIssueCount,
    required this.overallConfidenceScore,
    required this.decisions,
  });

  /// Real, deterministic — every field is read directly from [plan],
  /// nothing fabricated. `decisions` flattens `EngineeringCandidate
  /// .allDecisions` (already real, already used by Engineering Review),
  /// never re-derived independently.
  factory EngineeringMemorySummary.summarize(EngineeringPlan plan) {
    final candidate = plan.finalCandidate;
    final review = plan.finalReview;
    return EngineeringMemorySummary(
      candidateId: candidate.id,
      iteration: candidate.iteration,
      outcome: plan.outcome,
      reviewIssueCount: review.issues.length,
      criticalReviewIssueCount: review.issues
          .where((i) => i.severity.name == 'critical')
          .length,
      overallConfidenceScore: candidate.overallConfidence.score,
      decisions: candidate.allDecisions
          .map(
            (d) => EngineeringDecisionSummary(
              id: d.id,
              category: d.category,
              subjectId: d.subjectId,
              decision: d.decision,
              rationale: d.rationale,
              confidenceScore: d.confidence.score,
            ),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'candidateId': candidateId,
    'iteration': iteration,
    'outcome': outcome.name,
    'reviewIssueCount': reviewIssueCount,
    'criticalReviewIssueCount': criticalReviewIssueCount,
    'overallConfidenceScore': overallConfidenceScore,
    'decisions': decisions.map((d) => d.toJson()).toList(),
  };

  factory EngineeringMemorySummary.fromJson(
    Map<String, dynamic> json,
  ) => EngineeringMemorySummary(
    candidateId: json['candidateId'] as String,
    iteration: json['iteration'] as int,
    outcome: EngineeringRefinementOutcome.values.byName(
      json['outcome'] as String,
    ),
    reviewIssueCount: json['reviewIssueCount'] as int,
    criticalReviewIssueCount: json['criticalReviewIssueCount'] as int,
    overallConfidenceScore: (json['overallConfidenceScore'] as num).toDouble(),
    decisions: (json['decisions'] as List)
        .map(
          (d) => EngineeringDecisionSummary.fromJson(d as Map<String, dynamic>),
        )
        .toList(),
  );
}
