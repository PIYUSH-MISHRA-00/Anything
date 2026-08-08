/// RuntimeIntelligenceEngine — the top-level Runtime Intelligence
/// orchestrator: Learn -> Recommend -> Review -> Predict -> Plan
/// Automation, mirroring DesignReviewEngine (V6) / EvolutionEngine (V7)'s
/// role as the single facade over everything else in this package.
/// Deterministic: the same ObservationMemory contents always produce the
/// same UsageGraph, patterns, recommendations, and plans.
library;

import '../evolution/evolution_roadmap.dart';
import 'automation_plan.dart';
import 'automation_planner.dart';
import 'learning_engine.dart';
import 'learning_memory.dart';
import 'observation_memory.dart';
import 'prediction_engine.dart';
import 'recommendation_engine.dart';
import 'recommendation_review.dart';
import 'runtime_intelligence_result.dart';
import 'usage_graph.dart';

class RuntimeIntelligenceEngine {
  final LearningEngine _learningEngine;
  final RecommendationEngine _recommendationEngine;
  final RecommendationReview _recommendationReview;
  final AutomationPlanner _automationPlanner;
  final PredictionEngine _predictionEngine;

  const RuntimeIntelligenceEngine({
    LearningEngine learningEngine = const LearningEngine(),
    RecommendationEngine recommendationEngine = const RecommendationEngine(),
    RecommendationReview recommendationReview = const RecommendationReview(),
    AutomationPlanner automationPlanner = const AutomationPlanner(),
    PredictionEngine predictionEngine = const PredictionEngine(),
  }) : _learningEngine = learningEngine,
       _recommendationEngine = recommendationEngine,
       _recommendationReview = recommendationReview,
       _automationPlanner = automationPlanner,
       _predictionEngine = predictionEngine;

  RuntimeIntelligenceResult run(
    ObservationMemory observationMemory,
    LearningMemory learningMemory, {
    EvolutionRoadmap? evolutionRoadmap,
    int minOccurrences = 2,
  }) {
    final usageGraph = UsageGraph.fromRecords(observationMemory.records);
    final learned = _learningEngine.learn(
      usageGraph,
      learningMemory,
      minOccurrences: minOccurrences,
    );

    final recommendations = _recommendationEngine.recommend(
      learned,
      evolutionRoadmap: evolutionRoadmap,
    );
    final decisions = recommendations
        .map((r) => _recommendationReview.review(r, learningMemory))
        .toList();

    final partial = RuntimeIntelligenceResult(
      usageGraph: usageGraph,
      learned: learned,
      recommendations: recommendations,
      decisions: decisions,
      predictions: const [],
      automationPlans: const [],
    );

    final automationPlans = partial.acceptedRecommendations
        .map(_automationPlanner.plan)
        .whereType<AutomationPlan>()
        .toList();
    final predictions = _predictionEngine.predictAutomationOpportunities(
      learned.map((l) => l.pattern).toList(),
    );

    return RuntimeIntelligenceResult(
      usageGraph: usageGraph,
      learned: learned,
      recommendations: recommendations,
      decisions: decisions,
      predictions: predictions,
      automationPlans: automationPlans,
    );
  }
}
