/// Diagnostics — Vision Milestone V10. Every report here is a real,
/// typed SUMMARY derived from already-computed data this codebase
/// produces elsewhere (WorldGraph, ObservationMemory/LearningMemory/
/// AutomationHistory, ReviewSession, SqliteExperienceRepository) — never
/// a fabricated statistic, never a second engine that re-derives what
/// another subsystem already owns. "Everything accessible internally."
library;

import '../design_review/review_types.dart' show ReviewIssue, ReviewCategory;
import '../runtime_intelligence/automation_history.dart';
import '../runtime_intelligence/learning_memory.dart';
import '../runtime_intelligence/observation_memory.dart';
import '../world_model/graph_consistency.dart';
import '../world_model/world_graph.dart';
import '../world_model/world_types.dart';

class WorldGraphDiagnostics {
  final int nodeCount;
  final int edgeCount;
  final int danglingEdgeCount;
  final Map<WorldNodeKind, int> nodesByKind;

  const WorldGraphDiagnostics({
    required this.nodeCount,
    required this.edgeCount,
    required this.danglingEdgeCount,
    required this.nodesByKind,
  });

  bool get isConsistent => danglingEdgeCount == 0;

  factory WorldGraphDiagnostics.of(
    WorldGraph graph, {
    GraphConsistency consistency = const GraphConsistency(),
  }) {
    final validation = consistency.validate(graph);
    final byKind = <WorldNodeKind, int>{};
    for (final node in graph.nodes) {
      byKind[node.kind] = (byKind[node.kind] ?? 0) + 1;
    }
    return WorldGraphDiagnostics(
      nodeCount: graph.nodes.length,
      edgeCount: graph.edges.length,
      danglingEdgeCount: validation.danglingEdges.length,
      nodesByKind: byKind,
    );
  }
}

class RuntimeIntelligenceDiagnostics {
  final int observationCount;
  final int learningRecordCount;
  final int automationRecordCount;

  const RuntimeIntelligenceDiagnostics({
    required this.observationCount,
    required this.learningRecordCount,
    required this.automationRecordCount,
  });

  factory RuntimeIntelligenceDiagnostics.of({
    required ObservationMemory observationMemory,
    required LearningMemory learningMemory,
    required AutomationHistory automationHistory,
  }) {
    return RuntimeIntelligenceDiagnostics(
      observationCount: observationMemory.recordCount,
      learningRecordCount: learningMemory.records.length,
      automationRecordCount: automationHistory.recordCount,
    );
  }
}

class SecurityDiagnostics {
  final int securityIssueCount;
  final int criticalSecurityIssueCount;

  const SecurityDiagnostics({
    required this.securityIssueCount,
    required this.criticalSecurityIssueCount,
  });

  /// Reuses SCARE's own already-computed security findings directly —
  /// never a second security checker.
  factory SecurityDiagnostics.fromReviewIssues(List<ReviewIssue> issues) {
    final securityIssues = issues
        .where(
          (i) =>
              i.category == ReviewCategory.security ||
              i.category == ReviewCategory.integrity,
        )
        .toList();
    return SecurityDiagnostics(
      securityIssueCount: securityIssues.length,
      criticalSecurityIssueCount: securityIssues
          .where((i) => i.severity.name == 'critical')
          .length,
    );
  }
}

class StorageDiagnostics {
  final int experienceCount;
  final int protectedExperienceCount;

  const StorageDiagnostics({
    required this.experienceCount,
    required this.protectedExperienceCount,
  });
}

class HealthReport {
  final WorldGraphDiagnostics worldGraph;
  final RuntimeIntelligenceDiagnostics runtimeIntelligence;
  final SecurityDiagnostics security;
  final StorageDiagnostics storage;
  final DateTime generatedAt;

  HealthReport({
    required this.worldGraph,
    required this.runtimeIntelligence,
    required this.security,
    required this.storage,
    DateTime? generatedAt,
  }) : generatedAt = generatedAt ?? DateTime.now();

  bool get isHealthy =>
      worldGraph.isConsistent && security.criticalSecurityIssueCount == 0;
}
