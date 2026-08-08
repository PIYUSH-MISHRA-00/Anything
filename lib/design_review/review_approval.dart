/// Review Approval — the single gate Engineering must pass before
/// Specification/ExecutionPlan/Creation ever run. Fails closed: anything
/// short of a real `approved` outcome is a denial, never a soft pass.
library;

import 'review_result.dart';
import 'review_types.dart';

class ReviewApproval {
  const ReviewApproval();

  bool isApproved(ReviewResult result) =>
      result.outcome == ReviewOutcome.approved;

  String denialReason(ReviewResult result) {
    final critical = result.finalIteration.issues
        .where((i) => i.severity == ReviewSeverity.critical)
        .length;
    return 'Design review did not reach approval (outcome: ${result.outcome.name}); '
        '$critical critical issue(s) remain unresolved after ${result.iterations.length} review pass(es).';
  }
}
