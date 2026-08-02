/// RuntimeIntelligenceResult — the complete, typed output of one
/// RuntimeIntelligenceEngine pass: what was learned, recommended,
/// reviewed, predicted, and planned. Mirrors EvolutionResult (V7)'s role.
library;

import 'automation_plan.dart';
import 'learning_record.dart';
import 'prediction.dart';
import 'recommendation.dart';
import 'recommendation_review.dart';
import 'ril_types.dart';
import 'usage_graph.dart';

class RuntimeIntelligenceResult {
  final UsageGraph usageGraph;
  final List<LearningRecord> learned;
  final List<Recommendation> recommendations;
  final List<RecommendationDecision> decisions;
  final List<Prediction> predictions;
  final List<AutomationPlan> automationPlans;

  const RuntimeIntelligenceResult({
    required this.usageGraph,
    required this.learned,
    required this.recommendations,
    required this.decisions,
    required this.predictions,
    required this.automationPlans,
  });

  List<Recommendation> get acceptedRecommendations {
    final acceptedIds = decisions
        .where((d) => d.kind == RecommendationDecisionKind.accepted)
        .map((d) => d.subjectId)
        .toSet();
    return recommendations.where((r) => acceptedIds.contains(r.id)).toList();
  }
}
