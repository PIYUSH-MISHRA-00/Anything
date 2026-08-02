/// ImpactAnalyzer — answers "what depends on this / what breaks if this
/// changes / which Experiences use this / which capabilities depend on
/// this / which workflows use this" — entirely via real, reverse graph
/// traversal. Never a heuristic guess.
library;

import 'entity_identity.dart';
import 'graph_traversal.dart';
import 'world_graph.dart';
import 'world_node.dart';
import 'world_types.dart';

class ImpactReport {
  final EntityIdentity subject;
  final List<WorldNode> impactedNodes;

  const ImpactReport({required this.subject, this.impactedNodes = const []});

  List<WorldNode> ofKind(WorldNodeKind kind) => impactedNodes.where((n) => n.kind == kind).toList();
}

class ImpactAnalyzer {
  final GraphTraversal _traversal;

  const ImpactAnalyzer({GraphTraversal traversal = const GraphTraversal()}) : _traversal = traversal;

  /// Everything that would be affected if [subject] changed or was
  /// removed — a real reverse traversal over contains/references/
  /// dependsOn/consumes/produces edges, never a fabricated answer.
  ImpactReport analyze(WorldGraph graph, EntityIdentity subject, {int maxDepth = 5}) {
    final steps = _traversal.reverse(
      graph,
      subject,
      maxDepth: maxDepth,
      relationKinds: const {
        RelationshipKind.contains,
        RelationshipKind.references,
        RelationshipKind.dependsOn,
        RelationshipKind.consumes,
        RelationshipKind.produces,
        RelationshipKind.extends_,
      },
    );
    final nodes = steps.map((s) => graph.nodeById(s.nodeId)).whereType<WorldNode>().toList();
    return ImpactReport(subject: subject, impactedNodes: nodes);
  }
}
