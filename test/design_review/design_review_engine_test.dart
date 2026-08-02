/// Vision V6 SCARE — DesignReviewEngine: the top-level Produce -> Review
/// -> Improve -> Review -> Improve -> Approve orchestrator, and
/// ReviewApproval's fail-closed gate.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/application_engineering/accessibility_performance_security_engineering.dart';
import 'package:anything/design_review/design_review_engine.dart';
import 'package:anything/design_review/review_approval.dart';
import 'package:anything/design_review/review_refinement.dart';
import 'package:anything/design_review/review_result.dart';

import 'review_test_support.dart';

void main() {
  const engine = DesignReviewEngine();

  test('a real, well-formed design is approved', () {
    final context = buildReviewContext(fieldSurveyApp());
    final outcome = engine.review(context);
    expect(outcome.approved, isTrue);
    expect(outcome.session.result.outcome, ReviewOutcome.approved);
  });

  test('the fingerprint is deterministic for the same structural shape', () {
    final contextA = buildReviewContext(fieldSurveyApp());
    final contextB = buildReviewContext(fieldSurveyApp());
    expect(engine.fingerprintOf(contextA), engine.fingerprintOf(contextB));
  });

  test('ReviewApproval denies anything short of a real approved outcome, with a concrete reason', () {
    final context = buildReviewContext(fieldSurveyApp());
    // A missing security aspect is critical and not auto-fixable — the
    // refinement loop can never resolve it, so the session never approves.
    final strippedSecurity = SecurityEngineeringResult(
      decisions: context.engineering.security.decisions.where((d) => d.subjectId != SecurityAspect.kaalka.name).toList(),
    );
    final broken = withEngineering(context, withSecurityDecisions(context.engineering, strippedSecurity));

    final result = const ReviewRefinement().refine(broken);

    expect(const ReviewApproval().isApproved(result), isFalse);
    expect(const ReviewApproval().denialReason(result), contains('critical issue'));
  });
}
