/// Solution History — the audit trail SolutionRefinement produces: every
/// review pass plus the final, pruned candidate list.
library;

import 'solution_reviewer.dart';
import 'solution_types.dart';

enum SolutionRefinementOutcome { approved, refinementRequired, budgetExhausted, noViableSolution }

class SolutionHistory {
  final List<SolutionReviewResult> reviewHistory;
  final List<SolutionCandidate> finalCandidates;
  final SolutionRefinementOutcome outcome;

  const SolutionHistory({required this.reviewHistory, required this.finalCandidates, required this.outcome});

  SolutionReviewResult get finalReview => reviewHistory.last;
}
