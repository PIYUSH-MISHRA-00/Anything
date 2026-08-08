/// Vision V6 SCARE — PerformanceReviewer + MaintainabilityReviewer,
/// OfflineReviewer, RuntimeReviewer.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/design_review/review_types.dart';
import 'package:anything/design_review/reviewers/offline_reviewer.dart';
import 'package:anything/design_review/reviewers/performance_reviewer.dart';
import 'package:anything/design_review/reviewers/runtime_reviewer.dart';

import 'review_test_support.dart';

void main() {
  final context = buildReviewContext(fieldSurveyApp());

  group('PerformanceReviewer', () {
    const reviewer = PerformanceReviewer();

    test(
      'a real solution never raises a critical performance issue (estimates are info/warning only)',
      () {
        final issues = reviewer.review(context);
        expect(
          issues.any((i) => i.severity == ReviewSeverity.critical),
          isFalse,
        );
      },
    );
  });

  group('MaintainabilityReviewer', () {
    const reviewer = MaintainabilityReviewer();

    test(
      'a small, real solution does not trigger the high-complexity warning',
      () {
        final issues = reviewer.review(context, otherIssueCount: 0);
        expect(
          issues.any((i) => i.id == 'maintainability:highComplexity'),
          isFalse,
        );
      },
    );

    test('a high issue volume is surfaced as an informational signal', () {
      final issues = reviewer.review(context, otherIssueCount: 20);
      expect(
        issues.any((i) => i.id == 'maintainability:highIssueVolume'),
        isTrue,
      );
    });
  });

  group('OfflineReviewer', () {
    const reviewer = OfflineReviewer();

    test('a real, approved offline/sync posture has no critical issues', () {
      final issues = reviewer.review(context);
      expect(issues.any((i) => i.severity == ReviewSeverity.critical), isFalse);
    });
  });

  group('RuntimeReviewer', () {
    const reviewer = RuntimeReviewer();

    test(
      'a small, real design stays well within every RuntimeSecurityLimits budget',
      () {
        final issues = reviewer.review(context);
        expect(
          issues.any((i) => i.category == ReviewCategory.runtime),
          isFalse,
        );
      },
    );
  });
}
