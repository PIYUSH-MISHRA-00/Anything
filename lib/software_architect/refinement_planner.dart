/// Refinement Planner — the real iterative loop: review, apply automatic
/// fixes for fixable issues, re-review, until either no critical issues
/// remain or a configurable iteration budget is exhausted. Always
/// terminates: the loop condition is bounded by `maxIterations` and stops
/// early the moment there is nothing left it knows how to fix
/// automatically.
library;

import 'architecture_candidate.dart';
import 'architecture_review.dart';
import 'architecture_report.dart';
import 'architecture_types.dart';
import 'confidence_analyzer.dart';
import 'self_critic.dart';

class RefinementPlanner {
  final SelfCritic _critic;
  final ConfidenceAnalyzer _confidenceAnalyzer;
  final int maxIterations;

  const RefinementPlanner({
    SelfCritic critic = const SelfCritic(),
    ConfidenceAnalyzer confidenceAnalyzer = const ConfidenceAnalyzer(),
    this.maxIterations = 3,
  }) : _critic = critic,
       _confidenceAnalyzer = confidenceAnalyzer;

  ArchitectureReport refine(ArchitectureCandidate initial) {
    var candidate = initial;
    var review = _critic.review(candidate);
    final history = <ArchitectureReview>[review];

    var iteration = 0;
    while (review.hasCriticalIssues && iteration < maxIterations) {
      final fixable = review.autoFixableIssues;
      if (fixable.isEmpty) {
        // No automatic fix exists for the remaining critical issues —
        // looping further would never change the outcome; stop here.
        break;
      }

      candidate = _applyFixes(candidate, fixable);
      iteration++;
      candidate = candidate.copyWith(
        iteration: iteration,
        overallConfidence: _confidenceAnalyzer.analyze(candidate),
      );
      review = _critic.review(candidate);
      history.add(review);
    }

    final outcome = !review.hasCriticalIssues
        ? RefinementOutcome.approved
        : (iteration >= maxIterations
              ? RefinementOutcome.budgetExhausted
              : RefinementOutcome.refinementRequired);

    return ArchitectureReport(
      finalCandidate: candidate,
      reviewHistory: history,
      outcome: outcome,
    );
  }

  ArchitectureCandidate _applyFixes(
    ArchitectureCandidate candidate,
    List<ArchitectureIssue> fixes,
  ) {
    var entities = candidate.entities;
    var relationships = candidate.relationships;

    for (final issue in fixes) {
      switch (issue.category) {
        case IssueCategory.duplicateEntity:
          final index = entities.indexWhere(
            (e) => e.entityId == issue.subjectId,
          );
          if (index != -1) {
            final e = entities[index];
            final disambiguated = EntityDecision(
              entityId: e.entityId,
              name: '${e.name} (${e.entityId})',
              fieldCount: e.fieldCount,
              storage: e.storage,
              storageDecision: e.storageDecision,
            );
            entities = [...entities];
            entities[index] = disambiguated;
          }
        case IssueCategory.navigationIssue:
          relationships = relationships
              .where((r) => '${r.fromEntityId}.${r.fieldId}' != issue.subjectId)
              .toList();
        default:
          break;
      }
    }

    return candidate.copyWith(entities: entities, relationships: relationships);
  }
}
