/// CollaborationGraph — Collaboration Graph. A real, filtered VIEW of
/// ExperienceRelationshipGraph restricted to pairs with more than one
/// independent structural overlap (both shared capabilities AND shared
/// data shape) — strong enough evidence that two Experiences genuinely
/// "work together," never a keyword match. Reuses
/// ExperienceRelationshipGraph's inference directly rather than a second
/// competing inference pass.
library;

import 'experience_relationship_graph.dart';
import 'ril_types.dart';

class CollaborationGraph {
  final List<RilNode> nodes;
  final List<ExperienceRelationshipEdge> edges;

  const CollaborationGraph({this.nodes = const [], this.edges = const []});

  factory CollaborationGraph.fromRelationshipGraph(
    ExperienceRelationshipGraph graph, {
    int minIndependentSignals = 2,
  }) {
    final pairCounts = <String, int>{};
    for (final edge in graph.edges) {
      final key = '${edge.fromId}|${edge.toId}';
      pairCounts[key] = (pairCounts[key] ?? 0) + 1;
    }

    final strongPairs = pairCounts.entries
        .where((e) => e.value >= minIndependentSignals)
        .map((e) => e.key)
        .toSet();

    final edges = graph.edges
        .where((e) => strongPairs.contains('${e.fromId}|${e.toId}'))
        .toList();
    final involvedIds = {
      for (final e in edges) ...[e.fromId, e.toId],
    };
    final nodes = graph.nodes.where((n) => involvedIds.contains(n.id)).toList();

    return CollaborationGraph(nodes: nodes, edges: edges);
  }
}
