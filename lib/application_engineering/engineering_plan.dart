/// Engineering Plan — the final, approved (or best-effort) output of the
/// AEE pipeline. This is what ExperienceSpecification/ExecutionPlan are
/// now derived from (via the blueprint it shapes — see
/// engineering_to_blueprint.dart), not the raw ArchitectureCandidate
/// directly.
library;

import 'engineering_candidate.dart';
import 'engineering_review.dart';

enum EngineeringRefinementOutcome {
  approved,
  refinementRequired,
  budgetExhausted,
}

class EngineeringPlan {
  final EngineeringCandidate finalCandidate;
  final List<EngineeringReviewResult> reviewHistory;
  final EngineeringRefinementOutcome outcome;

  const EngineeringPlan({
    required this.finalCandidate,
    required this.reviewHistory,
    required this.outcome,
  });

  EngineeringReviewResult get finalReview => reviewHistory.last;
}
