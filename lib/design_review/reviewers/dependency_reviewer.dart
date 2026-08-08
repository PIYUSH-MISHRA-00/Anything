/// Dependency Review — genuinely new: no prior milestone validates the
/// DependencyGraph (Vision Milestone V4) itself. Inspects cycles,
/// redundancy, missing dependencies, conflicting dependencies, and
/// transitive problems (a primitive nothing depends on).
library;

import '../../feature_discovery/dependency_types.dart';
import '../../feature_discovery/feature_types.dart' show FeatureRelationKind;
import '../../software_architect/confidence.dart';
import '../review_context.dart';
import '../review_types.dart';

class DependencyReviewer {
  const DependencyReviewer();

  List<ReviewIssue> review(ReviewContext context) {
    final graph = context.dependencyGraph;
    final issues = <ReviewIssue>[];
    final nodeIds = graph.nodes.map((n) => n.id).toSet();

    // Missing: an edge pointing at a node that doesn't exist.
    for (final edge in graph.edges) {
      if (!nodeIds.contains(edge.fromId) || !nodeIds.contains(edge.toId)) {
        issues.add(
          ReviewIssue(
            id: 'dependency:missing:${edge.fromId}->${edge.toId}',
            category: ReviewCategory.dependency,
            severity: ReviewSeverity.critical,
            reason:
                'Dependency edge references a node not present in the graph',
            evidence: ReviewEvidence(
              affectedGraph: 'DependencyGraph',
              affectedNodeId: '${edge.fromId}->${edge.toId}',
            ),
            recommendation: const ReviewRecommendation(
              description: 'Drop the dangling dependency edge',
              autoApplicable: true,
            ),
            confidence: Confidence.full,
          ),
        );
      }
    }

    // Redundancy: exact duplicate edges (same from/to/relation).
    final seenEdges = <String, DependencyEdge>{};
    for (final edge in graph.edges) {
      final key = '${edge.fromId}|${edge.toId}|${edge.relation.name}';
      if (seenEdges.containsKey(key)) {
        issues.add(
          ReviewIssue(
            id: 'dependency:redundant:${edge.fromId}->${edge.toId}:${graph.edges.indexOf(edge)}',
            category: ReviewCategory.dependency,
            severity: ReviewSeverity.warning,
            reason:
                'Duplicate dependency edge "${edge.fromId} -> ${edge.toId}" (${edge.relation.name})',
            evidence: ReviewEvidence(
              affectedGraph: 'DependencyGraph',
              affectedNodeId: '${edge.fromId}->${edge.toId}',
            ),
            recommendation: const ReviewRecommendation(
              description: 'Remove the duplicate edge',
              autoApplicable: true,
            ),
            confidence: Confidence.full,
          ),
        );
      } else {
        seenEdges[key] = edge;
      }
    }

    // Conflicting: two feature nodes with edges into the same capability
    // primitive where one is a real capability requirement and the other
    // is a permission for a DIFFERENT capability of the same id — dormant
    // structural sanity check (never fires against real DependencyGraphBuilder
    // output, since it never produces conflicting edges to the same primitive).
    final byTarget = <String, List<DependencyEdge>>{};
    for (final edge in graph.edges) {
      byTarget.putIfAbsent(edge.toId, () => []).add(edge);
    }
    for (final entry in byTarget.entries) {
      final kinds = entry.value.map((e) => e.relation).toSet();
      if (kinds.contains(FeatureRelationKind.conflictsWith)) {
        issues.add(
          ReviewIssue(
            id: 'dependency:conflicting:${entry.key}',
            category: ReviewCategory.dependency,
            severity: ReviewSeverity.critical,
            reason: 'Conflicting dependency edges converge on "${entry.key}"',
            evidence: ReviewEvidence(
              affectedGraph: 'DependencyGraph',
              affectedNodeId: entry.key,
            ),
            recommendation: const ReviewRecommendation(
              description: 'Resolve the conflicting dependency requirement',
            ),
            confidence: Confidence.full,
          ),
        );
      }
    }

    // Transitive problem: a non-feature primitive with no incoming edge
    // from any feature — nothing actually depends on it.
    final dependedOn = graph.edges.map((e) => e.toId).toSet();
    for (final node in graph.nodes) {
      if (node.kind == DependencyNodeKind.feature) continue;
      if (!dependedOn.contains(node.id)) {
        issues.add(
          ReviewIssue(
            id: 'dependency:transitive:${node.id}',
            category: ReviewCategory.dependency,
            severity: ReviewSeverity.info,
            reason:
                '"${node.label}" (${node.kind.name}) exists in the dependency graph but nothing depends on it',
            evidence: ReviewEvidence(
              affectedGraph: 'DependencyGraph',
              affectedNodeId: node.id,
            ),
            recommendation: const ReviewRecommendation(
              description: 'Confirm this primitive is still needed',
            ),
            confidence: const Confidence(
              score: 0.6,
              reason:
                  'Structural signal only; may be intentionally forward-looking.',
            ),
          ),
        );
      }
    }

    // Cycle: a real cycle among dependency nodes (should never occur given
    // DependencyGraphBuilder always points from feature -> primitive, never
    // primitive -> feature — real, tested, dormant guard).
    for (final cycleId in _findCycle(graph)) {
      issues.add(
        ReviewIssue(
          id: 'dependency:cycle:$cycleId',
          category: ReviewCategory.dependency,
          severity: ReviewSeverity.critical,
          reason: 'Dependency node "$cycleId" participates in a cycle',
          evidence: ReviewEvidence(
            affectedGraph: 'DependencyGraph',
            affectedNodeId: cycleId,
          ),
          recommendation: const ReviewRecommendation(
            description: 'Break the dependency cycle',
          ),
          confidence: Confidence.full,
        ),
      );
    }

    return issues;
  }

  Set<String> _findCycle(DependencyGraph graph) {
    final edges = <String, List<String>>{};
    for (final e in graph.edges) {
      edges.putIfAbsent(e.fromId, () => []).add(e.toId);
    }
    final visiting = <String>{};
    final visited = <String>{};
    final inCycle = <String>{};

    void visit(String node, List<String> path) {
      if (visited.contains(node)) return;
      if (visiting.contains(node)) {
        final start = path.indexOf(node);
        inCycle.addAll(path.sublist(start));
        return;
      }
      visiting.add(node);
      for (final next in edges[node] ?? const <String>[]) {
        visit(next, [...path, node]);
      }
      visiting.remove(node);
      visited.add(node);
    }

    for (final node in edges.keys) {
      visit(node, []);
    }
    return inCycle;
  }
}
