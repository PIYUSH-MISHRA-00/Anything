/// RuntimeGraphBridge — translates Runtime Intelligence's (V8) real
/// UsageGraph and learned patterns into a GraphUpdate: "Observations
/// update the World Graph. Learning updates the World Graph." A pure
/// translation — never a second usage-tracking or pattern-detection
/// implementation.
library;

import '../../runtime_intelligence/learning_record.dart';
import '../../runtime_intelligence/ril_types.dart';
import '../../runtime_intelligence/usage_graph.dart';
import '../entity_resolver.dart';
import '../graph_update.dart';
import '../world_edge.dart';
import '../world_node.dart';
import '../world_types.dart';

class RuntimeGraphBridge {
  final EntityResolver _resolver;

  const RuntimeGraphBridge({EntityResolver resolver = const EntityResolver()}) : _resolver = resolver;

  WorldNodeKind _mapKind(RilNodeKind kind) => switch (kind) {
    RilNodeKind.screen => WorldNodeKind.workflow,
    RilNodeKind.entity => WorldNodeKind.entity,
    RilNodeKind.capability => WorldNodeKind.capability,
    RilNodeKind.experience => WorldNodeKind.experience,
  };

  GraphUpdate bridgeUsage(UsageGraph usageGraph) {
    final nodes = usageGraph.nodes
        .map((n) => WorldNode(identity: _resolver.resolve(_mapKind(n.node.kind), stableId: n.id), kind: _mapKind(n.node.kind), label: n.node.label))
        .toList();

    final edges = usageGraph.edges
        .map(
          (e) => WorldEdge(
            fromId: _resolver.resolve(WorldNodeKind.workflow, stableId: e.fromId),
            toId: _resolver.resolve(WorldNodeKind.workflow, stableId: e.toId),
            kind: RelationshipKind.relatesTo,
            evidence: GraphEvidence(sourceGraph: 'UsageGraph', sourceNodeId: '${e.fromId}->${e.toId}'),
            confidence: GraphConfidence(score: e.coOccurrenceCount.toDouble().clamp(0.0, 1.0), reason: 'Observed ${e.coOccurrenceCount} time(s).'),
          ),
        )
        .toList();

    return GraphUpdate(addedNodes: nodes, addedEdges: edges);
  }

  /// Every learned pattern becomes a real `learning` node — connected
  /// only by presence, not re-derived edges, since a pattern's evidence
  /// key may name either a UsageGraph node or an edge and this bridge
  /// does not need to disambiguate that to honestly represent "this was
  /// learned."
  GraphUpdate bridgeLearning(List<LearningRecord> learned) {
    final nodes = learned
        .map(
          (record) => WorldNode(
            identity: _resolver.resolve(WorldNodeKind.learning, stableId: record.id),
            kind: WorldNodeKind.learning,
            label: record.pattern.description,
          ),
        )
        .toList();
    return GraphUpdate(addedNodes: nodes);
  }
}
