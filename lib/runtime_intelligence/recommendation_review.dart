/// RecommendationReview — every recommendation is checked against the
/// real, still-present LearningMemory record that produced it before it
/// is accepted. Mirrors EvolutionReviewer (V7)'s "verify the evidence is
/// still real" pattern exactly — never a fabricated approval.
library;

import '../software_architect/confidence.dart';
import 'learning_memory.dart';
import 'recommendation.dart';
import 'ril_types.dart';

class RecommendationDecision {
  final String subjectId;
  final RecommendationDecisionKind kind;
  final String rationale;
  final Confidence confidence;

  const RecommendationDecision({
    required this.subjectId,
    required this.kind,
    required this.rationale,
    required this.confidence,
  });
}

class RecommendationReview {
  const RecommendationReview();

  RecommendationDecision review(
    Recommendation recommendation,
    LearningMemory learningMemory,
  ) {
    final stillReal =
        learningMemory.latestForPattern(
          recommendation.reason.evidence.patternId,
        ) !=
        null;
    return RecommendationDecision(
      subjectId: recommendation.id,
      kind: stillReal
          ? RecommendationDecisionKind.accepted
          : RecommendationDecisionKind.rejected,
      rationale: stillReal
          ? 'Sourced from a real, still-present pattern in LearningMemory.'
          : 'The pattern this recommendation was based on is no longer present in LearningMemory.',
      confidence: recommendation.reason.confidence,
    );
  }
}
