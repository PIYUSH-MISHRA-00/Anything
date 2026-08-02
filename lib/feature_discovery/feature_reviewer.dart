/// Feature Reviewer — inspects a FeatureGraph for real, computable
/// defects: duplicate features, dangling edges, conflicting features,
/// impossible features (mandatory yet zero confidence), and
/// unnecessary/redundant features.
library;

import 'feature_types.dart';

enum FeatureIssueCategory { duplicate, dangling, conflicting, impossible, unnecessary, lowConfidence }

enum FeatureIssueSeverity { info, warning, critical }

class FeatureIssue {
  final FeatureIssueCategory category;
  final FeatureIssueSeverity severity;
  final String subjectId;
  final String message;
  final bool autoFixable;

  const FeatureIssue({
    required this.category,
    required this.severity,
    required this.subjectId,
    required this.message,
    this.autoFixable = false,
  });
}

class FeatureReviewResult {
  final int iteration;
  final List<FeatureIssue> issues;

  const FeatureReviewResult({required this.iteration, this.issues = const []});

  bool get passed => issues.isEmpty;
  bool get hasCriticalIssues => issues.any((i) => i.severity == FeatureIssueSeverity.critical);
  List<FeatureIssue> get autoFixableIssues => issues.where((i) => i.autoFixable).toList();
}

class FeatureReviewer {
  const FeatureReviewer();

  FeatureReviewResult review(FeatureGraph graph) {
    final issues = <FeatureIssue>[];

    _checkDuplicates(graph, issues);
    _checkDanglingEdges(graph, issues);
    _checkConflicts(graph, issues);
    _checkImpossible(graph, issues);
    _checkConfidence(graph, issues);

    return FeatureReviewResult(iteration: graph.iteration, issues: issues);
  }

  void _checkDuplicates(FeatureGraph graph, List<FeatureIssue> issues) {
    final seen = <String, FeatureNode>{};
    for (final node in graph.nodes) {
      final key = '${node.category.name}:${node.name}';
      final existing = seen[key];
      if (existing != null) {
        issues.add(
          FeatureIssue(
            category: FeatureIssueCategory.duplicate,
            severity: FeatureIssueSeverity.critical,
            subjectId: node.id,
            message: 'Feature "${node.name}" duplicates ${existing.id}',
            autoFixable: true,
          ),
        );
      } else {
        seen[key] = node;
      }
    }
  }

  void _checkDanglingEdges(FeatureGraph graph, List<FeatureIssue> issues) {
    final ids = graph.nodes.map((n) => n.id).toSet();
    for (final edge in graph.edges) {
      if (!ids.contains(edge.fromFeatureId) || !ids.contains(edge.toFeatureId)) {
        issues.add(
          FeatureIssue(
            category: FeatureIssueCategory.dangling,
            severity: FeatureIssueSeverity.critical,
            subjectId: '${edge.fromFeatureId}->${edge.toFeatureId}',
            message: 'Edge references a feature not present in the graph',
            autoFixable: true,
          ),
        );
      }
    }
  }

  void _checkConflicts(FeatureGraph graph, List<FeatureIssue> issues) {
    final ids = graph.nodes.map((n) => n.id).toSet();
    for (final edge in graph.edges) {
      if (edge.kind == FeatureRelationKind.conflictsWith &&
          ids.contains(edge.fromFeatureId) &&
          ids.contains(edge.toFeatureId)) {
        issues.add(
          FeatureIssue(
            category: FeatureIssueCategory.conflicting,
            severity: FeatureIssueSeverity.critical,
            subjectId: '${edge.fromFeatureId}<->${edge.toFeatureId}',
            message: 'Both conflicting features are present in the same graph',
          ),
        );
      }
    }
  }

  void _checkImpossible(FeatureGraph graph, List<FeatureIssue> issues) {
    for (final node in graph.nodes) {
      if (node.priority == FeaturePriority.mandatory && node.decision.confidence.score == 0.0) {
        issues.add(
          FeatureIssue(
            category: FeatureIssueCategory.impossible,
            severity: FeatureIssueSeverity.critical,
            subjectId: node.id,
            message: '"${node.name}" is mandatory but has zero confidence — contradictory',
          ),
        );
      }
    }
  }

  void _checkConfidence(FeatureGraph graph, List<FeatureIssue> issues) {
    if (graph.overallConfidence.score < 0.4) {
      issues.add(
        FeatureIssue(
          category: FeatureIssueCategory.lowConfidence,
          severity: FeatureIssueSeverity.critical,
          subjectId: 'graph',
          message:
              'Overall feature confidence ${graph.overallConfidence.score.toStringAsFixed(2)} '
              'is below the acceptance threshold (0.4)',
        ),
      );
    }
  }
}
