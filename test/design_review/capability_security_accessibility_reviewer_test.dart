/// Vision V6 SCARE — CapabilityReviewer, SecurityReviewer +
/// IntegrityReviewer, AccessibilityReviewer.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/application_engineering/accessibility_performance_security_engineering.dart';
import 'package:anything/application_engineering/engineering_types.dart'
    show EngineeringDecision;
import 'package:anything/design_review/review_types.dart';
import 'package:anything/design_review/reviewers/accessibility_reviewer.dart';
import 'package:anything/design_review/reviewers/capability_reviewer.dart';
import 'package:anything/design_review/reviewers/security_reviewer.dart';

import 'review_test_support.dart';

void main() {
  final context = buildReviewContext(fieldSurveyApp());

  group('CapabilityReviewer', () {
    const reviewer = CapabilityReviewer();

    test(
      'a real, approved http capability has no critical issues (permission not required for http)',
      () {
        final issues = reviewer.review(context);
        expect(
          issues.any((i) => i.severity == ReviewSeverity.critical),
          isFalse,
        );
      },
    );
  });

  group('SecurityReviewer', () {
    const reviewer = SecurityReviewer();

    test('a real, approved security posture has no critical issues', () {
      final issues = reviewer.review(context);
      expect(issues.any((i) => i.severity == ReviewSeverity.critical), isFalse);
    });
  });

  group('IntegrityReviewer', () {
    const reviewer = IntegrityReviewer();

    test(
      'a real, approved engineered security record has all 6 aspects and no critical issues',
      () {
        final issues = reviewer.review(context);
        expect(
          issues.any((i) => i.severity == ReviewSeverity.critical),
          isFalse,
        );
        expect(
          context.engineering.security.decisions,
          hasLength(SecurityAspect.values.length),
        );
      },
    );

    test('a missing security aspect is flagged critical', () {
      final stripped = SecurityEngineeringResult(
        decisions: context.engineering.security.decisions
            .where((d) => d.subjectId != SecurityAspect.kaalka.name)
            .toList(),
      );
      final broken = withSecurityDecisions(context.engineering, stripped);
      final issues = reviewer.review(withEngineering(context, broken));
      expect(
        issues.any((i) => i.id == 'integrity:missingAspect:kaalka'),
        isTrue,
      );
    });

    test(
      'a Kaalka decision that stops confirming canonical package:kaalka usage fails review — regression guard',
      () {
        final tampered = SecurityEngineeringResult(
          decisions: [
            for (final d in context.engineering.security.decisions)
              if (d.subjectId == SecurityAspect.kaalka.name)
                EngineeringDecision(
                  id: d.id,
                  category: d.category,
                  subjectId: d.subjectId,
                  decision: d.decision,
                  rationale:
                      'A second, independent protection mechanism was added.',
                  confidence: d.confidence,
                )
              else
                d,
          ],
        );
        final broken = withSecurityDecisions(context.engineering, tampered);
        final issues = reviewer.review(withEngineering(context, broken));
        final issue = issues.firstWhere(
          (i) => i.id == 'integrity:kaalkaNotCanonical',
        );
        expect(issue.severity, ReviewSeverity.critical);
      },
    );
  });

  group('AccessibilityReviewer', () {
    const reviewer = AccessibilityReviewer();

    test(
      'a real, approved accessibility record has all 6 aspects and no critical issues',
      () {
        final issues = reviewer.review(context);
        expect(
          issues.any((i) => i.severity == ReviewSeverity.critical),
          isFalse,
        );
        expect(
          context.engineering.accessibility.decisions,
          hasLength(AccessibilityAspect.values.length),
        );
      },
    );

    test(
      'a decision that no longer traces to Flutter/Material is flagged — never fabricate capability',
      () {
        final tampered = AccessibilityEngineeringResult(
          decisions: [
            for (final d in context.engineering.accessibility.decisions)
              if (d.subjectId == AccessibilityAspect.contrast.name)
                EngineeringDecision(
                  id: d.id,
                  category: d.category,
                  subjectId: d.subjectId,
                  decision: d.decision,
                  rationale:
                      'A fully custom contrast engine was built for this app.',
                  confidence: d.confidence,
                )
              else
                d,
          ],
        );
        final broken = withAccessibilityDecisions(
          context.engineering,
          tampered,
        );
        final issues = reviewer.review(withEngineering(context, broken));
        expect(
          issues.any((i) => i.id == 'accessibility:unverifiedClaim:contrast'),
          isTrue,
        );
      },
    );
  });
}
