/// Review Metrics — a real, computed summary of one ReviewResult. Never a
/// separate source of truth; always derived from the actual issues found.
library;

import 'review_result.dart';
import 'review_types.dart';

class ReviewCategoryCount {
  final ReviewCategory category;
  final int count;

  const ReviewCategoryCount({required this.category, required this.count});
}

class ReviewMetrics {
  final int totalIssuesFound;
  final int totalIssuesFixed;
  final int totalCritical;
  final int totalWarnings;
  final int totalInfo;
  final int iterationsRun;
  final List<ReviewCategoryCount> issuesByCategory;

  const ReviewMetrics({
    required this.totalIssuesFound,
    required this.totalIssuesFixed,
    required this.totalCritical,
    required this.totalWarnings,
    required this.totalInfo,
    required this.iterationsRun,
    this.issuesByCategory = const [],
  });

  factory ReviewMetrics.from(ReviewResult result) {
    final allIssues = result.allIssues;
    final finalIssueIds = result.finalIteration.issues.map((i) => i.id).toSet();
    final fixedCount = allIssues
        .where((i) => i.autoFixable && !finalIssueIds.contains(i.id))
        .length;

    final counts = <ReviewCategory, int>{};
    for (final issue in result.finalIteration.issues) {
      counts[issue.category] = (counts[issue.category] ?? 0) + 1;
    }

    return ReviewMetrics(
      totalIssuesFound: allIssues.length,
      totalIssuesFixed: fixedCount,
      totalCritical: result.finalIteration.issues
          .where((i) => i.severity == ReviewSeverity.critical)
          .length,
      totalWarnings: result.finalIteration.issues
          .where((i) => i.severity == ReviewSeverity.warning)
          .length,
      totalInfo: result.finalIteration.issues
          .where((i) => i.severity == ReviewSeverity.info)
          .length,
      iterationsRun: result.iterations.length,
      issuesByCategory: counts.entries
          .map((e) => ReviewCategoryCount(category: e.key, count: e.value))
          .toList(),
    );
  }
}
