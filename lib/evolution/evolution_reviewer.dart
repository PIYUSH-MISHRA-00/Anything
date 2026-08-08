/// EvolutionReviewer — every evolution candidate is checked against real,
/// already-computed structural evidence before it becomes a proposal.
///
/// Reuses SCARE directly rather than duplicating review logic: candidates
/// sourced from a Design Review finding (see EvolutionObserver) are
/// accepted only because that finding is already a real, vetted
/// ReviewIssue from `context.reviewSession` — this reviewer never
/// re-invokes DesignReviewEngine or re-implements its checks. Candidates
/// sourced from FeatureGraph/architecture data are verified the same way
/// ConsistencyReviewer (SCARE) verifies mandatory features: the
/// referenced feature/entity must still be real in the final design.
library;

import 'evolution_candidate.dart';
import 'evolution_context.dart';
import 'evolution_types.dart';

class EvolutionReviewer {
  const EvolutionReviewer();

  EvolutionDecision review(
    EvolutionCandidate candidate,
    EvolutionContext context,
  ) {
    final evidence = candidate.opportunity.reason.evidence;

    if (evidence.sourceReviewIssueId != null) {
      final stillReal = context.reviewSession.result.finalIteration.issues.any(
        (issue) => issue.id == evidence.sourceReviewIssueId,
      );
      return EvolutionDecision(
        subjectId: candidate.id,
        kind: stillReal
            ? EvolutionDecisionKind.accepted
            : EvolutionDecisionKind.rejected,
        rationale: stillReal
            ? 'Sourced from a real, already-vetted Design Review (SCARE) finding for this design.'
            : 'The Design Review finding this candidate was based on is no longer present.',
        confidence: candidate.opportunity.reason.confidence,
      );
    }

    if (evidence.sourceFeatureId != null) {
      final node = context.featureGraph.nodeById(evidence.sourceFeatureId!);
      if (node == null) {
        return EvolutionDecision(
          subjectId: candidate.id,
          kind: EvolutionDecisionKind.rejected,
          rationale:
              'The FeatureGraph node this candidate was based on no longer exists.',
          confidence: candidate.opportunity.reason.confidence,
        );
      }
      final entityRef = node.candidate.sourceNodeIds
          .map(
            (id) => id.startsWith('entity:')
                ? id.replaceFirst('entity:', '')
                : null,
          )
          .whereType<String>()
          .firstOrNull;
      final entityStillReal =
          entityRef == null ||
          context.architecture.entities.any((e) => e.entityId == entityRef);

      return EvolutionDecision(
        subjectId: candidate.id,
        kind: entityStillReal
            ? EvolutionDecisionKind.accepted
            : EvolutionDecisionKind.rejected,
        rationale: entityStillReal
            ? 'Sourced from a real FeatureGraph node whose referenced entity is still present.'
            : 'References entity "$entityRef", which is missing from the final architecture.',
        confidence: candidate.opportunity.reason.confidence,
      );
    }

    // Offline/synchronization opportunities: sourced live from the
    // architecture's own posture decisions, not from any entity —
    // verified against the current decision id, never an interaction.
    final postureCategories = {
      EvolutionOpportunityCategory.missingOffline,
      EvolutionOpportunityCategory.missingSynchronization,
    };
    if (postureCategories.contains(candidate.opportunity.category)) {
      final currentDecisionIds = {
        context.architecture.offline.decision.id,
        context.architecture.synchronization.decision.id,
      };
      final postureStillReal = currentDecisionIds.contains(
        evidence.affectedNodeId,
      );
      return EvolutionDecision(
        subjectId: candidate.id,
        kind: postureStillReal
            ? EvolutionDecisionKind.accepted
            : EvolutionDecisionKind.rejected,
        rationale: postureStillReal
            ? 'Sourced from a real, current ArchitectureCandidate offline/synchronization posture decision.'
            : 'References posture decision "${evidence.affectedNodeId}", which no longer matches the current architecture.',
        confidence: candidate.opportunity.reason.confidence,
      );
    }

    // Navigation/search/filtering opportunities: sourced live from the
    // current architecture's own interaction decisions.
    final entityId = evidence.affectedNodeId;
    final interactionStillReal = context.architecture.interactions.any(
      (i) => i.entityId == entityId,
    );
    return EvolutionDecision(
      subjectId: candidate.id,
      kind: interactionStillReal
          ? EvolutionDecisionKind.accepted
          : EvolutionDecisionKind.rejected,
      rationale: interactionStillReal
          ? 'Sourced from a real, current ArchitectureCandidate interaction decision.'
          : 'References entity "$entityId", whose interaction decision is missing.',
      confidence: candidate.opportunity.reason.confidence,
    );
  }
}
