/// Consistency Review — the one check that spans every earlier milestone
/// at once: does the FINAL design actually deliver every *mandatory*
/// feature Feature Discovery (V4) found? No prior stage can answer this,
/// since each only ever saw its own slice (FeatureGraph alone, or
/// ArchitectureCandidate alone, or EngineeringCandidate alone).
library;

import '../../feature_discovery/feature_types.dart' show FeaturePriority;
import '../../software_architect/confidence.dart';
import '../review_context.dart';
import '../review_types.dart';

class ConsistencyReviewer {
  const ConsistencyReviewer();

  List<ReviewIssue> review(ReviewContext context) {
    final issues = <ReviewIssue>[];
    final entityIds = context.architecture.entities
        .map((e) => e.entityId)
        .toSet();
    final capabilityIds = context.architecture.capabilities
        .map((c) => c.capabilityId)
        .toSet();

    for (final feature in context.featureGraph.nodes) {
      if (feature.priority != FeaturePriority.mandatory) continue;

      String? missingReferenceId;
      if (feature.id.startsWith('feature:persistence:') ||
          feature.id.startsWith('feature:data:')) {
        final entityId = feature.candidate.sourceNodeIds
            .map(
              (id) =>
                  id.replaceFirst('entity:', '').replaceFirst('storage:', ''),
            )
            .firstOrNull;
        if (entityId != null && !entityIds.contains(entityId)) {
          missingReferenceId = entityId;
        }
      } else if (feature.id.startsWith('feature:capability:')) {
        final capabilityId = feature.id.replaceFirst('feature:capability:', '');
        if (!capabilityIds.contains(capabilityId)) {
          missingReferenceId = capabilityId;
        }
      }

      if (missingReferenceId != null) {
        issues.add(
          ReviewIssue(
            id: 'consistency:missingMandatoryFeature:${feature.id}',
            category: ReviewCategory.consistency,
            severity: ReviewSeverity.critical,
            reason:
                'Mandatory feature "${feature.name}" references "$missingReferenceId", which is missing from the final architecture',
            evidence: ReviewEvidence(
              affectedGraph: 'FeatureGraph',
              affectedNodeId: feature.id,
            ),
            recommendation: const ReviewRecommendation(
              description:
                  'Reconcile the final architecture with Feature Discovery\'s findings',
            ),
            confidence: Confidence.full,
          ),
        );
      }
    }

    return issues;
  }
}
