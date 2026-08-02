/// Security Review — audits permission/credential/network posture
/// consistency, and (IntegrityReviewer) the completeness of the
/// engineered security record, including a direct regression guard that
/// Kaalka remains the sole, canonical protection mechanism. Neither class
/// makes a single security decision itself, or touches package:kaalka —
/// both only inspect what SecurityPlanner (V2) and SecurityEngineering
/// (V3) already decided.
library;

import '../../application_engineering/accessibility_performance_security_engineering.dart' show SecurityAspect;
import '../../feature_discovery/feature_discovery_engine.dart';
import '../../software_architect/architecture_types.dart' show NetworkMode;
import '../../software_architect/confidence.dart';
import '../review_context.dart';
import '../review_types.dart';

class SecurityReviewer {
  const SecurityReviewer();

  static const Set<String> _networkOrientedCapabilities = {'http', 'ai', 'knowledge'};

  List<ReviewIssue> review(ReviewContext context) {
    final architecture = context.architecture;
    final issues = <ReviewIssue>[];

    final hasNetworkCapability = architecture.capabilities.any(
      (c) => c.resolved && _networkOrientedCapabilities.contains(c.capabilityId),
    );
    if (hasNetworkCapability && architecture.security.networkMode == NetworkMode.none) {
      issues.add(
        ReviewIssue(
          id: 'security:networkModeInconsistent',
          category: ReviewCategory.security,
          severity: ReviewSeverity.critical,
          reason: 'A network-oriented capability is resolved but SecurityDecision.networkMode is none',
          evidence: const ReviewEvidence(affectedGraph: 'ArchitectureCandidate.security', affectedNodeId: 'networkMode'),
          recommendation: const ReviewRecommendation(description: 'Set networkMode to restrictedHttps'),
          confidence: Confidence.full,
        ),
      );
    }

    final hasCredentialCapability = architecture.capabilities.any(
      (c) => c.resolved && FeatureDiscoveryEngine.credentialRequiringCapabilities.contains(c.capabilityId),
    );
    if (architecture.security.requiresCredentialVault && !hasCredentialCapability) {
      issues.add(
        ReviewIssue(
          id: 'security:vaultInconsistent',
          category: ReviewCategory.security,
          severity: ReviewSeverity.critical,
          reason: 'SecurityDecision.requiresCredentialVault is true but no credential-resolving capability is present',
          evidence: const ReviewEvidence(affectedGraph: 'ArchitectureCandidate.security', affectedNodeId: 'requiresCredentialVault'),
          recommendation: const ReviewRecommendation(description: 'Reconcile the vault requirement with the resolved capabilities'),
          confidence: Confidence.full,
        ),
      );
    }

    return issues;
  }
}

class IntegrityReviewer {
  const IntegrityReviewer();

  List<ReviewIssue> review(ReviewContext context) {
    final decisions = context.engineering.security.decisions;
    final issues = <ReviewIssue>[];

    for (final aspect in SecurityAspect.values) {
      final decision = decisions.where((d) => d.subjectId == aspect.name).firstOrNull;
      if (decision == null) {
        issues.add(
          ReviewIssue(
            id: 'integrity:missingAspect:${aspect.name}',
            category: ReviewCategory.integrity,
            severity: ReviewSeverity.critical,
            reason: 'No engineered security decision recorded for "${aspect.name}"',
            evidence: ReviewEvidence(affectedGraph: 'EngineeringCandidate.security', affectedNodeId: aspect.name),
            recommendation: const ReviewRecommendation(description: 'Run SecurityEngineering for this aspect'),
            confidence: Confidence.full,
          ),
        );
      }
    }

    // Regression guard: the Kaalka aspect must always cite package:kaalka
    // as canonical — if this rationale ever changes to describe a second
    // protection mechanism, that is a direct violation of "never duplicate
    // Kaalka" and must fail the review, not slip through silently.
    final kaalkaDecision = decisions.where((d) => d.subjectId == SecurityAspect.kaalka.name).firstOrNull;
    if (kaalkaDecision != null &&
        !(kaalkaDecision.rationale.contains('package:kaalka') && kaalkaDecision.rationale.toLowerCase().contains('canonical'))) {
      issues.add(
        ReviewIssue(
          id: 'integrity:kaalkaNotCanonical',
          category: ReviewCategory.integrity,
          severity: ReviewSeverity.critical,
          reason: 'The Kaalka security decision no longer confirms package:kaalka as the sole canonical protection mechanism',
          evidence: const ReviewEvidence(affectedGraph: 'EngineeringCandidate.security', affectedNodeId: 'kaalka'),
          recommendation: const ReviewRecommendation(description: 'Restore the canonical-Kaalka rationale; never introduce a second protection mechanism'),
          confidence: Confidence.full,
        ),
      );
    }

    return issues;
  }
}
