/// Vision V4 FDI — FeatureRefinement: review -> apply auto-fixable fixes ->
/// re-review, deterministic termination. Mirrors
/// application_engineering/engineering_refinement.dart's proven design.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/feature_discovery/feature_plan.dart';
import 'package:anything/feature_discovery/feature_refinement.dart';
import 'package:anything/feature_discovery/feature_types.dart';
import 'package:anything/software_architect/confidence.dart';

FeatureNode _node({
  required String id,
  required String name,
  FeaturePriority priority = FeaturePriority.recommended,
  double confidenceScore = 0.9,
}) {
  return FeatureNode(
    candidate: FeatureCandidate(id: id, name: name, category: FeatureCategory.data, rationale: 'r'),
    priority: priority,
    complexity: const FeatureComplexity(),
    decision: FeatureDecision(
      id: 'd:$id',
      category: FeatureCategory.data,
      subjectId: id,
      decision: 'd',
      rationale: 'r',
      confidence: Confidence(score: confidenceScore, reason: 'r'),
    ),
    explanation: FeatureExplanation(featureId: id, whyDiscovered: 'r'),
  );
}

void main() {
  test('a clean graph is approved with zero iterations', () {
    final graph = FeatureGraph(nodes: [_node(id: 'a', name: 'A')], overallConfidence: const Confidence(score: 0.9, reason: 'r'));
    final plan = const FeatureRefinement().refine(graph);
    expect(plan.outcome, FeatureRefinementOutcome.approved);
    expect(plan.reviewHistory, hasLength(1));
  });

  test('fixes a dangling edge and reaches approved', () {
    final graph = FeatureGraph(
      nodes: [_node(id: 'a', name: 'A')],
      edges: const [FeatureEdge(fromFeatureId: 'a', toFeatureId: 'ghost', kind: FeatureRelationKind.requires)],
      overallConfidence: const Confidence(score: 0.9, reason: 'r'),
    );
    final plan = const FeatureRefinement().refine(graph);
    expect(plan.outcome, FeatureRefinementOutcome.approved);
    expect(plan.finalGraph.edges, isEmpty);
  });

  test('fixes a duplicate feature and reaches approved', () {
    final graph = FeatureGraph(
      nodes: [_node(id: 'a', name: 'Search'), _node(id: 'b', name: 'Search')],
      overallConfidence: const Confidence(score: 0.9, reason: 'r'),
    );
    final plan = const FeatureRefinement().refine(graph);
    expect(plan.outcome, FeatureRefinementOutcome.approved);
    expect(plan.finalGraph.nodes, hasLength(1));
  });

  test('terminates at the iteration budget when a critical issue has no fix', () {
    final graph = FeatureGraph(
      nodes: [_node(id: 'a', name: 'A', priority: FeaturePriority.mandatory, confidenceScore: 0.0)],
      overallConfidence: const Confidence(score: 0.9, reason: 'r'),
    );
    final plan = const FeatureRefinement().refine(graph);
    // "impossible" issues have no autoFixable path — the loop must break
    // immediately (iteration stays 0) rather than spin to the budget.
    expect(plan.outcome, isNot(FeatureRefinementOutcome.approved));
    expect(plan.reviewHistory, hasLength(1));
  });
}
