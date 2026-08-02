/// RecommendationEngine — Recommendations. Turns real, learned Patterns
/// into typed Recommendations. Reuses Evolution (V7) directly rather
/// than duplicating its reasoning: any recommendation whose description
/// already matches a real EvolutionRoadmap proposal is skipped, since
/// Evolution already surfaced it — Evolution Integration, not a second
/// competing proposal pipeline.
library;

import '../evolution/evolution_roadmap.dart';
import '../software_architect/confidence.dart';
import 'learning_record.dart';
import 'recommendation.dart';
import 'ril_types.dart';

class RecommendationEngine {
  const RecommendationEngine();

  List<Recommendation> recommend(List<LearningRecord> learned, {EvolutionRoadmap? evolutionRoadmap}) {
    final alreadyProposed = evolutionRoadmap?.allProposals.map((p) => p.candidate.opportunity.description).toSet() ?? const {};

    final recommendations = <Recommendation>[];
    for (final record in learned) {
      final kind = _kindFor(record.pattern.kind);
      final description = _describe(record.pattern.kind, record.pattern.description);
      if (alreadyProposed.contains(description)) continue;

      recommendations.add(
        Recommendation(
          id: 'recommendation:${record.pattern.id}',
          kind: kind,
          description: description,
          reason: RecommendationReason(
            summary: record.pattern.description,
            evidence: RecommendationEvidence(
              patternId: record.pattern.id,
              usageGraphNodeOrEdgeId: record.pattern.evidence.isNotEmpty ? record.pattern.evidence.first.usageGraphNodeOrEdgeId : '',
            ),
            confidence: Confidence(score: record.pattern.confidence.score, reason: record.pattern.confidence.reason),
          ),
        ),
      );
    }
    return recommendations;
  }

  RecommendationKind _kindFor(PatternKind kind) => switch (kind) {
    PatternKind.frequentFeaturePair => RecommendationKind.shortcut,
    PatternKind.frequentCapability => RecommendationKind.capability,
    PatternKind.navigationLoop => RecommendationKind.optimization,
    PatternKind.sequentialWorkflow => RecommendationKind.automation,
  };

  String _describe(PatternKind kind, String patternDescription) => switch (kind) {
    PatternKind.frequentFeaturePair => 'Add a shortcut: $patternDescription',
    PatternKind.frequentCapability => patternDescription,
    PatternKind.navigationLoop => 'Reduce friction: $patternDescription',
    PatternKind.sequentialWorkflow => 'Automate this workflow: $patternDescription',
  };
}
