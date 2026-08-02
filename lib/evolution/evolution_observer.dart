/// EvolutionObserver — Autonomous Observation. Continuously detects real,
/// structural gaps between what a design currently does and what it could
/// do next: missing capabilities, workflows, navigation, search,
/// filtering, accessibility, offline support, synchronization,
/// performance, and maintainability improvements.
///
/// Never a template: every detector here reuses a real, already-computed
/// signal rather than inventing new heuristics —
///  - missing capability/workflow: a real FeatureGraph (V4) node Feature
///    Discovery already found at `optional`/`future`/`experimental`
///    priority but that never made it into the approved architecture;
///  - missing navigation/search/filtering: real InteractionDecision
///    (V2 ASAE) flags already computed for each entity;
///  - missing offline/synchronization: the real OfflineDecision/
///    SynchronizationDecision (V2 ASAE) posture already chosen;
///  - missing accessibility/performance/maintainability: the real,
///    non-critical findings Design Review (V6/SCARE) already surfaced for
///    this exact design — reused directly, never re-derived.
library;

import '../design_review/review_types.dart' show ReviewCategory, ReviewSeverity;
import '../software_architect/architecture_types.dart' show OfflineCapability, SyncStrategy;
import '../software_architect/confidence.dart';
import '../feature_discovery/feature_types.dart' show FeaturePriority;
import 'evolution_context.dart';
import 'evolution_opportunity.dart';
import 'evolution_types.dart';

class EvolutionObserver {
  const EvolutionObserver();

  /// The minimum field count an entity needs before "no search" is worth
  /// surfacing as an opportunity — a documented heuristic, not a reused
  /// system constant (mirrors ArchitectureReviewer's own documented
  /// over-engineered-field-count heuristic).
  static const int _searchWorthwhileFieldCount = 4;

  List<EvolutionOpportunity> observe(EvolutionContext context) {
    return [
      ..._deferredFeatureOpportunities(context),
      ..._navigationOpportunities(context),
      ..._searchAndFilterOpportunities(context),
      ..._postureOpportunities(context),
      ..._reviewSignalOpportunities(context),
    ];
  }

  /// Every FeatureGraph node Feature Discovery classified as
  /// optional/future/experimental represents a real, already-detected
  /// capability or workflow this design chose not to build yet — the
  /// most direct, non-fabricated source of "what could this support
  /// next?".
  List<EvolutionOpportunity> _deferredFeatureOpportunities(EvolutionContext context) {
    final opportunities = <EvolutionOpportunity>[];
    for (final node in context.featureGraph.nodes) {
      if (node.priority == FeaturePriority.mandatory || node.priority == FeaturePriority.recommended) continue;

      final isCapability = node.category.name == 'capability';
      opportunities.add(
        EvolutionOpportunity(
          id: 'evolution:${isCapability ? 'missingCapability' : 'missingWorkflow'}:${node.id}',
          category: isCapability
              ? EvolutionOpportunityCategory.missingCapability
              : EvolutionOpportunityCategory.missingWorkflow,
          description: '${node.name} was discovered but deferred (priority: ${node.priority.name})',
          reason: EvolutionReason(
            summary: node.explanation.whyOptional ?? node.explanation.whyDiscovered,
            evidence: EvolutionEvidence(
              affectedGraph: 'FeatureGraph',
              affectedNodeId: node.id,
              sourceFeatureId: node.id,
            ),
            confidence: node.decision.confidence,
          ),
        ),
      );
    }
    return opportunities;
  }

  /// An entity with real interaction decisions (create/read) but no
  /// blueprint view of any kind — a genuinely missing entry point, not a
  /// defect (SCARE's NavigationReviewer already guards reachability of
  /// views that DO exist; this looks for entities with none at all).
  List<EvolutionOpportunity> _navigationOpportunities(EvolutionContext context) {
    final opportunities = <EvolutionOpportunity>[];
    final entitiesWithViews = context.blueprint.views.map((v) => v.sourceEntityId).whereType<String>().toSet();

    for (final interaction in context.architecture.interactions) {
      if (!interaction.canRead) continue;
      if (entitiesWithViews.contains(interaction.entityId)) continue;

      opportunities.add(
        EvolutionOpportunity(
          id: 'evolution:missingNavigation:${interaction.entityId}',
          category: EvolutionOpportunityCategory.missingNavigation,
          description: '"${interaction.entityId}" is readable but has no view of any kind',
          reason: EvolutionReason(
            summary: 'ArchitectureCandidate.interactions allows reading this entity, but no '
                'blueprint view exposes it to the user',
            evidence: EvolutionEvidence(affectedGraph: 'ArchitectureCandidate.interactions', affectedNodeId: interaction.entityId),
            confidence: Confidence.full,
          ),
        ),
      );
    }
    return opportunities;
  }

