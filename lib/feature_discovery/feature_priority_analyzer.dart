/// Feature Priority Analyzer — assigns a justified FeaturePriority +
/// Confidence to each FeatureCandidate. Every assignment traces to a real
/// structural signal, never a fixed guess.
library;

import '../software_architect/confidence.dart';
import '../software_architect/requirement_graph.dart';
import 'feature_types.dart';

class FeaturePriorityAnalyzer {
  const FeaturePriorityAnalyzer();

  /// Capabilities this codebase actually implements today — see
  /// docs/security/CAPABILITY_SECURITY_MATRIX.md. A request for anything
  /// else is honestly experimental, mirroring V2's CapabilityPlanner.
  static const Set<String> knownImplementedCapabilities = {
    'clock',
    'notifications',
    'http',
    'ai',
    'knowledge',
    'file',
  };

  ({FeaturePriority priority, FeatureDecision decision}) analyze(
    FeatureCandidate candidate, {
    required RequirementGraph requirements,
  }) {
    final (priority, confidence) = switch (candidate.category) {
      FeatureCategory.data ||
      FeatureCategory.persistence ||
      FeatureCategory.navigation ||
      FeatureCategory.validation ||
      FeatureCategory.state => (FeaturePriority.mandatory, Confidence.full),
      FeatureCategory.relational ||
      FeatureCategory.search ||
      FeatureCategory.indexing ||
      FeatureCategory.reporting => (
        FeaturePriority.recommended,
        const Confidence(score: 0.8, reason: 'Structural signal present, but not explicitly requested by name.'),
      ),
      FeatureCategory.capability => _capabilityPriority(candidate, requirements),
      FeatureCategory.permission => (
        FeaturePriority.mandatory,
        const Confidence(score: 0.9, reason: 'A permission-requiring capability was resolved without one.'),
      ),
      FeatureCategory.offline => _offlinePriority(candidate),
      FeatureCategory.security => _securityPriority(candidate),
    };

    final decision = FeatureDecision(
      id: 'priority:${candidate.id}',
      category: candidate.category,
      subjectId: candidate.id,
      decision: '${candidate.name}: ${priority.name}',
      rationale: confidence.reason,
      confidence: confidence,
    );
    return (priority: priority, decision: decision);
  }

  (FeaturePriority, Confidence) _capabilityPriority(FeatureCandidate candidate, RequirementGraph requirements) {
    final capId = candidate.id.replaceFirst('feature:capability:', '');
    if (!knownImplementedCapabilities.contains(capId)) {
      return (
        FeaturePriority.experimental,
        Confidence(
          score: 0.0,
          reason: 'No implementation exists for capability "$capId" yet.',
          risk: RiskLevel.medium,
        ),
      );
    }
    final source = requirements.nodeById('capability:$capId')?.source;
    return (
      source == RequirementSource.explicit ? FeaturePriority.mandatory : FeaturePriority.recommended,
      Confidence.full,
    );
  }

  (FeaturePriority, Confidence) _offlinePriority(FeatureCandidate candidate) {
    final fullyOffline = candidate.rationale.toLowerCase().contains('fully offline');
    return (
      fullyOffline ? FeaturePriority.mandatory : FeaturePriority.recommended,
      const Confidence(score: 0.85, reason: 'Derived from the declared network/offline non-functional requirement.'),
    );
  }

  (FeaturePriority, Confidence) _securityPriority(FeatureCandidate candidate) {
    if (candidate.id == 'feature:security:protection') {
      return (
        FeaturePriority.optional,
        const Confidence(score: 0.9, reason: 'Kaalka protection is available but always opt-in.'),
      );
    }
    // feature:security:credential_storage
    return (
      FeaturePriority.future,
      const Confidence(
        score: 0.5,
        reason: 'Dormant capability trigger — no capability implemented today resolves credentials.',
        risk: RiskLevel.low,
      ),
    );
  }
}
