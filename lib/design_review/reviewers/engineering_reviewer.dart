/// Engineering Review — inspects the SELECTED EngineeringCandidate for
/// concerns V3's own EngineeringReview does not already cover (that review
/// ran during Engineering itself, so dangling bindings/behavior
/// inconsistencies referencing undeclared events are already resolved by
/// the time Design Review runs): dead, unused, duplicate, inconsistent,
/// and unsafe engineering.
library;

import '../../application_engineering/engineering_types.dart';
import '../../application_engineering/persistence_offline_sync_engineering.dart'
    show OfflineStrategy;
import '../../software_architect/architecture_types.dart' show SyncStrategy;
import '../../software_architect/confidence.dart';
import '../review_context.dart';
import '../review_types.dart';

class EngineeringReviewer {
  const EngineeringReviewer();

  List<ReviewIssue> review(ReviewContext context) {
    final engineering = context.engineering;
    final issues = <ReviewIssue>[];

    // Dead: a behavior plan with zero actions at all.
    for (final behavior in engineering.behaviors) {
      if (behavior.eventGraph.actions.isEmpty) {
        issues.add(
          ReviewIssue(
            id: 'engineering:dead:${behavior.eventGraph.entityId}',
            category: ReviewCategory.engineering,
            severity: ReviewSeverity.warning,
            reason:
                'Entity "${behavior.eventGraph.entityId}" has an engineered behavior plan with zero actions',
            evidence: ReviewEvidence(
              affectedGraph: 'EngineeringCandidate.behaviors',
              affectedNodeId: behavior.eventGraph.entityId,
            ),
            recommendation: const ReviewRecommendation(
              description: 'Confirm this entity is meant to be read-only',
            ),
            confidence: Confidence.full,
          ),
        );
      }
    }

    // Unused: a viewToState binding to a form_<fieldId> id with no
    // matching field anywhere in the architecture. BindingEngineering
    // also emits a second, differently-shaped viewToState edge for search
    // (entityId -> 'searchTerm', no field involved at all) — only the
    // field-shaped bindings (targeting form_<fieldId>) are checked here.
    final knownFieldIds = context.architecture.fields
        .map((f) => '${f.entityId}.${f.fieldId}')
        .toSet();
    for (final edge in engineering.bindingGraph.edgesOfKind(
      BindingKind.viewToState,
    )) {
      if (!edge.toId.startsWith('form_')) continue;
      if (!knownFieldIds.contains(edge.fromId)) {
        issues.add(
          ReviewIssue(
            id: 'engineering:unused:${edge.fromId}->${edge.toId}',
            category: ReviewCategory.engineering,
            severity: ReviewSeverity.warning,
            reason:
                'Binding "${edge.fromId} -> ${edge.toId}" references a field not in this architecture',
            evidence: ReviewEvidence(
              affectedGraph: 'EngineeringCandidate.bindingGraph',
              affectedNodeId: '${edge.fromId}->${edge.toId}',
            ),
            recommendation: const ReviewRecommendation(
              description: 'Drop the stale binding',
              autoApplicable: true,
            ),
            confidence: Confidence.full,
          ),
        );
      }
    }

    // Duplicate: two identical binding edges.
    final seen = <String>{};
    for (final edge in engineering.bindingGraph.edges) {
      final key = '${edge.kind.name}|${edge.fromId}|${edge.toId}';
      if (!seen.add(key)) {
        issues.add(
          ReviewIssue(
            id: 'engineering:duplicate:${edge.fromId}->${edge.toId}:${engineering.bindingGraph.edges.indexOf(edge)}',
            category: ReviewCategory.engineering,
            severity: ReviewSeverity.warning,
            reason:
                'Duplicate binding edge "${edge.fromId} -> ${edge.toId}" (${edge.kind.name})',
            evidence: ReviewEvidence(
              affectedGraph: 'EngineeringCandidate.bindingGraph',
              affectedNodeId: '${edge.fromId}->${edge.toId}',
            ),
            recommendation: const ReviewRecommendation(
              description: 'Remove the duplicate binding edge',
              autoApplicable: true,
            ),
            confidence: Confidence.full,
          ),
        );
      }
    }

    // Inconsistent: an offlineFirst posture paired with a synchronization
    // strategy that assumes ongoing network use.
    if (engineering.offline.strategy == OfflineStrategy.offlineFirst &&
        engineering.synchronization.strategy != SyncStrategy.none) {
      issues.add(
        ReviewIssue(
          id: 'engineering:inconsistent:offline-sync',
          category: ReviewCategory.engineering,
          severity: ReviewSeverity.critical,
          reason:
              'Offline strategy is offlineFirst but synchronization strategy is ${engineering.synchronization.strategy.name}, not none',
          evidence: const ReviewEvidence(
            affectedGraph: 'EngineeringCandidate.offline/synchronization',
            affectedNodeId: 'offline-sync',
          ),
          recommendation: const ReviewRecommendation(
            description:
                'Set synchronization strategy to none for an offlineFirst posture',
          ),
          confidence: Confidence.full,
        ),
      );
    }

    // Unsafe: a persistence decision naming a storage kind that
    // disagrees with the architecture's own decision for that entity.
    final storageByEntity = {
      for (final e in context.architecture.entities) e.entityId: e.storage,
    };
    for (final decision in engineering.persistence.entityStorageDecisions) {
      final expected = storageByEntity[decision.subjectId];
      if (expected != null && !decision.decision.contains(expected.name)) {
        issues.add(
          ReviewIssue(
            id: 'engineering:unsafe:${decision.subjectId}',
            category: ReviewCategory.engineering,
            severity: ReviewSeverity.critical,
            reason:
                'Persistence decision for "${decision.subjectId}" disagrees with its architecture storage kind (${expected.name})',
            evidence: ReviewEvidence(
              affectedGraph: 'EngineeringCandidate.persistence',
              affectedNodeId: decision.subjectId,
            ),
            recommendation: const ReviewRecommendation(
              description:
                  'Reconcile the engineering and architecture storage decisions',
            ),
            confidence: Confidence.full,
          ),
        );
      }
    }

    return issues;
  }
}
