/// Review Result — one review pass (ReviewIteration) and the complete,
/// final outcome of a review+refine session (ReviewResult), mirroring the
/// proven pattern already established by EngineeringReviewResult (V3),
/// FeatureReviewResult (V4), and SolutionReviewResult (V5).
library;

import 'review_context.dart';
import 'review_types.dart';

class ReviewIteration {
  final int index;
  final List<ReviewIssue> issues;

  const ReviewIteration({required this.index, this.issues = const []});

  bool get passed => issues.isEmpty;
  bool get hasCriticalIssues =>
      issues.any((i) => i.severity == ReviewSeverity.critical);
  List<ReviewIssue> get autoFixableIssues =>
      issues.where((i) => i.autoFixable).toList();
}

enum ReviewOutcome { approved, refinementRequired, budgetExhausted }

class ReviewResult {
  final List<ReviewIteration> iterations;
  final ReviewContext finalContext;
  final ReviewOutcome outcome;

  const ReviewResult({
    required this.iterations,
    required this.finalContext,
    required this.outcome,
  });

  ReviewIteration get finalIteration => iterations.last;
  List<ReviewIssue> get allIssues =>
      iterations.expand((i) => i.issues).toList();
}
