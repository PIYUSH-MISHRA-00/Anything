/// BackendGraphBridge — Implementation Milestone R8. Translates a real
/// `BackendEngineeringPlan` into a `GraphUpdate`, the same pure-
/// translation pattern every other Bridge follows (Knowledge/Experience/
/// Evolution/Runtime/Review/Software, Vision Milestones V9-V11). Never
/// re-derives engineering decisions — only maps
/// `DatabaseTable`/`ApiEndpoint`'s already-computed shape onto
/// `WorldNode`/`WorldEdge`'s vocabulary. Database tables unify with the
/// EXISTING `WorldNodeKind.entity` identity space (a backend table and
/// its frontend entity are the same real thing) — the resolver's
/// `stableId` is the entity id, matching `ExperienceGraphBridge`'s own
/// structural convention exactly, so a genuinely shared entity resolves
/// to the SAME node whether observed from the frontend or the backend.
library;

import '../../backend_engineering/backend_engineering_plan.dart';
import '../entity_resolver.dart';
import '../graph_update.dart';
import '../world_edge.dart';
import '../world_node.dart';
import '../world_types.dart';

class BackendGraphBridge {
  final EntityResolver _resolver;

  const BackendGraphBridge({EntityResolver resolver = const EntityResolver()})
    : _resolver = resolver;

  GraphUpdate bridge(BackendEngineeringPlan plan) {
    final nodes = <WorldNode>[];
    final edges = <WorldEdge>[];

    for (final table in plan.database.tables) {
      nodes.add(
        WorldNode(
          identity: _resolver.resolve(WorldNodeKind.entity, stableId: table.id),
          kind: WorldNodeKind.entity,
          label: table.name,
        ),
      );
    }

    for (final endpoint in plan.api.endpoints) {
      final endpointIdentity = _resolver.resolve(
        WorldNodeKind.backendEndpoint,
        stableId: endpoint.id,
      );
      nodes.add(
        WorldNode(
          identity: endpointIdentity,
          kind: WorldNodeKind.backendEndpoint,
          label: '${endpoint.method.name.toUpperCase()} ${endpoint.path}',
        ),
      );

      final entityIdentity = _resolver.resolve(
        WorldNodeKind.entity,
        stableId: endpoint.entityId,
      );
      edges.add(
        WorldEdge(
          fromId: endpointIdentity,
          toId: entityIdentity,
          kind: RelationshipKind.references,
          evidence: const GraphEvidence(
            sourceGraph: 'BackendEngineering',
            sourceNodeId: 'api',
          ),
        ),
      );
    }

    return GraphUpdate(addedNodes: nodes, addedEdges: edges);
  }
}
