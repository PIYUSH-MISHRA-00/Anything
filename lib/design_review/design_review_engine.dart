/// Design Review Engine — the top-level Self-Critique & Autonomous Design
/// Review orchestrator: Produce (everything earlier stages already built)
/// -> Review -> Improve -> Review -> Improve -> Approve. No stage
/// bypasses this — AnythingKernel only ever reaches ExperienceSpec
/// conversion through a `session.approved == true` result.
library;

import 'review_approval.dart';
import 'review_context.dart';
import 'review_history.dart';
import 'review_memory.dart';
import 'review_refinement.dart';
import 'review_types.dart';

class DesignReviewEngine {
  final ReviewRefinement _refinement;
  final ReviewApproval _approval;

  const DesignReviewEngine({
    ReviewRefinement refinement = const ReviewRefinement(),
    ReviewApproval approval = const ReviewApproval(),
  }) : _refinement = refinement,
       _approval = approval;

  ({ReviewSession session, bool approved}) review(
    ReviewContext context, {
    ReviewMemory? memory,
    ReviewHistory? history,
  }) {
    final fingerprint = fingerprintOf(context);
    final result = _refinement.refine(context);
    final approved = _approval.isApproved(result);

    final initialIssues = result.iterations.first.issues;
    final finalIssueIds = result.finalIteration.issues.map((i) => i.id).toSet();
    final decisions = initialIssues
        .map(
          (issue) => ReviewDecision(
            issueId: issue.id,
            kind: finalIssueIds.contains(issue.id) ? ReviewDecisionKind.accepted : ReviewDecisionKind.fixed,
            rationale: issue.reason,
            confidence: issue.confidence,
          ),
        )
        .toList();

    final futureImprovements = result.finalIteration.issues
        .where((i) => i.severity != ReviewSeverity.critical)
        .map((i) => i.recommendation.description)
        .toSet()
        .toList();

    final session = ReviewSession(
      sessionId: 'review-${DateTime.now().microsecondsSinceEpoch}',
      fingerprint: fingerprint,
      startedAt: DateTime.now(),
      result: result,
      decisions: decisions,
      futureImprovements: futureImprovements,
    );

    memory?.record(session);
    history?.record(session);

    return (session: session, approved: approved);
  }

  /// A deterministic structural fingerprint — entity ids, capability ids,
  /// and screen count, sorted for stability — never a domain name. Two
  /// requests producing this same fingerprint within one Kernel lifetime
  /// share ReviewMemory.
  String fingerprintOf(ReviewContext context) {
    final entityIds = context.architecture.entities.map((e) => e.entityId).toList()..sort();
    final capabilityIds = context.architecture.capabilities.map((c) => c.capabilityId).toList()..sort();
    return '${entityIds.join(',')}|${capabilityIds.join(',')}|${context.architecture.navigation.screenIds.length}';
  }
}