  /// Entities with enough fields that search/filtering would genuinely
  /// help, but the real InteractionDecision doesn't support it yet.
  List<EvolutionOpportunity> _searchAndFilterOpportunities(EvolutionContext context) {
    final opportunities = <EvolutionOpportunity>[];
    final fieldCountByEntity = <String, int>{};
    for (final field in context.architecture.fields) {
      fieldCountByEntity[field.entityId] = (fieldCountByEntity[field.entityId] ?? 0) + 1;
    }
    final referenceFieldsByEntity = <String, bool>{};
    for (final rel in context.architecture.relationships) {
      referenceFieldsByEntity[rel.fromEntityId] = true;
    }

    for (final interaction in context.architecture.interactions) {
      if (!interaction.canRead) continue;
      final fieldCount = fieldCountByEntity[interaction.entityId] ?? 0;

      if (!interaction.supportsSearch && fieldCount >= _searchWorthwhileFieldCount) {
        opportunities.add(
          EvolutionOpportunity(
            id: 'evolution:missingSearch:${interaction.entityId}',
            category: EvolutionOpportunityCategory.missingSearch,
            description: '"${interaction.entityId}" has $fieldCount fields but no search',
            reason: EvolutionReason(
              summary: 'Entities with $_searchWorthwhileFieldCount+ fields are structurally likely to '
                  'benefit from search once records accumulate',
              evidence: EvolutionEvidence(affectedGraph: 'ArchitectureCandidate.interactions', affectedNodeId: interaction.entityId),
              confidence: const Confidence(score: 0.6, reason: 'Field-count heuristic, not a guaranteed need.'),
            ),
          ),
        );
      }

      if (!interaction.supportsFilter && (referenceFieldsByEntity[interaction.entityId] ?? false)) {
        opportunities.add(
          EvolutionOpportunity(
            id: 'evolution:missingFiltering:${interaction.entityId}',
            category: EvolutionOpportunityCategory.missingFiltering,
            description: '"${interaction.entityId}" has reference fields but no filtering',
            reason: EvolutionReason(
              summary: 'Entities with relationships are structurally likely to benefit from '
                  'filtering by the related entity',
              evidence: EvolutionEvidence(affectedGraph: 'ArchitectureCandidate.interactions', affectedNodeId: interaction.entityId),
              confidence: const Confidence(score: 0.6, reason: 'Relationship-presence heuristic, not a guaranteed need.'),
            ),
          ),
        );
      }
    }
    return opportunities;
  }

  /// The architecture's own real offline/synchronization posture
  /// decisions — never re-derived, only read.
  List<EvolutionOpportunity> _postureOpportunities(EvolutionContext context) {
    final opportunities = <EvolutionOpportunity>[];
    final offline = context.architecture.offline;
    final sync = context.architecture.synchronization;

    if (offline.capability != OfflineCapability.fullyOffline) {
      opportunities.add(
        EvolutionOpportunity(
          id: 'evolution:missingOffline:${offline.decision.id}',
          category: EvolutionOpportunityCategory.missingOffline,
          description: 'Offline posture is ${offline.capability.name}, not fullyOffline',
          reason: EvolutionReason(
            summary: offline.decision.rationale,
            evidence: EvolutionEvidence(affectedGraph: 'ArchitectureCandidate.offline', affectedNodeId: offline.decision.id),
            confidence: offline.decision.confidence,
          ),
        ),
      );
    }

    if (sync.strategy == SyncStrategy.none && offline.capability != OfflineCapability.onlineRequired) {
      opportunities.add(
        EvolutionOpportunity(
          id: 'evolution:missingSynchronization:${sync.decision.id}',
          category: EvolutionOpportunityCategory.missingSynchronization,
          description: 'Offline data exists but synchronization strategy is none',
          reason: EvolutionReason(
            summary: sync.decision.rationale,
            evidence: EvolutionEvidence(affectedGraph: 'ArchitectureCandidate.synchronization', affectedNodeId: sync.decision.id),
            confidence: sync.decision.confidence,
          ),
        ),
      );
    }
    return opportunities;
  }

  /// Reuses Design Review's (V6/SCARE) own non-critical findings directly
  /// — accessibility/performance/maintainability improvements SCARE
  /// already identified but that didn't block approval. This is the
  /// literal "reuse SCARE, don't duplicate review logic" directive: no
  /// second accessibility/performance checker is written here.
  List<EvolutionOpportunity> _reviewSignalOpportunities(EvolutionContext context) {
    const categoryMap = {
      ReviewCategory.accessibility: EvolutionOpportunityCategory.missingAccessibility,
      ReviewCategory.performance: EvolutionOpportunityCategory.missingPerformance,
      ReviewCategory.maintainability: EvolutionOpportunityCategory.missingMaintainability,
    };

    final opportunities = <EvolutionOpportunity>[];
    for (final issue in context.reviewSession.result.finalIteration.issues) {
      if (issue.severity == ReviewSeverity.critical) continue;
      final category = categoryMap[issue.category];
      if (category == null) continue;

      opportunities.add(
        EvolutionOpportunity(
          id: 'evolution:${category.name}:${issue.id}',
          category: category,
          description: issue.recommendation.description,
          reason: EvolutionReason(
            summary: issue.reason,
            evidence: EvolutionEvidence(
              affectedGraph: issue.evidence.affectedGraph,
              affectedNodeId: issue.evidence.affectedNodeId,
              sourceReviewIssueId: issue.id,
            ),
            confidence: issue.confidence,
          ),
        ),
      );
    }
    return opportunities;
  }
}
