/// Feature Refinement — review, apply automatic fixes for fixable issues,
/// re-review, until either no critical issues remain or a configurable
/// iteration budget is exhausted. Mirrors
/// application_engineering/engineering_refinement.dart and
/// software_architect/refinement_planner.dart's proven-terminating design.
library;

import 'feature_confidence_analyzer.dart';
import 'feature_plan.dart';
import 'feature_reviewer.dart';
import 'feature_types.dart';

class FeatureRefinement {
  final FeatureReviewer _review;
  final FeatureConfidenceAnalyzer _confidence;
  final int maxIterations;

  const FeatureRefinement({
    FeatureReviewer review = const FeatureReviewer(),
    FeatureConfidenceAnalyzer confidence = const FeatureConfidenceAnalyzer(),
    this.maxIterations = 3,
  }) : _review = review,
       _confidence = confidence;

  FeaturePlan refine(FeatureGraph initial) {
    var graph = initial;
    var review = _review.review(graph);
    final history = [review];

    var iteration = 0;
    while (review.hasCriticalIssues && iteration < maxIterations) {
      final fixable = review.autoFixableIssues;
      if (fixable.isEmpty) break;

      graph = _applyFixes(graph, fixable);
      iteration++;
      graph = graph.copyWith(
        iteration: iteration,
        overallConfidence: _confidence.analyze(graph.allDecisions),
      );
      review = _review.review(graph);
      history.add(review);
    }

    final outcome = !review.hasCriticalIssues
        ? FeatureRefinementOutcome.approved
        : (iteration >= maxIterations
              ? FeatureRefinementOutcome.budgetExhausted
              : FeatureRefinementOutcome.refinementRequired);

    return FeaturePlan(
      finalGraph: graph,
      reviewHistory: history,
      outcome: outcome,
    );
  }

  FeatureGraph _applyFixes(FeatureGraph graph, List<FeatureIssue> fixes) {
    var nodes = graph.nodes;
    var edges = graph.edges;

    for (final issue in fixes) {
      switch (issue.category) {
        case FeatureIssueCategory.duplicate:
          nodes = nodes.where((n) => n.id != issue.subjectId).toList();
          edges = edges
              .where(
                (e) =>
                    e.fromFeatureId != issue.subjectId &&
                    e.toFeatureId != issue.subjectId,
              )
              .toList();
        case FeatureIssueCategory.dangling:
          final parts = issue.subjectId.split('->');
          edges = edges
              .where(
                (e) =>
                    !(e.fromFeatureId == parts[0] && e.toFeatureId == parts[1]),
              )
              .toList();
        default:
          break;
      }
    }

    return graph.copyWith(nodes: nodes, edges: edges);
  }
}
