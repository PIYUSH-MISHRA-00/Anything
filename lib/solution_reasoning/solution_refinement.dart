/// Solution Refinement — review the candidate list, drop auto-fixable
/// critical candidates (duplicate/impossible/contradictory/incomplete),
/// re-review, until either no critical issues remain or a configurable
/// iteration budget is exhausted. Mirrors the proven-terminating design
/// already established in software_architect/, application_engineering/,
/// and feature_discovery/ — operating on a candidate *list* rather than a
/// single graph's nodes/edges.
library;

import 'solution_history.dart';
import 'solution_reviewer.dart';
import 'solution_types.dart';

class SolutionRefinement {
  final int maxIterations;

  const SolutionRefinement({this.maxIterations = 3});

  SolutionHistory refine(List<SolutionCandidate> initial) {
    var candidates = initial;
    var iteration = 0;
    var review = SolutionReviewer(iteration: iteration).review(candidates);
    final history = [review];

    while (review.hasCriticalIssues && iteration < maxIterations) {
      final fixable = review.autoFixableIssues;
      if (fixable.isEmpty) break;

      final dropIds = fixable.map((i) => i.subjectId).toSet();
      final remaining = candidates.where((c) => !dropIds.contains(c.id)).toList();
      if (remaining.isEmpty) break; // never drop every candidate — keep the last known-non-empty set

      candidates = remaining;
      iteration++;
      review = SolutionReviewer(iteration: iteration).review(candidates);
      history.add(review);
    }

    final outcome = candidates.isEmpty
        ? SolutionRefinementOutcome.noViableSolution
        : !review.hasCriticalIssues
        ? SolutionRefinementOutcome.approved
        : (iteration >= maxIterations
              ? SolutionRefinementOutcome.budgetExhausted
              : SolutionRefinementOutcome.refinementRequired);

    return SolutionHistory(reviewHistory: history, finalCandidates: candidates, outcome: outcome);
  }
}
