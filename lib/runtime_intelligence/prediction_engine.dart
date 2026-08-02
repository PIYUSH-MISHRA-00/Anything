/// PredictionEngine — Prediction. Ranks real UsageGraph frequencies into
/// typed forecasts: likely next action (given the current screen) and
/// likely automation opportunities (from strong sequential-workflow
/// patterns). Deterministic — same inputs always produce the same
/// ranked predictions.
library;

import 'pattern.dart';
import 'prediction.dart';
import 'ril_types.dart';
import 'usage_graph.dart';

class PredictionEngine {
  const PredictionEngine();

  /// Ranks every real outgoing UsageGraph edge from [currentScreenId] by
  /// co-occurrence count — the most likely next screen first.
  List<Prediction> predictNextAction(UsageGraph graph, String currentScreenId) {
    final outgoing = [...graph.edgesFrom(currentScreenId)]..sort((a, b) => b.coOccurrenceCount.compareTo(a.coOccurrenceCount));
    final maxCount = outgoing.isEmpty ? 1 : outgoing.first.coOccurrenceCount;

    return outgoing
        .map(
          (edge) => Prediction(
            id: 'prediction:nextAction:${edge.fromId}->${edge.toId}',
            kind: PredictionKind.nextAction,
            description: 'Likely to navigate from "${edge.fromId}" to "${edge.toId}" next',
            confidence: PredictionConfidence(
              score: edge.coOccurrenceCount / maxCount,
              reason: 'Observed ${edge.coOccurrenceCount} time(s) out of a maximum of $maxCount for this screen.',
            ),
          ),
        )
        .toList();
  }

  /// Sequential-workflow patterns with real, above-threshold confidence
  /// become "automation opportunity" predictions — the substrate
  /// AutomationPlanner can plan from once reviewed as a Recommendation.
  List<Prediction> predictAutomationOpportunities(List<Pattern> patterns, {double minConfidence = 0.5}) {
    return patterns
        .where((p) => p.kind == PatternKind.sequentialWorkflow && p.confidence.score >= minConfidence)
        .map(
          (p) => Prediction(
            id: 'prediction:automationOpportunity:${p.id}',
            kind: PredictionKind.automationOpportunity,
            description: 'This workflow is a strong automation candidate: ${p.description}',
            confidence: PredictionConfidence(score: p.confidence.score, reason: p.confidence.reason),
          ),
        )
        .toList();
  }
}
