/// EvolutionGraphBridge — translates a real EvolutionRoadmap (V7, the
/// only Evolution artifact ExecutionPlanReady actually exposes) into a
/// GraphUpdate. Every evolution proposal becomes a real `evolution` node
/// related to whatever it would improve — never a duplicate of
/// Evolution's own reasoning, purely a translation of its already-typed
/// output.
///
/// Evolution/World identity unification (Vision Milestone V10): when the
/// caller supplies the real AppBlueprint a proposal's `affectedNodeId`
/// came from, this bridge resolves the SAME structural EntityIdentity
/// ExperienceGraphBridge would compute for that entity (name + sorted
/// field-type names, via the same
/// `GenericPackageBuilder.mapBlueprintFieldTypeToDataFieldType` mapping
/// used to build the real ExperiencePackage.data) — one entity, one
/// identity, resolving V9's own documented limitation that these two
/// bridges could otherwise produce two separate nodes for the same real
/// entity. Falls back to the prior stable-id-based node (never dangling,
/// never a fabricated match) when no blueprint is supplied or the id
/// doesn't name a real entity (e.g. an architecture posture decision id).
library;

import '../../evolution/evolution_roadmap.dart';
import '../../synthesis/app_blueprint.dart';
import '../../synthesis/generic_package_builder.dart';
import '../entity_resolver.dart';
import '../graph_update.dart';
import '../world_edge.dart';
import '../world_node.dart';
import '../world_types.dart';

class EvolutionGraphBridge {
  final EntityResolver _resolver;

  const EvolutionGraphBridge({EntityResolver resolver = const EntityResolver()})
    : _resolver = resolver;

  GraphUpdate bridge(EvolutionRoadmap roadmap, {AppBlueprint? blueprint}) {
    final nodes = <WorldNode>[];
    final edges = <WorldEdge>[];

    for (final proposal in roadmap.allProposals) {
      final opportunity = proposal.candidate.opportunity;
      final proposalIdentity = _resolver.resolve(
        WorldNodeKind.evolution,
        stableId: opportunity.id,
      );
      nodes.add(
        WorldNode(
          identity: proposalIdentity,
          kind: WorldNodeKind.evolution,
          label: opportunity.description,
        ),
      );

      final affectedNodeId = opportunity.reason.evidence.affectedNodeId;
      if (affectedNodeId.isEmpty) continue;

      final matchedEntity = blueprint?.entities
          .where((e) => e.id == affectedNodeId)
          .firstOrNull;
      final WorldNode affectedNode;
      if (matchedEntity != null) {
        // The real entity is known — unify with ExperienceGraphBridge's
        // identity for it, byte-for-byte the same fingerprint.
        final fieldTypeNames = matchedEntity.fields
            .map(
              (f) => GenericPackageBuilder.mapBlueprintFieldTypeToDataFieldType(
                f.type,
              ),
            )
            .toList();
        final identity = _resolver.resolve(
          WorldNodeKind.entity,
          structuralSignature: [matchedEntity.name, ...fieldTypeNames],
        );
        affectedNode = WorldNode(
          identity: identity,
          kind: WorldNodeKind.entity,
          label: matchedEntity.name,
        );
      } else {
        // Not a known entity (or no blueprint supplied) — never
        // fabricate a match; anchor on the raw id so the edge is never
        // dangling.
        final identity = _resolver.resolve(
          WorldNodeKind.entity,
          stableId: affectedNodeId,
        );
        affectedNode = WorldNode(
          identity: identity,
          kind: WorldNodeKind.entity,
          label: affectedNodeId,
        );
      }
      nodes.add(affectedNode);

      edges.add(
        WorldEdge(
          fromId: proposalIdentity,
          toId: affectedNode.identity,
          kind: RelationshipKind.improves,
          evidence: GraphEvidence(
            sourceGraph: 'EvolutionRoadmap',
            sourceNodeId: opportunity.id,
          ),
        ),
      );
    }

    return GraphUpdate(addedNodes: nodes, addedEdges: edges);
  }
}
