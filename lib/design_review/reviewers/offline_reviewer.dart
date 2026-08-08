/// Offline Review — audits offline readiness, network assumptions, cache/
/// conflict strategy, and storage durability consistency across the
/// already-engineered offline/synchronization/persistence decisions
/// (V3 Engineering, V5 Solution Reasoning). Never re-decides the offline
/// posture itself.
library;

import '../../application_engineering/persistence_offline_sync_engineering.dart'
    show ConflictStrategy;
import '../../software_architect/architecture_types.dart' show SyncStrategy;
import '../../software_architect/confidence.dart';
import '../review_context.dart';
import '../review_types.dart';

class OfflineReviewer {
  const OfflineReviewer();

  List<ReviewIssue> review(ReviewContext context) {
    final engineering = context.engineering;
    final issues = <ReviewIssue>[];

    // Conflicting synchronization: a real conflict-resolution policy
    // implies a real sync target, which today never exists (V3: "no
    // server component" — always SyncStrategy.none). If this ever
    // diverges it is a genuine design inconsistency worth catching.
    if (engineering.offline.conflictStrategy != ConflictStrategy.none &&
        engineering.synchronization.strategy == SyncStrategy.none) {
      issues.add(
        ReviewIssue(
          id: 'offline:conflictWithoutSync',
          category: ReviewCategory.offline,
          severity: ReviewSeverity.critical,
          reason:
              'A conflict-resolution strategy is set but synchronization strategy is none — nothing to conflict against',
          evidence: const ReviewEvidence(
            affectedGraph: 'EngineeringCandidate.offline',
            affectedNodeId: 'conflictStrategy',
          ),
          recommendation: const ReviewRecommendation(
            description:
                'Set conflictStrategy to none until a real sync target exists',
          ),
          confidence: Confidence.full,
        ),
      );
    }

    // Storage durability: every persisted entity should have a real
    // storage decision backing it, not merely a placeholder.
    for (final decision in engineering.persistence.entityStorageDecisions) {
      if (decision.decision.trim().isEmpty) {
        issues.add(
          ReviewIssue(
            id: 'offline:noDurabilityDecision:${decision.subjectId}',
            category: ReviewCategory.offline,
            severity: ReviewSeverity.critical,
            reason:
                'Entity "${decision.subjectId}" has no real persistence decision recorded',
            evidence: ReviewEvidence(
              affectedGraph: 'EngineeringCandidate.persistence',
              affectedNodeId: decision.subjectId,
            ),
            recommendation: const ReviewRecommendation(
              description: 'Run PersistenceEngineering for this entity',
            ),
            confidence: Confidence.full,
          ),
        );
      }
    }

    return issues;
  }
}
