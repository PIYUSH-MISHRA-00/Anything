/// RequirementGraphBridge — Implementation Specification IS-R24.
/// Translates a real `RequirementGraph` into a `GraphUpdate`, the same
/// pure-translation pattern every other Bridge follows. REALITY: before
/// this milestone, `RequirementGraph` was NEVER ingested into the World
/// Graph anywhere (confirmed by grep: zero `RequirementGraph` references
/// in `world_model_coordinator.dart`) — the World Graph only ever learned
/// about architecture-level entities via `SolutionArchitectureGraphBridge`
/// (R17)/`BackendGraphBridge` (R8), several stages downstream of the raw
/// requirement extraction.
///
/// Narrow and additive by design, matching R17's own "the two genuinely
/// NEW contributions" framing for the same reason (avoid re-ingesting
/// entities/permissions those bridges already cover):
///
/// 1. `RequirementNodeType.capability` nodes — a real, standalone
///    "this capability is required" signal from `RequirementExtractor`,
///    distinct from `ArchitectureCandidate.capabilities`
///    (`CapabilityDecision`, a RESOLVED capability decision, several
///    planning stages later) — never previously ingested under either
///    name.
/// 2. `view`/`action` -> `references` -> `entity` relations — real,
///    requirement-level traceability ("this specific view/action need
///    references this entity") that no other bridge captures; entities
///    resolve via the SAME `stableId: entity.id` convention every other
///    bridge uses, so they unify into the SAME node other bridges already
///    ingest, never a duplicate.
///
/// Field/constraint/storage/state/navigation nodes are deliberately NOT
/// ingested: they are real, but they add no new World Graph SIGNAL beyond
/// "this entity has fields" (already implied by the entity node existing)
/// — ingesting every field/constraint as its own node would flood the
/// graph with data no existing consumer reads, the same restraint R14/R17
/// applied to their own bridges.
library;

import '../../software_architect/requirement_graph.dart';
import '../entity_resolver.dart';
import '../graph_update.dart';
import '../world_edge.dart';
import '../world_node.dart';
import '../world_types.dart';

class RequirementGraphBridge {
  final EntityResolver _resolver;

  const RequirementGraphBridge({EntityResolver resolver = const EntityResolver()}) : _resolver = resolver;

  GraphUpdate bridge(RequirementGraph graph) {
    final nodes = <WorldNode>[];
    final edges = <WorldEdge>[];

    for (final node in graph.nodesOfType(RequirementNodeType.capability)) {
      final capabilityId = node.label;
      nodes.add(WorldNode(identity: _resolver.resolve(WorldNodeKind.capability, stableId: capabilityId), kind: WorldNodeKind.capability, label: capabilityId));
    }

    for (final node in [...graph.nodesOfType(RequirementNodeType.view), ...graph.nodesOfType(RequirementNodeType.action)]) {
      for (final relation in graph.relationsFrom(node.id)) {
        if (relation.type != RequirementRelationType.references) continue;
        final target = graph.nodeById(relation.toId);
        if (target == null || target.type != RequirementNodeType.entity) continue;
        final entityId = target.id.substring('entity:'.length);

        final sourceIdentity = _resolver.resolve(WorldNodeKind.softwareComponent, stableId: node.id);
        final entityIdentity = _resolver.resolve(WorldNodeKind.entity, stableId: entityId);
        nodes.add(WorldNode(identity: sourceIdentity, kind: WorldNodeKind.softwareComponent, label: node.label));
        nodes.add(WorldNode(identity: entityIdentity, kind: WorldNodeKind.entity, label: target.label));
        edges.add(
          WorldEdge(
            fromId: sourceIdentity,
            toId: entityIdentity,
            kind: RelationshipKind.references,
            evidence: GraphEvidence(sourceGraph: 'RequirementGraph', sourceNodeId: node.id),
          ),
        );
      }
    }

    return GraphUpdate(addedNodes: nodes, addedEdges: edges);
  }
}
