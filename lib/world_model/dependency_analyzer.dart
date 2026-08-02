/// DependencyAnalyzer — the forward counterpart to ImpactAnalyzer:
/// "what does this depend on / reference / consume." Reuses the same
/// GraphTraversal, just forward instead of reverse.
library;

import 'entity_identity.dart';
import 'graph_traversal.dart';
import 'world_graph.dart';
import 'world_node.dart';
import 'world_types.dart';

class DependencyReport {
  final EntityIdentity subject;
  final List<WorldNode> dependencies;

  const DependencyReport({required this.subject, this.dependencies = const []});
}

class DependencyAnalyzer {
  final GraphTraversal _traversal;

  const DependencyAnalyzer({GraphTraversal traversal = const GraphTraversal()}) : _traversal = traversal;

  DependencyReport analyze(WorldGraph graph, EntityIdentity subject, {int maxDepth = 5}) {
    final steps = _traversal.forward(
      graph,
      subject,
      maxDepth: maxDepth,
      relationKinds: const {
        RelationshipKind.contains,
        RelationshipKind.references,
        RelationshipKind.dependsOn,
        RelationshipKind.consumes,
      },
    );
    final nodes = steps.map((s) => graph.nodeById(s.nodeId)).whereType<WorldNode>().toList();
    return DependencyReport(subject: subject, dependencies: nodes);
  }
}
