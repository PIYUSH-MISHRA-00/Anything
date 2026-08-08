/// Vision V8 RIL — RecommendationEngine + RecommendationReview.
/// Evolution Integration: a recommendation whose description already
/// matches a real EvolutionRoadmap proposal is skipped, never duplicated.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/evolution/evolution_candidate.dart';
import 'package:anything/evolution/evolution_opportunity.dart';
import 'package:anything/evolution/evolution_roadmap.dart';
import 'package:anything/evolution/evolution_types.dart';
import 'package:anything/runtime_intelligence/learning_engine.dart';
import 'package:anything/runtime_intelligence/learning_memory.dart';
import 'package:anything/runtime_intelligence/observation_record.dart';
import 'package:anything/runtime_intelligence/recommendation_engine.dart';
import 'package:anything/runtime_intelligence/recommendation_review.dart';
import 'package:anything/runtime_intelligence/ril_types.dart';
import 'package:anything/runtime_intelligence/usage_graph.dart';
import 'package:anything/software_architect/confidence.dart';

void main() {
  const learningEngine = LearningEngine();
  const recommendationEngine = RecommendationEngine();
  const review = RecommendationReview();

  UsageGraph buildGraph() {
    DateTime base(int i) => DateTime(2026, 1, 1).add(Duration(seconds: i));
    final records = <ObservationRecord>[];
    for (final exp in ['exp-1', 'exp-2']) {
      records.addAll([
        ObservationRecord(
          id: '$exp-0',
          category: ObservationCategory.navigation,
          experienceId: exp,
          screenId: 'home',
          timestamp: base(0),
        ),
        ObservationRecord(
          id: '$exp-1',
          category: ObservationCategory.navigation,
          experienceId: exp,
          screenId: 'detail',
          timestamp: base(1),
        ),
      ]);
    }
    return UsageGraph.fromRecords(records);
  }

  test(
    'every recommendation is derived from a real, present pattern and is accepted on first review',
    () {
      final memory = LearningMemory();
      final learned = learningEngine.learn(
        buildGraph(),
        memory,
        minOccurrences: 2,
      );
      final recommendations = recommendationEngine.recommend(learned);

      expect(recommendations, isNotEmpty);
      for (final recommendation in recommendations) {
        final decision = review.review(recommendation, memory);
        expect(decision.kind, RecommendationDecisionKind.accepted);
      }
    },
  );

  test(
    'a recommendation whose pattern is missing from LearningMemory is rejected',
    () {
      final memory = LearningMemory(); // empty — never learned anything
      final learned = learningEngine.learn(
        buildGraph(),
        LearningMemory(),
        minOccurrences: 2,
      );
      final recommendations = recommendationEngine.recommend(learned);

      for (final recommendation in recommendations) {
        final decision = review.review(recommendation, memory);
        expect(decision.kind, RecommendationDecisionKind.rejected);
      }
    },
  );

  test(
    'Evolution Integration: a recommendation already proposed by Evolution is never duplicated',
    () {
      final memory = LearningMemory();
      final learned = learningEngine.learn(
        buildGraph(),
        memory,
        minOccurrences: 2,
      );
      final withoutRoadmap = recommendationEngine.recommend(learned);
      expect(withoutRoadmap, isNotEmpty);

      final duplicateDescription = withoutRoadmap.first.description;
      final fakeRoadmap = EvolutionRoadmap(
        fingerprint: 'fp',
        generatedAt: DateTime.now(),
        milestones: [
          EvolutionMilestone(
            phase: EvolutionPhase.immediate,
            proposals: [
              EvolutionProposal(
                candidate: EvolutionCandidate(
                  id: 'candidate:x',
                  opportunity: EvolutionOpportunity(
                    id: 'evolution:missingWorkflow:x',
                    category: EvolutionOpportunityCategory.missingWorkflow,
                    description: duplicateDescription,
                    reason: const EvolutionReason(
                      summary: 's',
                      evidence: EvolutionEvidence(
                        affectedGraph: 'g',
                        affectedNodeId: 'n',
                      ),
                      confidence: Confidence.full,
                    ),
                  ),
                  cost: const EvolutionCost(),
                  risk: const EvolutionRisk(),
                  benefit: const EvolutionBenefit(
                    engineeringValue: Confidence.full,
                    userValue: Confidence.full,
                    maintenanceValue: Confidence.full,
                    performanceValue: Confidence.full,
                    securityValue: Confidence.full,
                    accessibilityValue: Confidence.full,
                    offlineValue: Confidence.full,
                    futureValue: Confidence.full,
                  ),
                ),
                phase: EvolutionPhase.immediate,
                reviewDecision: const EvolutionDecision(
                  subjectId: 'x',
                  kind: EvolutionDecisionKind.accepted,
                  rationale: 'r',
                  confidence: Confidence.full,
                ),
              ),
            ],
          ),
          const EvolutionMilestone(phase: EvolutionPhase.current),
          const EvolutionMilestone(phase: EvolutionPhase.next),
          const EvolutionMilestone(phase: EvolutionPhase.later),
          const EvolutionMilestone(phase: EvolutionPhase.future),
          const EvolutionMilestone(phase: EvolutionPhase.experimental),
        ],
      );

      final withRoadmap = recommendationEngine.recommend(
        learned,
        evolutionRoadmap: fakeRoadmap,
      );
      expect(
        withRoadmap.any((r) => r.description == duplicateDescription),
        isFalse,
      );
      expect(withRoadmap.length, withoutRoadmap.length - 1);
    },
  );
}
