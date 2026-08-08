/// SolutionArchitectureGraphBridge — Implementation Milestone R17.
/// Translates a real `SemanticSolutionArchitecture` into a `GraphUpdate`,
/// the same pure-translation pattern every other Bridge follows. Narrow
/// and additive by design: `BackendGraphBridge` (R8) already ingests
/// `BackendEngineeringPlan`'s entities/endpoints — re-adding them here
/// would duplicate. The two genuinely NEW contributions this bridge makes:
///
/// 1. Frontend entities (`ArchitectureCandidate.entities`) — REALITY
///    before this milestone: frontend architecture was never ingested
///    into the World Graph at all (confirmed by grep: zero
///    `ArchitectureCandidate` references in `world_model_coordinator.dart`
///    before R17). Entities resolve via the SAME `stableId: entity.id`
///    convention `BackendGraphBridge` already uses, so a genuinely shared
///    entity unifies into the SAME node whether observed from the
///    frontend or the backend side — never a duplicate.
/// 2. Permission-requires-capability edges (`PermissionDecision`) — also
///    never previously ingested anywhere.
///
/// The real [CachingModel] signal is ingested as one
/// `WorldNodeKind.softwareComponent` node (the EXISTING catch-all kind
/// R14's pattern analyzers already reuse) only when caching is real —
/// never a new `WorldNodeKind` value for one boolean signal.
library;

import '../../solution_architecture/solution_architecture.dart';
import '../entity_resolver.dart';
import '../graph_update.dart';
import '../world_edge.dart';
import '../world_node.dart';
import '../world_types.dart';

class SolutionArchitectureGraphBridge {
  final EntityResolver _resolver;

  const SolutionArchitectureGraphBridge({
    EntityResolver resolver = const EntityResolver(),
  }) : _resolver = resolver;

  GraphUpdate bridge(SemanticSolutionArchitecture architecture) {
    final nodes = <WorldNode>[];
    final edges = <WorldEdge>[];

    for (final entity in architecture.frontend.entities) {
      nodes.add(
        WorldNode(
          identity: _resolver.resolve(
            WorldNodeKind.entity,
            stableId: entity.entityId,
          ),
          kind: WorldNodeKind.entity,
          label: entity.name,
        ),
      );
    }

    for (final permission in architecture.frontend.permissions) {
      final permissionIdentity = _resolver.resolve(
        WorldNodeKind.softwareComponent,
        stableId: 'permission:${permission.permission}',
      );
      final capabilityIdentity = _resolver.resolve(
        WorldNodeKind.capability,
        stableId: permission.requiredByCapabilityId,
      );
      nodes.add(
        WorldNode(
          identity: permissionIdentity,
          kind: WorldNodeKind.softwareComponent,
          label: 'permission:${permission.permission}',
        ),
      );
      nodes.add(
        WorldNode(
          identity: capabilityIdentity,
          kind: WorldNodeKind.capability,
          label: permission.requiredByCapabilityId,
        ),
      );
      edges.add(
        WorldEdge(
          fromId: permissionIdentity,
          toId: capabilityIdentity,
          kind: RelationshipKind.dependsOn,
          evidence: const GraphEvidence(
            sourceGraph: 'SemanticSolutionArchitecture',
            sourceNodeId: 'permission',
          ),
        ),
      );
    }

    if (architecture.caching.employsCaching) {
      nodes.add(
        WorldNode(
          identity: _resolver.resolve(
            WorldNodeKind.softwareComponent,
            stableId: 'caching:${architecture.caching.sourceStrategy.name}',
          ),
          kind: WorldNodeKind.softwareComponent,
          label: 'caching:${architecture.caching.sourceStrategy.name}',
        ),
      );
    }

    return GraphUpdate(addedNodes: nodes, addedEdges: edges);
  }
}
