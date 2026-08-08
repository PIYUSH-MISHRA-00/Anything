/// Vision V4 FDI — FeatureReviewer: real, computable defect detection
/// (duplicate/dangling/conflicting/impossible features, low confidence).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/feature_discovery/feature_reviewer.dart';
import 'package:anything/feature_discovery/feature_types.dart';
import 'package:anything/software_architect/confidence.dart';

FeatureNode _node({
  required String id,
  required String name,
  FeatureCategory category = FeatureCategory.data,
  FeaturePriority priority = FeaturePriority.recommended,
  double confidenceScore = 0.9,
}) {
  return FeatureNode(
    candidate: FeatureCandidate(
      id: id,
      name: name,
      category: category,
      rationale: 'r',
    ),
    priority: priority,
    complexity: const FeatureComplexity(),
    decision: FeatureDecision(
      id: 'd:$id',
      category: category,
      subjectId: id,
      decision: 'd',
      rationale: 'r',
      confidence: Confidence(score: confidenceScore, reason: 'r'),
    ),
    explanation: FeatureExplanation(featureId: id, whyDiscovered: 'r'),
  );
}

void main() {
  const reviewer = FeatureReviewer();

  test('a clean graph produces no issues', () {
    final graph = FeatureGraph(
      nodes: [
        _node(id: 'a', name: 'A'),
        _node(id: 'b', name: 'B'),
      ],
      overallConfidence: const Confidence(score: 0.9, reason: 'r'),
    );
    expect(reviewer.review(graph).passed, isTrue);
  });

  test(
    'two features with the same category+name are flagged duplicate and auto-fixable',
    () {
      final graph = FeatureGraph(
        nodes: [
          _node(id: 'a', name: 'Search'),
          _node(id: 'b', name: 'Search'),
        ],
        overallConfidence: const Confidence(score: 0.9, reason: 'r'),
      );
      final result = reviewer.review(graph);
      expect(result.hasCriticalIssues, isTrue);
      final issue = result.issues.firstWhere(
        (i) => i.category == FeatureIssueCategory.duplicate,
      );
      expect(issue.autoFixable, isTrue);
      expect(issue.subjectId, 'b');
    },
  );

  test(
    'an edge referencing a missing feature is flagged dangling and auto-fixable',
    () {
      final graph = FeatureGraph(
        nodes: [_node(id: 'a', name: 'A')],
        edges: const [
          FeatureEdge(
            fromFeatureId: 'a',
            toFeatureId: 'ghost',
            kind: FeatureRelationKind.requires,
          ),
        ],
        overallConfidence: const Confidence(score: 0.9, reason: 'r'),
      );
      final result = reviewer.review(graph);
      expect(result.hasCriticalIssues, isTrue);
      final issue = result.issues.firstWhere(
        (i) => i.category == FeatureIssueCategory.dangling,
      );
      expect(issue.autoFixable, isTrue);
    },
  );

  test(
    'two conflicting features both present is critical and NOT auto-fixable',
    () {
      final graph = FeatureGraph(
        nodes: [
          _node(id: 'a', name: 'A'),
          _node(id: 'b', name: 'B'),
        ],
        edges: const [
          FeatureEdge(
            fromFeatureId: 'a',
            toFeatureId: 'b',
            kind: FeatureRelationKind.conflictsWith,
          ),
        ],
        overallConfidence: const Confidence(score: 0.9, reason: 'r'),
      );
      final result = reviewer.review(graph);
      final issue = result.issues.firstWhere(
        (i) => i.category == FeatureIssueCategory.conflicting,
      );
      expect(issue.autoFixable, isFalse);
    },
  );

  test('a mandatory feature with zero confidence is impossible', () {
    final graph = FeatureGraph(
      nodes: [
        _node(
          id: 'a',
          name: 'A',
          priority: FeaturePriority.mandatory,
          confidenceScore: 0.0,
        ),
      ],
      overallConfidence: const Confidence(score: 0.9, reason: 'r'),
    );
    final result = reviewer.review(graph);
    expect(
      result.issues.any((i) => i.category == FeatureIssueCategory.impossible),
      isTrue,
    );
  });

  test('overall confidence below 0.4 is flagged critical', () {
    final graph = FeatureGraph(
      nodes: [_node(id: 'a', name: 'A')],
      overallConfidence: const Confidence(score: 0.1, reason: 'r'),
    );
    final result = reviewer.review(graph);
    expect(
      result.issues.any(
        (i) => i.category == FeatureIssueCategory.lowConfidence,
      ),
      isTrue,
    );
  });
}
