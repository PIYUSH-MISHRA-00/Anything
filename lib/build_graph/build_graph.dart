/// Universal Build Graph — Implementation Milestone R11. A real, typed,
/// LANGUAGE-INDEPENDENT dependency graph over `CanonicalImplementationModel`
/// (R9), mirroring the World Graph's proven `{id, kind, label}` node /
/// typed-relationship-kind edge shape (`lib/world_model/world_node.dart`,
/// `world_edge.dart`, Vision Milestone V9) — never a new graph shape
/// invented from scratch, never reusing `WorldNodeKind`/`EntityIdentity`
/// directly (those are World-Model-specific vocabulary — entity/
/// knowledge/capability at the WHOLE-APPLICATION level; a build graph
/// node is a narrower, generation-scoped concept).
///
/// Node kinds map 1:1 onto `CanonicalImplementationModel`'s own real
/// categories (entity/repository/controller/capability) — never invented
/// "module"/"package"/"library" distinctions this data doesn't actually
/// carry (Rule 5: never fabricate). DTOs/Validators/Services are
/// deliberately NOT modeled as separate build-graph nodes this milestone
/// — a real, honest, named scope limitation (see
/// `docs/architecture/UNIVERSAL_BUILD_GRAPH.md`), not a silent gap.
library;

enum BuildNodeKind { entity, repository, controller, capability }

enum BuildRelationshipKind { dependsOn }

class BuildGraphNode {
  final String id;
  final BuildNodeKind kind;
  final String label;

  const BuildGraphNode({
    required this.id,
    required this.kind,
    required this.label,
  });

  @override
  bool operator ==(Object other) =>
      other is BuildGraphNode &&
      other.id == id &&
      other.kind == kind &&
      other.label == label;

  @override
  int get hashCode => Object.hash(id, kind, label);
}

class BuildGraphEdge {
  final String fromId;
  final String toId;
  final BuildRelationshipKind kind;

  const BuildGraphEdge({
    required this.fromId,
    required this.toId,
    required this.kind,
  });

  @override
  bool operator ==(Object other) =>
      other is BuildGraphEdge &&
      other.fromId == fromId &&
      other.toId == toId &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(fromId, toId, kind);
}
