/// Capability Review — inspects declared-vs-resolved-vs-permission
/// consistency across the architecture's capability decisions. Never
/// decides capability resolution itself (that remains CapabilityPlanner's
/// job, V2) — only audits the result for completeness.
library;

import '../../feature_discovery/feature_discovery_engine.dart';
import '../../software_architect/confidence.dart';
import '../review_context.dart';
import '../review_types.dart';

class CapabilityReviewer {
  const CapabilityReviewer();

  List<ReviewIssue> review(ReviewContext context) {
    final architecture = context.architecture;
    final issues = <ReviewIssue>[];

    // Orphaned declaration: required by the blueprint but never resolved
    // into an architecture-level CapabilityDecision.
    final decidedIds = architecture.capabilities
        .map((c) => c.capabilityId)
        .toSet();
    for (final capabilityId in context.blueprint.requiredCapabilities) {
      if (!decidedIds.contains(capabilityId)) {
        issues.add(
          ReviewIssue(
            id: 'capability:orphanDeclaration:$capabilityId',
            category: ReviewCategory.capability,
            severity: ReviewSeverity.critical,
            reason:
                'Blueprint requires capability "$capabilityId" but no architecture decision resolved it',
            evidence: ReviewEvidence(
              affectedGraph: 'AppBlueprint.requiredCapabilities',
              affectedNodeId: capabilityId,
              affectedCapabilityId: capabilityId,
            ),
            recommendation: const ReviewRecommendation(
              description: 'Re-run capability resolution for this id',
            ),
            confidence: Confidence.full,
          ),
        );
      }
    }

    // Missing required permission: a resolved, permission-requiring
    // capability with no corresponding PermissionDecision — a real safety
    // gap, since the capability would be invoked without a declared
    // platform permission.
    final permittedCapabilityIds = architecture.permissions
        .map((p) => p.requiredByCapabilityId)
        .toSet();
    for (final capability in architecture.capabilities) {
      if (!capability.resolved) continue;
      if (!FeatureDiscoveryEngine.permissionRequiringCapabilities.contains(
        capability.capabilityId,
      )) {
        continue;
      }
      if (!permittedCapabilityIds.contains(capability.capabilityId)) {
        issues.add(
          ReviewIssue(
            id: 'capability:missingPermission:${capability.capabilityId}',
            category: ReviewCategory.capability,
            severity: ReviewSeverity.critical,
            reason:
                'Capability "${capability.capabilityId}" requires a platform permission but none was declared',
            evidence: ReviewEvidence(
              affectedGraph: 'ArchitectureCandidate.capabilities',
              affectedNodeId: capability.capabilityId,
              affectedCapabilityId: capability.capabilityId,
            ),
            recommendation: const ReviewRecommendation(
              description: 'Add the missing PermissionDecision',
            ),
            confidence: Confidence.full,
          ),
        );
      }
    }

    // Unresolved: honestly reported, not fabricated as working — informational.
    for (final capability in architecture.capabilities) {
      if (!capability.resolved) {
        issues.add(
          ReviewIssue(
            id: 'capability:unresolved:${capability.capabilityId}',
            category: ReviewCategory.capability,
            severity: ReviewSeverity.info,
            reason:
                'Capability "${capability.capabilityId}" is requested but not implemented in this codebase',
            evidence: ReviewEvidence(
              affectedGraph: 'ArchitectureCandidate.capabilities',
              affectedNodeId: capability.capabilityId,
              affectedCapabilityId: capability.capabilityId,
            ),
            recommendation: const ReviewRecommendation(
              description:
                  'Remove the capability or wait for it to be implemented',
            ),
            confidence: const Confidence(
              score: 0.0,
              reason: 'No implementation exists for this capability.',
            ),
          ),
        );
      }
    }

    return issues;
  }
}
