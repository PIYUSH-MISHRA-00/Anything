/// EvolutionGraphBridge — translates a real EvolutionRoadmap (V7, the
/// only Evolution artifact ExecutionPlanReady actually exposes) into a
/// GraphUpdate. Every evolution proposal becomes a real `evolution` node
/// related to whatever it would improve — never a duplicate of
/// Evolution's own reasoning, purely a translation of its already-typed
/// output.
library;

import '../../evolution/evolution_roadmap.dart';
import '../entity_resolver.dart';
import '../graph_update.dart';
import '../world_edge.dart';
import '../world_node.dart';
import '../world_types.dart';

class EvolutionGraphBridge {
  final EntityResolver _resolver;

  const EvolutionGraphBridge({EntityResolver resolver = const EntityResolver()}) : _resolver = resolver;

  GraphUpdate bridge(EvolutionRoadmap roadmap) {
    final nodes = <WorldNode>[];
    final edges = <WorldEdge>[];

    for (final proposal in roadmap.allProposals) {
      final opportunity = proposal.candidate.opportunity;
      final proposalIdentity = _resolver.resolve(WorldNodeKind.evolution, stableId: opportunity.id);
      nodes.add(WorldNode(identity: proposalIdentity, kind: WorldNodeKind.evolution, label: opportunity.description));

      // The affected node's id doesn't always align with
      // ExperienceGraphBridge's structural entity fingerprint (it may be
      // a raw entity id or an architecture decision id) — this bridge
      // adds its own node for it so the edge is never dangling, even
      // though it may not merge with an ExperienceGraphBridge node for
      // the "same" real entity. Documented honestly as a known
      // limitation, not silently papered over.
      final affectedNodeId = opportunity.reason.evidence.affectedNodeId;
      if (affectedNodeId.isNotEmpty) {
        final affectedIdentity = _resolver.resolve(WorldNodeKind.entity, stableId: affectedNodeId);
        nodes.add(WorldNode(identity: affectedIdentity, kind: WorldNodeKind.entity, label: affectedNodeId));
        edges.add(
          WorldEdge(
            fromId: proposalIdentity,
            toId: affectedIdentity,
            kind: RelationshipKind.improves,
            evidence: GraphEvidence(sourceGraph: 'EvolutionRoadmap', sourceNodeId: opportunity.id),
          ),
        );
      }
    }

    return GraphUpdate(addedNodes: nodes, addedEdges: edges);
  }
}
