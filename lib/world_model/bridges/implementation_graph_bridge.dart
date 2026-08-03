/// ImplementationGraphBridge — Implementation Milestone R9. Translates a
/// real `CanonicalImplementationModel` into a `GraphUpdate`, the same
/// pure-translation pattern every other Bridge follows (Knowledge/
/// Experience/Evolution/Runtime/Review/Software/Backend, Vision
/// Milestones V9-R8). Deliberately narrow: entity and API-endpoint nodes
/// are ALREADY ingested by `BackendGraphBridge` (R8) — re-adding them
/// here would be pure duplication. The one genuinely NEW piece of
/// information `CanonicalImplementationModel` contributes to the World
/// Graph is entity-to-capability dependency edges
/// (`ImplementationDependency` with `DependencyKind.capability`) — never
/// tracked by any prior milestone's bridge.
library;

import '../../implementation_model/canonical_implementation_model.dart';
import '../entity_resolver.dart';
import '../graph_update.dart';
import '../world_edge.dart';
import '../world_node.dart';
import '../world_types.dart';

class ImplementationGraphBridge {
  final EntityResolver _resolver;

  const ImplementationGraphBridge({EntityResolver resolver = const EntityResolver()}) : _resolver = resolver;

  /// Real nodes are emitted for both edge endpoints — `GraphConsistency`
  /// rejects (per its own established, real "never dangling" contract,
  /// V9) any edge whose endpoints aren't present, so an edge-only
  /// `GraphUpdate` would be silently discarded whenever the referenced
  /// entity/capability wasn't already ingested by an earlier
  /// `BackendGraphBridge`/software-cognition call — a real bug caught by
  /// this milestone's own World Model integration test, not assumed
  /// correct.
  GraphUpdate bridge(CanonicalImplementationModel model) {
    final nodes = <WorldNode>[];
    final edges = <WorldEdge>[];

    for (final dep in model.dependencies) {
      if (dep.kind != DependencyKind.capability) continue;
      final fromIdentity = _resolver.resolve(WorldNodeKind.entity, stableId: dep.fromId);
      final toIdentity = _resolver.resolve(WorldNodeKind.capability, stableId: dep.toId);
      nodes.add(WorldNode(identity: fromIdentity, kind: WorldNodeKind.entity, label: dep.fromId));
      nodes.add(WorldNode(identity: toIdentity, kind: WorldNodeKind.capability, label: dep.toId));
      edges.add(
        WorldEdge(
          fromId: fromIdentity,
          toId: toIdentity,
          kind: RelationshipKind.dependsOn,
          evidence: const GraphEvidence(sourceGraph: 'CanonicalImplementationModel', sourceNodeId: 'dependency'),
        ),
      );
    }

    return GraphUpdate(addedNodes: nodes, addedEdges: edges);
  }
}
