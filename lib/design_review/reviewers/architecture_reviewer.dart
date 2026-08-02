/// Architecture Review — inspects the SELECTED ArchitectureCandidate for
/// concerns V2's SelfCritic does not already cover (SelfCritic ran during
/// Architecture Exploration/V5 refinement, so duplicate names/dangling
/// relationships/empty entities are already resolved by the time Design
/// Review runs): missing, unused, contradictory, circular, dead, and
/// over/under-engineered architecture.
library;

import '../../software_architect/architecture_types.dart';
import '../../software_architect/confidence.dart';
import '../review_context.dart';
import '../review_types.dart';

class ArchitectureReviewer {
  const ArchitectureReviewer();

  /// Heuristic threshold, not a reused system constant (unlike
  /// RuntimeSecurityLimits) — no generated-blueprint validator bounds
  /// field count today. Documented explicitly as a v6 default, mirroring
  /// V2's 0.4/0.6 confidence thresholds ("a default, not a calibrated
  /// statistical cutoff").
  static const int _overEngineeredFieldCountThreshold = 15;

  List<ReviewIssue> review(ReviewContext context) {
    final architecture = context.architecture;
    final issues = <ReviewIssue>[];
    final entityIds = architecture.entities.map((e) => e.entityId).toSet();

    // Missing: a relationship referencing an entity not in the candidate.
    for (final rel in architecture.relationships) {
      if (!entityIds.contains(rel.toEntityId)) {
        issues.add(
          ReviewIssue(
            id: 'architecture:missing:${rel.fromEntityId}.${rel.fieldId}',
            category: ReviewCategory.architecture,
            severity: ReviewSeverity.critical,
            reason: 'Relationship targets entity "${rel.toEntityId}" which is not in this architecture',
            evidence: ReviewEvidence(affectedGraph: 'ArchitectureCandidate.relationships', affectedNodeId: '${rel.fromEntityId}.${rel.fieldId}'),
            recommendation: const ReviewRecommendation(description: 'Drop the dangling relationship', autoApplicable: false),
            confidence: Confidence.full,
          ),
        );
      }
    }

    // Duplicate: two entities sharing a name (SelfCritic already fixes
    // this upstream — real, defensive, dormant against approved candidates).
    final seenNames = <String, String>{};
    for (final entity in architecture.entities) {
      final existing = seenNames[entity.name];
      if (existing != null) {
        issues.add(
          ReviewIssue(
            id: 'architecture:duplicate:${entity.entityId}',
            category: ReviewCategory.architecture,
            severity: ReviewSeverity.critical,
            reason: 'Entity "${entity.name}" duplicates $existing',
            evidence: ReviewEvidence(affectedGraph: 'ArchitectureCandidate.entities', affectedNodeId: entity.entityId),
            recommendation: const ReviewRecommendation(description: 'Merge or rename the duplicate entity', autoApplicable: false),
            confidence: Confidence.full,
          ),
        );
      } else {
        seenNames[entity.name] = entity.entityId;
      }
    }

    // Unused: an entity with no interaction plan at all.
    final interactedEntities = architecture.interactions.map((i) => i.entityId).toSet();
    for (final entity in architecture.entities) {
      if (!interactedEntities.contains(entity.entityId)) {
        issues.add(
          ReviewIssue(
            id: 'architecture:unused:${entity.entityId}',
            category: ReviewCategory.architecture,
            severity: ReviewSeverity.warning,
            reason: 'Entity "${entity.name}" has no interaction plan — nothing ever reads or writes it',
            evidence: ReviewEvidence(affectedGraph: 'ArchitectureCandidate.entities', affectedNodeId: entity.entityId),
            recommendation: const ReviewRecommendation(description: 'Confirm this entity is intentional, or remove it'),
            confidence: Confidence.full,
          ),
        );
      }
    }

    // Contradictory: a "restrict" delete policy pointing at a memory-only
    // (transient) entity — restrict cannot be enforced on data that was
    // never persisted in the first place.
    final storageByEntity = {for (final e in architecture.entities) e.entityId: e.storage};
    for (final rel in architecture.relationships) {
      if (rel.deletePolicy == RelationshipDeletePolicy.restrict && storageByEntity[rel.toEntityId] == StorageKind.memory) {
        issues.add(
          ReviewIssue(
            id: 'architecture:contradictory:${rel.fromEntityId}.${rel.fieldId}',
            category: ReviewCategory.architecture,
            severity: ReviewSeverity.critical,
            reason: '"restrict" delete policy targets "${rel.toEntityId}", which is transient (memory) storage',
            evidence: ReviewEvidence(affectedGraph: 'ArchitectureCandidate.relationships', affectedNodeId: '${rel.fromEntityId}.${rel.fieldId}'),
            recommendation: const ReviewRecommendation(description: 'Use setNull/cascade for a transient target instead of restrict'),
            confidence: Confidence.full,
          ),
        );
      }
    }

    // Circular: a cycle among entity relationships.
    for (final cycleEntityId in _findRelationshipCycle(architecture.relationships)) {
      issues.add(
        ReviewIssue(
          id: 'architecture:circular:$cycleEntityId',
          category: ReviewCategory.architecture,
          severity: ReviewSeverity.warning,
          reason: 'Entity "$cycleEntityId" participates in a relationship cycle',
          evidence: ReviewEvidence(affectedGraph: 'ArchitectureCandidate.relationships', affectedNodeId: cycleEntityId),
          recommendation: const ReviewRecommendation(description: 'Confirm the cycle is intentional (e.g. a self-referencing tree)'),
          confidence: const Confidence(score: 0.7, reason: 'Some relationship cycles are legitimate; flagged for review, not assumed wrong.'),
        ),
      );
    }

    // Dead: a permission tied to a capability that isn't actually in this
    // architecture — stale, safe to drop.
    final capabilityIds = architecture.capabilities.map((c) => c.capabilityId).toSet();
    for (final permission in architecture.permissions) {
      if (!capabilityIds.contains(permission.requiredByCapabilityId)) {
        issues.add(
          ReviewIssue(
            id: 'architecture:dead:${permission.permission}',
            category: ReviewCategory.architecture,
            severity: ReviewSeverity.warning,
            reason: 'Permission "${permission.permission}" is tied to a capability not present in this architecture',
            evidence: ReviewEvidence(
              affectedGraph: 'ArchitectureCandidate.permissions',
              affectedNodeId: permission.permission,
              affectedCapabilityId: permission.requiredByCapabilityId,
            ),
            recommendation: const ReviewRecommendation(description: 'Drop the orphaned permission', autoApplicable: true),
            confidence: Confidence.full,
          ),
        );
      }
    }

    // Over/under-engineered.
    for (final entity in architecture.entities) {
      if (entity.fieldCount > _overEngineeredFieldCountThreshold) {
        issues.add(
          ReviewIssue(
            id: 'architecture:overEngineered:${entity.entityId}',
            category: ReviewCategory.architecture,
            severity: ReviewSeverity.info,
            reason: 'Entity "${entity.name}" has ${entity.fieldCount} fields — consider splitting it',
            evidence: ReviewEvidence(affectedGraph: 'ArchitectureCandidate.entities', affectedNodeId: entity.entityId),
            recommendation: const ReviewRecommendation(description: 'Consider decomposing into related entities'),
            confidence: const Confidence(score: 0.5, reason: 'A heuristic threshold, not a calibrated statistical cutoff.'),
          ),
        );
      }
    }

    return issues;
  }

  /// Real cycle detection via DFS over the relationship graph — returns
  /// the entity ids that participate in at least one cycle.
  Set<String> _findRelationshipCycle(List<RelationshipDecision> relationships) {
    final edges = <String, List<String>>{};
    for (final rel in relationships) {
      edges.putIfAbsent(rel.fromEntityId, () => []).add(rel.toEntityId);
    }

    final visiting = <String>{};
    final visited = <String>{};
    final inCycle = <String>{};

    void visit(String node, List<String> path) {
      if (visited.contains(node)) return;
      if (visiting.contains(node)) {
        final cycleStart = path.indexOf(node);
        inCycle.addAll(path.sublist(cycleStart));
        return;
      }
      visiting.add(node);
      for (final next in edges[node] ?? const <String>[]) {
        visit(next, [...path, node]);
      }
      visiting.remove(node);
      visited.add(node);
    }

    for (final node in edges.keys) {
      visit(node, []);
    }
    return inCycle;
  }
}
