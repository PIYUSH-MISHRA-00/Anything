/// ExperienceGraphBridge — translates a real, already-persisted
/// Experience (ExperienceMetadataRecord + ExperiencePackage, read via the
/// existing SqliteExperienceRepository) into a GraphUpdate. Entity nodes
/// use EntityResolver's structural fingerprint — never entity data,
/// never field values, only entity name + field TYPE names — so two
/// Experiences with the same entity shape resolve to the same
/// SemanticEntity, exactly as required by "no duplicate identities."
library;

import '../../creation/experience_package.dart';
import '../../storage/sqlite_experience_repository.dart';
import '../entity_resolver.dart';
import '../graph_update.dart';
import '../world_edge.dart';
import '../world_node.dart';
import '../world_types.dart';

class ExperienceGraphBridge {
  final EntityResolver _resolver;

  const ExperienceGraphBridge({
    EntityResolver resolver = const EntityResolver(),
  }) : _resolver = resolver;

  GraphUpdate bridge(
    ExperienceMetadataRecord metadata,
    ExperiencePackage package,
  ) {
    final experienceIdentity = _resolver.resolve(
      WorldNodeKind.experience,
      stableId: metadata.id,
    );
    final nodes = <WorldNode>[
      WorldNode(
        identity: experienceIdentity,
        kind: WorldNodeKind.experience,
        label: metadata.name,
      ),
    ];
    final edges = <WorldEdge>[];

    for (final entity in package.data?.entities ?? const <DataEntitySchema>[]) {
      final fieldTypeNames = entity.fields.map((f) => f.type).toList();
      final entityIdentity = _resolver.resolve(
        WorldNodeKind.entity,
        structuralSignature: [entity.name, ...fieldTypeNames],
      );
      nodes.add(
        WorldNode(
          identity: entityIdentity,
          kind: WorldNodeKind.entity,
          label: entity.name,
        ),
      );
      edges.add(
        WorldEdge(
          fromId: experienceIdentity,
          toId: entityIdentity,
          kind: RelationshipKind.contains,
          evidence: GraphEvidence(
            sourceGraph: 'ExperiencePackage.data',
            sourceNodeId: entity.id,
          ),
        ),
      );
    }

    for (final capability in package.capabilityDeclarations) {
      final capabilityIdentity = _resolver.resolve(
        WorldNodeKind.capability,
        stableId: capability.capabilityId,
      );
      nodes.add(
        WorldNode(
          identity: capabilityIdentity,
          kind: WorldNodeKind.capability,
          label: capability.capabilityId,
        ),
      );
      edges.add(
        WorldEdge(
          fromId: experienceIdentity,
          toId: capabilityIdentity,
          kind: RelationshipKind.consumes,
          evidence: GraphEvidence(
            sourceGraph: 'ExperiencePackage.capabilityDeclarations',
            sourceNodeId: capability.capabilityId,
          ),
        ),
      );
    }

    return GraphUpdate(addedNodes: nodes, addedEdges: edges);
  }
}
