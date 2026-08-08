/// Feature Plan — the final, approved (or best-effort) output of the
/// Feature Discovery pipeline. This is what Architecture (and, via
/// EngineeringContext, Engineering) now consumes alongside the raw
/// SemanticApp, not in place of it.
library;

import 'feature_reviewer.dart';
import 'feature_types.dart';

enum FeatureRefinementOutcome { approved, refinementRequired, budgetExhausted }

class FeaturePlan {
  final FeatureGraph finalGraph;
  final List<FeatureReviewResult> reviewHistory;
  final FeatureRefinementOutcome outcome;

  const FeaturePlan({
    required this.finalGraph,
    required this.reviewHistory,
    required this.outcome,
  });

  FeatureReviewResult get finalReview => reviewHistory.last;
}
