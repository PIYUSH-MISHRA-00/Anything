/// Engineering Refinement — review, apply automatic fixes for fixable
/// issues, re-review, until either no critical issues remain or a
/// configurable iteration budget is exhausted. Mirrors
/// software_architect/refinement_planner.dart's proven-terminating design.
library;

import 'behavior_engineering.dart';
import 'engineering_candidate.dart';
import 'engineering_confidence.dart';
import 'engineering_plan.dart';
import 'engineering_review.dart';
import 'engineering_types.dart';

class EngineeringRefinement {
  final EngineeringReview _review;
  final EngineeringConfidence _confidence;
  final int maxIterations;

  const EngineeringRefinement({
    EngineeringReview review = const EngineeringReview(),
    EngineeringConfidence confidence = const EngineeringConfidence(),
    this.maxIterations = 3,
  }) : _review = review,
       _confidence = confidence;

  EngineeringPlan refine(EngineeringCandidate initial) {
    var candidate = initial;
    var review = _review.review(candidate);
    final history = [review];

    var iteration = 0;
    while (review.hasCriticalIssues && iteration < maxIterations) {
      final fixable = review.autoFixableIssues;
      if (fixable.isEmpty) break;

      candidate = _applyFixes(candidate, fixable);
      iteration++;
      candidate = candidate.copyWith(
        iteration: iteration,
        overallConfidence: _confidence.analyze(candidate),
      );
      review = _review.review(candidate);
      history.add(review);
    }

    final outcome = !review.hasCriticalIssues
        ? EngineeringRefinementOutcome.approved
        : (iteration >= maxIterations
              ? EngineeringRefinementOutcome.budgetExhausted
              : EngineeringRefinementOutcome.refinementRequired);

    return EngineeringPlan(
      finalCandidate: candidate,
      reviewHistory: history,
      outcome: outcome,
    );
  }

  EngineeringCandidate _applyFixes(
    EngineeringCandidate candidate,
    List<dynamic> fixes,
  ) {
    var bindingEdges = candidate.bindingGraph.edges;
    var behaviors = candidate.behaviors;

    for (final issue in fixes) {
      switch (issue.category) {
        case EngineeringIssueCategory.danglingBinding:
          bindingEdges = bindingEdges
              .where((e) => '${e.fromId}->${e.toId}' != issue.subjectId)
              .toList();
        case EngineeringIssueCategory.behaviorInconsistency:
          final parts = (issue.subjectId as String).split(':');
          final entityId = parts.first;
          final eventId = parts.sublist(1).join(':');
          behaviors = behaviors.map((b) {
            if (b.eventGraph.entityId != entityId) return b;
            final filteredTransitions = b.stateMachine.transitions
                .where((t) => t.eventId != eventId)
                .toList();
            return BehaviorEngineeringResult(
              eventGraph: b.eventGraph,
              stateMachine: StateMachineDefinition(
                entityId: b.stateMachine.entityId,
                initial: b.stateMachine.initial,
                transitions: filteredTransitions,
              ),
              decision: b.decision,
            );
          }).toList();
        default:
          break;
      }
    }

    return candidate.copyWith(
      bindingGraph: BindingGraph(edges: bindingEdges),
      behaviors: behaviors,
    );
  }
}
