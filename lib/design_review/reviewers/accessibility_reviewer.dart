/// Accessibility Review — audits the completeness and honesty of the
/// already-engineered accessibility record (V3's AccessibilityEngineering).
/// Reviews only what actually exists; never fabricates a capability this
/// codebase does not implement.
library;

import '../../application_engineering/accessibility_performance_security_engineering.dart' show AccessibilityAspect;
import '../../software_architect/confidence.dart';
import '../review_context.dart';
import '../review_types.dart';

class AccessibilityReviewer {
  const AccessibilityReviewer();

  List<ReviewIssue> review(ReviewContext context) {
    final decisions = context.engineering.accessibility.decisions;
    final issues = <ReviewIssue>[];

    for (final aspect in AccessibilityAspect.values) {
      final decision = decisions.where((d) => d.subjectId == aspect.name).firstOrNull;
      if (decision == null) {
        issues.add(
          ReviewIssue(
            id: 'accessibility:missingAspect:${aspect.name}',
            category: ReviewCategory.accessibility,
            severity: ReviewSeverity.warning,
            reason: 'No engineered accessibility decision recorded for "${aspect.name}"',
            evidence: ReviewEvidence(affectedGraph: 'EngineeringCandidate.accessibility', affectedNodeId: aspect.name),
            recommendation: const ReviewRecommendation(description: 'Run AccessibilityEngineering for this aspect'),
            confidence: Confidence.full,
          ),
        );
        continue;
      }
      // Honesty guard: every current accessibility decision is inherited
      // from Flutter/Material defaults, never custom-built — if a future
      // change silently drops that framing while still claiming the
      // aspect is covered, that would overclaim capability this codebase
      // doesn't have.
      final rationale = decision.rationale.toLowerCase();
      if (!rationale.contains('material') && !rationale.contains('flutter')) {
        issues.add(
          ReviewIssue(
            id: 'accessibility:unverifiedClaim:${aspect.name}',
            category: ReviewCategory.accessibility,
            severity: ReviewSeverity.warning,
            reason: 'Accessibility decision for "${aspect.name}" no longer traces to a real Flutter/Material mechanism',
            evidence: ReviewEvidence(affectedGraph: 'EngineeringCandidate.accessibility', affectedNodeId: aspect.name),
            recommendation: const ReviewRecommendation(description: 'Ground the decision in a real, inspectable implementation'),
            confidence: const Confidence(score: 0.6, reason: 'Rationale-text heuristic, not a guaranteed detector.'),
          ),
        );
      }
    }

    return issues;
  }
}
