/// Affected-entity identification — Implementation Specification IS-R24.
/// A real, deterministic function of the ALREADY-REAL
/// `RequirementGraphDiff` (R3) / `ArchitectureDiff` (R4): translates "these
/// nodes/decisions changed" into "these entity ids are affected" — the
/// missing link R24 asks for ("Graph -> Diff -> Affected Nodes"). Never a
/// new diff algorithm; both diff types are consumed exactly as R3/R4 built
/// them.
library;

import '../software_architect/architecture_candidate_diff.dart';
import '../software_architect/requirement_graph_diff.dart';

/// The set of entity ids a diff touched — real, deduplicated, never a
/// fabricated superset ("when unsure, mark everything affected" would
/// defeat the point of incremental synthesis).
class AffectedEntities {
  final Set<String> entityIds;

  const AffectedEntities(this.entityIds);

  static const AffectedEntities none = AffectedEntities({});

  bool get isEmpty => entityIds.isEmpty;

  AffectedEntities merge(AffectedEntities other) => AffectedEntities({...entityIds, ...other.entityIds});
}

class AffectedEntityAnalyzer {
  const AffectedEntityAnalyzer();

  /// `RequirementNode.id` is always `<prefix>:<entityId>` or
  /// `<prefix>:<entityId>.<childId>` (`RequirementExtractor`'s own real,
  /// established convention — e.g. `entity:note`, `field:note.title`,
  /// `constraint:note.title`) — never opaque. Every node type is rooted at
  /// exactly one entity except `capability:<id>` (a capability id, not an
  /// entity id — correctly excluded here) and `navigation:<viewId>` (rooted
  /// at a view, not an entity — excluded for the same reason: this
  /// analyzer only ever reports real entity ids, never a fabricated one
  /// from a node that structurally has none).
  static const _entityRootedPrefixes = {'entity', 'field', 'relationship', 'constraint', 'storage', 'state'};

  AffectedEntities fromRequirementDiff(RequirementGraphDiff diff) {
    final ids = <String>{};
    for (final node in [...diff.addedNodes, ...diff.removedNodes]) {
      final colon = node.id.indexOf(':');
      if (colon < 0) continue;
      final prefix = node.id.substring(0, colon);
      if (!_entityRootedPrefixes.contains(prefix)) continue;
      final rest = node.id.substring(colon + 1);
      final dot = rest.indexOf('.');
      ids.add(dot < 0 ? rest : rest.substring(0, dot));
    }
    return AffectedEntities(ids);
  }

  /// `ArchitectureDiff`'s own decision types are already real,
  /// directly-entity-keyed values (`EntityDecision.entityId`,
  /// `FieldDecision.entityId`, `RelationshipDecision.fromEntityId`/
  /// `.toEntityId`) — read straight off them, no parsing needed.
  AffectedEntities fromArchitectureDiff(ArchitectureDiff diff) {
    final ids = <String>{
      for (final e in [...diff.addedEntities, ...diff.removedEntities]) e.entityId,
      for (final f in [...diff.addedFields, ...diff.removedFields]) f.entityId,
      for (final r in [...diff.addedRelationships, ...diff.removedRelationships]) ...[r.fromEntityId, r.toEntityId],
    };
    return AffectedEntities(ids);
  }
}
